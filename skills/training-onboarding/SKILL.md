---
name: training-onboarding
description: Collect, confirm, and update the training user profile. Use when the user is new, profile fields are missing, they mention goals, experience, time, equipment, injuries, health, recovery, or life constraints, or they ask to update the profile. Do not use to create weekly plans, log sessions, or give meal plans.
---

# training-onboarding

Collect profile data, run a safety screen, and write confirmed facts only after explicit approval.

## Do not

- Create or activate weekly plans (hand off to `training-plan`)
- Invent meal plans or session logs
- Diagnose, or advise on medication
- Write `user_profiles.data` before the user approves the summary
- Store AI conclusions as profile facts

## Before you start

Read, in this order if not already in context (repo paths; from this skill folder use `../../docs/`):

- `docs/safety.md`
- `docs/autonomy.md`
- `docs/provenance.md`
- `docs/data-contracts.md`
- `references/profile-fields.md`

Use `USER_ID` from the Project instructions. Filter every query on that id.

## Procedure

### 1. Load current state

```sql
select id, user_id, locale, timezone, week_start,
       onboarding_status, safety_status, data, provenance
from user_profiles
where user_id = :USER_ID;
```

If no row, you will insert one only after the first approved confirmation.

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
2. Experience per selected modality
3. Days per week, preferred days, minutes per session
4. Location and equipment
5. Injuries/pain in their own words (observation + confirmed health lists)
6. Optional: sleep, stress, schedule, nutrition preferences (allergies/exclusions only)

Stop when the minimum plan fields in `references/profile-fields.md` are ready, unless the user wants to continue.

### 4. Show a confirmation card

In Swedish, clearly labelled:

**Bekräftade förslag** — will be saved  
**Fortfarande okänt** — will not be saved  
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

Insert `profile_updated` (and `safety_screening_completed` if screening changed). Update `user_profiles` by merging new confirmed keys into `data` and `provenance`. Never delete unrelated confirmed keys unless the user asked to remove them.

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

## Dialogue

Speak Swedish. Be brief. One cluster of questions per turn. Never claim medical clearance.
