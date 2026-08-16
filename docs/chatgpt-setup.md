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

3. [`0004_plan_active_uniqueness.sql`](../supabase/migrations/0004_plan_active_uniqueness.sql) and [`0005_invariants.sql`](../supabase/migrations/0005_invariants.sql) have been applied. Confirm:

```sql
select indexname
from pg_indexes
where tablename = 'plans'
  and indexname in ('plans_one_active_per_user', 'plans_one_proposed_per_user_period');

select conname
from pg_constraint
where conrelid = 'plans'::regclass
  and conname in ('plans_iso_week_chk', 'plans_no_overlap_active_proposed');

select tgname
from pg_trigger
where tgrelid = 'events'::regclass
  and tgname = 'events_append_only';
```

Expected: both indexes, both constraints, and the append-only trigger.

4. [`0006_exercise_key_index.sql`](../supabase/migrations/0006_exercise_key_index.sql), [`0007_exercise_prs.sql`](../supabase/migrations/0007_exercise_prs.sql), and [`0008_exercise_prs_safe_date.sql`](../supabase/migrations/0008_exercise_prs_safe_date.sql) have been applied. Confirm:

```sql
select indexname
from pg_indexes
where tablename = 'events'
  and indexname = 'events_exercise_logged_key_idx';

select tgname
from pg_trigger
where tgrelid = 'events'::regclass
  and tgname = 'events_update_exercise_prs';

select to_regclass('public.exercise_prs') as exercise_prs;
```

Expected: the index, the trigger, and a non-null `exercise_prs` oid.

5. [`0009_food_logged.sql`](../supabase/migrations/0009_food_logged.sql) has been applied. Confirm:

```sql
select pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'events'::regclass
  and conname = 'events_type_check';

select indexname
from pg_indexes
where tablename = 'events'
  and indexname = 'events_food_logged_date_idx';
```

Expected: the definition includes `food_logged`, and the partial index exists.

6. [`0010_body_weight_logged.sql`](../supabase/migrations/0010_body_weight_logged.sql) has been applied. Confirm:

```sql
select pg_get_constraintdef(oid)
from pg_constraint
where conrelid = 'events'::regclass
  and conname = 'events_type_check';

select indexname
from pg_indexes
where tablename = 'events'
  and indexname = 'events_body_weight_logged_date_idx';
```

Expected: the definition includes `body_weight_logged`, and the partial index exists.

7. Confirm the five tables still exist:

```sql
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in ('user_profiles', 'plans', 'events', 'recommendations', 'exercise_prs')
order by table_name;
```

Expected: five rows.

8. Project instructions already use `SUPABASE_PROJECT_REF=eqgfiaqqsmupbvcvcuce`.

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

Expected: it follows the show-saved-session fast path (`queries.md` + the listed `Q_*`, no constitution docs, no skill references, no generic Supabase skill). It runs the covering-plan SELECT for **today** (not `status = 'active'` alone), then shows only the sessions stored for today's date in that plan, labelled **Sparat pass**. If today is not in any saved week, it says there is no saved plan for that date (not a rest day, not an invented workout). If the tool fails it says so and does not invent a workout.

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

### D7. Förslag vikt uses a two-session streak

After D (a covering week exists) and at least two `exercise_logged` rows for one compound lift, on **different dates**, same `load_kg`, every working set at or above the planned low end, RPE missing or ≤ 7.5.

New chat: `Lägg en veckoplan för nästa vecka.` Do not `godkänn` yet.

Expected: that lift is labelled **Förslag vikt** at last working + 2.5 kg (isolation: +1.25 or hold). A lift with only **one** successful current log at that kg stays at last working (no bump). `Vad är dagens pass?` and `logga gympasset` still cue / copy last working with no bump.

Without `godkänn`: `plans.content` unchanged. After `godkänn`: `item.load` on the bumped lift matches the proposal.

If the latest log for that key missed reps or has RPE ≥ 9: hold or −2.5, not +2.5.

### D8. PR ignores a corrected load

After an `exercise_logged` for a key at a high kg, send a correction (`nej, [lower] kg` or `[lift] [lower]`). Then: `Vad är mitt PR i [lift]?`

Expected: PR is the corrected (current) kg, not the superseded row. `exercise_prs.pr_kg` for that key matches the current-log max. `Q_pr` must not change if you only `UPDATE` an event (that write must fail: events are append-only).

Then log a lighter set for the same key on a **different** date. Expected: `pr_kg` stays at the current-log max (the lighter day does not lower PR).

```sql
select exercise_key, pr_kg, pr_kg_date
from exercise_prs
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
order by exercise_key;
```

### D9. Profile merge does not wipe

