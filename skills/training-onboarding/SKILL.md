---
name: training-onboarding
description: Collect, confirm, and update the training user profile. Use when the user is new, profile fields are missing, they mention goals, experience, time, equipment, injuries, health, recovery, life constraints, two sessions in one day, training as a hobby, or recurring everyday movement / extra sports / yoga (walks, climbing, hiking, yoga habits), they say lägg till vana / ändra vana / ta bort vana, they add or remove routine-gym substitutions with no live session change, they say nu har gymmet X, they want to set up diet (jag vill sätta upp kosten), they mention body weight / height / calorie target, or they ask to update the profile. Do not use to create weekly plans, swap a planned exercise on an active week (that is training-plan, including gym-unavailable), log sessions or extra-plan activity instances, log meals or weigh-ins (training-nutrition), give meal suggestions, draft a weekly meal schema (training-nutrition), or list/fetch the food library (training-nutrition §8).
---

# training-onboarding

Collect profile data, run a safety screen, and write confirmed facts only after explicit approval.

## Do not

- Create or activate weekly training plans (hand off to `training-plan`) or weekly meal schemas (hand off to `training-nutrition`)
- Swap or substitute a **planned** exercise on an active week, including when they mean the gym cannot provide it (hand off to `training-plan`; that skill writes `home_gym_substitutions`)
- Invent meal plans, session logs, `activity_logged` rows, or `food_logged` rows (weekly meal schemas and meal instances belong in `training-nutrition`)
- List or fetch the food library (`mina recept`, `vanearkivet`, `hämta` a recipe) — that is `training-nutrition` §8
- Diagnose, or advise on medication
- Write `user_profiles.data` before the user approves the summary
- Replace all of `user_profiles.data` on a later save (`data = :data` drops unrelated keys)
- Store AI conclusions, BMR, TDEE, macros, or MET as profile facts. `nutrition.energy.target_kcal` may be stored only after `godkänn`
- Set `safety_status` from a nutrition disclosure (eating disorder, clinician-prescribed diet, insulin-treated diabetes). Those refuse a calorie-target write only; see `docs/safety.md`

## Intent

Classify once. Run only those ids from `skills/_shared/queries.md`. Writes stay in this skill.

| User means | Section | Queries | Skip |
| --- | --- | --- | --- |
| New user, missing profile, safety screening, “jag vill börja” | §1–5 | `Q_profile` | Plans, logs, last working, PR |
| Update a confirmed field (goals, time, equipment, injuries) | §1, then confirmation | `Q_profile` | Plan UPDATE, session logs |
| `lägg till vana` / `ändra vana` / `ta bort vana` | §3b | `Q_profile` | Covering-plan writes, `activity_logged` |
| Set up diet, body measures, calorie target, kitchen (including schema extras), change goal/allergies, `lägg till matvana` without a live suggestion | §3d | `Q_profile` | Meal suggestions, meal weeks, `food_logged` |
| List/fetch food library (`mina recept`, `vanearkivet`, `hämta` X) | hand off to `training-nutrition` §8 | — | writes here |
| Add/remove gym-substitution pairs with no live session, or “nu har gymmet X” | confirmation then profile write | `Q_profile` | `training-plan` session UPDATE |
| They want a week but minimum fields are missing | this skill first, then `training-plan` | `Q_profile` | Drafting a full week from guesses |

## Before you start

Classify intent first. Then read **only** the files that row needs. Do not open the others in this turn. Do not load a generic Supabase skill to run `Q_*`.

| Intent | Read now |
| --- | --- |
| New user, missing profile, safety screening, field updates, habits, gym substitutions | the list below |
| Set up diet §3d | `skills/_shared/queries.md`, `references/profile-fields.md`, `docs/autonomy.md`, `docs/provenance.md`. Also `skills/training-nutrition/references/energy.md` when proposing `target_kcal`. Do not open `training-nutrition/SKILL.md` or `meal-suggestions.md` |

Full list (new-user / general profile), if not already in context (repo paths; from this skill folder use `../../docs/`):

