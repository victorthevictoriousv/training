# Parse and match

Match intent. Do not require these exact strings.

## Parse (Swedish gym order)

Treat `x` and `×` the same. Ignore `kg` as a unit token.

| Input | Meaning |
| --- | --- |
| `bänk 80x5` | 1 set, 80 kg, 5 reps |
| `bänk 80kg 4x8` | 4 sets of 8 at 80 kg |
| `bänk 4x8 @ 80` | same |
| `pullups 12kg 6,6,5,5` | 4 sets, 12 kg, those reps |
| `bänk 80x5, 80x5, 82.5x4` | 3 sets, listed loads/reps |
| `bänk 82.5` | correction: all working sets today at 82.5 kg, keep last known reps if any, else ask reps only if never logged |
| `jogg 32 min` | running, `duration_min` 32, `load_kg` null |
| `10 km 52 min` | running, `distance_km` 10, `duration_min` 52 |
| `farmer 40 kg 40s` | timed, `reps` null, `duration_min` ~0.7 or `load_text` `40 s` |

If RPE is present (`RPE 8`, `@8`), store it on those sets.

**Reps are a single integer per set.** Never store `8–10`, `6-10`, or `reps_text`. If they only repeat the planned range, save the **low end** (8 from 8–10, 6 from 6–10) on each set and echo `Sparat som 8 reps (lägsta i intervallet)`. Prefer per-set lists when they give them (`9,8,8`).

**Dumbbells:** `load_kg` is per dumbbell. `load_text` must include `/hantel` (or `/sida` for one-arm / pallof / lunges when that is how it was loaded).

Log all working sets they did. Do not collapse `4x8` into one set of 8.

If two parses are possible, ask.

## Match to today's plan

Normalize: lowercase, strip diacritics, treat `-` and spaces as nothing (`pull-up` = `pullup` = `pullups`).

1. Prefer a unique planned item for that date. Match `name`, aliases, **or** `preferred.name` / `preferred.key` when present.
2. If several items match, ask.
3. If none match but the name is a clear exercise, log it anyway with a slug from the user text. `session_id` is **null** even if the day has exactly one planned session of another kind (do not attach extra goblet to evening intervals). `plan_id` is the covering plan for that date when one exists. Do not write `session_completed`.

When matched:

- Log against the prescribed `name` (routine gym) → `exercise_key` = item `key` if set, else slug from `name`. `exercise_name` = `name`.
- Log against the first-choice (`preferred.name` or an alias of it) → `exercise_key` = `preferred.key`. `exercise_name` = `preferred.name`. Separate history from the home exercise, on purpose.

Cue last working load for the key you are about to log. Default cue when showing the session is the prescribed (home) key.

## Aliases → typical keys

Use the planned `name` as `exercise_name` when matched to the prescribed line. Use `preferred.name` when they logged the first-choice. Keys are hints:

- `bänk`, `bänkpress`, `hantelbänk`, `db bench` → dumbbell bench / bench press item
- `knäböj`, `goblet`, `squat` → squat item
- `mark`, `rdl`, `rumänsk` → RDL / deadlift item
- `chins`, `pullup`, `pullups`, `latsdrag` → pull-up item
- `rodd`, `row` → row item (ask if two rows)
- `lunge`, `utfall` → lunge item
- `pallof` → pallof
- `hang`, `dead hang` → dead hang
- `jogg`, `löpning`, `easy run` → running item that day

## Extra-plan activity (not a gym exercise log)

Background walks and one-off recreation are `activity_logged`, never `exercise_logged`.

If today's plan has a session with matching `habit_key` (scheduled climbing/hiking), it is that pass: `activity_logged` with `plan_id`/`session_id` plus `session_completed`.

| Input | Meaning |
| --- | --- |
| `gick 30 min` | walk, `duration_min` 30, `kind` lifestyle, `intensity` easy |
| `gåband` | treadmill, one new instance; fill `typical_duration_min` / `typical_speed_kmh` from the habit; echo `(enligt vana)` |
| `gåband 30 min 4,5` / `gåband 4,5 km/h 30 min` | treadmill, those numbers (stated values win) |
| `gåband 60 min 5 km/h` / `gåband 60 min 5` | treadmill, `duration_min` 60, `speed_kmh` 5; not a correction of an earlier bout |
| `promenerade 45 min` | walk, `duration_min` 45 |
| `klättrade 2h` / `klättring 2 timmar` | climbing, `duration_min` 120, `kind` extra; complete the scheduled session if one exists that day |
| `vandrade 12 km` | hike, `distance_km` 12, `kind` extra; ask duration if useful, do not invent it |
| `vandrade 3h` | hike, `duration_min` 180, `kind` extra |
| `yoga 20 min` / `yoga` / `morgonyoga` | yoga; bare `yoga` fills typical duration from the habit when present |
| `nej, 40 min` / `rättelse 5 km/h` | correction of the **latest** instance today, same `instance` |

Comma vs decimal: `4,5` and `4.5` are the same speed. `2h` / `2 tim` → `duration_min` 120.

If a confirmed habit matches (same `key` or name, e.g. gåband → `treadmill_walk`, morgonyoga → `yoga`), set `habit_key`. Otherwise `habit_key` is null and slug `activity_key` from the user text (`climbing`, `hiking`, `walk`, `yoga`).

**Instances vs corrections.** Each clear log line is a new `instance` for that date + `activity_key` (1, then 2, …). `times_per_day` on the habit is the usual pattern, not a cap. Only correction language (`nej`, `rättelse`, `det var 40 min`) reuses the latest `instance`. Do not treat a longer/faster gåband as overwriting the earlier bout.

Do not treat `jogg` / planned running as extra-plan activity. Planned easy-run items stay `exercise_logged`.

If it is unclear whether a long walk is the planned run or extra-plan walking, ask once.

## Whole session shortcut

Match intent. Do not require these exact strings. This is not a single-exercise line and not `resten enligt plan`.

| Input | Meaning |
| --- | --- |
| `logga mitt gympass` / `logga gympasset` | fill remaining **strength** work from last working; card + one `godkänn` |
| `logga passet` | same for today's main session (strength on a gym day, run on a run-only day) |
| `jag körde hela passet` / `klarade alla övningar` / `allt som senast` | same as above |

Not this path: `bänk 80x5` (immediate log), `hoppade över`, `resten enligt plan` (mark done **without** weights).

Fill rules: last working kg/`load_text` (not PR, not plan RPE, no auto-bump); today's planned sets; last per-set reps if set count matches, else planned low end. Ask all missing weights in one message before the card. Default home `name`/`key`; mention `preferred` on the card. Skip warmup. Skip already-logged items. This path does not apply when today has no planned strength session — then log exercise by exercise, or add the session via `training-plan` first.

## Echo

After a successful insert, one line:

`Sparat: Hantelpress 80 kg × 5`

After a correction:

`Sparat: Hantelpress 82.5 kg (uppdaterad vikt idag).`

After extra-plan activity:

`Sparat: Gåband 30 min, 4,5 km/h.`

`Sparat: Gåband 30 min, 4,5 km/h (enligt vana).`

`Sparat: Gåband 60 min, 5 km/h.`

`Sparat: Klättring 120 min.`

After a second bout the same day:

`Sparat: Gåband 30 min, 4,5 km/h (2 idag).`

After a scheduled habit session:

`Sparat: Klättring 120 min (pass klart).`

After a shortcut session fill (one line or a short list):

`Sparat: Hantelpress 4×8 @ 30 kg/hantel (enligt senaste). Pass klart.`

Do not add a PR line unless they asked. Do not mention kcal.
