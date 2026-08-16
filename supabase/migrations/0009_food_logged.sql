-- Optional meal logs. Same instance rules as activity_logged; slot plays activity_key's role.
-- ChatGPT's official app uses a privileged connection and still bypasses RLS.

alter table events drop constraint if exists events_type_check;

alter table events add constraint events_type_check
  check (type in (
    'safety_screening_completed',
    'profile_confirmed',
    'profile_updated',
    'plan_proposed',
    'plan_activated',
    'plan_superseded',
    'exercise_logged',
    'session_completed',
    'session_missed',
    'activity_logged',
    'food_logged'
  ));

create index if not exists events_food_logged_date_idx
  on events (user_id, ((payload->>'date')), occurred_at desc)
  where type = 'food_logged';

comment on table events is
  'Append-only history. Do not UPDATE or DELETE. Corrections are new rows. Latest exercise_logged for user+date+exercise_key is current. Latest activity_logged for user+date+activity_key+instance is current; day load is the sum of current bouts. Latest food_logged for user+date+slot+instance is current; same instance rules as activity_logged.';
