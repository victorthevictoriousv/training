# Loads, PRs, running, and results

Derived from `exercise_logged`. No extra table. Do not use `activity_logged` for last working load, PRs, or running PRs.

**Prescribe with RPE until there is a logged load. After that, track kg/reps/time so results are visible.** Do not show PRs unless asked.

## Prescription vs results

| Situation | What to put on the session | What is stored |
| --- | --- | --- |
| No log history for that exercise | Planned sets/reps + RPE only | Nothing until they log |
| History exists | Last working kg (run: last duration/distance) plus planned sets/reps. Keep RPE as effort cue | Each log is a result row |
| They log kg, reps, RPE, run time/distance | Echo **Sparat:** | That becomes both today's result and next time's starting point |

Track what they actually give: load, reps, sets, RPE, run duration, run distance. Do not invent missing kg. Optional RPE on a log is worth saving when they say it — it explains the result.

## Copy last working into today's log (shortcut)

When they mean they completed the session (`logga gympasset`, `klarade alla övningar`, similar): last working may be copied into new `exercise_logged` rows **after** a summary card and one `godkänn`. Use the last-working query below (full `payload` / `sets`, not only kg).

- Copy last `load_kg` and `load_text`. Dumbbell `/hantel` as last time. Bodyweight or timed with null `load_kg`: copy that.
- Sets from today's plan. Reps from last log when set counts match, else planned low end.
- Do not copy PR. Do not copy planned RPE or suggested kg from `item.load`. Do not auto-bump (+2.5 stays a plan-draft rule, not a log write).
- No history, or no usable load for a loaded exercise → ask for kg; do not invent. Do not write until those answers are on the card and they `godkänn`.
- Until `godkänn`, copied loads are not confirmed facts.

## Three numbers (strength)

| Name | Meaning | Use |
| --- | --- | --- |
| Last working | Latest `exercise_logged` for that `exercise_key` (any date) | Default bar weight next time |
| Today's log | Latest log for that key on the session date | **Loggat** / today's result |
| PR | Max `load_kg` on **current** logs for that key (latest row per date; corrections replace that date) | Ceiling and “what is my PR?”. Not the default working weight |

Last working beats PR for programming and for the shortcut fill.

## Queries

SQL lives in `skills/_shared/queries.md`. Copy the named id; do not paste a variant.

| Need | Id |
| --- | --- |
| Last working per exercise | `Q_last_working` |
| Recent working logs per exercise (draft) | `Q_recent_working` |
| PR per exercise (strength) | `Q_pr` |
| Running PR (distance / duration / pace) | `Q_run_pr` |
| Recent results for one exercise | `Q_recent_results` |

`Q_pr` and `Q_run_pr` use **current** logs only (latest row per date + key). A correction (`nej`, `bänk 82.5`) replaces that date; the old kg is not a PR. `Q_pr` uses `[.]` for a literal decimal point so values like `82.5` count. Do not write `\\.` — that drops decimals. `Q_recent_working` is already collapsed per date; do not collapse again.

Ordered by logged date first, then insert time, so a backfilled entry for an earlier date never outranks a genuinely more recent session.

Summarize `Q_recent_results` in Swedish: date, kg × reps, RPE if present. Same idea for a run key with duration/distance.

## Suggest the next strength load

When *showing* an already saved session (today/tomorrow):

- If today's log exists: that is the result; do not suggest a bump.
- Else if last working kg exists: `lägg på 80 kg` for the planned sets/reps. RPE from the plan is still the effort cap.
- Else: RPE only. Do not invent kg.
- Do not print PR.

When *drafting a new week* (plan proposal):

1. No history → RPE-only `load`.
2. History → start from last working load (first row per key in `Q_recent_working`). `load_kg` for a log is the first working set.
3. Walk consecutive current sessions newest-first. A session **hits** when every working set’s `reps` is ≥ the planned low end (`8–10` → 8). Missing RPE is not a stop (same as ≤ 7.5).

| Latest current logs for that key | Förslag |
| --- | --- |
| 2 in a row, same `load_kg`, both hit, RPE missing or ≤ 7.5 on both | +2.5 kg on compounds, +1.25 or same weight on small isolation work |
| Only 1 hit at the current kg, or mixed | hold = last working |
| Latest missed reps or RPE ≥ 9 | hold or −2.5 kg (streak breaks) |
| `load_kg` null (bodyweight / timed) | no kg bump |
| Different kg (already raised) | start from the latest; do not bump unless the streak at *that* kg is 2 |

Do not bump from a single last log. Do not count calendar weeks. Do not run `Q_recent_results` once per exercise (`Q_recent_working` only). Do not bump when *showing* a saved session or filling `logga gympasset`.
4. Never jump more than 2.5 kg in one week (the streak bump is already that step). Do not run `Q_pr` or `Q_run_pr` on draft.
5. Label kg as **Förslag vikt** (from logs), not as a confirmed PR.

Put suggested kg in the chat draft and in `item.load` (e.g. `80 kg, RPE 7`) only after the usual plan approval.

## Running

Store on the set object: `duration_min` and/or `distance_km`, `load_kg` null.

| Last | Latest run: duration and/or distance and intensity |
| PR distance | Max `distance_km` on current logs (`Q_run_pr`) |
| PR duration | Max `duration_min` on current logs (`Q_run_pr`) |
| PR pace | Fastest min/km among current logs with both distance and duration (`Q_run_pr`) |

No run history → RPE/prattempo from the plan. History → last duration/distance as the target. Do not jump to longest-ever PR. Shortcut fill of a run session copies last duration/distance after the same card + `godkänn`.

## When to show PRs or results

- PRs: only if they ask (`vad är mitt PR`, `personbästa`, `bästa 10 km`).
- Results / trend: if they ask (`hur går bänken`, `utveckling`, `visa vikter`, or similar) — last ~8 logs, not a PR headline.
- Do not add PR or trend lines to every **Sparat:** or every **Sparat pass**.
