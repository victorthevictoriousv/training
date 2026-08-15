---
name: training-log-and-review
description: Log completed or missed training — a single exercise with weight and reps, a run, today's whole session, filling remaining work from last loads (logga gympasset / klarade alla övningar), extra-plan activity (walk, treadmill, yoga, climbing, hiking), unplanned gym that is not in today's plan, a load correction, a PR question, how an exercise is progressing, or catching up habits after a quiet week. Use whenever the user reports what they lifted, ran, walked, did yoga, climbed, or hiked, skips a session, or asks for last weights, personal bests, or results. Match intent, not exact wording. Do not use to create weekly plans, change programmed sessions, collect profile habits, run weekly reviews, or give meal plans. If they also want extra work put in the week or remaining days adapted, log first, then load training-plan.
---

# training-log-and-review

Record what actually happened. Do not invent loads. Weekly review is not implemented; say so if asked.

## Do not

- Create or rewrite the weekly plan (load `training-plan`). Log first if they already did the work; do not UPDATE `plans` here
- Save a recurring habit to the profile (load `training-onboarding`)
- Invent kilogram values the user did not state or confirm on the shortcut card (copied last working after one `godkänn` is allowed)
- Store kcal, MET, or TDEE
- UPDATE or DELETE `events`
- Run DDL or weekly reviews
- Attach unmatched gym work to another session the same day, or write `session_completed` for extra work that is not in `content`
- Auto-rewrite remaining days because they logged extra. Offer a reshape if it conflicts; wait

## Extra session vs plan change

If the message is extra or unplanned work, or a new condition, classify intent (meaning, not a phrase list):

- **Log only** — they report what already happened. Write the event here. Leave the plan unchanged.
- **Add to this week** / **reshape remaining** — they want it programmed or remaining days adapted. Log any work they already did, then load `training-plan` for one remaining-week draft. Do not log a future session as done.

`logga gympasset` only fills a *planned* strength session. If today has no planned gym, log exercise by exercise, or they add the session via `training-plan` first.

## Before you start

Read if not already in context:

- `docs/safety.md`
- `docs/autonomy.md`
- `docs/provenance.md`
- `docs/data-contracts.md`
- `references/log-schema.md`
- `references/parse-and-match.md`
- `references/loads-and-prs.md`
- `skills/training-plan/references/activity-load.md`

## Procedure

### 1. Load plan, habits, and existing logs

Date = today in `Europe/Stockholm` unless the user named a day.

```sql
select id, title, content
from plans
where user_id = :USER_ID
  and status = 'active'
order by created_at desc
limit 1;

select data->'lifestyle'->'habits' as habits
from user_profiles
where user_id = :USER_ID;

select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
  and payload->>'date' = :date
order by occurred_at desc;

select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'activity_logged'
  and payload->>'date' = :date
order by occurred_at desc;

select payload->>'habit_key' as habit_key, max(payload->>'date') as last_date
from events
where user_id = :USER_ID
  and type = 'activity_logged'
  and payload->>'habit_key' is not null
group by payload->>'habit_key';
```

Current load per `exercise_key` is the first row for that key in this list (already newest-first). Current extra-plan activity is the latest row per `activity_key` + `instance` (missing `instance` = 1). Sum those current bouts for the day's load. Next new bout: `max(instance) + 1` for that date + key.

If the SELECT fails: say you could not read the saved plan or logs. Do not invent a session or loads.

A profile habit is not done until `activity_logged`. If habit catch-up in `activity-load.md` applies and this is not a mid-set gym log, ask once with their habit names, then continue.

### 2. Single exercise line

If the message is (or includes) an exercise + load and/or reps, parse with `references/parse-and-match.md`.

- One clear match to today's planned items (`name` or `preferred.name`), or a clear accessory of that same planned session: `INSERT` `exercise_logged` immediately. Echo **Sparat:** in Swedish (exercise, sets, kg, reps). Use the home `key` when they logged the prescribed name; use `preferred.key` when they logged the first-choice. Extra gym that is not an accessory of a planned strength session that day is unmatched (`session_id` null).
- `reps` must be an integer or null. Never write a range or `reps_text`. Range-only input → low end, and say so in the echo.
- Dumbbell `load_kg` is per implement (`30 kg/hantel`).
- Store one object per working set (4×8 → four sets of 8), not a single set.
- Several possible matches: ask which one. Do not write.
- Correction of today's exercise (`bänk 82.5`): insert another `exercise_logged` for the same `exercise_key`. Echo that the latest weight is now that value.

