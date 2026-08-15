---
name: training-plan
description: Create or change a weekly training plan combining strength, running, mobility, and recovery. Use when the user wants a week plan, wants to adapt this week, or asks to replace the current plan. Do not use for profile collection, session logging, weekly reviews, or meal plans.
---

# training-plan

Create one ISO week of training from the confirmed profile. Draft in chat. Write only after explicit approval.

## Do not

- Collect a new profile (load `training-onboarding` instead)
- Log completed or missed sessions
- Write meal plans or `recommendations`
- Activate a plan when `safety_status` is `stop` or `unknown`
- Add modalities the user did not confirm
- Run DDL

## Before you start

Read if not already in context:

- `docs/safety.md`
- `docs/autonomy.md`
- `docs/provenance.md`
- `docs/data-contracts.md`
- `references/plan-schema.md`
- `references/minor-vs-major.md`

## Procedure

### 1. Load profile and current plan

```sql
select safety_status, onboarding_status, data, provenance
from user_profiles
where user_id = :USER_ID;

select id, status, period_start, period_end, version, title, content
from plans
where user_id = :USER_ID
  and status = 'active'
order by created_at desc
limit 1;
```

If no profile row, or any minimum field from `skills/training-onboarding/references/profile-fields.md` is missing, switch to `training-onboarding`. Do not draft a full week from guesses.

If `safety_status = stop`, refuse and tell them to seek care.

If `safety_status = restricted`, keep the week conservative and avoid aggravating patterns they confirmed.

### 2. Choose the week

Default: next ISO week in `Europe/Stockholm` (Monday–Sunday) unless the user named dates.

- `period_start` = Monday
- `period_end` = Sunday
- `week_label` = `%G-W%V` (e.g. `2026-W33`)

### 3. Draft in chat only

Build `content` per `references/plan-schema.md`.

Programming rules (v1, not a periodization engine):

- Include only confirmed `data.modalities`
- Fit `availability.days_per_week` / `preferred_days` and `session_minutes`
- Use `equipment.location` and `items`
- Scale volume/complexity to `experience.*`
- At least one recovery-oriented slot if `recovery` is a selected modality or if days per week ≥ 4 (easy walk, mobility, or full rest)
- Combine modalities across the week, not all in one session unless the user asked for a short combo day
- If only one modality was selected, the whole week may be that modality plus rest days
- Strength: compound lifts first, named sets/reps/RPE
- Running: easy / quality / long as fits experience; no expert race plan
- Mobility: short named drills with minutes
- Recovery: explicit rest or easy work, not hidden intensity

Show the week in Swedish as **Förslag (sparas inte än)**. Label inferences separately. Wait for `godkänn` / `ja` / `spara`.

If they request a major change to an already active plan, draft a replacement week and wait. If they request a minor tweak, you may apply it after saying what changes; see `references/minor-vs-major.md`.

### 4. Write after approval (new or replacement week)

Keep exactly one `active` plan.

If an active plan exists:

```sql
update plans
set status = 'superseded', archived_at = now()
where id = :old_plan_id
  and user_id = :USER_ID
  and status = 'active';

insert into events (user_id, type, source, source_status, plan_id, payload)
values (
  :USER_ID,
  'plan_superseded',
  'user',
  'confirmed',
  :old_plan_id,
  jsonb_build_object('superseded_plan_id', :old_plan_id)
);
```

If there is no active plan, skip the supersede step and set `supersedes_plan_id` to null.

Insert proposed, then activate (same turn). Allocate `new_plan_id` with `gen_random_uuid()` first:

```sql
insert into plans (
  id, user_id, status, period_start, period_end, version,
  supersedes_plan_id, title, intent, content
) values (
  :new_plan_id,
  :USER_ID,
  'proposed',
  :period_start,
  :period_end,
  :version,
  :old_plan_id,
  :title,
  :intent,
  :content::jsonb
);

insert into events (user_id, type, source, source_status, plan_id, payload)
values (
  :USER_ID, 'plan_proposed', 'user', 'confirmed', :new_plan_id, :payload::jsonb
);

update plans
set status = 'active', activated_at = now()
where id = :new_plan_id
  and user_id = :USER_ID;

insert into events (user_id, type, source, source_status, plan_id, payload)
values (
  :USER_ID, 'plan_activated', 'user', 'confirmed', :new_plan_id, :payload::jsonb
);
```

`version` is `1` for the first plan, otherwise previous `version + 1`.
`payload` follows `docs/data-contracts.md`.

### 5. Minor tweak to the active plan

If the change is minor and a plan is already `active`:

- `UPDATE plans.content` (and title/intent if needed) on that row
- Tell the user what changed
- Do not insert a new plan
- Do not insert `plan_proposed` / `plan_activated`
- Optional: skip extra events in v1 for minor tweaks (no matching event type). Mention the change in the Swedish reply only.

If unsure whether it is minor, treat it as major (replacement plan).

### 6. After the write

Confirm in Swedish: week dates, number of sessions, modalities, and that it is saved as `active`.

## Dialogue

Swedish. Show a compact week table (day, modality, title, minutes, RPE). Do not dump raw JSON to the user unless they ask.
