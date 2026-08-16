# Meal-plan schema

`plans.content` JSON for one ISO week when `plans.kind = nutrition`. Training weeks (`kind = training`) stay in `training-plan/references/plan-schema.md`. Do not mix `sessions` and `meals` on the same row.

```json
{
  "week_label": "2026-W34",
  "days": [
    {
      "date": "2026-08-17",
      "weekday": "mon",
      "meals": [
        {
          "id": "m1",
          "slot": "lunch",
          "library_key": "chicken_rice_broccoli",
          "name": "Kyckling, ris, broccoli",
          "prep": "cook",
          "alternatives": [{ "library_key": "keso_pita", "name": "Keso pita" }],
          "notes": ""
        }
      ]
    }
  ]
}
```

## Rules

- `days` covers `period_start` through `period_end` (seven dates). Every date is present. A kitchen slot they do not eat that day is omitted from `meals`, not a missed event.
- `weekday`: `mon | tue | wed | thu | fri | sat | sun`
- Meal `id` unique within the plan (`m1`, `m2`, …)
- `slot`: `breakfast | lunch | dinner | evening | snack`
- Cover confirmed `nutrition.kitchen.meals` on days that are not travel/`eat_out` exceptions
- `prep`: `cook | leftover | packed | eat_out`
- `leftover` requires `leftover_from`: `{ "date": "2026-08-16", "meal_id": "m3" }` pointing at a `cook` (or `packed`) meal
- Prefer `nutrition.library` items whose `slots` match. `library_key` null/omitted is a one-off that week
- `alternatives`: 1–2 other library items when the archive has them. Used first on “byt lunch”
- No kcal, protein, macros, or MET on meals. Those belong on `food_logged`
- This-week context (resa, skift, hur styrt) may live in `notes` or `intent`. Do not write it to `user_profiles`
- Do not store kitchen equipment here. A one-off appliance note may sit in `notes`

## Copy-forward

Default draft for next week: copy the covering (or latest) nutrition plan’s `meals`, shift every `date` and `leftover_from.date` by the period delta, keep `library_key` / `name` / `prep` / `alternatives`. Then adjust against this week’s covering **training** plan (simpler `cook` on hard days; a snack between two-a-days) and against this-week context they just stated.

## Row-level columns

- `kind`: always `'nutrition'` on `INSERT`
- `title`: short Swedish, e.g. `Vecka 34 — kostschema`
- `intent`: one or two Swedish sentences (inspiration + functioning week, not a commandment)
- `status` after the approval write: `active` for a same-week replacement (`period_start` ≤ today). `proposed` for a future week — do not activate until that Monday (lazy activate)
- `period_start` / `period_end`: Monday and Sunday of the same ISO week
