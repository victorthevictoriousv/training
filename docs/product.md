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
- give simple meal suggestions tied to goals, training, and preferences
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
- four tables: `user_profiles`, `plans`, `events`, `recommendations`
- RLS enabled with no anon policies (Data API denied)
- `training-onboarding`
- `training-plan` for the weekly plan and showing saved sessions. Background habits stay out of `plans.content` and count only when logged (`activity_logged`). Scheduled habits (e.g. climbing on a named weekday) become `other` sessions with `habit_key`. Same-day stacking is allowed on some days when the profile says so; it is not a 5+5 template. If a planned exercise is missing at the routine gym, the home alternative is prescribed and the first choice stays on the item as `preferred`; that pair is stored in `equipment.home_gym_substitutions`. A this-week swap (they want another exercise, not that the gym lacks it) does not write the profile
- `training-log-and-review` for exercise and session logging plus extra-plan activity (not weekly review). PRs are derived from `exercise_logged` only; they are not shown unless asked

v1 does not implement:

- weekly reviews inside `training-log-and-review`
- `training-nutrition` (meal suggestions)
- auth, user-scoped RLS policies, multiple users, admin, or invites
- a web app, custom backend, custom MCP server, or background jobs
- Garmin read/write
- automatic research monitoring
- periodization engines or dedicated PR tables
- publishing as an OpenAI plugin
- auto-progressing loads into the next week's proposal
- a named gym registry or more than one routine gym; “another gym” is the first-choice (`preferred`) on a plan item

## Skills

Four skills are in scope for the product. Nutrition is still a stub; weekly review inside the log skill is not implemented.

### `training-onboarding`

Collects profile data progressively, including optional `lifestyle.habits` and optional `equipment.home_gym_substitutions`. After the plan minimum it asks once about recurring everyday movement, yoga, or extra sports. Collects training **days**, possible windows, and whether two sessions the same day is fine on some days — not a weekly gym+run quota. Does not run a missing-machines form. Habits and gym-substitution pairs can be added, changed, or removed later after approval. Does not create weekly plans or meal suggestions. If `safety_status` is `stop`, it must refuse training-plan handoff.

### `training-plan`

Creates and changes weekly plans across the modalities the user actually chose. Reads confirmed profile data, lifestyle habits, home-gym substitutions, and recent extra-plan activity. Lays out the week from capacity (windows, `two_a_day`, experience); recovery is a hard gate. Background habits stay in `intent` as a pattern and count only when logged. Scheduled habits become sessions (`modality` `other`). If habits exist and none were logged in the last 7 days, ask once with the user's habit names. When showing a day, reads the latest exercise logs for that date and shows first-choice (`preferred`) when it differs from the home exercise. Writes `plans` and plan events. Gym-unavailable substitutions also write `equipment.home_gym_substitutions`. Does not log completed sets or extra-plan activity. Does not list background habits as **Sparat pass**.

### `training-log-and-review`

Logs completed and missed sessions, per-exercise sets (load, reps, optional RPE), and extra-plan activity (`activity_logged`: walks, yoga, climbing, hiking, and similar). A whole-session shortcut may copy last working loads into `exercise_logged` after one approval. Writes append-only `events`. A profile habit is not done until logged. After a week without habit logs, ask once with the user's habit names. Weekly reviews are not implemented yet. Must not activate major plan changes.

### `training-nutrition` (deferred)

Collects nutrition preferences and constraints. Gives simple meal suggestions tied to training, goals, recovery, confirmed lifestyle habits, and `activity_logged`. No diagnoses, no medication advice, no clinical diets. Do not store kcal as confirmed facts.

## Defaults

These are easy to change later:

- One personal `user_id` stored in the ChatGPT Project instructions
- Locale `sv-SE`, timezone `Europe/Stockholm`, ISO week Monday–Sunday (`week_start = 1`)
- First weekly plan combines only the modalities the user selected
- Nutrition preferences may be stored on the profile; no meal plans in v1
- `recommendations` exists but is unused in the first vertical
- Schema changes go through SQL files in this repo, not ad-hoc DDL in chat
