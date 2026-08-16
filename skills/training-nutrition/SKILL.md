---
name: training-nutrition
description: Give meal suggestions from confirmed nutrition preferences, the
  food/recipe library, and recent training. Use when the user asks what to eat,
  wants lunch/dinner/evening ideas, asks how to fuel a session or recover from
  one, reports a meal they ate (optional kcal and protein on that log), asks
  what they ate today, logs a
  body weight, wants to save a recipe or
  food staple from a suggestion, asks how diet is going or how they sit versus
  the calorie target, wants the calorie
  target reviewed against training and food, mentions a food reaction, asks
  about saved nutrition preferences, or wants to list or fetch saved recipes
  and food staples (mina recept, vanearkivet, hämta keso pita). Meal log /
  weigh-in / saved prefs / vanearkivet browse follow the nutrition fast path
  (queries.md only, plus §8 for vanearkivet presentation) when there is no
  suggestion, follow-up, or “vad åt jag idag?” list. Match intent,
  not exact wording. Do not use to collect the first
  nutrition profile (training-onboarding), create or change weekly training
  plans (training-plan), log exercises or extra-plan activity, or give a
  weekly training overview (training-log-and-review). Do not diagnose
  conditions or give clinical diets.
---

# training-nutrition

Give meal suggestions in chat. Log meals and weigh-ins they report. Optional `kcal` and `protein_g` on the meal (stated or estimated). Review diet against training and food. Save library items and an adjusted `target_kcal` after approval.

## Do not

- Collect the **first** nutrition profile (`body.*` other than a weigh-in, `nutrition.goal` / pattern / allergies / exclusions / preferences, `nutrition.kitchen`) — hand off to `training-onboarding`
- Auto-rewrite `target_kcal` from a formula, a new weight, or a single log. Propose, wait for `godkänn`, then write
- Create or change weekly training plans — hand off to `training-plan`
- Log exercises, sessions, or extra-plan activity — hand off to `training-log-and-review`
- Open `training-plan`, `training-log-and-review`, or their `references/`. Training load is listed `Q_*` only (`Q_covering_plan`, `Q_today_logs`, `Q_today_activity`, `Q_week_events`). Never `Q_pr`, `Q_last_working`, `Q_recent_working`, `Q_lazy_activate_candidate`
- Diagnose a food reaction, allergy, or condition; give clinical or medically restrictive diets
- Store BMR, TDEE, macros, or MET on the profile, library, gym logs, activity, or weigh-ins. Optional `kcal` / `protein_g` belong only on `food_logged`. No `target_protein`
- Write `kcal` or `protein_g` on `exercise_logged`, `activity_logged`, `body_weight_logged`, or `nutrition.library`
- Write `recommendations` or `plans`
- Change `safety_status` for a nutrition disclosure
- Give a tailored suggestion if `safety_status` is `stop` or `unknown` (ordinary generic food is allowed when `stop` so they can eat; do not use training logs or a calorie target)
- Nag them to log meals or weigh-ins. Do not say remaining kcal or remaining protein after a log

## Intent

Classify once. Run only those ids from `skills/_shared/queries.md`. Match meaning, not a phrase list. Examples in the table are illustrations (`väger 88,6`, `åt X`, `hur går kosten`) — same as gym logging.

| User means | Section | Queries | Skip |
| --- | --- | --- | --- |
| Meal/snack suggestion, “vad ska jag äta”, lunch+middag+kväll, fuel/recover from a session | §2 | `Q_profile`, `Q_covering_plan`, `Q_today_logs`, `Q_today_activity`, `Q_today_food` | `Q_pr` |
| Nutrition tied to the whole week | §2 (week variant) | Same as a day, plus `Q_week_events`, `Q_week_food`, `Q_habits` | `Q_pr`, `Q_recent_working` |
| How diet is going / justera kalorier / hur ligger jag mot målet / följ upp mot träning och mat | §6 | `Q_profile`, `Q_covering_plan`, `Q_week_events`, `Q_week_food`, `Q_week_weights`, `Q_habits` | `Q_pr`, plan writes |
| Reported a meal (“åt X”, “vanlig lunch”) | §4 | `Q_profile`, `Q_today_food` | plan writes; remainder ticker |
| “Vad åt jag idag?” (list, no new log) | §4 (list) | `Q_profile`, `Q_today_food` | remainder vs target unless they asked; `energy.md` |
| Weigh-in (“väger 88,6”, “ny vikt”) | §7 | `Q_profile` | auto-changing `target_kcal` |
| Save this suggestion as a staple/recipe | §5 | `Q_profile` | `food_logged` unless they also ate it |
| List vanearkivet / mina recept / matvanor, or fetch one (name or number) | §8 | `Q_profile` | meal suggestion, constitution, `food_logged` |
| Reported food reaction / new allergy | §3 | `Q_profile` | writing it here |
| “What preferences do you have saved?” / calorie target | §1 | `Q_profile` | others, including dumping full recipes (that is §8) |
| First-time diet setup, change goal/allergies/kitchen | hand off to `training-onboarding` §3d | `Q_profile` if already loaded | writes here |

