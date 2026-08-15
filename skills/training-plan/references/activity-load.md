# Extra-plan activity and weekly load

Confirmed `data.lifestyle.habits` are the **pattern** (what they usually do). `activity_logged` is the **instance** (what they actually did). Only instances count as done.

`plan_inclusion` decides whether a habit is also a planned session. It does not mean the habit happened.

Do not diagnose. Infer body-region stress from logged `activity_key` / habit `key` and label it as a slutsats in chat. Do not write `load_regions` into the database.

## Pattern vs instance

- A profile habit is not a completed walk, yoga, or climb. Never assume it was done because it sits on the profile or in `intent`.
- Done = current `activity_logged` bouts for that date (`habit_key` when it matches). Each log line is a new `instance` unless they use correction language. Latest row per `user_id + date + activity_key + instance` wins. Day load is the **sum** of current instances, not the last row only. Typical habit duration/speed is a default for a bare name (`gåband`), not a cap.
- Programming **structure** may still use the pattern: if a background yoga habit exists, do not add extra mobility sessions; if a background walk habit exists, do not add extra easy-walk slots.
- This week's **load**, recovery credit, and (later) energy use only `activity_logged`. No logs → no credit.

## Habit catch-up (not a weekly review)

If `lifestyle.habits` is non-empty AND there is no `activity_logged` with a matching `habit_key` whose `payload.date` is within the last 7 days in `Europe/Stockholm`:

Ask once in Swedish. List **their** habit names as examples, e.g. `Har du gjort några vanor den här veckan? T.ex. gåband, yoga.`

- Do not invent instances. Do not auto-log.
- If they report some (`yoga i morse`, `gåband 30 min 4,5`): `training-log-and-review` writes `activity_logged` immediately and echoes **Sparat:**.
- `nej` / `hoppa` / `sen` → do not write. Continue the original task.
- Already asked in this conversation → do not ask again.
- Do not ask in the middle of a set-by-set gym log (`bänk 80x5`). Ask when drafting or showing a week, when they log **dagens pass**, or when they ask how training is going.

This is a nudge, not `training-nutrition` and not a weekly review.

## Kinds and inclusion

- `lifestyle` — easy everyday movement or easy mobility/yoga (treadmill walk, commute, yoga). Complements training. Default `plan_inclusion`: `background`.
- `extra` — recreational load (climbing, hiking, similar). Default `plan_inclusion`: `scheduled` if weekdays are named and the user agreed; otherwise `background`.

`background`: never a session. Mention in `intent`. Skip is not `session_missed`.

`scheduled`: insert an `other` session on each habit `day`, with `habit_key`. Show it as **Sparat pass**. Skip is `session_missed`. Do not count it against `availability.days_per_week`.

## When drafting a week

1. Read `lifestyle.habits`. Read `activity_logged` from the previous Monday through the plan week's Sunday.
2. Background habits: one Swedish line in `intent` as pattern, not as done, e.g. `Vanor (räknas när du loggar): gåband 2×30 min arbetsdagar, yoga vardagar.`
3. Scheduled habits: add a session on those weekdays (`modality` `other`, `habit_key`, duration from the habit). Do not add `other` to top-level `content.modalities`. Still do not mark them completed until `activity_logged` / `session_completed`.
4. If a background walk habit exists, do not program extra easy-walk recovery slots. If a background yoga/mobility habit exists, do not program extra mobility sessions. Prefer full rest (no gym/run) for the recovery day. Do not credit those habits as this week's load unless logged.
5. For scheduled extra habits, unplanned `activity_logged` of `kind` extra, and unmatched `exercise_logged` (extra gym): keep that weekday and the following morning lighter for the patterns below. Extra lower body the same day as a quality run: offer to swap that run to easy jogging; do not keep both in a remaining-week draft.
6. Easy background walking and easy background yoga do not reduce strength or running **days**. They also do not require a two-a-day.
7. Do not invent a scheduled session for a one-off climb/hike or extra gym unless the user asks to put it in the week.
8. If the habit catch-up in this file applies, ask with their habit names before treating last week's load as known.

## Default inferences (not facts)

| activity_key / habit key (or alias) | Inference |
| --- | --- |
| `treadmill_walk`, `walk`, gåband, promenad | Low easy aerobic load. Legs, low eccentric stress. Stacks with almost any session. |
| `yoga`, yoga, rörlighet | Easy mobility. Not a planned session when `plan_inclusion` is `background`. Covers programmed mobility. Time of day is not required. |
| `climbing`, klättring | Upper body, fingers, shoulders, pulling. Avoid heavy rows, pull-ups, dead hangs, and high-volume pressing the same day and the next morning. |
| `hiking`, vandring | Legs, eccentric downhill. Avoid heavy squats and hinges the same day and the next day if the hike was long or `moderate`/`hard`. |

Unknown activity: treat duration + `intensity` only. Ask once if `kind` is unclear. Default unknown easy walks to `lifestyle`; default climbing/hiking to `extra`.

## Unplanned gym (`exercise_logged`)

An `exercise_logged` that does not match a planned item that day is extra gym load, not a new session unless they ask to put it in the week (`training-plan`).

- `session_id` is null. Do not treat it as completing the day's other session. Do not write `session_completed` for it.
- Infer region from the exercise (squat, RDL, lunge, leg press → lower body; press, row, pull-up → upper). Label as slutsats. Do not write `load_regions`.
- Extra lower body the same day as a remaining quality run: do not auto-rewrite. Offer to swap the quality run to 30–40 min easy jogging (`training-plan`). Wait for `godkänn`.
- Easy upper or mobility can stack with an evening quality run. One fueling line as inference.
- Easy background yoga or gåband does not trigger this and does not drop the quality run.

When drafting or reshaping this week, also read today's unmatched `exercise_logged`. Same load caution as unplanned `activity_logged` of `kind` extra for the region inferred.

## Presenting a saved day

Show `plans.content` sessions as **Sparat pass**, including scheduled habit sessions. Do not append background walks, background yoga, or unplanned gym (`exercise_logged` with `session_id` null) to that list.

## Nutrition later

Profile habits are what to prompt for. Sum of `activity_logged` is what happened. Do not treat typical habit duration × days as confirmed energy. kcal in chat is inference only. Do not write energy into `user_profiles.data` or `plans.content`.
