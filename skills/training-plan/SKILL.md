---
name: training-plan
description: Create, show, or change a weekly training plan combining strength, running, mobility, and recovery. Use whenever the user wants to see or change *planned* training — including today's session, tomorrow, a named day, the weekly plan, skipping/moving a session, adding an extra session this week (including on a rest day), reshaping the rest of the week after a new condition, swapping an exercise, or saying a planned exercise does not exist at the routine gym and needs a substitute (that also updates home_gym_substitutions). Match intent, not exact wording. Do not use for logging completed sets, extra-plan walks/climbing/hiking (that is training-log-and-review), general profile collection, weekly reviews, or meal plans. If they already did extra work, log it first, then return here only if they want remaining days adapted.
---

# training-plan

Create one ISO week of training from the confirmed profile. Draft in chat. Write only after explicit approval.

## Do not

- Collect a new profile (load `training-onboarding` instead). Exception: a gym-unavailable substitution from an active plan is written here together with the plan update (`equipment.home_gym_substitutions`)
- Log completed sets or extra-plan activity (load `training-log-and-review` instead)
- Write meal plans or `recommendations`
- Activate a plan when `safety_status` is `stop` or `unknown`
- Add modalities the user did not confirm (`other` from a scheduled habit is allowed; do not add `other` to `data.modalities`)
- Put `plan_inclusion = background` habits into `content.days` as sessions
- Run DDL

## Before you start

Read if not already in context:

- `docs/safety.md`
- `docs/autonomy.md`
- `docs/provenance.md`
- `docs/data-contracts.md`
- `references/plan-schema.md`
- `references/minor-vs-major.md`
- `references/exercise-substitutions.md`
- `references/activity-load.md`
- `references/volume-and-slots.md`
- `skills/training-log-and-review/references/loads-and-prs.md`

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

select distinct on (payload->>'exercise_key')
  payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
order by payload->>'exercise_key', occurred_at desc;

select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'activity_logged'
  and (payload->>'date') >= :lookback_date
  and (payload->>'date') <= :period_end
order by occurred_at desc;

select payload->>'habit_key' as habit_key, max(payload->>'date') as last_date
from events
where user_id = :USER_ID
  and type = 'activity_logged'
  and payload->>'habit_key' is not null
