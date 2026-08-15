# Log event payloads

See also `docs/data-contracts.md`.

## `exercise_logged`

```json
{
  "date": "2026-08-15",
  "plan_id": null,
  "session_id": "s1",
  "exercise_key": "goblet_squat",
  "exercise_name": "Goblet Squat",
  "sets": [
    { "load_kg": 24, "load_text": "24 kg", "reps": 8, "rpe": 7 }
  ],
  "raw_text": "goblet 24x8"
}
```

- `exercise_key`: lowercase snake_case, stable. Prefer the planned item `key` when matched to `name`; prefer `preferred.key` when matched to `preferred.name`. Else slug from the user text.
- `load_kg`: number when known. Null for bodyweight, time carries, or duration-only work.
- `load_text`: always set (`24 kg`, `kroppsvikt`, `+12 kg`, `32 min`).
- `reps`: integer or null for timed or distance work. Never a range. Never `reps_text`. If the user only gives `8–10`, store `8` (low end) and echo that.
- `rpe`: number or null.
- `duration_min` / `distance_km`: for running or timed work; `load_kg` is then null.
- Dumbbells and similar: `load_kg` is **per implement** (one dumbbell). `load_text` like `30 kg/hantel`.
- Several working sets: one event with several objects in `sets`. Log every working set, even when they are identical.
- Shortcut fill (`logga gympasset`): `raw_text` is their phrase. Optional `notes`: `enligt senaste`. Loads come from last working after `godkänn`, not from plan RPE.

## `session_completed` / `session_missed`

```json
{
  "date": "2026-08-15",
  "plan_id": null,
  "session_id": "s1",
  "status": "completed",
  "session_rpe": null,
  "notes": ""
}
```

`status`: `completed` | `partial` | `missed`.

## `activity_logged`

Extra-plan lifestyle or recreational activity. Not a planned session.

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

- `activity_key`: lowercase snake_case, stable. Prefer the matching habit `key` when one exists.
- `habit_key`: that habit `key`, or null for a one-off.
- `instance`: 1-based bout on that date for this `activity_key`. Default `1` if omitted (older rows). A second gåband the same day is `instance` 2, not a correction.
- `kind`: `lifestyle` (easy everyday movement or easy yoga/mobility) or `extra` (climbing, hiking, similar).
- `intensity`: `easy | moderate | hard`. Default `easy` for ordinary walking.
- `duration_min`, `distance_km`, `speed_kmh`, `rpe`: numbers or null. Store only values the user stated, or the matching habit's `typical_*` when they named the habit without numbers. Do not derive distance from speed × time. Do not store kcal.
- `activity_name`: user-facing, may be Swedish.
- `plan_id` / `session_id`: set when this matches a scheduled habit session that day; otherwise omit or null.

Typical-from-habit: `gåband` with no numbers → `duration_min` / `speed_kmh` from `typical_duration_min` / `typical_speed_kmh`. Echo `(enligt vana)`. Stated numbers always win (`gåband 60 min 5 km/h` stores 60 and 5.0). If they state only duration or only speed, fill the omitted one from the habit typical when present.

One-off climbing example: `{ "habit_key": null, "activity_key": "climbing", "activity_name": "Klättring", "kind": "extra", "instance": 1, "duration_min": 120, "intensity": "moderate" }`.

Scheduled climbing the same day as a plan session: set `plan_id` and `session_id`, and also write `session_completed`.

A confirmed habit on the profile is not an instance. Yoga and gåband count only after this event exists. `times_per_day` is the usual pattern, not a max and not auto-filled bouts.

## Current value

Latest `exercise_logged` for (`user_id`, `date`, `exercise_key`) wins.

Latest `activity_logged` for (`user_id`, `date`, `activity_key`, `instance`) wins. Treat missing `instance` as `1`. Older rows stay for history. Load for the day is the **sum** of current instances (e.g. two gåband bouts), not only the last row.

Correction language (`nej, 40 min`, `rättelse`) writes a new row with the **same** `instance` as the latest bout. A second `gåband` the same day without that language is a new `instance`.
