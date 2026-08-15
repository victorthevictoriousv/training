# Minor vs major plan changes

Use this after a plan is `active`. When unsure, treat the change as major.

Do not change the profile for a one-week situation. `availability` / habits updates are onboarding, then a new week.

**Exception:** they **mean** a planned exercise is unavailable at the routine gym (context, not a set phrase). That is gym fact (`equipment.home_gym_substitutions`), not a one-week squeeze. After one `godkänn`, update the plan item **and** the profile. A this-week swap without that meaning is plan-only. See `references/exercise-substitutions.md`.

## Minor (after approval: edit the active plan in place)

Show **Förslag (sparas inte än)**. On explicit approval, `UPDATE plans.content`. If they do not approve, write nothing.

- Change the exercises or structure of an already scheduled day
- Swap an exercise for a close equivalent (same pattern and difficulty) **this week only** — do not write `preferred` or `home_gym_substitutions`
- Gym-unavailable: replace the prescribed `name` with one home-gym substitute, set `preferred` to the original first choice, and merge the pair into `equipment.home_gym_substitutions`
- Add or remove about one set
- Move a session to another day in the same week
- Turn one session into rest or easy recovery the same day if the user reports poor recovery, time pressure, or non-stop pain
- Reshape **remaining days of this week** after a skip, time pressure, or poor recovery, in one draft: drop or add a two-a-day, move quality, shorten evening work. Stay inside confirmed modalities. Do not raise another session to hard because one quality session was skipped
- Drop the remaining evening sessions this week (“bara lunch”) when the profile is unchanged

Minor changes stay inside the already approved modalities and overall intensity band. `days_per_week` is training days, not a session quota; using or skipping a two-a-day this week is still minor.

Draft remaining-week changes as one card. Do not ask pass by pass.

## Major (after approval: new proposed plan)

Then follow the supersede + proposed + activated write in `SKILL.md`.

- Change how many **days** per week they train (new normal, not a one-week squeeze)
- Add or remove a modality
- Change the primary goal the week is built around
- Replace the week's structure (e.g. full-body ×3 → split + intervals as the new default)
- A clear jump in intensity or volume across the whole week, not just ±1 set or dropping this week's extra slot
- Add or remove a scheduled habit that reshapes the week (new climbing day plus lighter surrounding sessions)

v1 does not insert into `recommendations`. The replacement `plans` row is the proposal; chat approval is the gate.
