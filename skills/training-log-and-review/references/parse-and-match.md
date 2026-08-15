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

1. Prefer a unique planned item for that date (name or alias).
2. If several items match, ask.
3. If none match but the name is a clear exercise, log it anyway with a slug from the user text (`session_id` null unless only one session that day).

## Aliases → typical keys

Use the planned `name` as `exercise_name` when matched. Keys are hints:

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
| `gåband 30 min 4,5` / `gåband 4,5 km/h 30 min` | treadmill, `duration_min` 30, `speed_kmh` 4.5 |
| `promenerade 45 min` | walk, `duration_min` 45 |
| `klättrade 2h` / `klättring 2 timmar` | climbing, `duration_min` 120, `kind` extra; complete the scheduled session if one exists that day |
| `vandrade 12 km` | hike, `distance_km` 12, `kind` extra; ask duration if useful, do not invent it |
| `vandrade 3h` | hike, `duration_min` 180, `kind` extra |
| `yoga 20 min` / `yoga` / `morgonyoga` | yoga, `duration_min` if given, `kind` lifestyle, `intensity` easy; `habit_key` `yoga` if that habit exists |

Comma vs decimal: `4,5` and `4.5` are the same speed. `2h` / `2 tim` → `duration_min` 120.

If a confirmed habit matches (same `key` or name, e.g. gåband → `treadmill_walk`, morgonyoga → `yoga`), set `habit_key`. Otherwise `habit_key` is null and slug `activity_key` from the user text (`climbing`, `hiking`, `walk`, `yoga`).

Do not treat `jogg` / planned running as extra-plan activity. Planned easy-run items stay `exercise_logged`.

If it is unclear whether a long walk is the planned run or extra-plan walking, ask once.

## Echo

After a successful insert, one line:

`Sparat: Hantelpress 80 kg × 5`

After a correction:

`Sparat: Hantelpress 82.5 kg (uppdaterad vikt idag).`

After extra-plan activity:

`Sparat: Gåband 30 min, 4,5 km/h.`

`Sparat: Klättring 120 min.`

After a scheduled habit session:

`Sparat: Klättring 120 min (pass klart).`

Do not add a PR line unless they asked. Do not mention kcal.
