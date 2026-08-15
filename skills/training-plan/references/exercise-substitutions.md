# Exercise substitutions

Routine gym vs first-choice. No exercise catalog. ChatGPT picks **one** close equivalent.

`equipment.items` is too coarse for “the gym has no hip abductor”. Confirmed missing exercises live in `data.equipment.home_gym_substitutions`. The plan item shows what to do at the routine gym and keeps the first choice as `preferred` for another gym.

## Intent

Read the whole message and the conversation. **Meaning, not keywords.** Do not wait for a set phrase.

**Gym-unavailable** — they mean the routine gym cannot provide that exercise (missing machine, no cables, “här finns inte”, “mitt gym har den inte”, “går inte att köra på mitt vanliga ställe”). After `godkänn`: plan item **and** `home_gym_substitutions`. Keep the original as first choice.

**This-week swap** — they want a different exercise without saying the gym lacks it (variety, preference, “byt”, “kör Y istället”, “ge mig ett annat förslag”, “jag är less på X”). After `godkänn`: plan only. No `preferred`. No profile. Next week may program the original again.

**Gym has it now** — they mean the missing piece exists again. Onboarding removes that pair.

If the gym-missing meaning is not in the message or recent turns, treat it as a swap. Do not infer “saknas på gymmet” from a request for another exercise alone.

Ask **once** only when the meaning is actually unclear (“den funkar inte”, “kan inte köra den” — injury, dislike, or missing kit?). Do not ask after a clear swap or a clear “gymmet saknar den”.

Gym-unavailable is not a one-week situation. One confirmation card may authorize both the plan update and `profile_updated`.

## When drafting a week

Read `data.equipment.home_gym_substitutions` (may be absent).

- Pick first-choice exercises as usual (`equipment.location`, `items`, injuries, experience).
- If a first-choice matches a pair (`preferred_key` or `preferred_name`): prescribe `home_name` / `home_key` as `name` / `key`, and set `preferred` to the first choice. Do not ask again.
- Known pairs beat a new guess.
- If the stored home exercise is also missing, ask and propose a new pair.

## Gym-unavailable from a covering plan

1. Identify the planned item (today or the named day).
2. Propose **one** substitute using the rules below. Draft as **Förslag (sparas inte än)**.
3. On the card, state as confirmed proposals: X saknas på rutin-gymmet. Den här veckan (och framåt där) gör du Y. Förstahand X följer med till annat gym.
4. Wait for `godkänn` / `ja` / `spara`.
5. After approval:
   - `UPDATE plans.content`: that item’s `name` / `key` = Y, `preferred` = `{ name, key }` for X. Keep sets/reps/load unless the substitute cannot load the same way (then adjust and label as slutsats).
   - Merge the pair into `data.equipment.home_gym_substitutions`. Write the **full** array. Keep unrelated pairs. Provenance key `equipment.home_gym_substitutions`. Insert `profile_updated`.
6. Without approval: write nothing.
7. Tell them in Swedish what was saved (plan + gym-lista).

This-week swap: same draft/approval/`UPDATE` of `content`, but replace `name` only. Do not set `preferred` from this. Do not write the profile. Next week may program the original again.

## How to pick a substitute

1. Same movement pattern: squat, hinge, lunge, horizontal press, vertical press, horizontal pull, vertical pull, carry, core, isolation.
2. Same difficulty band (`experience.strength`). Do not replace back squat with pistol squat for a beginner.
3. Respect `equipment.items` and confirmed `health.injuries`.
4. Similar stability demand when possible (machine → another machine or dumbbell, not a sudden skill jump).
5. Keep sets/reps/RPE if the substitute can be loaded the same way. Otherwise adjust and label as slutsats.
6. One proposal, not a menu. Do not change modality (strength → running).
7. Reuse a stored pair for the same `preferred_key` without asking.

Do not store the pattern on the plan item (that is an inference).

## Display

Prescribed line first. First-choice only when `preferred` exists:

```
Sidogång med band  3×12–15  RPE 7  — lägg på X kg
Förstahand (annat gym): Höftabduktion maskin
```

Cue last working load for `name` (home) by default. If they log the preferred name, that log uses `preferred.key`.

## Logging

Match both `name` and `preferred.name` (`skills/training-log-and-review/references/parse-and-match.md`). Home name → home `key`. Preferred name → `preferred.key`. Separate histories on purpose.
