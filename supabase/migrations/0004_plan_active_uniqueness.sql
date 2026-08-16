-- At most one active plan per user.
-- 0005 adds: one proposed per (user_id, period_start), ISO week check,
-- no overlapping active/proposed periods, and append-only events.

create unique index if not exists plans_one_active_per_user
  on plans (user_id)
  where status = 'active';
