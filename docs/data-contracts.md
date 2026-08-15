# Data contracts

Source of truth for the v1 schema and JSON payloads. Skills must follow this file. A future TypeScript backend should implement the same shapes.

Language: English identifiers. User-visible strings stored in JSON (titles, intent, summaries) may be Swedish.

## Conventions

- Table names have no `training_` prefix.
- Every row has `user_id uuid`. There is no `auth.users` foreign key in v1.
- Enums are `text` columns with `check` constraints.
- `user_profiles.data` stores only `confirmed` fields.
- Observations belong in `events` with `source_status = observation`.
- AI conclusions belong in `events` with `source = ai` and `source_status = inference`, or later in `recommendations.rationale`.
- `events` is append-only. Corrections are new rows, never UPDATE or DELETE.
- After `0001_init.sql` is applied, ChatGPT must not run DDL. Schema changes belong in new migration files.

## Tables

### `user_profiles`

One row per user. `user_id` is unique.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` pk | `gen_random_uuid()` |
| `user_id` | `uuid` not null unique | Personal user in v1 |
| `locale` | `text` not null | Default `sv-SE` |
| `timezone` | `text` not null | Default `Europe/Stockholm` |
| `week_start` | `smallint` not null | Default `1` (Monday) |
| `onboarding_status` | `text` not null | `not_started \| in_progress \| complete` |
| `safety_status` | `text` not null | `unknown \| cleared \| restricted \| stop` |
| `data` | `jsonb` not null | Confirmed profile payload |
| `provenance` | `jsonb` not null | Per-field provenance map |
| `created_at` | `timestamptz` not null | |
| `updated_at` | `timestamptz` not null | Maintained by trigger |

### `plans`

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` pk | |
| `user_id` | `uuid` not null | |
| `status` | `text` not null | `proposed \| active \| completed \| superseded \| archived` |
| `period_start` | `date` not null | Monday of the ISO week |
| `period_end` | `date` not null | Sunday of the same week |
| `version` | `int` not null | Starts at `1` |
| `supersedes_plan_id` | `uuid` null | Previous plan, if any |
| `title` | `text` | User-facing, Swedish |
| `intent` | `text` | User-facing, Swedish |
| `content` | `jsonb` not null | Days and sessions |
| `created_at` | `timestamptz` not null | |
| `activated_at` | `timestamptz` | Set when status becomes `active` |
| `archived_at` | `timestamptz` | |

v1 allows more than one `active` row at the database level. Skills must keep exactly one `active` plan per user by superseding the previous one.

### `events`

Append-only history.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` pk | |
| `user_id` | `uuid` not null | |
| `type` | `text` not null | See event types |
| `occurred_at` | `timestamptz` not null | When it happened |
| `recorded_at` | `timestamptz` not null | When it was written |
| `source` | `text` not null | `user \| ai \| system` |
| `source_status` | `text` not null | `confirmed \| observation \| inference` |
| `plan_id` | `uuid` null | |
| `payload` | `jsonb` not null | |
| `created_at` | `timestamptz` not null | |

v1 event types:

- `safety_screening_completed`
- `profile_confirmed`
- `profile_updated`
- `plan_proposed`
- `plan_activated`
- `plan_superseded`

### `recommendations`

Created in v1, unused by the first vertical.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` pk | |
| `user_id` | `uuid` not null | |
| `type` | `text` not null | `plan_change \| nutrition \| recovery \| other` |
| `scope` | `text` not null | `minor \| major` |
| `status` | `text` not null | `proposed \| accepted \| rejected \| expired \| applied` |
| `plan_id` | `uuid` null | |
| `summary` | `text` not null | User-facing, Swedish |
| `rationale` | `jsonb` not null | AI conclusion; never copy into `user_profiles.data` |
| `payload` | `jsonb` not null | |
| `created_at` | `timestamptz` not null | |
| `decided_at` | `timestamptz` | |

## `user_profiles.data`

Only confirmed fields. Omit keys that are not yet confirmed.

