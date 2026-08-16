# Product

`training` is a personal AI training and nutrition partner.

ChatGPT is the interface and reasoning layer. GitHub holds versioned skills and contracts. Supabase holds durable state.

The long-term product should:

- build and adapt plans for strength, running/conditioning, mobility/yoga, and recovery
- combine those modalities into one weekly plan
- account for goals, experience, time, equipment, injuries, health, recovery, and life context
- log sessions, results, extra-plan activity (everyday movement, climbing, hiking), body weight, personal bests, perceived effort, and other observations
- track progress over time
- adapt after missed sessions, illness, time pressure, travel, poor recovery, or other changes
- give meal suggestions from a confirmed nutrition profile, a food/recipe library, and recent training; an optional saved weekly meal schema (`plans.kind = nutrition`) that can be followed or treated as inspiration and is easy to swap; optional food logging with optional kcal and protein on the meal; a saved daily calorie target after approval (`nutrition.goal` shapes whether that number is a floor to reach, a riktmärke, or a modest deficit — same integer, no extra field)
- run weekly reviews
- separate confirmed facts, user observations, and AI conclusions
- ask before saving new facts
- propose larger changes and wait for approval
- later ingest research updates and Garmin data without those being required now

## Principles

- Ship one complete vertical at a time. Do not build the future system in advance.
- Keep the long-term idea visible in this document and in the data contracts.
- Never present AI assumptions as confirmed facts.
- Prefer a small, migratable schema over extra tables.
- Product logic lives in contracts and skills so a later TypeScript backend can reuse it.

## v1 boundary

v1 runtime: a ChatGPT Project with the GitHub connector and the official Supabase ChatGPT app.

v1 implements:

- shared safety, autonomy, and provenance rules
- five tables: `user_profiles`, `plans`, `events`, `recommendations`, `exercise_prs`
- RLS enabled with no anon policies (Data API denied)
- `training-onboarding`
- `training-plan` for the weekly **training** plan (`plans.kind = training`) and showing saved sessions. Background habits stay out of `plans.content` and count only when logged (`activity_logged`). Scheduled habits (e.g. climbing on a named weekday) become `other` sessions with `habit_key`. Same-day stacking is allowed on some days when the profile says so; it is not a 5+5 template. If a planned exercise is missing at the routine gym, the home alternative is prescribed and the first choice stays on the item as `preferred`; that pair is stored in `equipment.home_gym_substitutions`. A this-week swap (they want another exercise, not that the gym lacks it) does not write the profile. At most one `active` training plan per user; a nutrition week does not count
- `training-log-and-review` for exercise and session logging plus extra-plan activity, and a read-only weekly overview in chat (no write). PRs live in `exercise_prs`, one row per `exercise_key`, kept in sync by a DB trigger on `exercise_logged` from **current** logs (a correction replaces that date) — no skill writes to it directly. Not shown unless asked. Bare “hur gick veckan” on Monday summarizes the week that just ended.
- `training-nutrition` for meal suggestions from confirmed preferences, a food/recipe library, and recent activity; a persisted weekly meal schema in `plans` (`kind = nutrition`) after `godkänn` (**Sparat schema**), easy slot swaps (`alternatives` first), not required to follow (no `meal_missed`); optional `food_logged` (optional `kcal` / `protein_g` on the meal, user-stated or estimated; `åt enligt schema` matches the covering meal plan) and `body_weight_logged`; follow-up against the covering week’s training and food (planerat vs loggat is unknown, not a miss); may write `nutrition.library` or a new working `target_kcal` after approval. Everyday meal lists use kitchen slots; numbers vs the target only on follow-up or when they asked (incomplete sums, never a remainder ticker after a log). First-time `nutrition.*` / `body.*` via `training-onboarding`. Chat ideas without a covering meal plan stay **Förslag**

v1 does not implement:

- auth, user-scoped RLS policies, multiple users, admin, or invites
- a web app, custom backend, custom MCP server, or background jobs
- Garmin read/write
- automatic research monitoring
- periodization engines (mesocycles, blocks, automatic deloads) beyond the Förslag vikt streak rule in `loads-and-prs.md`
- publishing as an OpenAI plugin
- auto-progressing loads into the next week's proposal beyond the existing **Förslag vikt** rule in `loads-and-prs.md` (applied when drafting, written to `item.load` only after approval)
- a named gym registry or more than one routine gym; “another gym” is the first-choice (`preferred`) on a plan item

## Skills

Four skills are in scope for the product.

### `training-onboarding`

