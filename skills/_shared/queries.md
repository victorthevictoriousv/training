# Named queries

Canonical `SELECT` statements. Skills name a `Q_*` id; they do not paste these statements.

## How to run

1. Classify intent with the skill’s intent table. On the show-saved-session fast path, skip that and use the ids listed there.
2. Open this file and copy **only** the listed ids.
3. Replace `:USER_ID` from Project instructions. Never invent another user.
4. Replace other `:placeholders` from the skill (`:date` is the session date in `Europe/Stockholm`; `:today` is today’s date there).
5. Do not run unlisted `Q_*` ids. Do not invent `ORDER BY`. Writes stay in the skill procedure.
6. Do not load a generic Supabase skill, CLI help, or docs search to run these. Execute the copied SQL.

---

### Q_profile

Current profile row. Onboarding load; plan draft; safety gate.

```sql
select id, user_id, locale, timezone, week_start,
       onboarding_status, safety_status, data, provenance
from user_profiles
where user_id = :USER_ID;
```

---

### Q_habits

Confirmed habits only. Activity logging and typicals. Skip during a mid-set gym log.

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

`exercise_logged` on `:date`. Current load per key is the first row for that key (already newest-first).

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

`activity_logged` on `:date`. Latest row per `activity_key` + `instance` (missing `instance` = 1). Next bout: `max(instance) + 1` for that date + key.

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'activity_logged'
  and payload->>'date' = :date
order by occurred_at desc;
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

Logs in the covering week. Weekly overview and the one-line “denna vecka i korthet” when drafting. `:period_start` / `:period_end` come from `Q_covering_plan`, never guessed. Skip this query if there is no covering row.

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

Max numeric `load_kg` per exercise from **current** logs only (latest row per date + `exercise_key`). A correction does not keep the old kg as a PR. Only when they ask for a strength PR. `[.]` is a literal dot (do not write `\\.`). Running PRs: `Q_run_pr`.

```sql
select current_log.payload->>'exercise_key' as exercise_key,
       max((set_row->>'load_kg')::numeric) as pr_kg
from (
  select distinct on (payload->>'exercise_key', payload->>'date')
    payload
  from events
  where user_id = :USER_ID
    and type = 'exercise_logged'
  order by payload->>'exercise_key', payload->>'date', occurred_at desc
) current_log
cross join lateral jsonb_array_elements(current_log.payload->'sets') as set_row
where (set_row->>'load_kg') ~ '^[0-9]+([.][0-9]+)?$'
group by 1;
```

---

### Q_run_pr

Max distance / duration and fastest pace from **current** `exercise_logged` per date + key. Only when they ask for a running PR (10 km, tid, pace). Do not use `activity_logged`. `[.]` is a literal dot.

```sql
select
  exercise_key,
  max(distance_km) as pr_distance_km,
  max(duration_min) as pr_duration_min,
  min(pace_min_per_km) filter (where pace_min_per_km is not null) as pr_pace_min_per_km
from (
  select
    current_log.payload->>'exercise_key' as exercise_key,
    case
      when (set_row->>'distance_km') ~ '^[0-9]+([.][0-9]+)?$'
      then (set_row->>'distance_km')::numeric
    end as distance_km,
    case
      when (set_row->>'duration_min') ~ '^[0-9]+([.][0-9]+)?$'
      then (set_row->>'duration_min')::numeric
    end as duration_min,
    case
      when (set_row->>'distance_km') ~ '^[0-9]+([.][0-9]+)?$'
       and (set_row->>'duration_min') ~ '^[0-9]+([.][0-9]+)?$'
       and (set_row->>'distance_km')::numeric > 0
      then (set_row->>'duration_min')::numeric
         / (set_row->>'distance_km')::numeric
    end as pace_min_per_km
  from (
    select distinct on (payload->>'exercise_key', payload->>'date')
      payload
    from events
    where user_id = :USER_ID
      and type = 'exercise_logged'
    order by payload->>'exercise_key', payload->>'date', occurred_at desc
  ) current_log
  cross join lateral jsonb_array_elements(current_log.payload->'sets') as set_row
  where (set_row->>'distance_km') ~ '^[0-9]+([.][0-9]+)?$'
     or (
       (set_row->>'duration_min') ~ '^[0-9]+([.][0-9]+)?$'
       and current_log.payload->>'exercise_key' ~ '(run|jog|lopp)'
     )
) t
group by 1;
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
