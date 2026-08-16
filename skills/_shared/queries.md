# Named queries

Canonical `SELECT` statements. Skills name a `Q_*` id; they do not paste these statements.

## How to run

1. Classify intent with the skill’s intent table. On the show-saved-session or nutrition log / weigh-in / prefs fast path, skip that and use the ids listed there.
2. Open this file and copy **only** the listed ids (the groups below are orientation, not extra queries).
3. Replace `:USER_ID` from Project instructions. Never invent another user.
4. Replace other `:placeholders` from the skill (`:date` is the session date in `Europe/Stockholm`; `:today` is today’s date there).
5. Do not run unlisted `Q_*` ids. Do not invent `ORDER BY`. Writes stay in the skill procedure.
6. Do not load a generic Supabase skill, CLI help, or docs search to run these. Execute the copied SQL.

## Id groups

**Shared:** `Q_profile`, `Q_covering_plan`, `Q_habits`

**Training show:** `Q_lazy_activate_candidate`, `Q_covering_plan`, `Q_today_logs`, `Q_last_working`, `Q_queued_next_week`

**Training log:** `Q_covering_plan`, `Q_today_logs`, `Q_today_activity`, `Q_last_working`, `Q_pr`, `Q_recent_results`, `Q_habit_last_dates`, `Q_week_events`, `Q_queued_next_week`, `Q_habits`

**Training draft week:** `Q_profile`, `Q_lazy_activate_candidate`, `Q_covering_plan`, `Q_queued_next_week`, `Q_recent_working`, `Q_activity_lookback`, `Q_habit_last_dates`, `Q_week_events`

**Nutrition day (suggestion):** `Q_profile`, `Q_covering_plan`, `Q_today_logs`, `Q_today_activity`, `Q_today_food`

**Nutrition week / follow-up:** `Q_profile`, `Q_covering_plan`, `Q_week_events`, `Q_week_food`, `Q_week_weights`, `Q_habits`

**Nutrition log / prefs:** `Q_profile`, `Q_today_food`

Nutrition never runs `Q_pr`, `Q_last_working`, `Q_recent_working`, `Q_lazy_activate_candidate`. Training never runs `Q_today_food`, `Q_week_food`, `Q_week_weights` unless the same message also asked about diet.

---

### Q_profile

Current profile row. Onboarding load; plan draft; safety gate; nutrition context.

```sql
select id, user_id, locale, timezone, week_start,
       onboarding_status, safety_status, data, provenance
from user_profiles
where user_id = :USER_ID;
```

---

### Q_habits

Confirmed habits only. Activity logging and typicals. Skip during a mid-set gym log; nutrition context.

```sql
select data->'lifestyle'->'habits' as habits
from user_profiles
where user_id = :USER_ID;
```

---

### Q_covering_plan

Plan whose period contains `:date`. Never `status = 'active'` alone.

```sql
select id, status, period_start, period_end, version, title, content
from plans
where user_id = :USER_ID
  and period_start <= :date
  and period_end >= :date
  and status in ('active', 'proposed', 'completed', 'superseded')
order by
  case status
    when 'active' then 0
    when 'proposed' then 1
    when 'completed' then 2
    else 3
  end,
  activated_at desc nulls last,
  created_at desc
limit 1;
```

---

### Q_queued_next_week

Approved future week, not yet current. `:today` = today in `Europe/Stockholm`.

```sql
select id, status, period_start, period_end, version, title, content
from plans
where user_id = :USER_ID
  and status = 'proposed'
  and period_start > :today
order by period_start, created_at desc
limit 1;
```

---

### Q_lazy_activate_candidate

`proposed` week whose period contains `:today`. training-plan reads only. If a row returns, apply the lazy-activate writes in `training-plan` §1 (complete expired `active`, then activate). Do not run from `training-log-and-review`.

```sql
select id, status, period_start, period_end, version, title, content
from plans
where user_id = :USER_ID
  and status = 'proposed'
  and period_start <= :today
  and period_end >= :today
order by created_at desc
limit 1;
```

---

### Q_last_working

Latest `exercise_logged` per `exercise_key` by logged date, then insert time. Showing a session, `logga gympasset`. Not for drafting a week (`Q_recent_working`). Not for a single-set log. Not the answer to a PR question.

```sql
select distinct on (payload->>'exercise_key')
  payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
order by payload->>'exercise_key', payload->>'date' desc, occurred_at desc;
```

---

### Q_recent_working

Last 8 **current** `exercise_logged` per `exercise_key` (latest row per date + key already collapsed). Drafting a week (Förslag vikt streak). Last working is the first row per key. Do not collapse again. Do not run `Q_recent_results` once per exercise.

