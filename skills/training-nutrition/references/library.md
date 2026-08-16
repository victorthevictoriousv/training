# Food library

Confirmed go-to meals and saved recipes in `user_profiles.data.nutrition.library`. Provenance key: `nutrition.library` for the whole array. Same add/change/remove pattern as `lifestyle.habits`.

Nothing here is a weekly menu. Suggestions pick from this list; they do not write `plans`.

## Shape

```json
{
  "key": "chicken_rice_broccoli",
  "name": "Kyckling, ris, broccoli",
  "kind": "staple",
  "slots": ["lunch", "dinner"],
  "notes": ""
}
```

Recipe extras (omit on `staple`):

```json
{
  "kind": "recipe",
  "time_min": 25,
  "servings": 2,
  "ingredients": [{ "name": "kyckling", "amount": 400, "unit": "g" }],
  "method": "Stek kycklingen. Koka ris. Ånga broccoli."
}
```

- `key`: lowercase snake_case, stable
- `kind`: `staple | recipe`
- `slots`: `breakfast | lunch | dinner | evening | snack`
- `staple`: frequent meal, short notes, no recipe required
- `recipe`: ingredients + short Swedish `method` when they say spara receptet

Omit the array until at least one item is confirmed. Do not save `[]`. Do not store kcal, macros, or MET on items. Portion kcal in chat is a slutsats if they ask.

## Writes

After `godkänn`, write the full confirmed array. Keep unrelated items. Drop the key from `data` and `provenance` if the array would be empty.

`training-onboarding` owns library edits with no live suggestion (`lägg till matvana`). `training-nutrition` may write the array in the same turn as a meal **Förslag** after approval — same exception as `training-plan` writing `home_gym_substitutions`.

## Using the library

Prefer matching `slots` for the ask. Vary items when they want lunch + dinner + evening. Named log line without detail fills `name` / `library_key` and echoes `(enligt vana)`.

Listing or fetching saved items (index then one full card) is `training-nutrition` §8. Do not dump the whole array as recipes on a prefs question.
