# training

Personal AI training and nutrition partner. ChatGPT is the interface and reasoning layer. This repository is the source of truth for skills, contracts, and the database schema. Supabase is the memory.

The product is called **training**. Do not rename it to AI-PT, AI PT, or ai-pt.

## v1 scope

v1 is a ChatGPT Project that:

- follows versioned skills in this repo
- reads five Supabase tables through the official Supabase ChatGPT app (`exercise_prs` is trigger-maintained; skills never write it)
- confirms facts with the user before saving profile and plan drafts
- logs explicit exercise lines, extra-plan activity, and optional meals without a second confirmation (optional kcal and protein on the meal, user-stated or estimated)
- creates a first weekly plan only after the profile is confirmed
- gives meal suggestions from confirmed nutrition preferences and a food/recipe library (no persisted weekly menu); may save a confirmed daily calorie target

v1 is not a web app, not a custom backend, and not a custom MCP server.

The first complete vertical is:

1. Onboarding with safety screening
2. A confirmed profile in `user_profiles`
3. A proposed then activated weekly plan in `plans`
4. Append-only `events` for those writes

## Repository layout

```text
docs/                  Product rules and ChatGPT setup
skills/                Agent skills (Agent Skills format)
supabase/migrations/   Versioned Postgres schema
```

| Path | Role |
| --- | --- |
| [docs/product.md](docs/product.md) | Vision, v1 boundary, deferred work |
| [docs/chatgpt-setup.md](docs/chatgpt-setup.md) | Connect ChatGPT, GitHub, and Supabase; verify the vertical |
| [docs/chatgpt-project-instructions.md](docs/chatgpt-project-instructions.md) | Paste into the ChatGPT Project named **träning** |
| [docs/data-contracts.md](docs/data-contracts.md) | Tables, JSON payloads, provenance |
| [skills/training-onboarding/](skills/training-onboarding/) | Collect and confirm the profile |
| [skills/training-plan/](skills/training-plan/) | Create, show, and change the weekly plan |
| [skills/training-log-and-review/](skills/training-log-and-review/) | Log sets, loads, extra-plan activity, and completed or missed sessions |
| [skills/training-nutrition/](skills/training-nutrition/) | Meal suggestions, optional food and weight logs (optional kcal/protein on the meal), follow-up, library saves after approval |
| [skills/_shared/queries.md](skills/_shared/queries.md) | Named `SELECT`s (`Q_*`). Skills name an id; they do not paste SQL |
| [supabase/migrations/0001_init.sql](supabase/migrations/0001_init.sql) | Initial schema |
| [supabase/migrations/0002_rls_and_log_events.sql](supabase/migrations/0002_rls_and_log_events.sql) | RLS enabled; `exercise_logged`, `session_completed`, `session_missed` event types |
| [supabase/migrations/0003_activity_logged.sql](supabase/migrations/0003_activity_logged.sql) | `activity_logged` event type |
| [supabase/migrations/0004_plan_active_uniqueness.sql](supabase/migrations/0004_plan_active_uniqueness.sql) | DB-level guard: at most one `active` plan per user |
| [supabase/migrations/0005_invariants.sql](supabase/migrations/0005_invariants.sql) | Append-only `events`; ISO week; one `proposed` per period; no overlapping `active`/`proposed` |
| [supabase/migrations/0006_exercise_key_index.sql](supabase/migrations/0006_exercise_key_index.sql) | Index on `exercise_logged` `exercise_key` for last-working scans |
| [supabase/migrations/0007_exercise_prs.sql](supabase/migrations/0007_exercise_prs.sql) | `exercise_prs` table; trigger recomputes current-log PRs |
| [supabase/migrations/0008_exercise_prs_safe_date.sql](supabase/migrations/0008_exercise_prs_safe_date.sql) | Safe date cast in the PR recompute so a bad log date cannot abort `events` insert |
| [supabase/migrations/0009_food_logged.sql](supabase/migrations/0009_food_logged.sql) | `food_logged` event type; partial date index |
| [supabase/migrations/0010_body_weight_logged.sql](supabase/migrations/0010_body_weight_logged.sql) | `body_weight_logged` event type; partial date index |

## Language

- Code, tables, filenames, and technical docs: English
- Dialogue with the user and product copy: Swedish

## Later migration

Skills and `docs/data-contracts.md` are the product logic. A future TypeScript backend and custom MCP tools should implement the same contracts rather than inventing new ones.