```sql
select payload, occurred_at
from (
  select payload, occurred_at,
         row_number() over (
           partition by payload->>'exercise_key'
           order by payload->>'date' desc, occurred_at desc
         ) as rn
  from (
    select distinct on (payload->>'exercise_key', payload->>'date')
      payload, occurred_at
    from events
    where user_id = :USER_ID
      and type = 'exercise_logged'
    order by payload->>'exercise_key', payload->>'date' desc, occurred_at desc
  ) current_per_day
) t
where rn <= 8
order by payload->>'exercise_key', payload->>'date' desc, occurred_at desc;
```

---

### Q_today_logs

`exercise_logged` on `:date`. Current load per key is the first row for that key (already newest-first); nutrition context.

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
  and payload->>'date' = :date
order by occurred_at desc;
```

---

### Q_today_activity

`activity_logged` on `:date`. Latest row per `activity_key` + `instance` (missing `instance` = 1). Next bout: `max(instance) + 1` for that date + key; nutrition context.

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'activity_logged'
  and payload->>'date' = :date
order by occurred_at desc;
```

---

### Q_today_food

`food_logged` on `:date`. Latest row per `slot` + `instance` (missing `instance` = 1). Next bout: `max(instance) + 1` for that date + slot. Same instance rules as `Q_today_activity`. Nutrition only.

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'food_logged'
  and payload->>'date' = :date
order by occurred_at desc;
```

---

### Q_week_food

`food_logged` in the covering week. Nutrition follow-up only — not the training weekly overview. `:period_start` / `:period_end` from `Q_covering_plan`. Skip if there is no covering row. Latest per `date + slot + instance` is current (same rules as `Q_today_food`).

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'food_logged'
  and (payload->>'date') >= :period_start
  and (payload->>'date') <= :period_end
order by payload->>'date', occurred_at desc;
```

---

### Q_week_weights

`body_weight_logged` in the covering week. Nutrition follow-up. Latest per `date` is current. `:period_start` / `:period_end` from `Q_covering_plan`. Skip if there is no covering row.

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'body_weight_logged'
  and (payload->>'date') >= :period_start
  and (payload->>'date') <= :period_end
order by payload->>'date', occurred_at desc;
```

---

### Q_activity_lookback

Extra-plan activity in the plan’s lookback window. Drafting a week. `:lookback_date` = Monday of the week before the covering plan (or the week being drafted). `:period_end` = that plan’s `period_end`.

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'activity_logged'
  and (payload->>'date') >= :lookback_date
  and (payload->>'date') <= :period_end
order by occurred_at desc;
```

---

### Q_week_events

Logs in the covering week. Weekly overview and the one-line “denna vecka i korthet” when drafting; training load for nutrition follow-up. `:period_start` / `:period_end` come from `Q_covering_plan`, never guessed. Skip this query if there is no covering row. Does not include `food_logged` or `body_weight_logged` (those are `Q_week_food` / `Q_week_weights`).

```sql
select type, plan_id, payload, occurred_at
from events
where user_id = :USER_ID
  and type in ('exercise_logged', 'session_completed', 'session_missed', 'activity_logged')
  and (payload->>'date') >= :period_start
  and (payload->>'date') <= :period_end
order by payload->>'date', occurred_at desc;
```

---

### Q_habit_last_dates

Last logged date per habit. Habit catch-up when drafting or wrapping the day — not during a mid-set gym log.

```sql
select payload->>'habit_key' as habit_key, max(payload->>'date') as last_date
from events
where user_id = :USER_ID
  and type = 'activity_logged'
  and payload->>'habit_key' is not null
group by payload->>'habit_key';
```

---

### Q_pr

Personal records, one row per `exercise_key`, from `exercise_prs`. Maintained by a DB trigger from **current** `exercise_logged` (latest row per date + key; a correction replaces that date). Never written by a skill. Only when they ask. Strength and running PRs both come from this id. Skip rows where every PR dimension is null (bodyweight / timed with no qualifying kg, distance, duration, or pace).

```sql
select exercise_key, pr_kg, pr_kg_date,
       pr_distance_km, pr_distance_date,
       pr_duration_min, pr_duration_date,
       pr_pace_min_per_km, pr_pace_date
from exercise_prs
where user_id = :USER_ID
  and (
    pr_kg is not null
    or pr_distance_km is not null
    or pr_duration_min is not null
    or pr_pace_min_per_km is not null
  );
```

---

### Q_recent_results

Last ~8 logs for one exercise. Only when they ask how it is going.

```sql
select occurred_at, payload
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
  and payload->>'exercise_key' = :exercise_key
order by payload->>'date' desc, occurred_at desc
limit 8;
```
