---
name: alveolus-change-workflow
description: Use for every ALVEOLUS repository change that needs a safe local baseline, a scoped plan, file leases, focused verification, compact handoff, or GIF/video evidence preparation. Keeps work local, prevents oversized tasks, and separates durable rules from one-off results.
---

# ALVEOLUS change workflow

Use this workflow for one coherent outcome at a time. Keep implementation and
its plan in the same task until the transcript warning requires a rollover.

## Start safely

1. Read `AGENTS.md`, the risk class in `docs/QUALITY.md`, and only the relevant
   source-of-truth documents.
2. Inspect branch, HEAD, worktree status, relevant diff, and existing local
   reports. Never discard or silently absorb another writer's changes.
3. Plan read-only before a multi-system, ambiguous, save-sensitive, or
   performance-sensitive change.
4. Require an exact local `BASELINE_READY` commit before writing on top of a
   dirty integration state. Local commits and worktrees are allowed; push,
   upload, deployment, PR, and release actions are not.
5. Name one integrator and one writer per file. Spawn at most two subagents,
   always with `fork_turns="none"` and a self-contained short briefing. Agents
   that review product or architecture remain read-only.

## Execute one slice

1. Start or update one focused goal in the same task.
2. Record the exact file lease and invariants before the first edit.
3. Store raw logs, capture indexes, and benchmark JSON under
   `.codex-temp/reports/<slice>/`; report only condensed findings in the task.
4. Run the smallest focused check first. Godot processes remain serial.
5. For performance work, measure the exact baseline and changed build with the
   same seed and scenario. Never infer performance from code shape alone.
6. Review `git diff --check`, the owned diff, and worktree status before the
   local commit. Do not publish.

## Prepare visual evidence

Never attach an animated GIF directly to an ALVEOLUS task. Keep the original
under `.codex-temp/evidence/<case>/` and run:

```powershell
python .agents/skills/alveolus-change-workflow/scripts/prepare_feedback_media.py `
  <path-to-original.gif> --case <case-id>
```

The script preserves the original bytes and creates at most six reduced PNG
frames, one contact sheet, and `manifest.md`. Put only the contact sheet or
selected frames in the task, with a timestamp and a precise observation
request. Prepared task media must remain at or below 8 MiB. Refer to short
MP4/WebM evidence only by local path and timestamp; do not embed it.

## Rollover and finish

- At the 20 MiB warning, finish only the smallest safe current slice, move raw
  output to `.codex-temp`, and send a prompt beginning with
  `ALVEOLUS-ROLLOVER` without attachments.
- At 40 MiB normal prompts are blocked. The rollover prompt produces text only;
  start a new task from that text and archive the old task after the handoff is
  confirmed.
- Finish with exactly one compact `ALVEOLUS-HANDOFF-v2` as specified in
  `docs/WORKSTREAMS.md`. Do not repeat project history, logs, or media.

The repository hooks are an accident-prevention guardrail, not a network
security boundary. A later release requires a separate, explicit release task
and deliberate hook/policy change; a development prompt cannot bypass it.
