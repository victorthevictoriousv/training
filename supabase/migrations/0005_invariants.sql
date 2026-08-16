-- DB guards that skills were only promising in prose.
-- ChatGPT must not run this (or any DDL). Apply as a migration.

create or replace function set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function events_reject_mutation()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  raise exception 'events is append-only; insert a new row instead of UPDATE or DELETE';
end;
$$;

drop trigger if exists events_append_only on events;
create trigger events_append_only
before update or delete on events
for each row
execute procedure events_reject_mutation();

alter table plans drop constraint if exists plans_iso_week_chk;
alter table plans add constraint plans_iso_week_chk
  check (
    period_end = (period_start + 6)
    and extract(isodow from period_start) = 1
  );

create unique index if not exists plans_one_proposed_per_user_period
  on plans (user_id, period_start)
  where status = 'proposed';

create index if not exists plans_user_id_period_idx
  on plans (user_id, period_start, period_end);

create extension if not exists btree_gist with schema extensions;

alter table plans drop constraint if exists plans_no_overlap_active_proposed;
alter table plans add constraint plans_no_overlap_active_proposed
  exclude using gist (
    user_id with =,
    daterange(period_start, period_end, '[]') with &&
  )
  where (status in ('active', 'proposed'));