group by payload->>'habit_key';
```

`:lookback_date` is the Monday of the week before the plan week. Use `data.lifestyle.habits` from the profile row (may be absent). Use last working loads when drafting or showing sessions (`skills/training-log-and-review/references/loads-and-prs.md`). Do not print PRs unless asked. Apply `references/activity-load.md` when drafting: pattern vs instance, and habit catch-up if no matching `activity_logged` in the last 7 days.

If no profile row, or any minimum field from `skills/training-onboarding/references/profile-fields.md` is missing, switch to `training-onboarding`. Do not draft a full week from guesses.

If the minimum is present but selected-modality `experience.*` is missing, or `training_age_years` ≥ 5 and both `availability.two_a_day` and `availability.windows` are missing: switch to `training-onboarding` for those gaps (2–4 questions), then return here. If they skip (`sen` / `hoppa`), draft using `references/volume-and-slots.md` inferences. Do not loop. Do not draft a beginner one-session-per-day week as a stand-in.

If `safety_status = stop`, refuse and tell them to seek care.

If `safety_status = restricted`, keep the week conservative and avoid aggravating patterns they confirmed.

### 2. Choose the week

Default: next ISO week in `Europe/Stockholm` (Monday–Sunday) unless the user named dates.

- `period_start` = Monday
- `period_end` = Sunday
- `week_label` = `%G-W%V` (e.g. `2026-W33`)

### 3. Draft in chat only

Build `content` per `references/plan-schema.md`.

Programming rules (v1, not a periodization engine). Follow `references/volume-and-slots.md`:

- Include only confirmed `data.modalities`
- Fit `availability.days_per_week` / `preferred_days` as **training days**, not session count. Use `session_minutes` as fallback; per-window minutes win
- You lay out the week from confirmed capacity. Do not ask the user to pick a gym+run quota. Do not hard-code two sessions every training day
- If `availability.two_a_day` is `some_days`, two sessions the same day are a **tool** on some days (work + easy). Other days stay one session. Never hard + hard the same day
- If `windows` exist, use those slots when placing sessions. Set session `slot` when known
- Use `equipment.location`, `items`, and `home_gym_substitutions`. If a first-choice matches a stored pair, prescribe the home exercise as `name` / `key` and set `preferred` to the first choice (`references/exercise-substitutions.md`). Do not ask again
- Scale volume/complexity to `experience.*`. If experience is missing and `training_age_years` ≥ 5, program intermediate volume (inference, not a profile write). Do not use a beginner template
- Recovery is a hard gate: most sessions easy; at most one hard quality run per week; at least one day with no gym and no run if `recovery` is selected or days per week ≥ 4. If a background walk or yoga habit exists, do not add extra walk/mobility sessions; that day may still be empty of gym/run
- If only one modality was selected, the whole week may be that modality plus rest days
- Strength: compound lifts first, named sets/reps/RPE. Fill suggested kg from last working loads per `loads-and-prs.md`. Working sets around RPE 7, not failure
- Running: easy / quality / long as fits experience and `volume-and-slots.md`; use last duration/distance, not running PRs, as the default target. No quality run after heavy lower body the same day
- Mobility: short named drills with minutes, unless a background yoga/mobility habit already covers it
- Recovery: explicit rest or easy work, not hidden intensity
- Habits with `plan_inclusion = background`: mention in `intent` as pattern (räknas när du loggar). Never add them as sessions. Never show them as **Sparat pass**. Never treat them as done without `activity_logged`.
- Habits with `plan_inclusion = scheduled`: insert a session on each listed weekday. `modality` `other`, `habit_key` set, `title` and `duration_min` from the habit. One block item with the habit name. Do not add `other` to top-level `content.modalities`. Do not count these slots against `availability.days_per_week`. Keep gym/run work off conflicting patterns that day and the next morning per `references/activity-load.md`.
- Unplanned `activity_logged` of `kind` extra in the lookback window: same load caution, still not a new session unless they ask to schedule it.
- Do not store kcal in the plan. If two sessions land the same day, one fueling line as inference is allowed; do not save it.

Show the week in Swedish as **Förslag (sparas inte än)**. When an item has `preferred`, show **Förstahand (annat gym)** on that line. Label inferences separately. If habit catch-up applies (`activity-load.md`), ask with their habit names in the same turn as the draft — do not assume the vanor were done. Wait for `godkänn` / `ja` / `spara` on the week. Habit instances they report go to `training-log-and-review` without a second `godkänn`.

If they request a change to an already active plan, follow "Present or change a saved session" or the major-replacement write. Never treat a newly generated session as the saved plan.

### 4. Present or change a saved session

Use this whenever the user wants to see or change planned training for today, tomorrow, a named date, or the current week. Match intent, not exact wording.

**Read first. Always.** Run the `SELECT` in step 1 in this turn. Do not use an earlier chat message as the source of the workout.

Also load today's logs and last working loads (do not skip this when presenting a day):

```sql
select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
  and payload->>'date' = :date
order by occurred_at desc;

select distinct on (payload->>'exercise_key')
  payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
