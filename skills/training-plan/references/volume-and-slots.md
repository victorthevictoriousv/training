# Volume, slots, and recovery

How to lay out a week from confirmed capacity. This is programming guidance, not a periodization engine and not a fixed template.

Do not store these rules as profile facts. Do not write a weekly quota of gym sessions + runs into `user_profiles.data`.

## Capacity vs template

Profile fields describe **what is possible**, not a daily mandate:

- `availability.days_per_week` — training **days**, not session count
- `availability.windows` — slots that *may* be used (`morning` / `lunch` / `evening`)
- `availability.two_a_day` — `some_days` means two sessions the same day are allowed on **some** days; never treat as every training day. Omit or `never` → one planned session per training day unless they asked otherwise this week
- `availability.anchor` — preference (e.g. lunch strength when the day has gym). Drop it under poor recovery or time pressure
- `availability.session_minutes` — fallback length. Per-window `minutes` wins when present
- `goals.notes` may say training is a hobby / they like high volume. That raises the **ceiling**, not a requirement to fill every slot

You lay out the week. Do not ask the user to pick how many gym vs run sessions. Draft, then wait for one `godkänn`.

## Recovery is a hard gate

High volume is allowed when they confirmed hobby/high-volume willingness and `two_a_day` is `some_days`. Recovery still wins:

- Most sessions easy. Strength working sets around RPE 7, not failure
- At most one hard quality run per week
- Never hard + hard the same day
- No quality run after heavy lower body the same day. Quality running may be the only session that day
- At least one day with no gym and no run if `recovery` is a selected modality or `days_per_week` ≥ 4. A yoga/walk habit may exist that day as pattern; it still only counts if logged
- Poor sleep, high stress, time pressure, or non-stop pain: cut quality and two-a-days first, keep easy work
- Do not copy elite volume. Do not default to a beginner 3+3 week when `training_age_years` is high or `two_a_day` is `some_days`

## Two-a-days are a tool

When `two_a_day` is `some_days`, use a second session on some days **if it serves the week** (e.g. lunch strength + easy evening run after upper body). Other days stay one session.

Pair work + easy, never two hard sessions. Set `slot` on each session when the window is known.

Do not fill every window every day.

## Mid-week extra session

These rules apply when adding or logging extra work on an already active week, not only when first drafting.

- Extra session this week (including on a rest day) stays inside this week. Do not write `days_per_week`. That is minor reshape, not a new normal.
- Easy upper or mobility lunch can stack with an evening quality run. One fueling line. Keep the quality run.
- Extra lower-body strength the same day as a quality run: the draft must not keep both. Swap the quality run to 30–40 min easy jogging unless they insist; never program hard + hard. Do not auto-write because they logged extra. Offer the swap; wait for `godkänn`.
- Gåband or yoga is background; do not add a session and do not drop the quality run for that alone.

## Experience when fields are missing

- Confirmed `experience.*` for a selected modality wins
- If that is missing and `training_age_years` ≥ 5: program intermediate volume (inference in chat, not a profile write). Do not use a beginner template
- If both are missing: moderate week, still respect `two_a_day` and windows

## Mobility and background yoga

If a background yoga/mobility habit exists, it covers **programmed** mobility (do not add extra mobility sessions). Mention it in `intent` as a vana that counts when logged. Do not treat it as done this week without `activity_logged`.

If mobility is selected and there is no such habit, keep short mobility as today.

## Running toward a time goal

If `goals.notes` includes a 10 km (or similar) target: one quality run, one longer easy run, remaining runs conversational. How many easy runs is your call, not a quota.

Use last logged duration/distance, not running PRs, as the default target.

## Fueling (inference only)

On days that actually have two sessions (e.g. lunch gym + evening run), one Swedish line that they should eat between sessions. Label it as slutsats. Do not store kcal.

## Illustrative, not to hard-code

A fit week might mix single-session days and a few two-a-days, keep lunch strength as an anchor when it helps, put quality running on a day without heavy legs, include one longer easy run, and leave at least one day without gym/run. The next week may look different.
