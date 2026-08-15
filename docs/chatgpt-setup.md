# ChatGPT and Supabase setup

v1 runtime: one ChatGPT Project, the GitHub connector, and the official Supabase ChatGPT app. No plugin, no custom MCP, no app.

## 1. Supabase

1. A dedicated Supabase project named `Training` already exists (`eqgfiaqqsmupbvcvcuce`, West EU / Ireland). Use that project.
2. `0001_init.sql` and `0002_rls_and_log_events.sql` have been applied. Apply [`0003_activity_logged.sql`](../supabase/migrations/0003_activity_logged.sql) in the SQL editor if `activity_logged` is not yet in the `events` type check:

```sql
select pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'events'::regclass
  and conname = 'events_type_check';
```

Expected: the definition includes `activity_logged`.

3. Confirm the four tables still exist:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('user_profiles', 'plans', 'events', 'recommendations')
order by table_name;
```

Expected: four rows.

4. Project instructions already use `SUPABASE_PROJECT_REF=eqgfiaqqsmupbvcvcuce`.

`USER_ID` is already set to `815c0d8e-9e76-4dbb-9c89-86a504bb5da0`. Keep it unless you intentionally rotate identity.

## 2. GitHub

This repository should stay the live source of skills:

[https://github.com/victorthevictoriousv/training](https://github.com/victorthevictoriousv/training)

In ChatGPT, connect the GitHub app and allow this repo.

Fallback if GitHub is unavailable: upload `docs/` and `skills/` into the Project files. Re-upload after every change. Prefer GitHub so versions stay live.

## 3. ChatGPT Project

1. Create a Project named **träning** (the Swedish UI name). The GitHub repo and product stay `training`.
2. Paste everything below the line in [`chatgpt-project-instructions.md`](chatgpt-project-instructions.md) into Project instructions. There are no placeholders to replace: GitHub URL, Supabase ref, and `USER_ID` are already filled.
3. Enable the official Supabase app for the project and point it at `eqgfiaqqsmupbvcvcuce`.
4. Enable the GitHub app and allow `https://github.com/victorthevictoriousv/training`.
5. Start a new chat inside **träning**.

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

### D2. Show today's saved session

New chat: `Vad är dagens pass?`

Expected: it runs SELECT, then shows only the sessions stored for today's date in the active plan, labelled **Sparat pass**. If the tool fails it says so and does not invent a workout.

Then ask to change one exercise. Expected: **Förslag (sparas inte än)**. After `godkänn`, that day in `plans.content` matches the new session. Without `godkänn`, `content` is unchanged.

### D3. Log a set and the session

In **träning**: `bänk 80x5` (or the name of a planned exercise).

Expected: **Sparat:** … and a new `exercise_logged` row. Then `bänk 82.5` → another `exercise_logged`; latest load is 82.5.

`logga dagens pass` then `resten enligt plan` without `godkänn`: no `session_completed`. After `godkänn`: `session_completed` and no invented `load_kg`.

```sql
select type, payload->>'date' as date, payload
from events
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
  and type in ('exercise_logged', 'session_completed', 'session_missed')
order by created_at;
```

### D4. Lifestyle habit and extra-plan activity

After B, in **träning**: `Jag går på gåband hemma 30 min 4,5 km/h två gånger om dagen på arbetsdagar.`

Expected: confirmation card proposing `lifestyle.habits`. Without `godkänn`, `data` is unchanged. After `ja, spara`:

```sql
select data->'lifestyle'->'habits' as habits,
       provenance->'lifestyle.habits' as habits_provenance
from user_profiles
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';
```

Expected: one habit (`treadmill_walk` or similar), `kind` `lifestyle`, `plan_inclusion` `background`, `times_per_day` 2, workdays, `typical_speed_kmh` 4.5. Provenance for `lifestyle.habits`. No kcal in `data`.

Then: `Gick 30 min på gåbandet`.

Expected: **Sparat:** … immediately (no second `godkänn`). No `session_completed`. Payload `instance` 1.

Then another: `Gåband 60 min 5 km/h`.

Expected: a **second** `activity_logged` the same date, `instance` 2, `duration_min` 60, `speed_kmh` 5. First row unchanged. Echo not a rättelse.

Then: `Gåband` with no numbers.

Expected: `instance` 3 (or 1 if this is a new day), typicals from the habit, echo `(enligt vana)`.

```sql
select type, payload
from events
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
  and type = 'activity_logged'
order by created_at;
```

Expected: `kind` `lifestyle`, `duration_min` 30, `habit_key` matching the habit, `plan_id` null. Speed only if you stated it. No kcal.

Then `Lägg en veckoplan för nästa vecka.` Expected: draft `intent` mentions the gåband habit; `content.days` has no gåband sessions. After `godkänn`, same in the saved plan.

`Vad är dagens pass?` Expected: **Sparat pass** is only programmed sessions, not the walks.

Optional habit with a weekday: `Jag klättrar onsdagar ca 90 min, lägg in det i schemat.` After `godkänn`, a climbing habit with `plan_inclusion` `scheduled`. Next week draft has an `other` session on Wednesday with `habit_key`. `Klättrade 2h` that Wednesday → `activity_logged` plus `session_completed`. An extra climb on another day → `activity_logged` only.

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
