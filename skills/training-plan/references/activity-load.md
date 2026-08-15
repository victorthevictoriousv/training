# Extra-plan activity and weekly load

Confirmed `data.lifestyle.habits` are the **pattern** (what they usually do). `activity_logged` is the **instance** (what they actually did). Only instances count as done.

`plan_inclusion` decides whether a habit is also a planned session. It does not mean the habit happened.

Do not diagnose. Infer body-region stress from logged `activity_key` / habit `key` and label it as a slutsats in chat. Do not write `load_regions` into the database.

## Pattern vs instance

- A profile habit is not a completed walk, yoga, or climb. Never assume it was done because it sits on the profile or in `intent`.
- Done = an `activity_logged` row for that date (and `habit_key` when it matches). Corrections are a new row; latest for `user_id + date + activity_key` wins.
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
5. For scheduled extra habits and for unplanned `activity_logged` of `kind` extra: keep that weekday and the following morning lighter for the patterns below.
6. Easy background walking and easy background yoga do not reduce strength or running **days**. They also do not require a two-a-day.
7. Do not invent a scheduled session for a one-off climb/hike unless the user asks to put it in the week.
8. If the habit catch-up in this file applies, ask with their habit names before treating last week's load as known.

## Default inferences (not facts)

| activity_key / habit key (or alias) | Inference |
| --- | --- |
| `treadmill_walk`, `walk`, gåband, promenad | Low easy aerobic load. Legs, low eccentric stress. Stacks with almost any session. |
| `yoga`, yoga, rörlighet | Easy mobility. Not a planned session when `plan_inclusion` is `background`. Covers programmed mobility. Time of day is not required. |
| `climbing`, klättring | Upper body, fingers, shoulders, pulling. Avoid heavy rows, pull-ups, dead hangs, and high-volume pressing the same day and the next morning. |
| `hiking`, vandring | Legs, eccentric downhill. Avoid heavy squats and hinges the same day and the next day if the hike was long or `moderate`/`hard`. |

Unknown activity: treat duration + `intensity` only. Ask once if `kind` is unclear. Default unknown easy walks to `lifestyle`; default climbing/hiking to `extra`.

## Presenting a saved day

Show `plans.content` sessions as **Sparat pass**, including scheduled habit sessions. Do not append background walks or background yoga to that list.

## Nutrition later

Profile habits are what to prompt for. Sum of `activity_logged` is what happened. Do not treat typical habit duration × days as confirmed energy. kcal in chat is inference only. Do not write energy into `user_profiles.data` or `plans.content`.
