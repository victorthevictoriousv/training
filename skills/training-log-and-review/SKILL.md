---
name: training-log-and-review
description: Log completed or missed training — a single exercise with weight and reps, a run, today's whole session, a load correction, a PR question, or how an exercise is progressing. Use whenever the user reports what they lifted or ran, skips a session, or asks for last weights, personal bests, or results. Match intent, not exact wording. Do not use to create weekly plans, change programmed sessions, collect profile data, run weekly reviews, or give meal plans.
---

# training-log-and-review

Record what actually happened. Do not invent loads. Weekly review is not implemented; say so if asked.

## Do not

- Create or rewrite the weekly plan (load `training-plan`)
- Invent kilogram values the user did not state
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

## Procedure

### 1. Load plan and existing logs

Date = today in `Europe/Stockholm` unless the user named a day.

```sql
select id, title, content
from plans
where user_id = :USER_ID
  and status = 'active'
order by created_at desc
limit 1;

select payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
  and payload->>'date' = :date
order by occurred_at desc;
```

Current load per `exercise_key` is the first row for that key in this list (already newest-first).

If the SELECT fails: say you could not read the saved plan or logs. Do not invent a session or loads.

### 2. Single exercise line

If the message is (or includes) an exercise + load and/or reps, parse with `references/parse-and-match.md`.

- One clear match to today's planned items, or a clear new accessory: `INSERT` `exercise_logged` immediately. Echo **Sparat:** in Swedish (exercise, sets, kg, reps).
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

### 3. Log the whole session

Intent like `logga dagens pass`, `jag är klar`, `klart för idag`.

1. List today's planned sessions and which exercises already have a current log.
2. Show **Loggat** vs **Kvar**.
3. If they give remaining loads in the same turn, parse those as step 2.
4. If they say `resten enligt plan`: show what will be marked done **without weights**, wait for `godkänn`, then `session_completed` with `status = partial` if any planned strength work lacks loads, else `completed`.
5. Do not copy planned RPE/load text into `load_kg`.

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

### 4. Missed session

Clear skip (`hoppade över`, `kunde inte träna idag`): insert `session_missed`, echo **Sparat:**. If it is unclear which session, ask once.

### 5. PR, last weight, or results (only when asked)

If they ask for a PR, last weight, how an exercise is going, or similar: use `references/loads-and-prs.md`. Answer that exercise (or a short list if they asked generally). Do not volunteer PRs or full histories on ordinary logs or “dagens pass”.

### 6. After a write

Swedish, one or two lines. Offer the next planned exercise if any remain. Do not dump JSON. Do not mention PR unless they just asked or you need it to choose a weight.

## Dialogue

Match intent. Keep replies short during a workout.
