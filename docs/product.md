# Product

`training` is a personal AI training and nutrition partner.

ChatGPT is the interface and reasoning layer. GitHub holds versioned skills and contracts. Supabase holds durable state.

The long-term product should:

- build and adapt plans for strength, running/conditioning, mobility/yoga, and recovery
- combine those modalities into one weekly plan
- account for goals, experience, time, equipment, injuries, health, recovery, and life context
- log sessions, results, body weight, personal bests, perceived effort, and other observations
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
- `training-onboarding`
- `training-plan` for the first weekly plan

v1 does not implement:

- `training-log-and-review` (logging, missed sessions, weekly review)
- `training-nutrition` (meal suggestions)
- auth, RLS policies, multiple users, admin, or invites
- a web app, custom backend, custom MCP server, or background jobs
- Garmin read/write
- automatic research monitoring
- periodization engines or dedicated PR tables
- publishing as an OpenAI plugin

## Skills

Four skills are in scope for the product. Only the first two exist as files in v1.

### `training-onboarding`

Collects profile data progressively, identifies missing fields for later capabilities, runs a basic safety screen, and updates the profile after explicit approval. Does not create weekly plans or meal suggestions. If `safety_status` is `stop`, it must refuse training-plan handoff.

### `training-plan`

Creates and changes weekly plans across the modalities the user actually chose. Reads only confirmed profile data. Writes `plans` and `events`. May apply minor reversible tweaks inside an already active plan. Larger changes require a new proposed plan and approval. Does not log completed sessions.

### `training-log-and-review` (deferred)

Logs completed and missed sessions, metrics, and observations. Runs weekly reviews. Writes append-only `events`. May propose adjustments; must not silently activate major plan changes.

### `training-nutrition` (deferred)

Collects nutrition preferences and constraints. Gives simple meal suggestions tied to training, goals, and recovery. No diagnoses, no medication advice, no clinical diets.

## Defaults

These are easy to change later:

- One personal `user_id` stored in the ChatGPT Project instructions
- Locale `sv-SE`, timezone `Europe/Stockholm`, ISO week Monday–Sunday (`week_start = 1`)
- First weekly plan combines only the modalities the user selected
- Nutrition preferences may be stored on the profile; no meal plans in v1
- `recommendations` exists but is unused in the first vertical
- Schema changes go through SQL files in this repo, not ad-hoc DDL in chat
