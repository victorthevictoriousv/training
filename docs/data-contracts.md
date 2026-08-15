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
- After the initial schema is applied, ChatGPT must not run DDL. Schema changes belong in new migration files.
- RLS is enabled with no `anon`/`authenticated` policies. The Data API is denied. ChatGPT uses a privileged connection.

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

Event types:

- `safety_screening_completed`
- `profile_confirmed`
- `profile_updated`
- `plan_proposed`
- `plan_activated`
- `plan_superseded`
- `exercise_logged`
- `session_completed`
- `session_missed`
- `activity_logged`

Current load for an exercise on a date is the latest `exercise_logged` for that `user_id + payload.date + payload.exercise_key`. Last working load is the latest log for that `exercise_key` on any date. PR is max numeric `load_kg` for that key. Current extra-plan activity for a date is the latest `activity_logged` per `user_id + payload.date + payload.activity_key + payload.instance` (missing `instance` = 1). Day load is the sum of those current bouts. Do not UPDATE earlier rows. Do not store PRs in a separate table. Do not mix `activity_logged` into exercise PR or last-load queries.

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
    "constraints": "",
    "two_a_day": "some_days",
    "windows": [
      { "slot": "lunch", "modality": "strength", "minutes": 45 },
      { "slot": "evening", "modality": "running" }
    ],
    "anchor": "Styrka på lunchen när dagen har gym"
  },
  "equipment": {
    "location": "gym",
    "items": ["barbell", "dumbbells", "rack", "bench"],
    "home_gym_substitutions": [
      {
        "preferred_key": "hip_abductor_machine",
        "preferred_name": "Höftabduktion maskin",
        "home_key": "banded_lateral_walk",
        "home_name": "Sidogång med band"
      }
    ]
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
  "lifestyle": {
    "habits": [
      {
        "key": "treadmill_walk",
        "name": "Gåband",
        "kind": "lifestyle",
        "plan_inclusion": "background",
        "typical_duration_min": 30,
        "typical_speed_kmh": 4.5,
        "typical_distance_km": null,
        "times_per_day": 2,
        "days": ["mon", "tue", "wed", "thu", "fri"],
        "notes": "hemma, arbetsdagar"
      },
      {
        "key": "yoga",
        "name": "Yoga",
        "kind": "lifestyle",
        "plan_inclusion": "background",
        "typical_duration_min": 20,
        "typical_speed_kmh": null,
        "typical_distance_km": null,
        "times_per_day": 1,
        "days": ["mon", "tue", "wed", "thu", "fri", "sun"],
        "notes": "lätt rörlighet, även vissa vilodagar"
      }
    ]
  },
  "modalities": ["strength", "running", "mobility", "recovery"]
}
```

Field rules:

- `goals.primary`: `strength | running | mobility | recovery | general`
- `goals.notes` may include that training is a hobby or they like high volume, in their words. Do not infer elite volume tolerance
- `experience.*` (except `training_age_years`): `beginner | intermediate | advanced`
- `equipment.location`: `gym | home | mixed`
- `equipment.home_gym_substitutions` is optional. Confirmed pairs for the routine gym only: first-choice exercise (`preferred_key`, `preferred_name`) that is missing there, and the home-gym alternative (`home_key`, `home_name`). One routine gym in v1. Not an AI guess. Provenance key is `equipment.home_gym_substitutions` for the whole array, same pattern as `lifestyle.habits`. Keys are lowercase snake_case. Omit the array until at least one pair is confirmed. Do not store a second named gym
- `preferred_days` and `modalities`: `mon | tue | wed | thu | fri | sat | sun` and `strength | running | mobility | recovery`
- `availability.days_per_week` is training **days**, not session count
- `availability.session_minutes` is a fallback length; per-window `minutes` on `windows` win when present
- `availability.windows` is optional. Possible slots (`morning | lunch | evening`), not a daily mandate. Each: `slot`, optional `modality`, optional `minutes`
- `availability.two_a_day`: `never | some_days` when confirmed. `some_days` allows two sessions the same day on some days, not every training day. Do not store a weekly gym+run quota
- `availability.anchor` is optional preference text the planner may drop under poor recovery or time pressure
- `health.*` stores the user's own words and lists, not diagnoses
- `medications_mentioned` is a boolean flag only. Do not store drug names in `data`. If the user mentions medication, record an observation event and never give medication advice
- `modalities` is the set the user wants in weekly plans
- `lifestyle.habits` is optional. Recurring activity outside the four training modalities. Pattern only: an instance must be `activity_logged` to count as done. Do not store kcal, MET, or TDEE here
- habit `kind`: `lifestyle` (easy everyday movement or easy mobility/yoga ritual) or `extra` (recreational load such as climbing or hiking)
- habit `plan_inclusion`: `background` (never a plan session) or `scheduled` (insert a session on `days`)
- Default `plan_inclusion`: `background` for `kind` `lifestyle`; ask for `extra` when `days` are named (suggest `scheduled`); `background` if no days
- habit `days`: `mon | tue | wed | thu | fri | sat | sun`
- habit `key`: lowercase snake_case, stable. Do not add a habit `key` as a `data.modalities` value

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
          "slot": "lunch",
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

Session `modality`: `strength | running | mobility | recovery | other`.

Optional session `slot`: `morning | lunch | evening`. Set when the window is known. Omit on older plans.

`other` is only for `plan_inclusion = scheduled` habits (climbing, hiking). Do not put `other` in top-level `content.modalities`. Set `habit_key` on those sessions. Background habits are not sessions.

Block items are intentionally loose in v1:

- Strength: `name`, `sets`, `reps`, `load`, `notes`. Optional `key`. Optional `preferred` (`name`, `key`) when the prescribed home-gym exercise differs from the first-choice exercise
- Running: `name`, `duration_min` and/or `distance_km`, `intensity`, `notes`
- Mobility: `name`, `duration_min`, `notes`
- Recovery: `name`, `duration_min`, `notes`
- Other (scheduled habit): `name`, `duration_min` and/or `distance_km`, `notes`

`name` / `key` is what they do at the routine gym. `preferred` is omitted when it is the same as `name`. Set `key` when a substitution exists so logs can tell home vs first-choice apart. A this-week swap (they want another exercise, not that the gym lacks it) does not add `preferred` and does not write `home_gym_substitutions`.

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

`exercise_logged`

```json
{
  "date": "2026-08-15",
  "plan_id": "8755805b-b916-4e59-bb6a-e2a91ce9dd9d",
  "session_id": "s1",
  "exercise_key": "dumbbell_bench_press",
  "exercise_name": "Dumbbell Bench Press",
  "sets": [
    { "load_kg": 80, "load_text": "80 kg", "reps": 5, "rpe": null }
  ],
  "raw_text": "bänk 80x5"
}
```

`reps` must be an integer or null. Never store a range (`8–10`) or `reps_text`. If only a range is known, store the low end. Dumbbell `load_kg` is per implement; `load_text` like `30 kg/hantel`.

A shortcut session log may copy last working `load_kg` / reps into a new `exercise_logged` after one user `godkänn`. Until then it is not a confirmed fact. Do not copy planned RPE text into `load_kg`. Optional `notes`: `enligt senaste`. `raw_text` may be the user’s phrase (`logga gympasset`).

Running set example: `{ "load_kg": null, "load_text": "32 min", "reps": null, "rpe": 3, "duration_min": 32, "distance_km": null }`.

`session_completed` / `session_missed`

```json
{
  "date": "2026-08-15",
  "plan_id": "8755805b-b916-4e59-bb6a-e2a91ce9dd9d",
  "session_id": "s1",
  "status": "completed",
  "session_rpe": 7,
  "notes": ""
}
```

`status`: `completed | partial | missed`. For running, put duration/distance in `notes` or log a matching `exercise_logged` with `load_kg` null and duration in `load_text`.

`activity_logged`

Lifestyle or recreational activity. Background walks and background yoga are never planned sessions. A profile habit is not done until this event exists. Scheduled habit sessions (climbing on a plan day) set `plan_id` / `session_id` and also get `session_completed`.

```json
{
  "date": "2026-08-15",
  "habit_key": "treadmill_walk",
  "activity_key": "treadmill_walk",
  "activity_name": "Gåband",
  "kind": "lifestyle",
  "instance": 1,
  "duration_min": 30,
  "distance_km": null,
  "speed_kmh": 4.5,
  "rpe": null,
  "intensity": "easy",
  "notes": "",
  "raw_text": "gick 30 min 4,5 km/h"
}
```

- `habit_key`: matching confirmed `lifestyle.habits[].key`, or null for a one-off
- `instance`: 1-based bout that day for this `activity_key`. A second gåband the same day is `2`. Missing on old rows means `1`
- `kind`: `lifestyle | extra`
- `intensity`: `easy | moderate | hard`
- `plan_id` / `session_id`: set when the activity matches a scheduled habit session that day; otherwise null
- Store what the user said, or the habit `typical_*` when they named the habit with no numbers. Do not derive `distance_km` from speed × time as a confirmed value
- Do not store kcal
- Latest row for `user_id + date + activity_key + instance` is current for that bout. Corrections (`nej`, `rättelse`) reuse `instance`. A new log line the same day without that language is a new `instance`. Sum current bouts for the day's load

## Identity in v1

ChatGPT Project instructions hold a single `USER_ID`. Every query must filter on that id. Do not invent a second user.
