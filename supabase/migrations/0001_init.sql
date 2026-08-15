-- training v1 schema
-- Apply once to an empty Supabase project. Later schema changes belong in new files.

create extension if not exists pgcrypto;

create or replace function set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- user_profiles -------------------------------------------------------------

create table user_profiles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique,
  locale text not null default 'sv-SE',
  timezone text not null default 'Europe/Stockholm',
  week_start smallint not null default 1,
  onboarding_status text not null default 'not_started'
    check (onboarding_status in ('not_started', 'in_progress', 'complete')),
  safety_status text not null default 'unknown'
    check (safety_status in ('unknown', 'cleared', 'restricted', 'stop')),
  data jsonb not null default '{}'::jsonb,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint user_profiles_week_start_chk check (week_start between 1 and 7)
);

create trigger user_profiles_set_updated_at
before update on user_profiles
for each row
execute procedure set_updated_at();

comment on table user_profiles is
  'Current confirmed profile. data contains confirmed fields only; provenance maps field paths to source metadata.';

-- plans ---------------------------------------------------------------------

create table plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  status text not null
    check (status in ('proposed', 'active', 'completed', 'superseded', 'archived')),
  period_start date not null,
  period_end date not null,
  version integer not null default 1,
  supersedes_plan_id uuid references plans (id),
  title text,
  intent text,
  content jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  activated_at timestamptz,
  archived_at timestamptz,
  constraint plans_period_chk check (period_end >= period_start),
  constraint plans_version_chk check (version >= 1)
);

create index plans_user_id_status_idx on plans (user_id, status);

comment on table plans is
  'Weekly training plans. Skills must keep at most one active plan per user.';

-- events --------------------------------------------------------------------

create table events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  type text not null
    check (type in (
      'safety_screening_completed',
      'profile_confirmed',
      'profile_updated',
      'plan_proposed',
      'plan_activated',
      'plan_superseded'
    )),
  occurred_at timestamptz not null default now(),
  recorded_at timestamptz not null default now(),
  source text not null
    check (source in ('user', 'ai', 'system')),
  source_status text not null
    check (source_status in ('confirmed', 'observation', 'inference')),
  plan_id uuid references plans (id),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index events_user_id_occurred_at_idx on events (user_id, occurred_at desc);
create index events_user_id_type_idx on events (user_id, type);

comment on table events is
  'Append-only history. Do not UPDATE or DELETE. Corrections are new rows.';

-- recommendations -----------------------------------------------------------

create table recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  type text not null
    check (type in ('plan_change', 'nutrition', 'recovery', 'other')),
  scope text not null
    check (scope in ('minor', 'major')),
  status text not null
    check (status in ('proposed', 'accepted', 'rejected', 'expired', 'applied')),
  plan_id uuid references plans (id),
  summary text not null,
  rationale jsonb not null default '{}'::jsonb,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);

create index recommendations_user_id_status_idx on recommendations (user_id, status);

comment on table recommendations is
  'Proposed changes that need approval. Unused by the first vertical; rationale is AI inference, never a confirmed fact.';

-- RLS is intentionally not enabled in v1. user_id is present so policies
-- can be added when a real client and auth exist.
-- ChatGPT's official Supabase app is privileged; RLS would not constrain it.
