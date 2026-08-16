---
name: training-plan
description: Create, show, or change a weekly training plan combining strength, running, mobility, and recovery. Use whenever the user wants to see or change *planned* training — including today's session, tomorrow, a named day, the weekly plan, skipping/moving a session, adding an extra session this week (including on a rest day), reshaping the rest of the week after a new condition, swapping an exercise, or saying a planned exercise does not exist at the routine gym and needs a substitute (that also updates home_gym_substitutions). Match intent, not exact wording. Do not use for logging completed sets, extra-plan walks/climbing/hiking (that is training-log-and-review), general profile collection, weekly reviews, or meal plans. If they already did extra work, log it first, then return here only if they want remaining days adapted.
---

# training-plan

Create one ISO week of training from the confirmed profile. Draft in chat. Write only after explicit approval.

## Do not

- Collect a new profile (load `training-onboarding` instead). Exception: a gym-unavailable substitution from a covering plan is written here together with the plan update (`equipment.home_gym_substitutions`)
- Log completed sets or extra-plan activity (load `training-log-and-review` instead)
- Write meal plans or `recommendations`
- Activate a plan when `safety_status` is `stop` or `unknown`
- Add modalities the user did not confirm (`other` from a scheduled habit is allowed; do not add `other` to `data.modalities`)
- Put `plan_inclusion = background` habits into `content.days` as sessions
- Run DDL

## Intent

Classify once (meaning, not a phrase list). Run only those ids from `skills/_shared/queries.md`. Do not run every SELECT in this file. Writes stay in the procedure below.

| User means | Section | Queries | Skip |
| --- | --- | --- | --- |
| Today / tomorrow / a named day / “vad ska jag träna” | §4 | `Q_lazy_activate_candidate` (apply §1 writes if a row), `Q_covering_plan`, `Q_today_logs`, `Q_last_working` | `Q_pr`, `Q_activity_lookback`, week INSERT |
| This week / the weekly plan | §4 | Same as a day, plus `Q_queued_next_week` | `Q_pr` |
| Draft or approve a new week | §2–3, §5 | `Q_profile`, `Q_lazy_activate_candidate`, `Q_covering_plan`, `Q_queued_next_week`, `Q_last_working`, `Q_activity_lookback`, `Q_habit_last_dates`, `Q_week_events` | `Q_pr`. Future week: do not activate |
| Swap, gym-unavailable, extra session, reshape remaining | §4 | `Q_covering_plan`, then draft; writes after `godkänn` | Log `INSERT`, `Q_pr` |
| They already did the work | hand off `training-log-and-review` | — | Plan UPDATE until they ask |
| PR / last weight / “hur går det” | hand off log skill | — | All plan writes |

## Before you start

Classify intent first. Then read **only** the files that row needs. Do not open the others in this turn. Do not load a generic Supabase skill to run `Q_*`.

| Intent | Read now |
| --- | --- |
| Today / tomorrow / a named day / this week (show only) | `skills/_shared/queries.md` |
| Swap, gym-unavailable, extra session, reshape remaining | `queries.md`, `docs/autonomy.md`, `references/minor-vs-major.md`, `references/exercise-substitutions.md`, `references/volume-and-slots.md` |
| Draft or approve a new week | the list below |

New-week list (if not already in context):

- `docs/safety.md`
- `docs/autonomy.md`
- `docs/provenance.md`
- `docs/data-contracts.md`
- `skills/_shared/queries.md`
- `references/plan-schema.md`
- `references/minor-vs-major.md`
- `references/exercise-substitutions.md`
- `references/activity-load.md`
- `references/volume-and-slots.md`
- `skills/training-log-and-review/references/loads-and-prs.md`

A show-only lookup that already followed the project-instruction fast path should not re-open this skill’s references.

## Procedure

### 1. Load profile and current plan

Today = current date in `Europe/Stockholm`. Session lookup is by **date**, not by “the `active` row”. Run only the `Q_*` ids from the intent table.

**Lazy activate** (no cron). When the intent table includes `Q_lazy_activate_candidate`, run it. If a `proposed` plan’s period contains today:

1. Set any `active` plan whose `period_end < today` to `completed` and `archived_at = now()`. That week ended; do not `superseded`.
2. Set that `proposed` row to `active`, `activated_at = now()`, insert `plan_activated`.

If `Q_lazy_activate_candidate` returns a row, complete the expired active week (if any), then activate:

