# Provenance

Three kinds of information exist. Mixing them is a defect.

| Kind | Where it may live | `source` / `source_status` |
| --- | --- | --- |
| Confirmed fact | `user_profiles.data`, `plans` after approval, events with `source_status = confirmed` | `user` + `confirmed` (or `system` + `confirmed` for generated ids/timestamps) |
| User observation | `events` only | `user` + `observation` |
| AI conclusion | Conversation, and later `recommendations.rationale` or events with `source_status = inference` | `ai` + `inference` |

## Rules

- If the user did not say it, it is not a confirmed fact.
- Do not copy inferences into `user_profiles.data`.
- `provenance` keys exist only for confirmed fields. Unconfirmed fields are omitted from both `data` and `provenance`.
- Every profile write must include matching `provenance` entries with `event_id` of the event just inserted.
- Label inferences in the Swedish reply, for example: "Min slutsats (inte sparad som faktum): …"

## Examples

Confirmed:

> Du har sagt att du kan träna fyra dagar i veckan. Det sparas som bekräftat.

Observation:

> Du nämnde att vänster knä känns stelt efter löpning. Jag loggar det som din observation, inte som en diagnos.

Inference (do not save as profile fact):

> Min slutsats (inte sparad som faktum): tre styrkepass och ett lugnt jogpass passar troligen bättre än fyra hårda pass.

## Event pairing

| Write | Required event |
| --- | --- |
| First confirmed profile | `safety_screening_completed` then `profile_confirmed` |
| Later confirmed profile edits | `profile_updated` (and `safety_screening_completed` if screening changed) |
| New plan after approval | `plan_proposed` then `plan_activated` |
| Replacing an active plan | `plan_superseded` on the old plan, then proposed + activated on the new |
| Exercise log or weight correction | `exercise_logged` (append; latest wins) |
| Finished or skipped session | `session_completed` or `session_missed` |

Insert events; never update or delete them.
