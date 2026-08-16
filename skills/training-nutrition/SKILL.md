---
name: training-nutrition
description: Give meal suggestions from confirmed nutrition preferences, the
  food/recipe library, and recent training. Use when the user asks what to eat,
  wants lunch/dinner/evening ideas, asks how to fuel a session or recover from
  one, reports a meal they ate, logs a body weight, wants to save a recipe or
  food staple from a suggestion, asks how diet is going, wants the calorie
  target reviewed against training and food, mentions a food reaction, or asks
  about saved nutrition preferences. Meal log / weigh-in / saved prefs follow
  the nutrition fast path (queries.md only) when there is no suggestion or
  follow-up. Match intent, not exact wording. Do not use to collect the first
  nutrition profile (training-onboarding), create or change weekly training
  plans (training-plan), log exercises or extra-plan activity, or give a
  weekly training overview (training-log-and-review). Do not diagnose
  conditions or give clinical diets.
---

# training-nutrition

Give meal suggestions in chat. Log meals and weigh-ins they report. Review diet against training and food. Save library items and an adjusted `target_kcal` after approval.

## Do not

- Collect the **first** nutrition profile (`body.*` other than a weigh-in, `nutrition.goal` / pattern / allergies / exclusions / preferences, `nutrition.kitchen`) — hand off to `training-onboarding`
- Auto-rewrite `target_kcal` from a formula, a new weight, or a single log. Propose, wait for `godkänn`, then write
- Create or change weekly training plans — hand off to `training-plan`
- Log exercises, sessions, or extra-plan activity — hand off to `training-log-and-review`
- Open `training-plan`, `training-log-and-review`, or their `references/`. Training load is listed `Q_*` only (`Q_covering_plan`, `Q_today_logs`, `Q_today_activity`, `Q_week_events`). Never `Q_pr`, `Q_last_working`, `Q_recent_working`, `Q_lazy_activate_candidate`
- Diagnose a food reaction, allergy, or condition; give clinical or medically restrictive diets
- Store BMR, TDEE, macros, or MET anywhere
- Write `recommendations` or `plans`
- Change `safety_status` for a nutrition disclosure
- Give a tailored suggestion if `safety_status` is `stop` or `unknown` (ordinary generic food is allowed when `stop` so they can eat; do not use training logs or a calorie target)
- Nag them to log meals or weigh-ins. Do not say remaining kcal

## Intent

Classify once. Run only those ids from `skills/_shared/queries.md`. Match meaning, not a phrase list. Examples in the table are illustrations (`väger 88,6`, `åt X`, `hur går kosten`) — same as gym logging.

| User means | Section | Queries | Skip |
| --- | --- | --- | --- |
| Meal/snack suggestion, “vad ska jag äta”, lunch+middag+kväll, fuel/recover from a session | §2 | `Q_profile`, `Q_covering_plan`, `Q_today_logs`, `Q_today_activity`, `Q_today_food` | `Q_pr` |
| Nutrition tied to the whole week | §2 (week variant) | Same as a day, plus `Q_week_events`, `Q_week_food`, `Q_habits` | `Q_pr`, `Q_recent_working` |
| How diet is going / justera kalorier / följ upp mot träning och mat | §6 | `Q_profile`, `Q_covering_plan`, `Q_week_events`, `Q_week_food`, `Q_week_weights`, `Q_habits` | `Q_pr`, plan writes |
| Reported a meal (“åt X”, “vanlig lunch”) | §4 | `Q_profile`, `Q_today_food` | plan writes |
| Weigh-in (“väger 88,6”, “ny vikt”) | §7 | `Q_profile` | auto-changing `target_kcal` |
| Save this suggestion as a staple/recipe | §5 | `Q_profile` | `food_logged` unless they also ate it |
| Reported food reaction / new allergy | §3 | `Q_profile` | writing it here |
| “What preferences do you have saved?” / calorie target | §1 | `Q_profile` | others |
| First-time diet setup, change goal/allergies/kitchen | hand off to `training-onboarding` §3d | `Q_profile` if already loaded | writes here |

## Before you start

Classify intent first. Then read **only** the files that row needs. Do not open the others in this turn. Do not load a generic Supabase skill to run `Q_*`. Do not open `docs/safety.md` or `docs/data-contracts.md` (safety gate and SQL shapes are in this file). A log / weigh-in / prefs lookup that already followed the project-instruction fast path should not re-open this skill’s references.

**Level A — log or suggest** (no constitution docs):

| Intent | Read now |
| --- | --- |
| Saved prefs / calorie target (§1) | `skills/_shared/queries.md` |
| Meal/snack suggestion (§2) | `queries.md`, `references/meal-suggestions.md`, `references/library.md`. Also `references/energy.md` only if they asked about amount/energy |
| Food reaction / new allergy (§3) | `queries.md` |
| Reported a meal (§4) | `queries.md` |
| Weigh-in (§7) | `queries.md` |
| First-time diet setup | hand off `training-onboarding` §3d |

