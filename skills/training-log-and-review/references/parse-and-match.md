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
| `jogg 32 min` | running, duration 32, `load_kg` null, `load_text` `32 min` |
| `farmer 40 kg 40s` | timed, `reps` null, `load_text` includes seconds |

If RPE is present (`RPE 8`, `@8`), store it on those sets.

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

## Echo

After a successful insert, one line:

`Sparat: Hantelpress 80 kg × 5`

After a correction:

`Sparat: Hantelpress 82.5 kg (uppdaterad vikt idag).`