```sql
update plans
set status = 'completed', archived_at = now()
where user_id = :USER_ID
  and status = 'active'
  and period_end < :today;

update plans
set status = 'active', activated_at = now()
where id = :proposed_plan_id
  and user_id = :USER_ID
  and status = 'proposed';

insert into events (user_id, type, source, source_status, plan_id, payload)
values (
  :USER_ID, 'plan_activated', 'user', 'confirmed', :proposed_plan_id, :payload::jsonb
);
```

Do not lazy-activate during `training-log-and-review` (that skill must not `UPDATE plans`). `Q_covering_plan` is enough for logs.

Then run the remaining ids from the intent table (`Q_profile`, `Q_covering_plan`, `Q_queued_next_week`, `Q_last_working`, `Q_activity_lookback`, `Q_habit_last_dates`, `Q_week_events` as listed). `:date` is today unless the user named a day.

`:lookback_date` is the Monday of the week before the covering plan’s week (or the week being drafted). `:period_end` is that plan’s `period_end`. For `Q_week_events`, `:period_start` / `:period_end` are the **current** covering plan’s dates (today), not the week being drafted. Skip `Q_week_events` if there is no covering row. Use `data.lifestyle.habits` from the profile row (may be absent). Use last working loads when drafting or showing sessions (`Q_last_working` plus `skills/training-log-and-review/references/loads-and-prs.md`). Do not print PRs unless asked. Apply `references/activity-load.md` when drafting: pattern vs instance, and habit catch-up if no matching `activity_logged` in the last 7 days.

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

Show the week in Swedish as **Förslag (sparas inte än)**. When an item has `preferred`, show **Förstahand (annat gym)** on that line. Label inferences separately. After the week draft, add one Swedish line **denna vecka i korthet** from `Q_week_events` (facts only, not the log skill’s full card). Skip the line if `Q_week_events` was not run. Suggested kg still come from last working per `loads-and-prs.md`. Do not invent a second progression rule. If habit catch-up applies (`activity-load.md`), ask with their habit names in the same turn as the draft — do not assume the vanor were done. Wait for `godkänn` / `ja` / `spara` on the week. Habit instances they report go to `training-log-and-review` without a second `godkänn`.

If they request a change to a saved plan, follow "Present or change a saved session" or the major-replacement write. Never treat a newly generated session as the saved plan.

### 4. Present or change a saved session

Use this whenever the user wants to see or change planned training for today, tomorrow, a named date, or the current week. Match intent, not exact wording.

For **show only**, `queries.md` plus the listed `Q_*` is enough. Do not open the new-week reference list. Chat history is a hint, not the source.

**Read first. Always.** Resolve the date in `Europe/Stockholm` (today unless the user named a date). Run the day-row queries from the intent table: `Q_lazy_activate_candidate` (apply §1 writes if a row), then `Q_covering_plan` for **that date**, `Q_today_logs`, and `Q_last_working`. Do not use an earlier chat message as the source of the workout. Do not use `status = 'active'` alone — that misses remaining days of a week that was superseded when the next week was saved.

Keep the latest row per `payload.exercise_key` in `Q_today_logs` for today, and use `Q_last_working` as last working weight.

- If the Supabase tool fails or returns an error: say in Swedish that you could not read the saved plan. Stop. Do not invent a session.
- If no covering plan exists for that date: say there is no saved plan for that date and offer to create a week (step 2–3). Do not invent a session. Do not call it a rest day.
- Find that date in the covering plan’s `content.days`.
- If the date is missing from `days`: say there is no stored day for that date. Do not treat it as rest.
- If the day exists and `sessions` is empty: tell them the saved plan has rest that day.
- Otherwise present those sessions in Swedish as **Sparat pass**. Mention the plan title and date. Do not add exercises that are not in `content`.
- If an item has `preferred`, show the prescribed `name` as the work, then **Förstahand (annat gym):** and `preferred.name`.
- If already logged today: show **Loggat** (kg × reps) for that `exercise_key`.
- If not yet logged and last working kg exists: show **lägg på X kg** for the prescribed `name` (home) by default. If they are clearly doing the first-choice, cue that key instead.
- If not yet logged and no history: RPE only; do not invent kg.
- Do not show PR unless asked. For “hur går det” / results, use `training-log-and-review`.
- If they ask for a PR, load `training-log-and-review` (`Q_pr`). Do not run `Q_pr` here.
- If they are reporting what they lifted, walked, climbed, or hiked, switch to `skills/training-log-and-review/SKILL.md`. Do not treat a log line as a plan rewrite. If they also asked to adapt remaining days, log first, then continue here with one remaining-week draft.
- Do not list background habits or unplanned `activity_logged` as **Sparat pass**. Scheduled habit sessions that are in `content` are **Sparat pass**. Unplanned gym (`exercise_logged` with `session_id` null) is also not **Sparat pass**.
- “Den här veckan” / the weekly plan: present the covering plan for **today**. If a `proposed` future week exists, mention it as already saved from that Monday — do not hide remaining days of the current week.