Collects profile data progressively, including optional `lifestyle.habits`, optional `equipment.home_gym_substitutions`, and optional nutrition (`body`, `nutrition.*`, `nutrition.energy.target_kcal`, `nutrition.library`, kitchen extras for a meal week). After the plan minimum it asks once about recurring everyday movement, yoga, or extra sports. Nutrition onboarding is separate and optional (`jag vill sätta upp kosten`); it asks once about frequent meals for the library. When they want a meal schema it may collect `servings`, `lunch_source`, `leftovers`, `time_min_weekend`, `eat_out_notes` as profile facts (this-week context is not saved). Collects training **days**, possible windows, and whether two sessions the same day is fine on some days — not a weekly gym+run quota. Does not run a missing-machines form. Habits, gym-substitution pairs, and nutrition library items can be added, changed, or removed later after approval. Does not create weekly training plans or meal schemas. If `safety_status` is `stop`, it must refuse training-plan handoff. Clinical nutrition flags (eating-disorder disclosure, clinician-prescribed diet, insulin-treated diabetes when they ask for a strict target) refuse a calorie-target write without changing `safety_status`.

### `training-plan`

Creates and changes weekly **training** plans (`kind = training`) across the modalities the user actually chose. Reads confirmed profile data, lifestyle habits, home-gym substitutions, and recent extra-plan activity. Lays out the week from capacity (windows, `two_a_day`, experience); recovery is a hard gate. Background habits stay in `intent` as a pattern and count only when logged. Scheduled habits become sessions (`modality` `other`). If habits exist and none were logged in the last 7 days, ask once with the user's habit names. When showing a day, reads the latest exercise logs for that date and shows first-choice (`preferred`) when it differs from the home exercise. When drafting, **Förslag vikt** uses a short successful streak at the same kg (`loads-and-prs.md`), not a single last log. Writes `plans` (`kind = training`) and plan events. Gym-unavailable substitutions also write `equipment.home_gym_substitutions`. Does not log completed sets or extra-plan activity. Does not list background habits as **Sparat pass**. Does not write nutrition weeks.

### `training-log-and-review`

Logs completed and missed sessions, per-exercise sets (load, reps, optional RPE), and extra-plan activity (`activity_logged`: walks, yoga, climbing, hiking, and similar). A whole-session shortcut may copy last working loads into `exercise_logged` after one approval. Writes append-only `events`. A profile habit is not done until logged. After a week without habit logs, ask once with the user's habit names. A weekly overview is a Swedish chat card (facts / unknown / conclusion) over the covering week’s plan and logs; it does not write `events`, `plans`, `recommendations`, `user_profiles`, or a new event type. Bare “hur gick veckan” on Monday is the week that just ended. PRs live in `exercise_prs` (trigger from current logs; a correction replaces that date). Next week is a `training-plan` draft after they ask. Must not activate major plan changes.

### `training-nutrition`

Reads confirmed profile nutrition fields, `data.body`, the food/recipe library, plus recent training and extra-plan activity. Chat meal ideas are **Förslag** when no covering meal plan exists. A weekly meal schema is a `plans` row with `kind = nutrition` after `godkänn` (**Sparat schema** / draft **Förslag (sparas inte än)**); slot swaps use stored `alternatives` first; following it is optional. Writes `food_logged` when they report a meal (same instance rules as `activity_logged`, `slot` for `activity_key`; optional `kcal` / `protein_g` with `*_source`; `åt enligt schema` matches the covering meal plan) and `body_weight_logged` when they report a weigh-in (syncs `data.body.weight_kg`; does not auto-rewrite `target_kcal`). Follow-up reads the covering week’s training, meals, and weights (plus planerat vs loggat when a meal week exists) and may propose a new working `target_kcal` after `godkänn`. Presentation follows `nutrition.goal`: floor language for `improve_performance` / `build_muscle` / `general_health`, riktmärke for `maintain` / `none`, modest deficit for `lose_weight`. Gaps are unknown, not a deficit. May write `nutrition.library` after approval in the same turn as a suggestion. First-time `body.*` / goal / allergies / kitchen extras stay `training-onboarding`. BMR/TDEE are inferences. No diagnoses or clinical diets. No stored protein target. Food reactions and clinical nutrition flags are chat observations; the latter refuse a calorie target without changing `safety_status`.

## Defaults

These are easy to change later:

- One personal `user_id` stored in the ChatGPT Project instructions
- Locale `sv-SE`, timezone `Europe/Stockholm`, ISO week Monday–Sunday (`week_start = 1`)
- First weekly plan combines only the modalities the user selected
- Nutrition preferences, body measures, a working `target_kcal`, and a food/recipe library may be stored on the profile; `training-nutrition` turns them into chat suggestions, an optional persisted weekly meal schema (`plans.kind = nutrition`), and follow-up. Optional `kcal` / `protein_g` live on `food_logged`, not on the profile or on schema slots. BMR/TDEE stay inferences. The target is replaceable after `godkänn`. How it is spoken follows `nutrition.goal` (no extra tracking field). No protein target on the profile
- `recommendations` exists but is unused in the first vertical
- Schema changes go through SQL files in this repo, not ad-hoc DDL in chat