**Level B — write after approval** (keep `autonomy.md` + `provenance.md`; silence / “ok, berätta mer” / questions / partial agreement is not `godkänn`):

| Intent | Read now |
| --- | --- |
| Save this suggestion as a staple/recipe (§5) | `queries.md`, `references/library.md`, `docs/autonomy.md`, `docs/provenance.md` |
| How diet is going / justera kalorier (§6) | `queries.md`, `references/energy.md`, `docs/autonomy.md`, `docs/provenance.md` |

Use `USER_ID` from the Project instructions. Filter every query on that id.

## Procedure

### 1. Saved preferences

Run `Q_profile`. Answer from confirmed `data.nutrition` and `data.body` only. Missing keys are unknown, not a guess. If they want to add or change a field other than `nutrition.library` in this turn, hand off to `training-onboarding`. Do not write those fields here.

If they ask what their calorie target is: print confirmed `nutrition.energy.target_kcal` if present, and that it is a working number they can change. Do not open `references/energy.md` here. If they want BMR/TDEE or a review against this week’s training and food, go to §6.

Clinical flags in this conversation (eating-disorder disclosure, clinician-prescribed diet, insulin-treated diabetes when they ask for a strict target): refuse energy calculation and any `target_kcal` write. Tell them to seek care. Do not change `safety_status`. Other suggestions may continue without numbers.

### 2. Meal or snack suggestion

Run `Q_profile`. Safety gate:

- `stop` → tell them to seek care. Do not give a tailored suggestion. Ordinary generic food is allowed so they can eat. Do not use today’s training logs or `target_kcal`. Do not suggest food as training fuel.
- `unknown` → route to `training-onboarding` for screening first. Generic only. Do not tailor.
- `cleared` or `restricted` → continue. If `restricted`, stay conservative.

Missing `nutrition.*` → a generic suggestion is fine. Offer the onboarding handoff for a tailored one. Missing library is fine: invent 1–3 **Förslag**.

Then run `Q_covering_plan`, `Q_today_logs`, `Q_today_activity`, and `Q_today_food` (date = today in `Europe/Stockholm` unless they named a day). For a week-level ask, also `Q_week_events`, `Q_week_food` (`:period_start` / `:period_end` from the covering row), and `Q_habits`.

Use what actually happened (`exercise_logged`, `activity_logged`, `session_completed`), not the aspirational plan. Prefer confirmed `nutrition.library` items whose `slots` match the ask. Skip a slot that already has a current `food_logged`. Compose 1–3 Swedish options. Rules in `references/meal-suggestions.md` and `references/library.md`.

`lose_weight` with a saved `target_kcal` may shape portions as a modest deficit (see `energy.md`); never a clinical restriction. Mention `target_kcal` only if it is saved **and** they asked about amount/energy — not on every dinner tip.

Label the reply **Förslag**. Offer once: spara som recept / lägg i vanearkivet. Nothing is a saved meal plan.

“Ge mig lunch, middag och kväll” = three slot suggestions in one turn, vary library items, fill gaps with new **Förslag**.

### 3. Food reaction or new allergy

Note it as their observation, not a diagnosis. If they want it remembered, hand off to `training-onboarding` to confirm into `nutrition.allergies` or `nutrition.exclusions`. Write nothing here.

### 4. Log a meal

A clear line (`åt kycklingris till middag`, `vanlig lunch`) is user confirmation. Same instance rules as `activity_logged`; `slot` plays `activity_key`'s role. Do not invent a second variant. Ambiguous match → ask once, do not write (same as gym logs).

- Run `Q_today_food` for that date (default today in `Europe/Stockholm`).
- New bout: `instance` = one more than today's max for that `slot` (start at 1).
- `nej` / `rättelse` keeps the latest `instance` for that slot.
- Named library item with no extra detail: copy `name` / `library_key` from `nutrition.library`, echo `(enligt vana)`. If that name matches more than one library item, ask once.
- Slot unclear (no meal time in the message, and the library item has more than one `slots` value, or none) → ask once. A clear slot in the message wins (`lunch var linsgryta` writes even when it is not in the library).
- `INSERT` `food_logged` (`source = user`, `source_status = confirmed`). Echo **Sparat:**. No second `godkänn`.
- Do not store kcal. Do not nag. Do not summarise remaining energy unless they asked (“vad åt jag idag?”).

```sql
insert into events (
  user_id, type, source, source_status, payload
) values (
  :USER_ID,
  'food_logged',
  'user',
  'confirmed',
  :payload::jsonb
);
```

If `INSERT` fails because `type` is not allowed (`food_logged` missing from `events_type_check`): say in Swedish that the live database is missing that event type. Do not tell them to rephrase. Do not run DDL. Do not write a substitute `type`.

