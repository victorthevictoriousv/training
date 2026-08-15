# Profile fields

Confirmed fields only in `user_profiles.data`. Paths below are also `provenance` keys (plus `safety_status`).

## Minimum for `training-plan`

| Path | Required |
| --- | --- |
| `safety_status` column | `cleared` or `restricted` |
| `goals.primary` | yes |
| `modalities` | non-empty array |
| `availability.days_per_week` or `availability.preferred_days` | at least one |
| `availability.session_minutes` | yes |
| `equipment.location` | yes |

`onboarding_status = complete` only when this set is confirmed.

## Field dictionary

### `goals`

- `primary`: `strength | running | mobility | recovery | general`
- `secondary`: array of the same enum, optional
- `notes`: short user string. If they say training is a hobby or they like high volume, store that here as their words. Do not infer “elite volume tolerance”.

### `modalities`

Array subset of `strength | running | mobility | recovery`. This is what weekly plans may include. Do not add a modality the user did not choose.

### `experience`

- `strength`, `running`, `mobility`: `beginner | intermediate | advanced` when that modality is selected
- `training_age_years`: number or omitted

### `availability`

- `days_per_week`: integer 1–7. Training **days**, not session count
- `session_minutes`: integer. Fallback length (typically strength). Per-window `minutes` on `windows` win when present
- `preferred_days`: `mon | tue | wed | thu | fri | sat | sun`
- `constraints`: user string
- `windows` (optional): possible slots, not a daily mandate. Each object: `slot` (`morning | lunch | evening`), optional `modality` (`strength | running | mobility | recovery`), optional `minutes`
- `two_a_day` (optional): `never | some_days`. `some_days` means two sessions the same day are allowed on some days. Do not store `every_training_day`. Omit or `never` if they do not want two-a-days
- `anchor` (optional): short user string, e.g. lunch strength when the day has gym. A preference the planner may drop under poor recovery or time pressure

Do not store a fixed weekly quota of strength sessions + run sessions. That is the week's draft, not a profile fact.

### `equipment`

- `location`: `gym | home | mixed`
- `items`: string array (e.g. `barbell`, `dumbbells`, `bands`, `none`)
- `home_gym_substitutions` (optional): array of confirmed pairs for the **routine gym**. Each object:
  - `preferred_key`, `preferred_name`: first-choice exercise that is missing there
  - `home_key`, `home_name`: what to do at the routine gym instead
  - Keys are lowercase snake_case, stable
  - One routine gym in v1. “Another gym” is the `preferred` field on a plan item, not a second profile gym

Do not ask a form of missing machines during onboarding. Capture organically when they mean an exercise is unavailable at the routine gym, or via later add/remove. Provenance key: `equipment.home_gym_substitutions` for the whole array. Write the full confirmed array on each update (add, change, or remove pairs they approved). Keep unrelated pairs. Omit the key until at least one pair is confirmed. Do not invent a pair from a this-week swap.

### `health`

User's own words, not diagnoses.

- `injuries`: string array
- `pain`: string array
- `conditions`: string array
- `medications_mentioned`: boolean only

If they name a drug, set `medications_mentioned: true` and write an `events` observation payload without copying the drug name into `data`. Never advise on medication.

### `nutrition` (optional in v1)

- `goal`, `allergies`, `exclusions`, `preferences`

Collect if offered. Do not generate meal plans.

### `recovery` / `life` (optional)

- `recovery.sleep_hours`, `recovery.stress`
- `life.travel`, `life.schedule_notes`

### `lifestyle.habits` (optional)

Recurring activity outside the four training modalities. Not required for a weekly plan. Ask once after the plan minimum. Collect later via `lägg till vana`. Do not invent a habit.

Each habit:

- `key`: lowercase snake_case, stable (`treadmill_walk`, `yoga`, `climbing`)
- `name`: user-facing, may be Swedish
- `kind`: `lifestyle` (easy everyday movement or easy mobility/yoga ritual) or `extra` (climbing, hiking, similar)
- `plan_inclusion`: `background` | `scheduled`
- `typical_duration_min`, `typical_speed_kmh`, `typical_distance_km`: numbers or omitted
- `times_per_day`: integer, default 1. Usual pattern, not a maximum and not auto-logged bouts
- `days`: `mon | tue | wed | thu | fri | sat | sun`
- `notes`: short user string

Defaults for `plan_inclusion`: `background` when `kind` is `lifestyle`; ask (suggest `scheduled`) when `kind` is `extra` and `days` are named; `background` when `extra` has no days.

Gåband example: 30 min, 4.5 km/h, twice per workday, `kind` `lifestyle`, `plan_inclusion` `background`.

Yoga example: typical duration, several days per week, `key` `yoga`, `kind` `lifestyle`, `plan_inclusion` `background`. Not a planned session; skip is not `session_missed`. Time of day is not required.

Climbing example: 90 min Wednesdays, `kind` `extra`, `plan_inclusion` `scheduled` if they want it in the week.

Provenance key: `lifestyle.habits` for the whole array. Do not store kcal. Do not add habit keys to `data.modalities`.

A single instance of the habit is `activity_logged` (and `session_completed` when it matches a scheduled session that day). The profile row is not proof it happened. After 7 days with no matching `activity_logged`, skills ask once with the user's habit names.

## Missing-field map

Use this when the user asks what you still need.

| Capability | Extra fields beyond the plan minimum |
| --- | --- |
| Better programming | `experience.*` for selected modalities, `availability.windows`, `availability.two_a_day`, `equipment.items`, `health.injuries`, `lifestyle.habits`, `recovery.sleep_hours` / `recovery.stress` |
| Logging / review (later) | nothing required in v1 |
| Nutrition (later) | `nutrition.allergies`, `nutrition.exclusions`, `nutrition.preferences`, `lifestyle.habits` |

## Provenance entry

```json
{
  "source": "user",
  "status": "confirmed",
  "confirmed_at": "<ISO-8601 Z>",
  "event_id": "<events.id>"
}
```
