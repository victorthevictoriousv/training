# Minor vs major plan changes

Use this after a plan is `active`. When unsure, treat the change as major.

## Minor (edit the active plan in place)

Tell the user what changed, then `UPDATE plans.content`.

- Swap an exercise for a close equivalent (same pattern and difficulty)
- Add or remove about one set
- Move a session to another day in the same week
- Turn one session into rest or easy recovery the same day if the user reports poor recovery, time pressure, or non-stop pain

Minor changes stay inside the already approved days-per-week, modalities, and overall intensity.

## Major (new proposed plan, wait for approval)

Then follow the supersede + proposed + activated write in `SKILL.md`.

- Change how many days per week they train
- Add or remove a modality
- Change the primary goal the week is built around
- Replace the week's structure (e.g. full-body ×3 → split + intervals)
- A clear jump in intensity or volume, not just ±1 set

v1 does not insert into `recommendations`. The replacement `plans` row is the proposal; chat approval is the gate.
