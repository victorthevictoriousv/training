# ChatGPT and Supabase setup

v1 runtime: one ChatGPT Project, the GitHub connector, and the official Supabase ChatGPT app. No plugin, no custom MCP, no app.

## 1. Supabase

1. A dedicated Supabase project named `Training` already exists (`eqgfiaqqsmupbvcvcuce`, West EU / Ireland). Use that project.
2. `0001_init.sql` has been applied. Confirm the four tables still exist:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('user_profiles', 'plans', 'events', 'recommendations')
order by table_name;
```

Expected: four rows.

3. Project instructions already use `SUPABASE_PROJECT_REF=eqgfiaqqsmupbvcvcuce`.

`USER_ID` is already set to `815c0d8e-9e76-4dbb-9c89-86a504bb5da0`. Keep it unless you intentionally rotate identity.

## 2. GitHub

This repository should stay the live source of skills:

[https://github.com/victorthevictoriousv/training](https://github.com/victorthevictoriousv/training)

In ChatGPT, connect the GitHub app and allow this repo.

Fallback if GitHub is unavailable: upload `docs/` and `skills/` into the Project files. Re-upload after every change. Prefer GitHub so versions stay live.

## 3. ChatGPT Project

1. Create a Project named `training`.
2. Paste the contents of [`chatgpt-project-instructions.md`](chatgpt-project-instructions.md) into Project instructions. `USER_ID` and `SUPABASE_PROJECT_REF` are already filled.
3. Enable the official Supabase app for the project and point it at the training project ref.
4. Enable GitHub for the project.
5. Start a new chat inside the project.

## 4. Verification

Use a new chat for each check. Speak Swedish as the user. Then inspect SQL in Supabase.

Replace the user id if you rotated it.

### A. Onboarding — abort without approval

Prompt: `Hej, jag vill börja träna.`

Answer screening and a few profile questions. When the assistant shows a summary, say `vänta, spara inte än`.

```sql
select id, onboarding_status, safety_status, data, provenance
from user_profiles
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';
```

Expected: no row, or a row with empty `data` and no confirmed provenance. No `profile_confirmed` event.

### B. Onboarding — confirm profile

Continue (or new chat): complete screening and the minimum fields, then `ja, spara`.

Minimum to confirm:

- safety screening
- primary goal
- days per week or preferred days
- session minutes
- equipment location
- modalities to include

```sql
select onboarding_status, safety_status, data, provenance
from user_profiles
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';

select type, source, source_status, payload, created_at
from events
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
order by created_at;
```

Expected:

- `safety_status` in (`cleared`, `restricted`)
- confirmed keys in both `data` and `provenance`
- events include `safety_screening_completed` and `profile_confirmed`
- every `provenance.*.event_id` matches an `events.id`
- `data` does not contain assistant guesses that you never said

### C. Plan — refuse without profile

In a fresh database (or before B), ask: `Lägg en veckoplan.`

Expected: onboarding starts; no `plans` row.

### D. Plan — propose then activate

After B: `Lägg en veckoplan för nästa vecka.`

Inspect the Swedish proposal. Then `godkänn`.

```sql
select id, status, period_start, period_end, title, content, activated_at
from plans
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
order by created_at;

select type, plan_id, payload
from events
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
  and type in ('plan_proposed', 'plan_activated', 'plan_superseded')
order by created_at;
```

Expected:

- exactly one `active` plan
- `period_start` is a Monday, `period_end` the following Sunday
- `content.days` only uses modalities you confirmed
- events `plan_proposed` and `plan_activated` for that `plan_id`
- `activated_at` is set

### E. End-to-end provenance

```sql
-- Confirmed profile fields should not look like inferences
select jsonb_pretty(data) as data, jsonb_pretty(provenance) as provenance
from user_profiles
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';

-- Inferences must not be stored as confirmed profile events
select id, type, source, source_status
from events
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
  and source = 'ai'
  and source_status = 'confirmed';
```

Expected: the last query returns zero rows. Profile `data` only contains things you actually confirmed.

### F. Safety stop (optional)

Start over or use a throwaway project. Answer that you get chest pain when exerting.

Expected: Swedish advice to seek care; `safety_status = stop` only after you approve that screening summary; no plan is created even if you ask for one.

## 5. What you cannot verify from this repo alone

The ChatGPT conversation itself has to be run in your account after GitHub and Supabase are connected. The SQL above is the source of truth for whether the vertical works.
