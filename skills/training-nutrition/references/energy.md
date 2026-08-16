# Energy

Compute in chat. Do not store BMR, TDEE, macros, MET, or a protein target on the profile. Store `nutrition.energy.target_kcal` only after `godkänn`, and only when the calorie-target minimum in `docs/data-contracts.md` is confirmed. Optional `kcal` / `protein_g` on `food_logged` are meal observations (`*_source` `user | estimated`), not a second target.

## Clinical flags (local)

Eating-disorder disclosure, a clinician-prescribed diet, or insulin-treated diabetes when they ask for a strict target: refuse this whole file. Tell them to seek care. Write nothing. Do **not** set `safety_status = stop` (`docs/safety.md`).

## Inputs (confirmed facts)

From `data.body`: `sex` (`male | female`), `birth_year`, `height_cm`, `weight_kg`.  
Age in whole years: current year in `Europe/Stockholm` minus `birth_year`.  
`nutrition.goal` shapes the proposed target. Logged training (`Q_today_logs`, `Q_today_activity`) shapes a same-day add-on as inference only.

## BMR (Mifflin–St Jeor)

Inference only.

- `male`: `10 * weight_kg + 6.25 * height_cm - 5 * age + 5`
- `female`: `10 * weight_kg + 6.25 * height_cm - 5 * age - 161`

Round to a whole number for display.

## TDEE

Inference only. `TDEE = BMR * PAL`.

PAL is everyday movement, **not** the gym:

- Light (~1.4): desk / sitting work, including gåband or easy walks in `lifestyle.habits`
- Moderate (~1.55): on-feet work most of the day

Do not multiply gym or quality running into PAL. Those are a separate same-day add-on below.

If everyday activity is unknown, use light and say so as a slutsats.

## Proposed `target_kcal`

Round TDEE to the nearest 50, then:

- `maintain` / `none` / `general_health` / `improve_performance`: that value
- `build_muscle`: +200 to +300
- `lose_weight`: −300 (max −500). Floor at BMR. Never a clinical deficit

One stored number: the daily target. Not a second training-day target. No extra tracking field.

How that integer is *spoken* (same value, no extra key):

- `improve_performance` / `build_muscle` / `general_health`: **sikta mot minst** that value — a floor to reach, not a budget to stay under
- `maintain` / `none`: a **riktmärke**, neither floor nor ceiling
- `lose_weight`: modest deficit as computed; never “minst”, never “kcal kvar” after a log

Missing `target_kcal`: slot/habit tracking still works. Offer onboarding for a target; do not block meal logs.

## Same-day training add-on (inference, not stored)

Use logged work, not `plans.content`:

- Logged hard gym or quality run: about +250–400 that day in the suggestion (more carbohydrate around the session)
- Easy gåband / yoga only, or rest with no logs: no add-on
- Two sessions the same day: mention eating between them (already in `volume-and-slots.md`; do not store kcal)

## Review against logs (working target)

`target_kcal` is not a lifetime lock. A real follow-up uses **what happened**, not the formula again as if it were new truth.

Signals (facts vs unknown vs slutsats):

- Training load this week from `Q_week_events` (logged sessions and activity, not `plans.content`)
- Meals from `Q_week_food`. Missing days are **unknown intake**, never a confirmed deficit. Sum `kcal` only on current meals that have the key; sum `protein_g` the same way. Two incomplete totals; a missing key is unknown, not 0. Do not fill gaps. Do not present the sums as the day’s intake.
- When they asked how they sit vs the target, or on this follow-up card: compare the incomplete kcal sum to `target_kcal` with the goal language above. Example: `Inloggat ~2350 av minst ~2600 (ofullständigt — lunch saknas)`. Never “du ligger under”. Never a remainder ticker after a meal log. `lose_weight` uses the same incomplete compare without “minst”.
- Weight from `Q_week_weights`: weekly mean of latest-per-date kg if at least two days exist; otherwise only current `data.body.weight_kg`. One point is not a trend
- Hunger, energy, recovery, performance: their words this turn, or notes they logged. Not a diagnosis

Propose at most one change after `godkänn`:

- Persistent hunger + hard training + stable or falling weight → consider +100–200 `target_kcal`, or more carbohydrate around logged hard sessions (suggestion tone, not a second stored target)
- Rising weekly mean without a goal of gain → consider −100–200, floor at BMR
- Recalculated TDEE after a new weight is a slutsats. It does not overwrite `target_kcal` until they approve

Do not change protein/fat working notes, library, and `target_kcal` in the same card. Stepwise.

## Confirmation card

**Bekräftade förslag** — `body.*` and proposed `target_kcal` if they are accepting it, phrased with the goal language above (`sikta mot minst 2600`, not only “dagligt mål 2600”)  
**Fortfarande okänt** — missing inputs  
**Mina slutsatser** — BMR, TDEE, PAL choice, protein guidance (~1.6–2.0 g/kg body weight), training-day add-on

After `godkänn`, write only approved body fields and `nutrition.energy.target_kcal`. Never write BMR/TDEE/protein into `user_profiles.data`.

## Stale target (intentional)

`target_kcal` becomes outdated if `body.weight_kg` is updated and the target is not confirmed again. That is the same non-auto-invalidation as `safety_status`. It is still **replaceable**: follow-up (§6) may propose a new number from logs.

Do not delete or silently rewrite `target_kcal`. Show that weight or the week changed, recompute as **Mina slutsatser**, wait for a new `godkänn` before writing a new target.

## Do not

- Print BMR/TDEE/macros on ordinary meal **Förslag** unless they asked about energy
- Store kcal or protein on `body_weight_logged`, `activity_logged`, `exercise_logged`, or `nutrition.library`. Optional `kcal` / `protein_g` belong only on `food_logged`
- Store `target_protein` or other macros on `user_profiles.data`
- Say “du har X kcal kvar” or remaining protein after a log. That remainder ticker is never the default. An incomplete sum vs `target_kcal` with goal language is allowed on follow-up or when they asked (“hur ligger jag mot målet”) — that is not a remainder ticker
- Treat a meal-kcal or protein sum as complete day intake, or missing meals as 0
- Use floor language (“minst”) for `lose_weight`, or deficit/budget language for `improve_performance` / `build_muscle` / `general_health`
