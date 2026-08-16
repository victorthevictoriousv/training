# Plan schema

`plans.content` JSON for one ISO week (`kind = training`). Nutrition weeks are `skills/training-nutrition/references/meal-plan-schema.md`.

```json
{
  "week_label": "2026-W33",
  "modalities": ["strength", "running", "mobility"],
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
              "name": "Uppvärmning",
              "items": [
                { "name": "Easy bike or walk", "duration_min": 8, "notes": "" }
              ]
            },
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

## Rules

- `days` covers `period_start` through `period_end` (seven dates). Days without training have `"sessions": []`.
- Background habits are not sessions; they belong in profile + `intent`.
- Scheduled habits are sessions: `modality` `other`, `habit_key` set. Do not add `other` to top-level `modalities`.
- `weekday`: `mon | tue | wed | thu | fri | sat | sun`
- Session `id` unique within the plan (`s1`, `s2`, …)
- Session `modality`: `strength | running | mobility | recovery | other`
- Optional session `slot`: `morning | lunch | evening`. Set when the window is known
- `modalities` at the top level is the training set actually used this week (`strength | running | mobility | recovery` only)
- `duration_min` and `rpe_target` are numbers; `rpe_target` on a 1–10 scale or omitted for full rest and for `other` when effort is not prescribed
- User-facing `title` / item `name` may be Swedish

## Item shapes

Strength item: `name`, `sets`, `reps`, `load`, `notes`. Optional `key`. Optional `preferred` (`name`, `key`) when the home-gym exercise differs from the first-choice exercise.  
Running item: `name`, `duration_min` and/or `distance_km`, `intensity`, `notes`  
Mobility item: `name`, `duration_min`, `notes`  
Recovery item: `name`, `duration_min`, `notes` (`duration_min` may be `0` for a rest day note)  
Other (scheduled habit): `name`, `duration_min` and/or `distance_km`, `notes`

`name` / `key` is what they do at the routine gym. Omit `preferred` when it would duplicate `name`. Set `key` when `preferred` is present.

Substituted strength item:

```json
{
  "name": "Sidogång med band",
  "key": "banded_lateral_walk",
  "sets": 3,
  "reps": "12-15",
  "load": "RPE 7",
  "notes": "",
  "preferred": {
    "name": "Höftabduktion maskin",
    "key": "hip_abductor_machine"
  }
}
```

Scheduled habit session:

```json
{
  "id": "s4",
  "modality": "other",
  "habit_key": "climbing",
  "title": "Klättring",
  "duration_min": 90,
  "blocks": [
    {
      "name": "Main",
      "items": [{ "name": "Klättring", "duration_min": 90, "notes": "" }]
    }
  ]
}
```

## Row-level columns

- `title`: short Swedish, e.g. `Vecka 33 — styrka och löpning`
- `intent`: one or two Swedish sentences on what the week is for
- `status` after the approval write: `active` for a same-week replacement (`period_start` ≤ today). `proposed` for a future week (`period_start` after today) — do not activate until that Monday (lazy activate)
- `period_start` / `period_end`: Monday and Sunday of the same ISO week (the database rejects other ranges)
