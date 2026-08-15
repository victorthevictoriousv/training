-- RLS for the Data API, plus event types for session logging.
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
    'session_missed'
  ));

create index if not exists events_exercise_logged_date_idx
  on events (user_id, ((payload->>'date')), occurred_at desc)
  where type = 'exercise_logged';

alter table user_profiles enable row level security;
alter table plans enable row level security;
alter table events enable row level security;
alter table recommendations enable row level security;

comment on table events is
  'Append-only history. Do not UPDATE or DELETE. Corrections are new rows. Latest exercise_logged for user+date+exercise_key is current.';