```sql
insert into events (
  user_id, type, source, source_status, plan_id, payload
) values (
  :USER_ID,
  'exercise_logged',
  'user',
  'confirmed',
  :plan_id,
  :payload::jsonb
);
```

`plan_id` may be the active plan when one exists. `session_id` is set only when the exercise matches a planned item that day (or is a clear accessory of that same session). If nothing planned matches, `session_id` is null even if the day has exactly one other session (do not attach extra goblet to evening intervals). Still log if the exercise is unambiguous. Do not write `session_completed` for unmatched extra gym.

### 3. Extra-plan activity and scheduled habit sessions

If the message is everyday movement, yoga, or recreation (`gick 30 min`, `gåband`, `yoga`, `klättrade`, `vandrade`, commute walk, similar): parse with `references/parse-and-match.md`.

If today's plan has a session with matching `habit_key` (or the same activity name):

- `INSERT` `activity_logged` with that `plan_id` and `session_id`.
- Also `INSERT` `session_completed` with `status = completed` in the same turn.
- Echo **Sparat:** (name, duration, and that the pass is done).
- Skip of that session (`hoppade över klättringen`) is `session_missed`, not a missed walk.

Otherwise (background habit or one-off):

- Do not match these to planned strength/run items. Do not write `exercise_logged` or `session_completed`.
- `INSERT` `activity_logged` immediately when the activity is unambiguous. Echo **Sparat:** in Swedish (name, duration and/or distance, speed if given; `(enligt vana)` when typicals were filled; `(N idag)` when `instance` > 1).
- `plan_id` / `session_id` are null.

Shared rules:

- Set `habit_key` when the activity matches a confirmed habit `key` or name; otherwise `habit_key` is null.
- Set `instance`: new bout = one more than today's max for that `activity_key` (start at 1). Correction language (`nej`, `rättelse`) keeps the latest `instance`.
- If they named a habit with no numbers, copy `typical_duration_min` / `typical_speed_kmh` / `typical_distance_km` from the habit into the payload and echo `(enligt vana)`. Stated numbers always win. If only duration or only speed is stated, fill the omitted typical when present.
- `kind`: `lifestyle` for easy everyday movement (walk, treadmill, commute) or easy yoga/mobility; `extra` for climbing, hiking, and similar load.
- `intensity`: `easy | moderate | hard`. Default `easy` for ordinary walking (including 5 km/h treadmill). Ask once if a hike or climb intensity is unclear.
- Store only what they said or the typicals just above. Do not invent `distance_km` from speed × time. Do not store kcal.
- `times_per_day` is not a maximum and not auto-completed. Two `gåband` lines the same day are two instances.
- A new recurring pattern (`jag går alltid 2×30 min arbetsdagar`, `jag klättrar onsdagar`) is a profile habit: switch to `training-onboarding`. Still log today's instance here if they also reported doing it.

```sql
insert into events (
  user_id, type, source, source_status, plan_id, payload
) values (
  :USER_ID,
  'activity_logged',
  'user',
  'confirmed',
  :plan_id,
  :payload::jsonb
);
```

`:plan_id` is the active plan when the activity matches a scheduled session that day; otherwise null. Put `session_id` in the payload in that case.

One user message may contain several activities (`gåband … och yoga …`). Parse each and `INSERT` one `activity_logged` per activity in the same turn.

If `INSERT` fails because `type` is not allowed (`activity_logged` missing from `events_type_check`): say in Swedish that the live database is missing that event type. Do not tell them to rephrase. Do not run DDL. Do not write a substitute `type`. Do not invent a gym log for gåband or yoga.

### 4. Log the whole session

Three intents. Match meaning, not exact wording. Do not copy planned RPE/load text into `load_kg`.

Do not treat background walks or background yoga as remaining planned work. Mention them as **Utanför schema** if logged today. If they have habits and none are logged today, you may ask `Någon vana idag?` with their habit names — only when habit catch-up applies (quiet week) or they are wrapping **dagens pass**, not after every set. Scheduled habit sessions (climbing) are planned work — include them in **Loggat** / **Kvar**.

**A. Wrap-up / status** (`logga dagens pass`, `jag är klar`, `klart för idag` — they want what is left, not a copy of last loads):

1. List today's planned sessions and which exercises already have a current log.
2. Show **Loggat** vs **Kvar**.
3. If they give remaining loads in the same turn, parse those as step 2.

