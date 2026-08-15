# training

Personal AI training and nutrition partner. ChatGPT is the interface and reasoning layer. This repository is the source of truth for skills, contracts, and the database schema. Supabase is the memory.

The product is called **training**. Do not rename it to AI-PT, AI PT, or ai-pt.

## v1 scope

v1 is a ChatGPT Project that:

- follows versioned skills in this repo
- reads and writes four Supabase tables through the official Supabase ChatGPT app
- confirms facts with the user before saving them
- creates a first weekly plan only after the profile is confirmed

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
| [docs/chatgpt-project-instructions.md](docs/chatgpt-project-instructions.md) | Paste into the ChatGPT Project |
| [docs/data-contracts.md](docs/data-contracts.md) | Tables, JSON payloads, provenance |
| [skills/training-onboarding/](skills/training-onboarding/) | Collect and confirm the profile |
| [skills/training-plan/](skills/training-plan/) | Create and activate a weekly plan |
| [supabase/migrations/0001_init.sql](supabase/migrations/0001_init.sql) | Initial schema |

## Language

- Code, tables, filenames, and technical docs: English
- Dialogue with the user and product copy: Swedish

## Later migration

Skills and `docs/data-contracts.md` are the product logic. A future TypeScript backend and custom MCP tools should implement the same contracts rather than inventing new ones.