- `docs/safety.md`
- `docs/autonomy.md`
- `docs/provenance.md`
- `docs/data-contracts.md`
- `skills/_shared/queries.md`
- `references/profile-fields.md`

Use `USER_ID` from the Project instructions. Filter every query on that id.

## Procedure

### 1. Load current state

Run `Q_profile`. If no row, you will insert one only after the first approved confirmation.

Do not re-ask confirmed fields unless the user wants to change them. Ask only for gaps.

### 2. Safety screening first

If `safety_status` is `unknown` or missing, screen before anything else. Ask in Swedish, a few questions at a time, covering the items in `docs/safety.md`.

Map answers:

- Any stop flag → proposed `safety_status = stop`
- Pain/injury/condition that limits training but is not a stop → proposed `restricted`
- All screening answers negative → proposed `cleared`

If proposed status is `stop`, tell the user to seek care. You may still save a confirmed stop profile after approval. Do not hand off to `training-plan`.

### 3. Fill gaps progressively

Ask 2–4 questions per turn. Prefer this order after screening:

1. Primary goal and modalities they want in the week
2. Experience per selected modality (do not skip this)
3. Training **days** per week (not session count); which windows usually exist (lunch / evening / morning) and roughly how long; whether two sessions the same day is fine on *some* days (`two_a_day: some_days` if yes). Do not ask them to design the week or pick a gym+run quota
4. Location and equipment
5. Injuries/pain in their own words (observation + confirmed health lists)
6. Optional: sleep, stress, schedule, nutrition (`goal`, `dietary_pattern`, allergies, exclusions, preferences) if offered. If they confirmed high volume willingness or `two_a_day: some_days`, ask sleep/stress in this cluster (still optional to save)

If they say training is a hobby or they like training a lot, put that in `goals.notes` as their words. Do not invent elite volume tolerance.

When the minimum plan fields in `references/profile-fields.md` are ready, go to step 3b before the confirmation card. Sleep, stress, and nutrition stay optional. Habits are also optional to *save*, but the question in 3b is asked once. `windows`, `two_a_day`, and `anchor` are optional to save but should be asked in step 3 when those gaps exist. Full nutrition onboarding (body, energy target, library) is §3d — do not run it unless they offered nutrition or asked to set up diet.

### 3b. Habits (once, after the plan minimum)

If `lifestyle.habits` is not yet confirmed, ask once in Swedish:

> Gör du något regelbundet utöver träningspassen — vardagsmotion eller annat, till exempel gåband, promenad, yoga, klättring eller vandring?

- `nej` / `hoppa` / `sen` → omit `lifestyle.habits`. Do not save an empty array.
- If yes: ask what, which days, typical duration (and speed/distance only if they give it). A few questions, not a form.
- `kind`: `lifestyle` for easy everyday movement (gåband, commute walk) or easy mobility/yoga; `extra` for climbing, hiking, similar.
- `plan_inclusion`: default `background` for `lifestyle` (including yoga). For `extra` with named weekdays, ask whether it should sit in the weekly plan as a pass; suggest `scheduled`. For `extra` without days, default `background`.
- Propose the habit list on the confirmation card. Wait for `godkänn`.

`lägg till vana` / `ändra vana` / `ta bort vana` at any later time: load current `habits`, draft the merged list, confirm, then `profile_updated`. Keep unrelated habits. Provenance key is `lifestyle.habits` for the whole array.

A one-off without a pattern is not a habit — load `training-log-and-review` for that instance.

If they both confirm a habit and report doing it today, save the habit here, then log today's instance with `training-log-and-review`.

Tell them in Swedish that the vana is the pattern; each time they do it they still say so (e.g. `yoga`, `gåband 30 min`) so it can be logged. Do not claim they already did it.

### 3c. Routine-gym substitutions (optional, never a form)

Do not ask “vilka maskiner saknas?” during gap-fill.

If they volunteer that the routine gym lacks an exercise, and this is **not** a change to a planned item on an active week:

- Propose **one** home alternative (same rules as `skills/training-plan/references/exercise-substitutions.md`).
- Confirmation card: X saknas på rutin-gymmet; hemma-alternativ Y; förstahand X följer med till annat gym.
- After `godkänn`, write the full `equipment.home_gym_substitutions` array. Keep unrelated pairs. Provenance key is `equipment.home_gym_substitutions`.

If a covering plan for this week has that exercise, load `training-plan` instead so the session is updated in the same turn.

`nu har gymmet X` / remove a pair: drop that object from the array, confirm, then `profile_updated`. If the array would be empty, omit the key from `data` and drop `equipment.home_gym_substitutions` from `provenance`. Do not save `[]`.

Adding or removing pairs later: same as habits — full confirmed array, keep unrelated pairs.

### 3d. Nutrition profile (optional, startable anytime)

If they say `jag vill sätta upp kosten`, mention weight/height for calories, or offer a calorie target: run this cluster. 2–4 questions per turn. Do not block `training-plan`.

Clinical flags (eating-disorder disclosure, clinician-prescribed diet, insulin-treated diabetes when they ask for a strict target): observation in chat, tell them to seek care, **do not** change `safety_status`, **do not** calculate or write `target_kcal`. Other nutrition fields they still confirm may be saved. Same as a food reaction.

Ask, in this order, only for gaps:

1. `nutrition.goal` if missing (closed enum in `references/profile-fields.md`)
2. `dietary_pattern`, allergies, exclusions, preferences. Confirmed no allergies → save `allergies: []` with provenance
3. `body.sex`, `body.birth_year`, `body.height_cm`, `body.weight_kg`
4. Optional `nutrition.kitchen`: which meals they actually eat, weekday `time_min`, `skill` (`beginner | intermediate | advanced`). If they want a weekly meal schema (or those gaps exist before a schema draft): also `time_min_weekend`, `servings`, `lunch_source` (`home | packed | work | mixed`), `leftovers` (`often | sometimes | never`), `eat_out_notes`. Label these as **profilfakta** on the confirmation card. This-week context (resa, skift, barn, hur styrt just den här veckan, tillfällig köksbegränsning) is **not** saved — say so and hand that to `training-nutrition` for the draft. Do not invent a kitchen equipment field; a one-off appliance note is draft context. If they then want the week itself, load `training-nutrition` after this write
5. Library once: *Vad äter du ofta till lunch eller middag?* Same spirit as §3b. `nej` / `hoppa` → omit `nutrition.library`. Do not save `[]`
6. If the calorie-target minimum in `references/profile-fields.md` is present and no clinical flag: load `skills/training-nutrition/references/energy.md`, compute BMR/TDEE as **Mina slutsatser**, propose `target_kcal` on the confirmation card with that file’s goal language (`sikta mot minst X` for `improve_performance` / `build_muscle` / `general_health`; riktmärke for `maintain` / `none`; modest deficit for `lose_weight` — not only “dagligt mål X”). Wait for `godkänn`. Never write BMR/TDEE

`lägg till matvana` / `spara receptet` / `ta bort` a library item with no live meal suggestion: load current `nutrition.library`, draft the merged list, confirm, then `profile_updated`. Keep unrelated items. Provenance key is `nutrition.library` for the whole array. If they are in a meal-suggestion turn, `training-nutrition` may write the library instead. Listing or fetching saved items without changing them is `training-nutrition` §8, not this section.

Updating `body.weight_kg`: if they report a weigh-in (`väger 88,6`), `training-nutrition` §7 logs `body_weight_logged` and syncs the profile. If they change weight as a profile edit here, write the new weight after approval **and** insert `body_weight_logged` for that date so history stays complete. Recalculate and **propose** a new `target_kcal`; do not overwrite the old target without a new `godkänn` (`energy.md` stale rule). `justera kalorimål` / follow-up against this week’s training and food is `training-nutrition` §6.

If they both confirm a staple and report eating it today, save the library here, then log today's instance with `training-nutrition`.

