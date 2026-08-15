-- Enforce at the database level what skills were only promising in prose:
-- at most one active plan per user. A "proposed" future week cannot get the
-- same treatment here because "future" depends on current_date, which is not
-- immutable enough for a partial index predicate; that half of the invariant
-- still relies on the skill procedure in training-plan/SKILL.md.

create unique index if not exists plans_one_active_per_user
  on plans (user_id)
  where status = 'active';
