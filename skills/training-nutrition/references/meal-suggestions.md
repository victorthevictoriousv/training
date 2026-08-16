# Meal suggestions

Chat suggestions are **Förslag**. They are not a saved weekly menu. Do not write `recommendations` or `plans`. Library saves and `food_logged` are the only writes, and only per `SKILL.md`.

## Never

- Diagnose a food reaction, allergy, or condition.
- Give clinical or medically restrictive diets. `lose_weight` with a saved `target_kcal` is a modest deficit (`references/energy.md`), not a clinical restriction. `improve_performance` / `build_muscle` / `general_health` must not get deficit or “kcal kvar” tone.
- Advise starting, stopping, or changing medication.
- Store BMR, TDEE, macros, or MET on the profile or library. Store `target_kcal` only via onboarding after `godkänn`. Do not print kcal or protein on **Förslag** unless they asked about amount or energy. Those numbers live on `food_logged`, not on the suggestion.
- Treat the weekly plan as what they ate or trained — use logged activity.
- Change `safety_status` for a nutrition disclosure.
- Give a tailored suggestion if `safety_status` is `stop` or `unknown`.
- Nag meal logging or print remaining kcal or remaining protein.

## Tie to real activity

Suggestions follow what they actually did (`Q_today_logs`, `Q_today_activity`, `Q_week_events`), not `plans.content` as if it happened.

- A logged hard gym or quality run → mention a bit more carbohydrate/protein around that session. Numbers only if `target_kcal` is saved **and** they asked about energy.
- Easy gåband / yoga only, or a rest day with no logs → keep it ordinary.
- No logs and no covering plan → generic, and say so.
- Skip a slot that already has a current `food_logged` (`Q_today_food`).

## Library first

Read confirmed `nutrition.library`. Prefer items whose `slots` match the ask. Fill remaining options with new **Förslag**. Offer to save a new idea (`references/library.md`).

## Profile fields

Read confirmed `data.nutrition` and `data.body` from `Q_profile`. Omit means unknown.

| Field | How it shapes the suggestion |
| --- | --- |
| `goal` | Tone from `energy.md` when `target_kcal` is saved: floor (eat enough) for `improve_performance` / `build_muscle` / `general_health`; riktmärke for `maintain` / `none`; modest deficit only for `lose_weight`. Never a clinical diet |
| `dietary_pattern` | `omnivore` / `vegetarian` / `vegan` / `pescatarian` / `other` — filter animal foods; `other` → use `preferences` |
| `allergies` | Hard avoid. Do not suggest those foods. Confirmed `[]` means none known |
| `exclusions` | Hard avoid (dislike, ethics, religion — their words). |
| `preferences` | Free-text notes beyond the enums (e.g. “gillar inte fisk”). |
| `kitchen` | Prefer meals they actually eat and `time_min` / `skill` when present |
| `energy.target_kcal` | Mention only if saved and they asked about amount/energy, with that same goal language |
| `library` | First source of options for the slot |

If `dietary_pattern` is missing, do not assume omnivore. Stay conservative when allergies or exclusions exist. `restricted` safety: prefer simple, familiar food; do not claim to treat anything.

## Food reaction

A mentioned reaction is a user observation, not a diagnosis. Do not write it here. If they want it remembered, `training-onboarding` confirms it into `nutrition.allergies` or `nutrition.exclusions`. Until then it stays in the conversation.

## Queries

SQL lives in `skills/_shared/queries.md`. Copy the named id; do not paste a variant.

| Need | Id |
| --- | --- |
| Safety gate, `nutrition.*`, `body`, library | `Q_profile` |
| Covering week / today’s planned sessions (context only) | `Q_covering_plan` |
| What they lifted or ran today | `Q_today_logs` |
| Extra-plan activity today | `Q_today_activity` |
| Meals already logged today | `Q_today_food` |
| Meals in the covering week (follow-up) | `Q_week_food` |
| Weigh-ins in the covering week (follow-up) | `Q_week_weights` |
| Week-level training and extra-plan activity | `Q_week_events` |
| Habit pattern (week-level only) | `Q_habits` |

Do not run `Q_pr`. Do not invent activity to justify a suggestion.