If they want to add an extra session, change an exercise or a day, or reshape remaining days after a skip, time pressure, poor recovery, extra work already done, or another new condition:

1. Classify intent: **add to this week** (program a new session) vs **reshape remaining** (adapt days already planned) vs they only reported work already done (that is `training-log-and-review` only). Ask once only if unclear. Classify exercise-change intent with `references/exercise-substitutions.md` (gym-unavailable vs this-week swap). Use the meaning of the message, not a phrase list.
2. Draft as **Förslag (sparas inte än)** with a short before/after. Gym-unavailable: one substitute, keep the original as first choice on the card. If they asked to reshape the rest of the week, or to add a session that affects later days, draft **remaining days in one card**, not pass-by-pass questions.
3. Apply `references/volume-and-slots.md`: never hard + hard; no quality run after heavy lower body the same day. If they add or already logged lunch lower body on a quality-run day, the draft swaps that quality run to 30–40 min easy jogging unless they clearly insist on both — then warn and still do not program hard + hard. Easy upper or mobility lunch may keep the evening quality run; one fueling line as inference. Easy gåband or yoga does not drop the quality run.
4. Adding a session this week (two-a-day, or work on a rest day with empty `sessions`) is minor when the profile is unchanged. Do not write `days_per_week`.
5. Wait for explicit approval (`ja`, `godkänn`, `spara`).
6. Classify using `references/minor-vs-major.md`.
7. Minor, one day: `UPDATE` the covering plan’s `content` so that day's `sessions` match the approved draft. Keep the rest of that week unchanged unless the draft also changed later days. The covering row may be `active`, `proposed`, `completed`, or `superseded` as long as its period still contains the date.
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
  and period_start <= :date
  and period_end >= :date;
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

Keep at most one `active` plan (the database rejects a second). At most one `proposed` future week. Chat drafts stay in the conversation until `godkänn`; a `proposed` **row** after approval is the saved next week, not a draft.

Today = current date in `Europe/Stockholm`. Allocate `new_plan_id` with `gen_random_uuid()` first. `version` is `1` for the first plan, otherwise previous `version + 1`. `payload` follows `docs/data-contracts.md`.

**Same-week replacement** — new `period_start` ≤ today, or the new period is the same ISO week as the current `active` plan. Supersede that `active` row, insert `proposed`, then activate in the same turn.

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

If there is no `active` plan for this path, skip the supersede step and set `supersedes_plan_id` to null.

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

**Future week** — new `period_start` > today. Do **not** supersede an `active` plan whose `period_end` ≥ today. Remaining days of the current week must stay visible.

If a `proposed` row already exists for the same `period_start`, supersede **that** row (not the current `active` week), then insert the new `proposed`. Set `supersedes_plan_id` to that old proposed id. Otherwise set `supersedes_plan_id` to null.

```sql
update plans
set status = 'superseded', archived_at = now()
where id = :old_proposed_id
  and user_id = :USER_ID
  and status = 'proposed';

insert into events (user_id, type, source, source_status, plan_id, payload)
values (
  :USER_ID,
  'plan_superseded',
  'user',
  'confirmed',
  :old_proposed_id,
  jsonb_build_object('superseded_plan_id', :old_proposed_id)
);
```

Insert the new week as `proposed` and insert `plan_proposed`. **Do not** set it `active` in this turn. **Do not** insert `plan_activated`.

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
  :old_proposed_id,
  :title,
  :intent,
  :content::jsonb
);

insert into events (user_id, type, source, source_status, plan_id, payload)
values (
  :USER_ID, 'plan_proposed', 'user', 'confirmed', :new_plan_id, :payload::jsonb
);
```

If there is no `active` plan and the new week starts in the future, still leave it `proposed` until lazy activate (step 1) when that Monday arrives.

### 6. After the write

Same-week / activated: confirm in Swedish week dates, number of sessions, modalities, and that it is saved as `active`.

Future week left `proposed`: confirm week dates, number of sessions, modalities, that it is **sparad för den veckan och gäller från måndag**, and that the current week is still the saved plan until `period_end`. Do not say the next week is `active`.

## Dialogue

Swedish. Label **Sparat pass** vs **Förslag (sparas inte än)** clearly. Show a compact week or day (slot if set, modality, title, minutes, RPE, exercises). When `preferred` exists, show **Förstahand (annat gym)** on that line. Do not dump raw JSON unless they ask. Do not make them design the week.
