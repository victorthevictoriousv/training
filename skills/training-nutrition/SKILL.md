---
name: training-nutrition
description: Give simple meal suggestions tied to training, goals, recovery,
  confirmed lifestyle habits, and recent activity. Use when the user asks what
  to eat, wants a meal or snack suggestion, asks how to fuel a session or
  recover from one, mentions a food reaction or new allergy, or asks about
  their saved nutrition preferences. Match intent, not exact wording. Do not
  use to collect or change nutrition.* profile fields (that is
  training-onboarding), create or change weekly plans (training-plan), log
  exercises or extra-plan activity (training-log-and-review), diagnose
  conditions, give clinical or medically restrictive diets, or store kcal,
  macros, or TDEE anywhere.
---

# training-nutrition

Give simple meal suggestions in chat. Write nothing.

## Do not

- Collect, confirm, or write `nutrition.*` (or any) profile fields — hand off to `training-onboarding`
- Create or change weekly training plans — hand off to `training-plan`
- Log exercises, sessions, or extra-plan activity — hand off to `training-log-and-review`
- Diagnose a food reaction, allergy, or condition; give clinical, medically restrictive, or weight-loss diets
- Store kcal, macros, MET, or TDEE anywhere, confirmed or not
- Write `recommendations`, `plans`, `user_profiles`, or `events` — this skill never writes
- Give a tailored suggestion if `safety_status` is `stop` or `unknown`

## Intent

Classify once. Run only those ids from `skills/_shared/queries.md`. This skill has no writes.

| User means | Section | Queries | Skip |
| --- | --- | --- | --- |
| Meal/snack suggestion, “vad ska jag äta”, fuel/recover from a session | §2 | `Q_profile`, `Q_covering_plan`, `Q_today_logs`, `Q_today_activity` | writes, `Q_pr` |
| Nutrition tied to the whole week | §2 (week variant) | Same as a day, plus `Q_week_events`, `Q_habits` | `Q_pr`, `Q_recent_working` |
| Reported food reaction / new allergy | §3 | `Q_profile` | writing it here |
| “What preferences do you have saved?” | §1 | `Q_profile` | others |

## Before you start

Read, in this order if not already in context (repo paths; from this skill folder use `../../docs/`):

- `docs/safety.md`
- `docs/provenance.md`
- `docs/data-contracts.md`
- `skills/_shared/queries.md`
- `references/meal-suggestions.md`

Use `USER_ID` from the Project instructions. Filter every query on that id.

## Procedure

### 1. Saved preferences

Run `Q_profile`. Answer from confirmed `data.nutrition` only. Missing keys are unknown, not a guess. If they want to add or change a field, hand off to `training-onboarding`. Do not write.

### 2. Meal or snack suggestion

Run `Q_profile`. Safety gate:

- `stop` → refuse. Tell them to seek care. Do not suggest food as training fuel.
- `unknown` → route to `training-onboarding` for screening first. Do not give a tailored suggestion.
- `cleared` or `restricted` → continue. If `restricted`, stay conservative.

Missing `nutrition.*` → a generic suggestion is fine. Offer the onboarding handoff for a tailored one.

Then run `Q_covering_plan`, `Q_today_logs`, and `Q_today_activity` (date = today in `Europe/Stockholm` unless they named a day). For a week-level ask, also `Q_week_events` (`:period_start` / `:period_end` from the covering row) and `Q_habits`.

Use what actually happened (`exercise_logged`, `activity_logged`, `session_completed`), not the aspirational plan. Compose 1–3 Swedish options from confirmed `nutrition.goal`, `dietary_pattern`, `allergies`, `exclusions`, `preferences`, plus real training/activity load. Rules in `references/meal-suggestions.md`. `lose_weight` is tone (simpler/lighter meals), never a deficit, restriction, or kcal target. Never print kcal, macros, or TDEE. Label the reply **Förslag** — nothing is saved.

### 3. Food reaction or new allergy

Note it as their observation (`docs/provenance.md`), not a diagnosis. If they want it remembered, hand off to `training-onboarding` to confirm into `nutrition.allergies` or `nutrition.exclusions`. Write nothing here.

## Dialogue

Speak Swedish. Keep it short. Always label suggestions **Förslag**. Never present a meal as a saved fact unless they confirmed the preference via `training-onboarding`.
