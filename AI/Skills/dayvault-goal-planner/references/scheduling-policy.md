# Scheduling Policy

## Time horizons

- One to 14 days: return every proposed block explicitly.
- Fifteen to 180 days: return a complete roadmap, explicit blocks for the first 14 days, and repeatable weekly patterns for the remainder.
- Beyond 180 days: plan the first 180 days and identify a review checkpoint instead of pretending the distant schedule is certain.

## Capacity

- Use the user's explicit availability when present.
- Otherwise assume 09:00–21:00 in the supplied timezone.
- Fill no more than 70 percent of available time.
- Schedule no more than two demanding blocks per day.
- Default to blocks of 15–120 minutes. Use up to 180 minutes only when the task clearly benefits.
- Leave at least 15 minutes between demanding blocks.
- For multi-week plans, keep at least one lighter or rest day in each seven-day period.

## Decomposition

- Create two to five phases with an observable outcome for each phase.
- Give each milestone a concrete definition of done.
- Put foundational work before polishing or repetition.
- Keep the first action small enough to begin without further planning.
- Use checkpoints to adapt later work instead of overspecifying every distant day.

## Conflicts and feasibility

- Never overlap a supplied busy window.
- Never schedule after the target deadline.
- If the full request cannot fit, reduce scope and return a warning.
- Preserve the user's stated rest, work, school, health, or family constraints.
- Use absolute timestamps with timezone offsets in generated blocks.

## Community challenges

- Recommend only an ID from `activeChallengeIDs`.
- Recommend at most one challenge.
- Prefer a challenge whose metric naturally reinforces the goal.
- Do not claim a challenge is popular; popularity is supplied and rendered by the host application.