### 5. Save a staple or recipe

When they want this suggestion (or a named meal) remembered, in this same turn:

1. Draft the merged `nutrition.library` array (`references/library.md`). Keep unrelated items.
2. Confirmation card: **Bekräftade förslag** / **Fortfarande okänt** / **Mina slutsatser**.
3. After `godkänn`: insert `profile_updated`, then `jsonb_set` `data.nutrition.library` (coalesce parent `nutrition` like onboarding does for habits). Provenance key `nutrition.library` for the whole array. If the array would be empty, omit the key — do not save `[]`.

```sql
update user_profiles
set
  data = jsonb_set(
    jsonb_set(
      data,
      '{nutrition}',
      coalesce(data->'nutrition', '{}'::jsonb)
    ),
    '{nutrition,library}',
    :library::jsonb
  ),
  provenance = jsonb_set(
    provenance,
    '{nutrition.library}',
    jsonb_build_object(
      'source', 'user',
      'status', 'confirmed',
      'confirmed_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'event_id', :event_id
    )
  )
where user_id = :USER_ID;
```

If the array would be empty: `data = data #- '{nutrition,library}'` and drop `nutrition.library` from provenance — do not save `[]`.

This is the same exception as `training-plan` writing `home_gym_substitutions`. Goal, allergies, and kitchen still go through `training-onboarding`. `target_kcal` after a follow-up card is §6.

If they also ate it today, log §4 in the same turn after the library write (or without it if they reject the save).

### 6. Follow-up (working target, not a lock)

How diet is going. Read training, optional meals, and weights. Draw conclusions. Do not nag for missing food logs.

1. Run `Q_profile`. Clinical flags → refuse a new `target_kcal`; do not change `safety_status`. `stop` or `unknown` → do not propose a new target from training load.
2. Run `Q_covering_plan`. No row → say so; you may still use `data.body` and `target_kcal`. Do not invent a training week.
3. If a covering row exists: `Q_week_events`, `Q_week_food`, `Q_week_weights`, `Q_habits` with that period.
4. Swedish card, three layers (`docs/provenance.md`):
   - **Fakta** — saved `target_kcal`; current `body.weight_kg`; current weigh-ins this week (latest per date); logged sessions/activity; logged meals (slots present, not kcal). Sparse food = unknown intake, not “they under-ate”.
   - **Fortfarande okänt** — no food logs, fewer than two weigh-ins, no training logs, hunger/energy they have not described.
   - **Mina slutsatser** — rules in `references/energy.md` (review). At most **one** proposed change (target ±100–200, more carbohydrate around hard sessions, or add a staple). Do not change several things at once.
5. If they `godkänn` a new `target_kcal`: insert `profile_updated`, then `jsonb_set` `nutrition.energy.target_kcal`. Same coalesce pattern as library. Do not write BMR/TDEE.

Do not write `recommendations`. Do not mix this into the training weekly overview (`training-log-and-review` §8).

### 7. Log a weigh-in

A clear line (`väger 88,6`, `88.6 kg idag`) is user confirmation. No second `godkänn`.

- Date = today in `Europe/Stockholm` unless they named a day.
- `INSERT` `body_weight_logged` (`source = user`, `source_status = confirmed`).
- Sync `data.body.weight_kg` with the coalesce-parent `jsonb_set` below (create `{body}` if missing). Provenance `body.weight_kg` with this event’s id. Do not insert a separate `profile_updated`.
- Echo **Sparat:** the kg. Do **not** rewrite `target_kcal`. Optionally one line: weight changed; say till if they want the target reviewed (§6).

```sql
insert into events (
  user_id, type, source, source_status, payload
) values (
  :USER_ID,
  'body_weight_logged',
  'user',
  'confirmed',
  :payload::jsonb
)
returning id;
```

Then:

```sql
update user_profiles
set
  data = jsonb_set(
    jsonb_set(
      data,
      '{body}',
      coalesce(data->'body', '{}'::jsonb)
    ),
    '{body,weight_kg}',
    to_jsonb(:weight_kg)
  ),
  provenance = jsonb_set(
    provenance,
    '{body.weight_kg}',
    jsonb_build_object(
      'source', 'user',
      'status', 'confirmed',
      'confirmed_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'event_id', :event_id
    )
  )
where user_id = :USER_ID;
```

If `INSERT` fails because the type is missing: say the live schema is missing `body_weight_logged`. Do not run DDL.

`nej` / `rättelse` → another `body_weight_logged` for that date; latest wins; same coalesce `jsonb_set` for `data.body.weight_kg`.

Changing goal, allergies, or kitchen is still `training-onboarding` §3d.

## Dialogue

Speak Swedish. Keep it short. Always label suggestions **Förslag**. Never present a meal as a saved fact unless it is in `nutrition.library` or they just logged it. Never present BMR/TDEE as confirmed.
