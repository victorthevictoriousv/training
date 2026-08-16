-- Weekly meal schemas share the plans table via kind (training | nutrition).
-- Uniqueness and overlap are per (user_id, kind), not per user alone.
-- ChatGPT must not run this (or any DDL). Apply as a migration.

alter table plans
  add column if not exists kind text not null default 'training';

alter table plans drop constraint if exists plans_kind_chk;
alter table plans add constraint plans_kind_chk
  check (kind in ('training', 'nutrition'));

comment on column plans.kind is
  'training = weekly training plan; nutrition = weekly meal schema. Skills filter every write and covering lookup by kind.';

comment on table plans is
  'Weekly training and nutrition plans. At most one active row per (user_id, kind).';

drop index if exists plans_one_active_per_user;
create unique index if not exists plans_one_active_per_user_kind
  on plans (user_id, kind)
  where status = 'active';

drop index if exists plans_one_proposed_per_user_period;
create unique index if not exists plans_one_proposed_per_user_kind_period
  on plans (user_id, kind, period_start)
  where status = 'proposed';

alter table plans drop constraint if exists plans_no_overlap_active_proposed;
alter table plans add constraint plans_no_overlap_active_proposed
  exclude using gist (
    user_id with =,
    kind with =,
    daterange(period_start, period_end, '[]') with &&
  )
  where (status in ('active', 'proposed'));