After a complete profile exists, `lägg till vana` (or change one field) then `godkänn`.

Expected: new habit (or field) is in `data`; `goals`, `availability`, `equipment`, and unrelated keys are still present. No `data = :data` replace of the whole document.

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

### G. Weekly overview then next-week draft

Prerequisite: a covering week with at least one `session_completed`, one `session_missed`, and e.g. gåband (`activity_logged`). New chat per prompt. Speak Swedish.

Count first (repeat after step 1; counts must not change until `godkänn` in step 2):

```sql
select type, count(*)
from events
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
group by type
order by type;

select id, status, period_start, period_end
from plans
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0'
order by created_at;

select count(*) as recommendations_count
from recommendations
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';
```

1. Prompt: `Hur gick veckan?`

Expected: a Swedish card, not D2’s show-saved-session fast path (not only today’s **Sparat pass**). Week dates = the covering plan’s `period_start`–`period_end` (not a guessed Monday). On **Monday**, a bare `Hur gick veckan?` is the week that just ended (lookup date = yesterday), not the new empty week. Gjort / hoppat över / oklart / kvar match the SQL. Habits as a count against the pattern, not as `session_missed`. No PR unless you asked. Event / plan / `recommendations` counts unchanged. No new `week_reviewed` (that type does not exist).

2. Then: `Ja, lägg nästa vecka` without `godkänn`.

Expected: **Förslag (sparas inte än)**; `plans` unchanged. The draft includes one line **denna vecka i korthet**. Suggested kg follow **Förslag vikt** in `loads-and-prs.md` (two successful current logs at the same kg, not a single last log). Not a second progression rule.

After `godkänn`: if that Monday is **after today**, a new `proposed` row; current week still `active`; `plan_proposed` only for the new id (no `plan_activated`). If a `proposed` week already existed for that Monday, that old row is `superseded`.

3. Mid-week (today is not Sunday): remaining days of the covering week are **kvar**, not hoppat över / missade.

4. With no covering plan for today (or a named week with no row): `ingen sparad plan` (or equivalent). No invented overview. No events written.

### I. Nutrition

Count first:

```sql
select count(*) as recommendations_count
from recommendations
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';

select count(*) as event_count
from events
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';

select data->'body' as body,
       data->'nutrition' as nutrition,
       safety_status
from user_profiles
where user_id = '815c0d8e-9e76-4dbb-9c89-86a504bb5da0';
```

1. Nutrition onboarding (`jag vill sätta upp kosten`): confirm body + proposed `target_kcal` after `godkänn`.

Expected: `data.body` has sex, birth_year, height_cm, weight_kg. `nutrition.energy.target_kcal` is an integer. No BMR, TDEE, macros, or MET keys in `data`. `recommendations_count` unchanged.

2. Save a staple (`lägg till matvana` or spara from a suggestion) and a recipe.

Expected: `nutrition.library` has both `kind` values after `godkänn`. Empty array is not stored.

3. New chat: meal suggestion tied to today's training (`Vad ska jag äta till middag?` or `Vad ska jag äta efter passet?`).

Expected: a Swedish **Förslag** card that prefers library items for that slot and references real logged activity (not only the aspirational plan). Does not print BMR/TDEE unless you asked about energy. `recommendations` unchanged. Without `godkänn`, library unchanged.

4. Log a meal without a second confirmation (`åt kycklingris till middag` or the staple name).

Expected: **Sparat:**; `event_count` increased by one `food_logged`. No kcal in payload. A second lunch the same day is a new `instance`. `nej` / `rättelse` reuses instance.

5. Suggestion with no meal log that day still returns **Förslag**. `godkänn` is required for target and library, not for “åt X”.

6. Food reaction (`Jag tål inte laktos längre`): stays conversational (observation, not a diagnosis), offers the onboarding handoff, writes nothing itself until they confirm.

7. Weigh-in without approving a new target (`väger 88,6`): **Sparat:**; `body_weight_logged` added; `body.weight_kg` matches; old `target_kcal` remains.

8. Follow-up (`hur går kosten?`): Swedish facts / unknown / slutsats over the covering week’s training (`Q_week_events`), meals (`Q_week_food`), and weights (`Q_week_weights`). Sparse food is unknown, not a deficit. No auto-write of `target_kcal`. After `godkänn` of a proposed change, only that integer updates.

9. Eating-disorder (or clinician diet / insulin-diabetes) disclosure while asking for a calorie target: refuses `target_kcal`; `safety_status` and the training plan unchanged.

## 5. What you cannot verify from this repo alone

The ChatGPT conversation itself has to be run in your account after GitHub and Supabase are connected. The SQL above is the source of truth for whether the vertical works.
