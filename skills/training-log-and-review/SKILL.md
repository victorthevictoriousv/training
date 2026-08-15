---
name: training-log-and-review
description: Log completed or missed training — a single exercise with weight and reps, a run, today's whole session, extra-plan activity (walk, treadmill, yoga, climbing, hiking), a load correction, a PR question, how an exercise is progressing, or catching up habits after a quiet week. Use whenever the user reports what they lifted, ran, walked, did yoga, climbed, or hiked, skips a session, or asks for last weights, personal bests, or results. Match intent, not exact wording. Do not use to create weekly plans, change programmed sessions, collect profile habits, run weekly reviews, or give meal plans.
---

# training-log-and-review

Record what actually happened. Do not invent loads. Weekly review is not implemented; say so if asked.

## Do not

- Create or rewrite the weekly plan (load `training-plan`)
- Save a recurring habit to the profile (load `training-onboarding`)
- Invent kilogram values the user did not state
- Store kcal, MET, or TDEE
- UPDATE or DELETE `events`
- Run DDL or weekly reviews

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

Current load per `exercise_key` is the first row for that key in this list (already newest-first). Current extra-plan activity per `activity_key` is the first matching `activity_logged` row.

If the SELECT fails: say you could not read the saved plan or logs. Do not invent a session or loads.

A profile habit is not done until `activity_logged`. If habit catch-up in `activity-load.md` applies and this is not a mid-set gym log, ask once with their habit names, then continue.

### 2. Single exercise line

If the message is (or includes) an exercise + load and/or reps, parse with `references/parse-and-match.md`.

- One clear match to today's planned items, or a clear new accessory: `INSERT` `exercise_logged` immediately. Echo **Sparat:** in Swedish (exercise, sets, kg, reps).
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

`plan_id` / `session_id` may be null if there is no active plan; still log if the exercise is unambiguous.

### 3. Extra-plan activity and scheduled habit sessions

If the message is everyday movement, yoga, or recreation (`gick 30 min`, `gåband`, `yoga`, `klättrade`, `vandrade`, commute walk, similar): parse with `references/parse-and-match.md`.

If today's plan has a session with matching `habit_key` (or the same activity name):

- `INSERT` `activity_logged` with that `plan_id` and `session_id`.
- Also `INSERT` `session_completed` with `status = completed` in the same turn.
- Echo **Sparat:** (name, duration, and that the pass is done).
- Skip of that session (`hoppade över klättringen`) is `session_missed`, not a missed walk.

Otherwise (background habit or one-off):

- Do not match these to planned strength/run items. Do not write `exercise_logged` or `session_completed`.
- `INSERT` `activity_logged` immediately when the activity is unambiguous. Echo **Sparat:** in Swedish (name, duration and/or distance, speed if given).
- `plan_id` / `session_id` are null.

Shared rules:

- Set `habit_key` when the activity matches a confirmed habit `key` or name; otherwise `habit_key` is null.
- `kind`: `lifestyle` for easy everyday movement (walk, treadmill, commute) or easy yoga/mobility; `extra` for climbing, hiking, and similar load.
- `intensity`: `easy | moderate | hard`. Default `easy` for ordinary walking. Ask once if a hike or climb intensity is unclear.
- Store only what they said. Do not invent `distance_km` from speed × time. Do not store kcal.
- Correction of today's activity (`nej, 40 min`) → another `activity_logged` for the same `activity_key`. Latest for that date + key is current.
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

### 4. Log the whole session

Intent like `logga dagens pass`, `jag är klar`, `klart för idag`.

1. List today's planned sessions and which exercises already have a current log.
2. Show **Loggat** vs **Kvar**.
3. If they give remaining loads in the same turn, parse those as step 2.
4. If they say `resten enligt plan`: show what will be marked done **without weights**, wait for `godkänn`, then `session_completed` with `status = partial` if any planned strength work lacks loads, else `completed`.
5. Do not copy planned RPE/load text into `load_kg`.
6. Do not treat background walks or background yoga as remaining planned work. Mention them as **Utanför schema** if logged today. If they have habits and none are logged today, you may ask `Någon vana idag?` with their habit names — only when habit catch-up applies (quiet week) or they are wrapping **dagens pass**, not after every set. Scheduled habit sessions (climbing) are planned work — include them in **Loggat** / **Kvar**.

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

## Dialogue

Match intent. Keep replies short during a workout. Do not assume gåband or yoga happened unless they just logged it.
