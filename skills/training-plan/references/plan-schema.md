# Plan schema

`plans.content` JSON for one ISO week.

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
- `weekday`: `mon | tue | wed | thu | fri | sat | sun`
- Session `id` unique within the plan (`s1`, `s2`, …)
- Session `modality`: `strength | running | mobility | recovery`
- `modalities` at the top level is the set actually used this week
- `duration_min` and `rpe_target` are numbers; `rpe_target` on a 1–10 scale or omitted for full rest
- User-facing `title` / item `name` may be Swedish

## Item shapes

Strength item: `name`, `sets`, `reps`, `load`, `notes`  
Running item: `name`, `duration_min` and/or `distance_km`, `intensity`, `notes`  
Mobility item: `name`, `duration_min`, `notes`  
Recovery item: `name`, `duration_min`, `notes` (`duration_min` may be `0` for a rest day note)

## Row-level columns

- `title`: short Swedish, e.g. `Vecka 33 — styrka och löpning`
- `intent`: one or two Swedish sentences on what the week is for
- `status` after the approval write: `active`
- `period_start` / `period_end`: Monday and Sunday