## Before you start

Classify intent first. Then read **only** the files that row needs. Do not open the others in this turn. Do not load a generic Supabase skill to run `Q_*`. Do not open `docs/safety.md` or `docs/data-contracts.md` (safety gate and SQL shapes are in this file). A log / weigh-in / prefs / vanearkivet lookup that already followed the project-instruction fast path should not re-open this skill’s references.

**Level A — log or suggest** (no constitution docs):

| Intent | Read now |
| --- | --- |
| Saved prefs / calorie target (§1) | `skills/_shared/queries.md` |
| Vanearkivet list or fetch one (§8) | `queries.md` |
| Meal/snack suggestion (§2) | `queries.md`, `references/meal-suggestions.md`, `references/library.md`. Also `references/energy.md` only if they asked about amount/energy |
| Food reaction / new allergy (§3) | `queries.md` |
| Reported a meal (§4) | `queries.md` |
| Today’s meals list (§4) | `queries.md` |
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

Do not dump `nutrition.library` ingredients or methods here. If the library exists: one line with counts (`N recept`, `M vanor`) and that `mina recept` shows the index. Missing library: say the vanearkivet is empty. Listing or fetching items is §8.

If they ask what their calorie target is: print confirmed `nutrition.energy.target_kcal` if present, and that it is a working number they can change. Phrase it from confirmed `nutrition.goal` without opening `references/energy.md`: `improve_performance` / `build_muscle` / `general_health` → **sikta mot minst** {n}; `maintain` / `none` → **riktmärke** {n}; `lose_weight` → {n} (blygsamt underskott, never “minst”); missing goal → the integer only. If they want BMR/TDEE or a review against this week’s training and food, go to §6.

Clinical flags in this conversation (eating-disorder disclosure, clinician-prescribed diet, insulin-treated diabetes when they ask for a strict target): refuse energy calculation and any `target_kcal` write. Tell them to seek care. Do not change `safety_status`. Other suggestions may continue without numbers.

### 2. Meal or snack suggestion

Run `Q_profile`. Safety gate:

- `stop` → tell them to seek care. Do not give a tailored suggestion. Ordinary generic food is allowed so they can eat. Do not use today’s training logs or `target_kcal`. Do not suggest food as training fuel.
- `unknown` → route to `training-onboarding` for screening first. Generic only. Do not tailor.
- `cleared` or `restricted` → continue. If `restricted`, stay conservative.

Missing `nutrition.*` → a generic suggestion is fine. Offer the onboarding handoff for a tailored one. Missing library is fine: invent 1–3 **Förslag**.

Then run `Q_covering_plan`, `Q_today_logs`, `Q_today_activity`, and `Q_today_food` (date = today in `Europe/Stockholm` unless they named a day). For a week-level ask, also `Q_week_events`, `Q_week_food` (`:period_start` / `:period_end` from the covering row), and `Q_habits`.

Use what actually happened (`exercise_logged`, `activity_logged`, `session_completed`), not the aspirational plan. Prefer confirmed `nutrition.library` items whose `slots` match the ask. Skip a slot that already has a current `food_logged`. Compose 1–3 Swedish options. Rules in `references/meal-suggestions.md` and `references/library.md`.

`lose_weight` with a saved `target_kcal` may shape portions as a modest deficit (see `energy.md`); never a clinical restriction. `improve_performance` / `build_muscle` / `general_health` may mention eating enough (floor) only if they asked about energy — never deficit or “kcal kvar”. Mention `target_kcal` only if it is saved **and** they asked about amount/energy — not on every dinner tip.

Label the reply **Förslag**. Offer once: spara som recept / lägg i vanearkivet. Nothing is a saved meal plan.

“Ge mig lunch, middag och kväll” = three slot suggestions in one turn, vary library items, fill gaps with new **Förslag**.

### 3. Food reaction or new allergy