**B. Shortcut — completed the session as last time** (`logga mitt gympass`, `logga gympasset`, `logga passet`, `jag körde hela passet`, `klarade alla övningar`, `allt som senast`):

Filling from history is an assumption. Show a card, wait for one `godkänn`, then write. Do not write before approval. Do not auto-bump. Do not copy PR or plan `load` text.

1. Also `SELECT` last working per `exercise_key` (any date) with the query in `references/loads-and-prs.md` (full `payload` / `sets`, not only kg). Use today's logs from step 1.
2. Target session: `gympass` → today's strength session only. Bare `passet` on a run-only day → the run. Two sessions the same day and they did not name one: ask once. Pain, skip, or “inte alla”: ask once, do not write.
3. Working items only: strength items with `sets` and `reps`, or a run item with duration/distance. Skip warmup and duration-only blocks (easy bike). Skip items already logged today.
4. Default to the prescribed (home) `name` / `key`. If the item has `preferred`, put `Förstahand (annat gym): {name} — säg till om du körde den` on the card. Stay on the home key unless they switch before `godkänn`.
5. Fill each remaining working item:
   - **Load:** last working for that key. Copy `load_kg` and `load_text` (dumbbell `/hantel` as last time). Bodyweight or timed with last `load_kg` null: copy null + last `load_text`. That is not “missing”.
   - **Sets:** today's planned set count. One set object per working set.
   - **Reps:** if last log's set count equals today's planned sets, copy that per-set reps list; else planned low end (`8–10` → 8) and say so on the card.
   - **Run** (only if this path includes the run): last duration/distance, not PR.
6. Missing last working (no history, or last log has no usable load for a loaded exercise): ask **all** unknowns in one message (`Vilken vikt på X, Y?`). Do not show the save card until those are answered. Stated kg in that reply fill those rows.
7. Card (Swedish, compact): session title + date; one line per remaining working item, e.g. `Hantelpress 4×8 @ 30 kg/hantel (enligt senaste)`; preferred hint if any. Wait for `godkänn`.
8. After `godkänn`: `INSERT` one `exercise_logged` per remaining working item (same shape as step 2; `raw_text` = their phrase; optional `notes`: `enligt senaste`; `source` `user`, `source_status` `confirmed`). Then `session_completed` with `status = completed` if every planned working item for that session now has a current log, else `partial`. Echo **Sparat:** a short list with `(enligt senaste)` on copied rows. Already-logged items today stay unchanged.

**C. Remaining according to plan, no loads** (`resten enligt plan`):

Show what will be marked done **without weights**, wait for `godkänn`, then `session_completed` with `status = partial` if any planned strength work lacks loads, else `completed`. This is not the shortcut. Do not copy last working into `exercise_logged`.

```sql
insert into events (
  user_id, type, source, source_status, plan_id, payload
) values (
  :USER_ID,
  'session_completed',
  'user',
  'confirmed',
  :plan_id,
  :payload::jsonb
);
```

One `session_completed` (or `session_missed`) per planned `session_id` on that date when possible. If the day has two sessions (strength + run) and they only finished one, log that `session_id` and leave the other.

### 5. Missed session

Clear skip (`hoppade över`, `kunde inte träna idag`): insert `session_missed`, echo **Sparat:**. If it is unclear which session, ask once. Skipping a background walk or background yoga is not `session_missed` (and do not invent that they did it either). Skipping a scheduled habit session is.

### 6. PR, last weight, or results (only when asked)

If they ask for a PR, last weight, how an exercise is going, or similar: use `references/loads-and-prs.md`. Answer that exercise (or a short list if they asked generally). Do not volunteer PRs or full histories on ordinary logs or “dagens pass”.

### 7. After a write

Swedish, one or two lines. Offer the next planned exercise if any remain. After `activity_logged`, do not offer gym exercises unless they were already mid-session. Do not dump JSON. Do not mention PR unless they just asked or you need it to choose a weight. Do not mention kcal.

If you just logged extra lower-body strength (unmatched to today's plan, or they said it was extra gym) and that date still has a planned quality run that is not completed: in the same turn, say in Swedish that quality running should not follow heavy lower body, and offer to swap it to 30–40 min easy jogging. Do not UPDATE the plan unless they then ask; that is `training-plan`. Easy gåband or yoga does not trigger this.

## Dialogue

Match intent. Keep replies short during a workout. Do not assume gåband or yoga happened unless they just logged it. Shortcut session fill waits for one `godkänn`; a single exercise line does not.
