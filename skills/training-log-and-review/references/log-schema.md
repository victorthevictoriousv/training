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
- `load_text`: always set (`24 kg`, `kroppsvikt`, `+12 kg`, `30 s`).
- `reps`: integer or null for timed work.
- `rpe`: number or null.
- Several working sets: one event with several objects in `sets`.

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

## Current value

Latest `exercise_logged` for (`user_id`, `date`, `exercise_key`) wins. Older rows stay for history.
