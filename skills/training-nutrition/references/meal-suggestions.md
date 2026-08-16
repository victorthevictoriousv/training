# Meal suggestions

Chat-only. Nothing in this file is a saved fact. Do not write `recommendations`, `plans`, `user_profiles`, or `events`.

## Never

- Diagnose a food reaction, allergy, or condition.
- Give clinical, medically restrictive, or weight-loss diets. `nutrition.goal = lose_weight` is tone only (simpler/lighter meals) — never a deficit, restriction, or kcal target.
- Advise starting, stopping, or changing medication.
- Store kcal, macros, MET, or TDEE anywhere.
- Treat the weekly plan as what they ate or trained — use logged activity.

## Tie to real activity

Suggestions follow what they actually did (`Q_today_logs`, `Q_today_activity`, `Q_week_events`), not `plans.content` as if it happened.

- A logged hard gym or quality run → mention a bit more food around that session (still no numbers).
- Easy gåband / yoga only, or a rest day with no logs → keep it light and ordinary.
- No logs and no covering plan → generic, and say so.

## Profile fields

Read confirmed `data.nutrition` from `Q_profile`. Omit means unknown.

| Field | How it shapes the suggestion |
| --- | --- |
| `goal` | `lose_weight` / `build_muscle` / `maintain` / `improve_performance` / `general_health` / `none` — tone only. `lose_weight` does not mean a diet, deficit, or kcal target |
| `dietary_pattern` | `omnivore` / `vegetarian` / `vegan` / `pescatarian` / `other` — filter animal foods; `other` → use `preferences` |
| `allergies` | Hard avoid. Do not suggest those foods. |
| `exclusions` | Hard avoid (dislike, ethics, religion — their words). |
| `preferences` | Free-text notes beyond the enums (e.g. “gillar inte fisk”). |

If `dietary_pattern` is missing, do not assume omnivore. Stay conservative when allergies or exclusions exist. `restricted` safety: prefer simple, familiar food; do not claim to treat anything.

## Food reaction

A mentioned reaction is a user observation, not a diagnosis. Do not write it here. If they want it remembered, `training-onboarding` confirms it into `nutrition.allergies` or `nutrition.exclusions`. Until then it stays in the conversation.

## Queries

SQL lives in `skills/_shared/queries.md`. Copy the named id; do not paste a variant.

| Need | Id |
| --- | --- |
| Safety gate and `nutrition.*` | `Q_profile` |
| Covering week / today’s planned sessions (context only) | `Q_covering_plan` |
| What they lifted or ran today | `Q_today_logs` |
| Extra-plan activity today | `Q_today_activity` |
| Week-level training and extra-plan activity | `Q_week_events` |
| Habit pattern (week-level only) | `Q_habits` |

Do not run `Q_pr`. Do not invent activity to justify a suggestion.