### 4. Show a confirmation card

In Swedish, clearly labelled:

**Bekräftade förslag** — will be saved as profile facts. If the card includes proposed `nutrition.energy.target_kcal`, phrase it with `energy.md` goal language (`sikta mot minst X` / riktmärke / modest deficit — not only “dagligt mål X”). Kitchen extras (`servings`, `lunch_source`, `leftovers`, `time_min_weekend`, `eat_out_notes`) belong here when they confirmed them.  
**Fortfarande okänt** — will not be saved. Include this-week-only context (resa, skift, hur styrt just den här veckan) so it is clear it is not a profile fact.  
**Mina slutsatser** — not saved as facts

Wait for explicit approval (`ja`, `stämmer`, `godkänn`, `spara`). If they edit, revise the card and wait again.

### 5. Write after approval

Generate event ids in SQL with `gen_random_uuid()` or insert events first and reuse their ids in `provenance`.

**First save (no row yet):**

Insert `events` for `safety_screening_completed` (`source = user`, `source_status = confirmed`) and `profile_confirmed`.

Then insert `user_profiles` with:

- `onboarding_status = complete` if minimum plan fields are confirmed, else `in_progress`
- confirmed `safety_status`
- `data` containing only confirmed fields
- `provenance` for each confirmed path, including `safety_status`

**Later save (row exists):**

Insert `profile_updated` (and `safety_screening_completed` if screening changed). Update `user_profiles` by merging new confirmed keys into `data` and `provenance`. Never `data = :data` — that drops unrelated keys. Never delete unrelated confirmed keys unless the user asked to remove them. For `lifestyle.habits`, `equipment.home_gym_substitutions`, and `nutrition.library`, write the full confirmed array (add, change, or remove items they approved).

Do not UPDATE `events`.

### 6. After the write

Tell the user in Swedish what was saved. If `safety_status` is `stop`, stop. If minimum plan fields are present and they want a week, load `skills/training-plan/SKILL.md`.

## SQL sketches

Insert screening event:

```sql
insert into events (
  id, user_id, type, source, source_status, payload
) values (
  gen_random_uuid(),
  :USER_ID,
  'safety_screening_completed',
  'user',
  'confirmed',
  :payload::jsonb
)
returning id;
```

Insert profile (first time):

```sql
insert into user_profiles (
  user_id, onboarding_status, safety_status, data, provenance
) values (
  :USER_ID,
  :onboarding_status,
  :safety_status,
  :data::jsonb,
  :provenance::jsonb
);
```

Later save (row exists): insert `profile_updated` first (`returning id`), then merge. Never `set data = :data`. If `lifestyle` is missing, the nested `jsonb_set` below creates it.

```sql
update user_profiles
set
  data = jsonb_set(
    jsonb_set(
      data,
      '{lifestyle}',
      coalesce(data->'lifestyle', '{}'::jsonb)
    ),
    '{lifestyle,habits}',
    :habits::jsonb
  ),
  provenance = jsonb_set(
    provenance,
    '{lifestyle.habits}',
    jsonb_build_object(
      'source', 'user',
      'status', 'confirmed',
      'confirmed_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
      'event_id', :event_id
    )
  )
where user_id = :USER_ID;
```

A single top-level key (example `modalities`): `data = jsonb_set(data, '{modalities}', :modalities::jsonb)`. Same `jsonb_set` pattern as `equipment.home_gym_substitutions` in `training-plan`. If the substitutions array would be empty, `data = data #- '{equipment,home_gym_substitutions}'` and drop that provenance key — do not save `[]`. Nested nutrition keys (`energy`, `kitchen`, `library`) use the same `jsonb_set` + coalesce parent object pattern as `lifestyle.habits` above. Body fields: `jsonb_set` on `{body}` then the field, or merge the whole `body` object they approved.

## Dialogue

Speak Swedish. Be brief. One cluster of questions per turn. Never claim medical clearance. Do not design the weekly plan here — collect capacity, then hand off to `training-plan`.
