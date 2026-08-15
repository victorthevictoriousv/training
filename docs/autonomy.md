# Autonomy

The assistant may think freely. It may not change durable state freely.

## Confirmation before writes

Profile facts and plan drafts are assistant proposals. Never write those until the user explicitly approves (`ja`, `stämmer`, `godkänn`, `spara`).

A clear session-log line from the user is already a stated fact. Save it and echo **Sparat:** so they can correct it. Do not ask for a second `godkänn`.

Filling gaps as “enligt plan” (no actual loads) is an assumption. Show a summary and wait for one approval.

Filling remaining work from last working loads (`logga gympasset`, `klarade alla övningar`) is also an assumption. Show a card and wait for one approval. After `godkänn`, those copied loads are confirmed. Missing weights: ask first; do not write.

Not approval for plans/profile: silence, "ok, berätta mer", questions, partial agreement with requested edits.

Before a plan or profile write, show:

1. What will be saved
2. What is still unknown
3. What is your inference and will not be saved as fact

After any write, say what was saved, in Swedish.

## Profile

- Proposed answers live in the conversation until approval.
- On approval, write `user_profiles` and an event (`profile_confirmed` or `profile_updated`).
- If the user rejects or edits the summary, revise and ask again. Do not write.

## Plans

- Draft a new week in the conversation first.
- On approval of a **same-week** replacement (`period_start` ≤ today, or the same ISO week as the current `active` plan):
  1. If another plan is `active`, set it to `superseded`, set `archived_at`, insert `plan_superseded`.
  2. Insert the new row as `proposed` and insert `plan_proposed`.
  3. Update that row to `active`, set `activated_at`, insert `plan_activated`.
- On approval of a **future** week (`period_start` > today):
  1. Do not supersede an `active` plan whose `period_end` is still today or later.
  2. If a `proposed` row already exists for that same `period_start`, supersede **that** row, then insert the new one.
  3. Insert the new row as `proposed` and insert `plan_proposed`. Do not activate in the same turn. A `proposed` row after `godkänn` is the saved next week, not a chat draft.
- Lazy activate on plan read in `training-plan`: if a `proposed` plan’s period contains today, set the expired `active` week (`period_end` < today) to `completed` and activate the new row. No cron.
- Keep at most one `active` plan. At most one `proposed` future week. Chat drafts stay in the conversation until approval.

## Presenting a saved session

- Always `SELECT` the **covering plan for that date** (`period_start` ≤ date ≤ `period_end`, prefer `active` then `proposed` then `completed` then `superseded`). Do not use `status = 'active'` alone.
- Show only what is stored in that plan’s `plans.content` for that date. Label it **Sparat pass**. Background habits and unplanned `activity_logged` are not sessions. Scheduled habit sessions that exist in `content` are **Sparat pass**.
- If a strength item has `preferred`, show the prescribed `name` as the work, then **Förstahand (annat gym):** and `preferred.name`. Cue last working load for `name` by default.
- If the read fails: say so. Never generate a stand-in workout.
- If no covering plan exists for that date: there is no saved plan for that date. Do not call it a rest day.
- If that date exists in `content.days` and has no sessions: it is a rest day in the saved plan. Do not fill it in unless the user asks to add something, and then wait for approval before writing.
- “This week” is the covering plan for **today**. A queued `proposed` next week must not hide remaining days of the current week.

## Changing a saved session

- The user may change a day or ask to reshape remaining days. Draft as **Förslag (sparas inte än)** with a short before/after. Remaining-week changes are one draft, not pass-by-pass questions.
- Nothing is written until explicit approval.
- After approval of a minor change, `UPDATE` the covering plan’s `content` so the saved plan matches the draft (the row that covers that date, even if it is not `active`). Then say that the plan was updated.
- Do not leave a changed workout only in the conversation.
- Do not change `user_profiles` for a one-week situation. A new normal (“så här tränar jag nu”) is onboarding, then a new week.
- **Exception — gym missing an exercise:** if they **mean** a planned exercise is unavailable at the routine gym (context, not a set phrase), that is confirmed gym fact, not a one-week squeeze. After approval of one card, `UPDATE` the plan item (`name` / `key` = home alternative, `preferred` = first choice) **and** merge the pair into `data.equipment.home_gym_substitutions` with `profile_updated`. If they only want another exercise, treat it as a this-week swap: plan only, no `preferred`, no profile write.
- Skipping today's session without asking to move or reshape it is a log (`session_missed`). Do not auto-raise another session to hard.
- Adding an extra session this week (two-a-day, or work on a rest day) is a remaining-week change: one draft, then `godkänn`. Do not write `days_per_week`.

## Extra session or new condition

When they mention extra or unplanned work, or a new condition this week, classify intent (meaning, not a phrase list):

- **Log only** — they report what already happened. That is session logging below. Do not rewrite the plan. If the log conflicts with remaining planned work the same day (extra lower body before a quality run), say so and offer to reshape. Do not write a plan change until they ask.
- **Add to this week** — they want it programmed. Draft as **Förslag (sparas inte än)**. Minor: `UPDATE` `content` (new session; ease the evening if it would stack with heavy legs). Wait for `godkänn`.
- **Reshape remaining** — new condition (poor sleep, time pressure, extra session already done, “anpassa kvällen”). One remaining-week draft. Do not change the profile. Do not auto-raise another session to hard.

