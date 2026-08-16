# Provenance

Three kinds of information exist. Mixing them is a defect.

| Kind | Where it may live | `source` / `source_status` |
| --- | --- | --- |
| Confirmed fact | `user_profiles.data`, `plans` after approval, events with `source_status = confirmed` | `user` + `confirmed` (or `system` + `confirmed` for generated ids/timestamps) |
| User observation | `events` only | `user` + `observation` |
| AI conclusion | Conversation, and later `recommendations.rationale` or events with `source_status = inference` | `ai` + `inference` |

## Rules

- If the user did not say it, it is not a confirmed fact.
- Copied last working loads (`logga gympasset`) become `confirmed` only after they approve the shortcut card (`godkänn`). Until then they stay in the conversation.
- Do not copy inferences into `user_profiles.data`.
- `provenance` keys exist only for confirmed fields. Unconfirmed fields are omitted from both `data` and `provenance`.
- Every profile write must include matching `provenance` entries with `event_id` of the event just inserted.
- Label inferences in the Swedish reply, for example: "Min slutsats (inte sparad som faktum): …"

## Examples

Confirmed:

> Du har sagt att du kan träna fyra dagar i veckan. Det sparas som bekräftat.

> Du har sagt att höftabduktion inte finns på rutin-gymmet. Det sparas som `equipment.home_gym_substitutions`, med sidogång med band som hemma-alternativ. Förstahandsvalet följer med på övningen, inte som en andra gym-profil.

A this-week exercise swap (variety or preference, not “the gym cannot provide this”) is a plan change only. Do not copy it into `home_gym_substitutions`.

Observation:

> Du nämnde att vänster knä känns stelt efter löpning. Jag loggar det som din observation, inte som en diagnos.

Inference (do not save as profile fact):

> Min slutsats (inte sparad som faktum): tre styrkepass och ett lugnt jogpass passar troligen bättre än fyra hårda pass.

> Min slutsats (inte sparad som faktum): BMR och TDEE från bekräftad kropp. Kalorimålet sparas bara efter `godkänn`. Ny vikt skriver inte över målet av sig själv.

## Event pairing

| Write | Required event |
| --- | --- |
| First confirmed profile | `safety_screening_completed` then `profile_confirmed` |
| Later confirmed profile edits | `profile_updated` (and `safety_screening_completed` if screening changed) |
| New plan after approval (same week / starts today or earlier) | `plan_proposed` then `plan_activated` |
| Replacing an active plan (same week) | `plan_superseded` on the old plan, then proposed + activated on the new |
| Future week after approval (`period_start` after today) | `plan_proposed` only; current `active` week stays. Activate later via lazy activate |
| Replacing a queued future `proposed` week | `plan_superseded` on that proposed row, then `plan_proposed` on the new (still not `active`) |
| Exercise log or weight correction | `exercise_logged` (append; latest wins; PR uses current rows only) |
| Extra-plan activity or a correction of it | `activity_logged` (append; latest per date + `activity_key` + `instance` wins; new bout vs correction per log-schema) |
| Meal log or a correction of it | `food_logged` (append; same instance rules as `activity_logged`; `slot` in place of `activity_key`) |
| Body-weight log or a correction of it | `body_weight_logged` (append; latest per date wins; syncs `data.body.weight_kg`) |
| Finished or skipped session | `session_completed` or `session_missed` |

Insert events; never update or delete them.
