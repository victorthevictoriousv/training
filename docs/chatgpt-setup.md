# ChatGPT and Supabase setup

v1 runtime: one ChatGPT Project, the GitHub connector, and the official Supabase ChatGPT app. No plugin, no custom MCP, no app.

## 1. Supabase

1. A dedicated Supabase project named `Training` already exists (`eqgfiaqqsmupbvcvcuce`, West EU / Ireland). Use that project.
2. `0001_init.sql`, `0002_rls_and_log_events.sql`, and [`0003_activity_logged.sql`](../supabase/migrations/0003_activity_logged.sql) have been applied. Confirm `activity_logged` is in the `events` type check:

```sql
select pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'events'::regclass
  and conname = 'events_type_check';
```

Expected: the definition includes `activity_logged`.

3. [`0004_plan_active_uniqueness.sql`](../supabase/migrations/0004_plan_active_uniqueness.sql) has been applied. Confirm the index exists:

```sql
select indexdef
from pg_indexes
where tablename = 'plans'
  and indexname = 'plans_one_active_per_user';
```

Expected: one row, `where (status = 'active'::text)` in the definition.

4. Confirm the four tables still exist:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('user_profiles', 'plans', 'events', 'recommendations')
order by table_name;
```

Expected: four rows.

5. Project instructions already use `SUPABASE_PROJECT_REF=eqgfiaqqsmupbvcvcuce`.

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

### D. Plan — propose then save

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

- at most one `active` plan; at most one `proposed` future week
- `period_start` is a Monday, `period_end` the following Sunday
- `content.days` only uses modalities you confirmed
- If that Monday is **after today**: the new row is `proposed`, event `plan_proposed` only, `activated_at` is null. No `plan_activated`. An existing current week (if any) stays `active`.
- If that Monday is **today or earlier**: events `plan_proposed` and `plan_activated` for that `plan_id`, `activated_at` is set, status `active`

### D2. Show today's saved session

New chat: `Vad är dagens pass?`

Expected: it runs the covering-plan SELECT for **today** (not `status = 'active'` alone), then shows only the sessions stored for today's date in that plan, labelled **Sparat pass**. If today is not in any saved week, it says there is no saved plan for that date (not a rest day, not an invented workout). If the tool fails it says so and does not invent a workout.

Then ask to **byt** one exercise (do not say it is missing at the gym). Expected: **Förslag (sparas inte än)**. After `godkänn`, that day in the covering plan’s `content` matches the new session and `data.equipment.home_gym_substitutions` is unchanged. Without `godkänn`, `content` is unchanged.

### D3. Log a set and the session

In **träning**: `bänk 80x5` (or the name of a planned exercise).

Expected: **Sparat:** … and a new `exercise_logged` row. Then `bänk 82.5` → another `exercise_logged`; latest load is 82.5.

`logga dagens pass` then `resten enligt plan` without `godkänn`: no `session_completed`. After `godkänn`: `session_completed` and no invented `load_kg`.

`logga gympasset` (or `klarade alla övningar`) without `godkänn`: no new `exercise_logged` / `session_completed`. If an exercise has no history, it asks for weight first and still does not write. After `godkänn` when history exists: one `exercise_logged` per remaining working item (loads = last working, not plan RPE) and `session_completed`. `bänk 80x5` still saves immediately without a second `godkänn`.

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

### D5. Gym-unavailable vs this-week swap

After D (a covering plan exists for the days you will edit). Pick a named strength exercise from that week. The prompts below are examples; the skill should also accept other wordings with the same meaning.

First, this-week swap only: `Byt [övning] mot något annat.` Do not imply the gym lacks it.

Expected: **Förslag (sparas inte än)**. After `godkänn`, that item's `name` in `plans.content` changed. No `preferred` from this swap. `data.equipment.home_gym_substitutions` unchanged. Without `godkänn` first, nothing written.

Then gym-unavailable (same or another planned exercise): `[Övning] finns inte på gymmet, ge mig ett annat förslag.`

Expected: **Förslag (sparas inte än)** with one home alternative and the original as first choice. Without `godkänn`: plan and profile unchanged. After `godkänn`:

```sql
select content
from plans
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
  and period_start <= (now() at time zone 'Europe/Stockholm')::date
  and period_end >= (now() at time zone 'Europe/Stockholm')::date
order by
  case status
    when 'active' then 0
    when 'proposed' then 1
    when 'completed' then 2
    else 3
  end
limit 1;

select data->'equipment'->'home_gym_substitutions' as substitutions,
       provenance->'equipment.home_gym_substitutions' as substitutions_provenance
from user_profiles
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';
```

Expected:

- prescribed `name` / `key` is the home alternative
- `preferred.name` / `preferred.key` is the original first choice
- `home_gym_substitutions` contains that pair
- provenance for `equipment.home_gym_substitutions`
- a `profile_updated` event

`Vad är dagens pass?` (or that day): **Sparat pass** shows the home exercise, then **Förstahand (annat gym):** and the original name.

Next week draft should reuse the stored pair without asking again.

`Nu har gymmet [originalövning].` After `godkänn`: that pair is gone from `home_gym_substitutions` (omit the key if the array is empty).

### D6. Next week must not hide the rest of this week

After a current-week plan is `active` (period still contains today), `Lägg en veckoplan för nästa vecka.` then `godkänn`.

Expected: current week still `active`; next week is `proposed` (not `active`). `plan_superseded` must not fire on the current week.

Then ask about a remaining day of the current week (e.g. `har jag något löppass imorgon?` when tomorrow is still in this ISO week). Expected: **Sparat pass** from the current week’s `content`, not “ingen plan” / rest just because next week is saved.

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