order by payload->>'exercise_key', occurred_at desc;
```

Keep the latest row per `payload.exercise_key` for today, and use the second query as last working weight.

- If the Supabase tool fails or returns an error: say in Swedish that you could not read the saved plan. Stop. Do not invent a session.
- If there is no `active` plan: say so and offer to create a week (step 2–3). Do not invent a session.
- Resolve the date in `Europe/Stockholm` (today unless the user named a date). Find that date in `content.days`.
- If `sessions` is empty: tell them the saved plan has rest that day.
- Otherwise present those sessions in Swedish as **Sparat pass**. Mention the plan title and date. Do not add exercises that are not in `content`.
- If an item has `preferred`, show the prescribed `name` as the work, then **Förstahand (annat gym):** and `preferred.name`.
- If already logged today: show **Loggat** (kg × reps) for that `exercise_key`.
- If not yet logged and last working kg exists: show **lägg på X kg** for the prescribed `name` (home) by default. If they are clearly doing the first-choice, cue that key instead.
- If not yet logged and no history: RPE only; do not invent kg.
- Do not show PR unless asked. For “hur går det” / results, use `training-log-and-review`.
- If they ask for a PR, load `training-log-and-review` and `loads-and-prs.md`.
- If they are reporting what they lifted, walked, climbed, or hiked, switch to `skills/training-log-and-review/SKILL.md`. Do not treat a log line as a plan rewrite. If they also asked to adapt remaining days, log first, then continue here with one remaining-week draft.
- Do not list background habits or unplanned `activity_logged` as **Sparat pass**. Scheduled habit sessions that are in `content` are **Sparat pass**. Unplanned gym (`exercise_logged` with `session_id` null) is also not **Sparat pass**.

If they want to add an extra session, change an exercise or a day, or reshape remaining days after a skip, time pressure, poor recovery, extra work already done, or another new condition:

1. Classify intent: **add to this week** (program a new session) vs **reshape remaining** (adapt days already planned) vs they only reported work already done (that is `training-log-and-review` only). Ask once only if unclear. Classify exercise-change intent with `references/exercise-substitutions.md` (gym-unavailable vs this-week swap). Use the meaning of the message, not a phrase list.
2. Draft as **Förslag (sparas inte än)** with a short before/after. Gym-unavailable: one substitute, keep the original as first choice on the card. If they asked to reshape the rest of the week, or to add a session that affects later days, draft **remaining days in one card**, not pass-by-pass questions.
3. Apply `references/volume-and-slots.md`: never hard + hard; no quality run after heavy lower body the same day. If they add or already logged lunch lower body on a quality-run day, the draft swaps that quality run to 30–40 min easy jogging unless they clearly insist on both — then warn and still do not program hard + hard. Easy upper or mobility lunch may keep the evening quality run; one fueling line as inference. Easy gåband or yoga does not drop the quality run.
4. Adding a session this week (two-a-day, or work on a rest day with empty `sessions`) is minor when the profile is unchanged. Do not write `days_per_week`.
5. Wait for explicit approval (`ja`, `godkänn`, `spara`).
6. Classify using `references/minor-vs-major.md`.
7. Minor, one day: `UPDATE` the active row's `content` so that day's `sessions` match the approved draft. Keep the rest of the week unchanged unless the draft also changed later days.
8. Minor, gym-unavailable: same plan `UPDATE`, **and** merge the pair into `data.equipment.home_gym_substitutions` (full array, keep unrelated pairs), insert `profile_updated`, set provenance `equipment.home_gym_substitutions`. Tell them both were saved.
9. Minor, remaining week: `UPDATE` `content` so all drafted days match. Do not change the profile unless the same turn also confirmed gym-unavailable pairs.
10. This-week swap: `UPDATE` `content` only. Do not set `preferred`. Do not write the profile.
11. Major: do not UPDATE in place. Follow the new-or-replacement week write below after approval.
12. If they do not approve: leave the database unchanged.

Skipping today's session without asking to move or reshape it is `training-log-and-review` (`session_missed`). Do not auto-raise another session to hard.

Example update after approval (replace `:content` with the full updated JSON, not a fragment):

```sql
update plans
set content = :content::jsonb
where id = :plan_id
  and user_id = :USER_ID
  and status = 'active';
```

Gym-unavailable also needs a profile write in the same turn after `godkänn`. Insert `profile_updated` first, then merge the **full** `home_gym_substitutions` array (keep unrelated pairs):

```sql
insert into events (id, user_id, type, source, source_status, payload)
values (
  gen_random_uuid(),
  :USER_ID,
  'profile_updated',
  'user',
  'confirmed',
  jsonb_build_object(
    'fields', jsonb_build_array('equipment.home_gym_substitutions'),
    'summary', :summary
  )
)
returning id;

-- Use that returned id as :event_id below.

update user_profiles
set
  data = jsonb_set(
    data,
    '{equipment,home_gym_substitutions}',
    :substitutions::jsonb
  ),
  provenance = jsonb_set(
    provenance,
    '{equipment.home_gym_substitutions}',
    jsonb_build_object(
      'source', 'user',
      'status', 'confirmed',
      'confirmed_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'event_id', :event_id
    )
  )
where user_id = :USER_ID;
```

If `data.equipment` is missing `home_gym_substitutions`, `jsonb_set` still creates that key. Do not drop other `equipment` fields. Do not run this for a this-week swap.

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

Swedish. Label **Sparat pass** vs **Förslag (sparas inte än)** clearly. Show a compact week or day (slot if set, modality, title, minutes, RPE, exercises). When `preferred` exists, show **Förstahand (annat gym)** on that line. Do not dump raw JSON unless they ask. Do not make them design the week.
