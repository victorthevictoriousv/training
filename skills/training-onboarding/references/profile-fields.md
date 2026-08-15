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
- `notes`: short user string

### `modalities`

Array subset of `strength | running | mobility | recovery`. This is what weekly plans may include. Do not add a modality the user did not choose.

### `experience`

- `strength`, `running`, `mobility`: `beginner | intermediate | advanced` when that modality is selected
- `training_age_years`: number or omitted

### `availability`

- `days_per_week`: integer 1–7
- `session_minutes`: integer
- `preferred_days`: `mon | tue | wed | thu | fri | sat | sun`
- `constraints`: user string

### `equipment`

- `location`: `gym | home | mixed`
- `items`: string array (e.g. `barbell`, `dumbbells`, `bands`, `none`)

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

## Missing-field map

Use this when the user asks what you still need.

| Capability | Extra fields beyond the plan minimum |
| --- | --- |
| Better programming | `experience.*` for selected modalities, `equipment.items`, `health.injuries` |
| Logging / review (later) | nothing required in v1 |
| Nutrition (later) | `nutrition.allergies`, `nutrition.exclusions`, `nutrition.preferences` |

## Provenance entry

```json
{
  "source": "user",
  "status": "confirmed",
  "confirmed_at": "<ISO-8601 Z>",
  "event_id": "<events.id>"
}
```
