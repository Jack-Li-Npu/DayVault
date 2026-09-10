# Executable rules, version 1.0.0

- completionCount counts unique completed occurrence keys belonging to this goal.
- activeDays counts distinct completion days in the goal's saved timezone.
- completedCycles counts completed, fixed cycles configured by the user. Use it only when cycleIsConfigured=true; do not create a cycle or change its required days.
- Every threshold is an integer from 1 to 1000. Do not encourage excessive activity, skipping rest, purchases, notifications, or ratings to earn anything.
- At most two definitions have isHidden=false and at most one has isHidden=true. Definitions have unique short IDs. They are drafts, not accepted definitions; the application performs goal-level confirmation and freezes the accepted rules.
- For hidden definitions, provide a cryptic, nonnumeric Chinese clue. The host must keep the name, detail, rule type and target out of normal companion/chat context until unlocked. This designer output is not a chat reply.
- badgeStyleKey must be crest, orbit, steps, spark or ribbon. These select original code-rendered components; do not output image URLs, game characters, SVG, executable code or asset names.
- sourceIDs must cite supplied IDs (or goal/message). Never invent user records, timestamps or achievement evidence.
