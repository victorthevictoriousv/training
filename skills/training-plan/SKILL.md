---
name: training-plan
description: Create, show, or change a weekly training plan combining strength, running, mobility, and recovery. Use whenever the user wants to see or change *planned* training — including today's session, tomorrow, a named day, the weekly plan, or similar phrasing. Match intent, not exact wording. Do not use for logging completed sets or skipped sessions (that is training-log-and-review), profile collection, weekly reviews, or meal plans.
---

# training-plan

Create one ISO week of training from the confirmed profile. Draft in chat. Write only after explicit approval.

## Do not

- Collect a new profile (load `training-onboarding` instead)
- Log completed sets (load `training-log-and-review` instead)
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

If they request a change to an already active plan, follow "Present or change a saved session" or the major-replacement write. Never treat a newly generated session as the saved plan.

### 4. Present or change a saved session

Use this whenever the user wants to see or change planned training for today, tomorrow, a named date, or the current week. Match intent, not exact wording.

**Read first. Always.** Run the `SELECT` in step 1 in this turn. Do not use an earlier chat message as the source of the workout.

Also load today's logs (do not skip this when presenting a day):

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
  and payload->>'date' = :date
order by occurred_at desc;
```

Keep the latest row per `payload.exercise_key`.

- If the Supabase tool fails or returns an error: say in Swedish that you could not read the saved plan. Stop. Do not invent a session.
- If there is no `active` plan: say so and offer to create a week (step 2–3). Do not invent a session.
- Resolve the date in `Europe/Stockholm` (today unless the user named a date). Find that date in `content.days`.
- If `sessions` is empty: tell them the saved plan has rest that day.
- Otherwise present those sessions in Swedish as **Sparat pass**. Mention the plan title and date. Do not add exercises that are not in `content`.
- Next to matching exercises, show **Loggat** from the latest log (kg × reps). Planned load stays visible if no log exists.
- If they are reporting what they lifted, switch to `skills/training-log-and-review/SKILL.md`. Do not treat a log line as a plan rewrite.

If they want to change that day:

1. Draft the new session(s) as **Förslag (sparas inte än)** with a short before/after.
2. Wait for explicit approval (`ja`, `godkänn`, `spara`).
3. Classify using `references/minor-vs-major.md`.
4. Minor: `UPDATE` the active row's `content` so that day's `sessions` match the approved draft. Keep the rest of the week unchanged. Then confirm that the saved plan was updated.
5. Major: do not UPDATE in place. Follow step 5 (new week) after approval.
6. If they do not approve: leave the database unchanged.

Example update after approval (replace `:content` with the full updated JSON, not a fragment):

```sql
update plans
set content = :content::jsonb
where id = :plan_id
  and user_id = :USER_ID
  and status = 'active';
```

### 5. Write after approval (new or replacement week)

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

### 6. After the write

Confirm in Swedish: week dates, number of sessions, modalities, and that it is saved as `active`.

## Dialogue

Swedish. Label **Sparat pass** vs **Förslag (sparas inte än)** clearly. Show a compact week or day (modality, title, minutes, RPE, exercises). Do not dump raw JSON unless they ask.
