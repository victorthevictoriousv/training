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

- `exercise_key`: lowercase snake_case, stable. Prefer the planned item name slug when matched.
- `load_kg`: number when known. Null for bodyweight, time carries, or duration-only work.
- `load_text`: always set (`24 kg`, `kroppsvikt`, `+12 kg`, `32 min`).
- `reps`: integer or null for timed or distance work. Never a range. Never `reps_text`. If the user only gives `8–10`, store `8` (low end) and echo that.
- `rpe`: number or null.
- `duration_min` / `distance_km`: for running or timed work; `load_kg` is then null.
- Dumbbells and similar: `load_kg` is **per implement** (one dumbbell). `load_text` like `30 kg/hantel`.
- Several working sets: one event with several objects in `sets`. Log every working set, even when they are identical.

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
- `kind`: `lifestyle` (easy everyday movement or easy yoga/mobility) or `extra` (climbing, hiking, similar).
- `intensity`: `easy | moderate | hard`. Default `easy` for ordinary walking.
- `duration_min`, `distance_km`, `speed_kmh`, `rpe`: numbers or null. Store only values the user stated. Do not derive distance from speed × time. Do not store kcal.
- `activity_name`: user-facing, may be Swedish.
- `plan_id` / `session_id`: set when this matches a scheduled habit session that day; otherwise omit or null.

One-off climbing example: `{ "habit_key": null, "activity_key": "climbing", "activity_name": "Klättring", "kind": "extra", "duration_min": 120, "intensity": "moderate" }`.

Scheduled climbing the same day as a plan session: set `plan_id` and `session_id`, and also write `session_completed`.

A confirmed habit on the profile is not an instance. Yoga and gåband count only after this event exists for that date.

## Current value

Latest `exercise_logged` for (`user_id`, `date`, `exercise_key`) wins. Latest `activity_logged` for (`user_id`, `date`, `activity_key`) wins. Older rows stay for history.