An extra session on a rest day **this week only** is minor reshape, not a new `days_per_week`. Easy gåband or yoga is background logging, not a new session and not a reason to drop a quality run.

## Exercise swap vs gym-unavailable

Read context. Do not require exact wording. Examples below are illustrations, not a phrase list.

- They mean the routine gym cannot provide the exercise → gym-unavailable. Propose **one** substitute. Keep the original as first choice. Persist after `godkänn`.
- They want a different exercise without meaning it is missing → this-week swap only. Next week may program the original again.
- Unclear (could be injury, dislike, or missing kit): ask once. Do not ask after a clear swap or a clear gym-missing message.
- They mean the gym has that exercise now → onboarding removes that pair from `home_gym_substitutions`.

## Session logging

- Explicit lines like `bänk 80x5` → `INSERT` `exercise_logged` (`source = user`, `source_status = confirmed`) and echo **Sparat:**
- Correction (`bänk 82.5`) → another `exercise_logged`. Latest for that date + `exercise_key` is current. Never UPDATE events.
- Extra-plan activity (`gick 30 min`, `gåband`, `gåband 60 min 5 km/h`, `klättrade 2h`) → `INSERT` `activity_logged` and echo **Sparat:**. A second `gåband` the same day is a new instance, not a correction, unless they say `nej` / `rättelse`. Bare `gåband` uses the habit typicals and echoes `(enligt vana)`. If it matches a scheduled habit session that day (`habit_key` on the session), also `session_completed` and set `plan_id` / `session_id` on the activity. Otherwise `plan_id` is null and do not write `session_completed`.
- Recurring habits (`gåband 2×30 min arbetsdagar`, `yoga`, `klättrar onsdagar`) are profile **patterns**. Propose `lifestyle.habits` with `plan_inclusion`, wait for approval, then write via onboarding. A single instance is still logged without a second `godkänn`. Never treat the pattern as done without `activity_logged`.
- If habits exist and none were logged in the last 7 days: ask once with their habit names as examples, then log what they report. Not a weekly review. Do not ask in the middle of set-by-set gym logging.
- `logga dagens pass` / remaining “enligt plan” → summary, then one approval, then `session_completed` (`status` `completed` or `partial`). Do not invent kilogram values. Do not include background walks in that summary as planned work. Scheduled habit sessions (climbing) are planned work.
- `logga gympasset` / `klarade alla övningar` / similar → fill remaining working items from last working (today’s planned sets; last kg; last reps if set count matches). Ask all missing weights once. Card, one `godkänn`, then `exercise_logged` plus `session_completed`. Do not copy PR, plan RPE, or auto-bump. Not the same as “enligt plan” (no weights).
- `hoppade över` → `session_missed` after a short confirm if the intent is unclear; a clear “jag hoppade över dagens pass” may be saved and echoed. Missing a background walk or background yoga is not a missed session. Skipping a scheduled habit session is `session_missed`. If they also want the rest of the week reshaped, that is a plan change (`training-plan`), not a log write.
- Ambiguous exercise match → ask, do not write.
- Unplanned gym that does not match that day's planned items → `exercise_logged` with `session_id` null even if the day has another session (do not attach extra lunch strength to an evening run). Do not write `session_completed` for that extra work. `logga gympasset` only fills a planned strength session.
- After extra lower body the same day as a remaining quality run: echo the log, then offer to swap that run to easy jogging (`training-plan`). Do not auto-write the plan. Easy gåband or yoga does not trigger this.

## Minor vs major changes

Applies once a covering plan exists for the date. Both still wait for approval before any write.

Minor (after approval: `UPDATE` the covering plan's `content` in place):

- Change the exercises, sets, or structure of an already scheduled day
- Swap an exercise for a close equivalent (this week only, unless they said it is missing at the gym)
- Replace a missing routine-gym exercise with a close equivalent and keep the first choice as `preferred` (also writes the profile; see above)
- Change volume by about one set
- Move a session to another day in the same week
- Turn one session into rest the same day if the user reports poor recovery, time pressure, or pain that is not a stop flag
- Reshape remaining days of this week in one draft (drop or add a two-a-day, move quality, “bara lunch”, extra session on a rest day) without changing the profile
- After extra lower body the same day as a quality run: swap that quality run to easy jogging this week (only after they approve)

Major (after approval: new proposed plan that supersedes the old one):

- Change training **days** per week as a new normal (not a one-week extra session on a rest day)
- Add or remove a modality
- Change the primary goal
- Replace the week's structure
- Add or remove a scheduled habit that reshapes the week (new climbing day plus lighter surrounding sessions)

When unsure, treat it as major.

v1 does not write `recommendations`. A major change is a new `plans` row that supersedes the old one after approval.

## Reversible by default

Prefer changes the user can undo by restoring the previous week's structure. Do not discard history: supersede, do not delete.