```json
{
  "goals": {
    "primary": "strength",
    "secondary": ["running", "mobility"],
    "notes": ""
  },
  "experience": {
    "strength": "intermediate",
    "running": "beginner",
    "mobility": "beginner",
    "training_age_years": 4
  },
  "availability": {
    "days_per_week": 4,
    "session_minutes": 60,
    "preferred_days": ["mon", "wed", "fri", "sun"],
    "constraints": ""
  },
  "equipment": {
    "location": "gym",
    "items": ["barbell", "dumbbells", "rack", "bench"]
  },
  "health": {
    "injuries": [],
    "pain": [],
    "conditions": [],
    "medications_mentioned": false
  },
  "nutrition": {
    "goal": "",
    "allergies": [],
    "exclusions": [],
    "preferences": []
  },
  "recovery": {
    "sleep_hours": null,
    "stress": null
  },
  "life": {
    "travel": "",
    "schedule_notes": ""
  },
  "modalities": ["strength", "running", "mobility", "recovery"]
}
```

Field rules:

- `goals.primary`: `strength | running | mobility | recovery | general`
- `experience.*` (except `training_age_years`): `beginner | intermediate | advanced`
- `equipment.location`: `gym | home | mixed`
- `preferred_days` and `modalities`: `mon | tue | wed | thu | fri | sat | sun` and `strength | running | mobility | recovery`
- `health.*` stores the user's own words and lists, not diagnoses
- `medications_mentioned` is a boolean flag only. Do not store drug names in `data`. If the user mentions medication, record an observation event and never give medication advice
- `modalities` is the set the user wants in weekly plans

## `user_profiles.provenance`

Keys are dotted paths into `data`, plus `safety_status` when screening is confirmed.

```json
{
  "safety_status": {
    "source": "user",
    "status": "confirmed",
    "confirmed_at": "2026-08-15T08:00:00Z",
    "event_id": "00000000-0000-0000-0000-000000000001"
  },
  "goals.primary": {
    "source": "user",
    "status": "confirmed",
    "confirmed_at": "2026-08-15T08:00:00Z",
    "event_id": "00000000-0000-0000-0000-000000000002"
  }
}
```

`source`: `user | system`  
`status` in this map: always `confirmed` (unconfirmed fields are absent from both `data` and `provenance`)

## Minimum profile for a plan

`training-plan` may run only when all of the following are confirmed:

- `safety_status` is `cleared` or `restricted` (never `stop` or `unknown`)
- `data.goals.primary`
- `data.availability.days_per_week` or `data.availability.preferred_days`
- `data.availability.session_minutes`
- `data.equipment.location`
- `data.modalities` (non-empty)

If `safety_status` is `restricted`, the plan must stay conservative and respect stated injuries and pain.

## `plans.content`

```json
{
  "week_label": "2026-W33",
  "modalities": ["strength", "running", "mobility", "recovery"],
  "days": [
    {
      "date": "2026-08-17",
      "weekday": "mon",
      "sessions": [
        {
          "id": "s1",
          "modality": "strength",
          "title": "Undre kropp",
          "duration_min": 60,
          "rpe_target": 7,
          "blocks": [
            {
              "name": "Main",
              "items": [
                {
                  "name": "Back squat",
                  "sets": 3,
                  "reps": "6-8",
                  "load": "RPE 7",
                  "notes": ""
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

Session `modality`: `strength | running | mobility | recovery`.

Block items are intentionally loose in v1:

- Strength: `name`, `sets`, `reps`, `load`, `notes`
- Running: `name`, `duration_min` and/or `distance_km`, `intensity`, `notes`
- Mobility: `name`, `duration_min`, `notes`
- Recovery: `name`, `duration_min`, `notes`

## Event payloads (v1)

`safety_screening_completed`

```json
{
  "safety_status": "cleared",
  "answers": {
    "chest_pain": false,
    "dizziness": false,
    "uncontrolled_condition": false,
    "exercise_pain": false,
    "medical_advice_against_exercise": false
  },
  "notes": ""
}
```

`profile_confirmed` / `profile_updated`

```json
{
  "fields": ["goals.primary", "availability.days_per_week"],
  "summary": "Bekräftade mål och tid."
}
```

`plan_proposed` / `plan_activated` / `plan_superseded`

```json
{
  "period_start": "2026-08-17",
  "period_end": "2026-08-23",
  "week_label": "2026-W33",
  "superseded_plan_id": null
}
```

## Identity in v1

ChatGPT Project instructions hold a single `USER_ID`. Every query must filter on that id. Do not invent a second user.
