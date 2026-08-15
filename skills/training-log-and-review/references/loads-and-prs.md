# Loads, PRs, running, and results

Derived from `exercise_logged`. No extra table.

**Prescribe with RPE until there is a logged load. After that, track kg/reps/time so results are visible.** Do not show PRs unless asked.

## Prescription vs results

| Situation | What to put on the session | What is stored |
| --- | --- | --- |
| No log history for that exercise | Planned sets/reps + RPE only | Nothing until they log |
| History exists | Last working kg (run: last duration/distance) plus planned sets/reps. Keep RPE as effort cue | Each log is a result row |
| They log kg, reps, RPE, run time/distance | Echo **Sparat:** | That becomes both today's result and next time's starting point |

Track what they actually give: load, reps, sets, RPE, run duration, run distance. Do not invent missing kg. Optional RPE on a log is worth saving when they say it — it explains the result.

## Three numbers (strength)

| Name | Meaning | Use |
| --- | --- | --- |
| Last working | Latest `exercise_logged` for that `exercise_key` (any date) | Default bar weight next time |
| Today's log | Latest log for that key on the session date | **Loggat** / today's result |
| PR | Max `load_kg` ever for that key | Ceiling and “what is my PR?”. Not the default working weight |

Last working beats PR for programming.

## Queries

Last working per exercise:

```sql
select distinct on (payload->>'exercise_key')
  payload, occurred_at
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
order by payload->>'exercise_key', occurred_at desc;
```

PR per exercise (ignore null / non-numeric `load_kg`):

```sql
select payload->>'exercise_key' as exercise_key,
       max((set_row->>'load_kg')::numeric) as pr_kg
from events e
cross join lateral jsonb_array_elements(e.payload->'sets') as set_row
where e.user_id = :USER_ID
  and e.type = 'exercise_logged'
  and (set_row->>'load_kg') ~ '^[0-9]+(\\.[0-9]+)?$'
group by 1;
```

Recent results for one exercise (when they ask how it is going):

```sql
select occurred_at, payload
from events
where user_id = :USER_ID
  and type = 'exercise_logged'
  and payload->>'exercise_key' = :exercise_key
order by occurred_at desc
limit 8;
```

Summarize in Swedish: date, kg × reps, RPE if present. Same idea for a run key with duration/distance.

## Suggest the next strength load

When *showing* an already saved session (today/tomorrow):

- If today's log exists: that is the result; do not suggest a bump.
- Else if last working kg exists: `lägg på 80 kg` for the planned sets/reps. RPE from the plan is still the effort cap.
- Else: RPE only. Do not invent kg.
- Do not print PR.

When *drafting a new week* (plan proposal):

1. No history → RPE-only `load`.
2. History → start from last working load.
3. If last log hit the planned reps (or more) and RPE is missing or ≤ 7.5 → suggest +2.5 kg on compounds, +1.25 or same weight on small isolation work.
4. If they missed reps or RPE ≥ 9 → same weight or −2.5 kg.
5. Never jump more than 2.5 kg toward PR in one week.
6. Label kg as **Förslag vikt** (from logs), not as a confirmed PR.

Put suggested kg in the chat draft and in `item.load` (e.g. `80 kg, RPE 7`) only after the usual plan approval.

## Running

Store on the set object: `duration_min` and/or `distance_km`, `load_kg` null.

| Last | Latest run: duration and/or distance and intensity |
| PR distance | Max `distance_km` |
| PR duration | Max `duration_min` |
| PR pace | Fastest min/km among logs with both distance and duration |

No run history → RPE/prattempo from the plan. History → last duration/distance as the target. Do not jump to longest-ever PR.

## When to show PRs or results

- PRs: only if they ask (`vad är mitt PR`, `personbästa`, `bästa 10 km`).
- Results / trend: if they ask (`hur går bänken`, `utveckling`, `visa vikter`, or similar) — last ~8 logs, not a PR headline.
- Do not add PR or trend lines to every **Sparat:** or every **Sparat pass**.