Note it as their observation, not a diagnosis. If they want it remembered, hand off to `training-onboarding` to confirm into `nutrition.allergies` or `nutrition.exclusions`. Write nothing here.

### 4. Log a meal

A clear line (`åt kycklingris till middag`, `vanlig lunch`) is user confirmation. Same instance rules as `activity_logged`; `slot` plays `activity_key`'s role. Do not invent a second variant. Ambiguous match → ask once, do not write (same as gym logs). Ask once only for slot, name clash, or bare `nej` after an estimated echo — never “och kalorier?”.

- Run `Q_today_food` for that date (default today in `Europe/Stockholm`).
- New bout: `instance` = one more than today's max for that `slot` (start at 1).
- `nej` / `rättelse` keeps the latest `instance` for that slot.
- Named library item with no extra detail: copy `name` / `library_key` from `nutrition.library`, echo `(enligt vana)`. If that name matches more than one library item, ask once.
- Slot unclear (no meal time in the message, and the library item has more than one `slots` value, or none) → ask once. A clear slot in the message wins (`lunch var linsgryta` writes even when it is not in the library).
- A bare day total without a slot (`åt 2400 kcal idag`) is not a day-level event. Ask once which meal.
- Optional numbers on this payload only: `kcal` + `kcal_source`, `protein_g` + `protein_source` (`user | estimated`). Independent omit — if a number is absent, omit both keys for that number. Not `null`, not `0` as unknown. Do not write carbs, fat, or these keys on gym logs or the library. Portion estimate is food knowledge here; do not open `energy.md`.
- Numbers they stated: store as said, `*_source = user`. Do **not** invent the other number.
- Concrete vs unclear (no numbers). **Estimate both** only when you can name the dish or its main foods without inventing a recipe: library match (`enligt vana`); a named composed dish (kycklingris, keso pita); a stated portion of a known food (200 g kyckling). Round kcal to 50, `protein_g` to 5. `*_source = estimated`. **Omit both** when contents or portion are unknown: rester, något, snacks, “åt lunch” with no dish; an unspecified mix (`drack en smoothie`, en bar, bowl, wrap, något från ICA) unless they named ingredients or it matches the library. If unsure, omit. Do not ask whether to estimate.
- `INSERT` `food_logged` (`source = user`, `source_status = confirmed`). Echo **Sparat:** one line. No second `godkänn`. Never “protein saknas”.
  - Both stated: `Sparat: Middag — kycklingris, 650 kcal, 45 g protein.`
  - Both estimated: `Sparat: Middag — kycklingris, ~650 kcal, ~45 g protein (uppskattat).`
  - Only one stated: that number only, no guessed pair.
  - No numbers: meal name only (`Sparat: Lunch — rester.`).
- After an `(uppskattat)` echo, `nej` is ambiguous (numbers vs whole meal). Do not write until it is clear:
  - `nej till siffrorna` / `utan uppskattningen` / `skippa kcal` → new row, same instance, **without** the number keys (meal stays).
  - `nej, 40 g protein` (or another stated number) → that key `user`; leave other numbers as they were.
  - `nej, det var X` / a different dish → whole-meal correction, same instance (existing rule). Re-apply concrete vs unclear on the new dish.
  - Bare `nej` / `rättelse` → ask once: siffrorna eller hela måltiden? Then write.
- Without an estimate, `nej` / `rättelse` is a correction of the whole meal (existing rule).
- Do not nag. Do not say remaining kcal or remaining protein after this echo. No ticker on **Sparat:**.
- “Vad åt jag idag?” (list, no new log this turn): current meals (slot, name; numbers only if already on the row; `(enligt vana)` if `library_key`). Then one line vs confirmed `nutrition.kitchen.meals` when that array exists. Swedish slot labels as §8. Several snack instances: `N mellanmål`. Kitchen slots with no current row: `{slot} saknas`. Example: `Idag: frukost, middag, kväll, 3 mellanmål. Lunch saknas.` No valuation. No kcal comparison. Missing `kitchen.meals`: list logged slots only; do not invent expected meals. Empty day: say no meals logged; do not nag. Remainder vs `target_kcal` only if they also asked about amount or how they sit vs the target — that is §6, not this list.

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
   - **Fakta** — saved `target_kcal` phrased with `nutrition.goal` (floor / riktmärke / modest deficit — `energy.md`); current `body.weight_kg`; current weigh-ins this week (latest per date); logged sessions/activity; logged meals (slots) plus one slot line vs `kitchen.meals` when present (same as §4 list). Two incomplete sums over **current** meals: `kcal` where the key exists, `protein_g` where the key exists. Gaps counted separately. A missing key is unknown, not 0. Sparse food = unknown intake, not “they under-ate”. Compare the incomplete kcal sum to `target_kcal` with that goal language (`Inloggat ~2350 av minst ~2600 (ofullständigt — lunch saknas)`). Never “du ligger under”. Never “kcal kvar”.
   - **Fortfarande okänt** — no food logs, meals without numbers, fewer than two weigh-ins, no training logs, hunger/energy they have not described.
   - **Mina slutsatser** — rules in `references/energy.md` (review). Protein vs ~1.6–2.0 g/kg only here, never a stored target. After hard gym: more protein around the session as a suggestion, not “du ligger under”. At most **one** proposed change (target ±100–200, more carbohydrate around logged hard sessions, or add a staple). Do not change several things at once.
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

