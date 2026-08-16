-- Speeds last-working / Förslag-vikt scans on payload->>'exercise_key'.
-- ChatGPT must not run this (or any DDL). Apply as a migration.

create index if not exists events_exercise_logged_key_idx
  on events (user_id, (payload->>'exercise_key'), (payload->>'date') desc)
  where type = 'exercise_logged';
