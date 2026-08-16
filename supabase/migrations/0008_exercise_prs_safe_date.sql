-- Safe date cast in recompute_exercise_prs so a bad payload.date
-- cannot abort the exercise_logged INSERT. ChatGPT must not run this.

create or replace function recompute_exercise_prs(p_user_id uuid, p_exercise_key text)
returns void
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if p_exercise_key is null or p_exercise_key = '' then
    return;
  end if;

  with current_logs as (
    select distinct on (payload->>'date')
      id,
      payload,
      case
        when (payload->>'date') ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        then (payload->>'date')::date
      end as log_date
    from events
    where user_id = p_user_id
      and type = 'exercise_logged'
      and payload->>'exercise_key' = p_exercise_key
    order by payload->>'date', occurred_at desc
  ),
  set_rows as (
    select
      c.id as event_id,
      c.log_date,
      case
        when (s->>'load_kg') ~ '^[0-9]+([.][0-9]+)?$'
        then (s->>'load_kg')::numeric
      end as load_kg,
      case
        when (s->>'distance_km') ~ '^[0-9]+([.][0-9]+)?$'
        then (s->>'distance_km')::numeric
      end as distance_km,
      case
        when (s->>'duration_min') ~ '^[0-9]+([.][0-9]+)?$'
         and (
           (s->>'distance_km') ~ '^[0-9]+([.][0-9]+)?$'
           or p_exercise_key ~ '(run|jog|lopp)'
         )
        then (s->>'duration_min')::numeric
      end as duration_min,
      case
        when (s->>'distance_km') ~ '^[0-9]+([.][0-9]+)?$'
         and (s->>'duration_min') ~ '^[0-9]+([.][0-9]+)?$'
         and (s->>'distance_km')::numeric > 0
        then (s->>'duration_min')::numeric / (s->>'distance_km')::numeric
      end as pace_min_per_km
    from current_logs c
    cross join lateral jsonb_array_elements(coalesce(c.payload->'sets', '[]'::jsonb)) as s
  ),
  kg as (
    select event_id, log_date, load_kg
    from set_rows
    where load_kg is not null
    order by load_kg desc, log_date desc, event_id
    limit 1
  ),
  dist as (
    select event_id, log_date, distance_km
    from set_rows
    where distance_km is not null
    order by distance_km desc, log_date desc, event_id
    limit 1
  ),
  dur as (
    select event_id, log_date, duration_min
    from set_rows
    where duration_min is not null
    order by duration_min desc, log_date desc, event_id
    limit 1
  ),
  pace as (
    select event_id, log_date, pace_min_per_km
    from set_rows
    where pace_min_per_km is not null
    order by pace_min_per_km asc, log_date desc, event_id
    limit 1
  )
  insert into exercise_prs (
    user_id,
    exercise_key,
    pr_kg,
    pr_kg_event_id,
    pr_kg_date,
    pr_distance_km,
    pr_distance_event_id,
    pr_distance_date,
    pr_duration_min,
    pr_duration_event_id,
    pr_duration_date,
    pr_pace_min_per_km,
    pr_pace_event_id,
    pr_pace_date,
    updated_at
  )
  select
    p_user_id,
    p_exercise_key,
    kg.load_kg,
    kg.event_id,
    kg.log_date,
    dist.distance_km,
    dist.event_id,
    dist.log_date,
    dur.duration_min,
    dur.event_id,
    dur.log_date,
    pace.pace_min_per_km,
    pace.event_id,
    pace.log_date,
    now()
  from (select 1) as dummy
  left join kg on true
  left join dist on true
  left join dur on true
  left join pace on true
  on conflict (user_id, exercise_key) do update set
    pr_kg = excluded.pr_kg,
    pr_kg_event_id = excluded.pr_kg_event_id,
    pr_kg_date = excluded.pr_kg_date,
    pr_distance_km = excluded.pr_distance_km,
    pr_distance_event_id = excluded.pr_distance_event_id,
    pr_distance_date = excluded.pr_distance_date,
    pr_duration_min = excluded.pr_duration_min,
    pr_duration_event_id = excluded.pr_duration_event_id,
    pr_duration_date = excluded.pr_duration_date,
    pr_pace_min_per_km = excluded.pr_pace_min_per_km,
    pr_pace_event_id = excluded.pr_pace_event_id,
    pr_pace_date = excluded.pr_pace_date,
    updated_at = now();
end;
$$;