### 8. Vanearkivet (browse)

Read-only index, then one full card. Run `Q_profile`. Do not write. Do not open `meal-suggestions.md`, `energy.md`, or constitution docs. Adding, changing, or removing items is `training-onboarding` §3d (or §5 in a suggestion turn). “vad ska jag äta” is §2, not this section.

Missing `nutrition.library` → say the vanearkivet is empty. Do not invent items. Offer once to add.

Chat history may hint at a filter or a number. The live array is the source. Re-sort every turn.

**Stable sort** (after the filter below): `kind = recipe` first, then `kind = staple` (missing `kind` counts as staple). Within a group, `name` ascending, `sv-SE`, case-insensitive. Number `1…n` across that filtered list.

**Filter** (meaning, not a phrase list). Apply before numbering:

- Whole archive (`vanearkivet`, “vad har jag sparat för mat”, lista without a kind) → no kind/slot filter
- Recept only (`mina recept`, `lista recept`) → `kind = recipe`. If they clearly mean the whole archive, do not filter by kind
- Vanor only (`matvanor`, vanor i köket) → `kind = staple`
- Slot (`recept till lunch`, middag, frukost, kväll, mellanmål) → `slots` contains that value. Missing `slots` → drop from a slot filter
- Kind + slot (`recept till lunch`) → combine both filters (AND)
- Name fragment (`bröd`, `pita`) → `name` or `key` contains it (case-insensitive). One match and they asked to fetch → full card. Several → index of those matches. None → say unknown; show the unfiltered index once

If a filter yields nothing: say so, then the unfiltered index. Label a filtered index **Vanearkivet · {filter}** and number only that set.

**Index vs fetch.** Match meaning:

- List → index card only. No ingredients, no method
- Fetch (`hämta`, `receptet på X`, `visa X`, a number, `hela receptet`) → one full card
- A number uses this turn’s sort. If they are clearly continuing a filtered index from this chat, keep that filter; otherwise unfiltered. Out of range → say so and show that same index
- Bare name: fetch if they meant the recipe (browse context, or `recept`). Log §4 if they meant they ate it (`åt`, a slot). Ask once if unclear
- Several name matches → ask which one. Do not print two full cards

**Index card** — label **Vanearkivet**. Omit an empty group heading.

```text
**Vanearkivet** (N)

**Recept**
1. {name} — {slots sv} · {time_min} min
2. …

**Vanor**
3. {name} — {slots sv}

Säg ett nummer eller namn för hela receptet.
```

Slot labels: `breakfast` frukost, `lunch` lunch, `dinner` middag, `evening` kväll, `snack` mellanmål. Show `time_min` only when present. Do not print `key`, kcal, or `notes` on the index.

**Full card** — one item. Label **Sparat recept** (`kind = recipe`) or **Sparad vana** (`staple`).

- Recipe: name; servings if set; slots; `time_min` if set; ingredients as a list (`amount` `unit` `name`); `method`; `notes` under **Tips** (not facts)
- Staple: name; slots; `notes` if any
- No JSON, no `key` unless they asked, no kcal/macros/protein. Those stay **Mina slutsatser** only if they asked
- Do not list the rest of the archive. One line: `Övriga: säg mina recept` (recipe) or `Övriga: säg matvanor` (staple)

## Dialogue

Speak Swedish. Keep it short. Always label suggestions **Förslag**. Label the archive **Vanearkivet**, a fetched recipe **Sparat recept**, a fetched staple **Sparad vana**. Never present a meal as a saved fact unless it is in `nutrition.library` or they just logged it. Never present BMR/TDEE as confirmed.
