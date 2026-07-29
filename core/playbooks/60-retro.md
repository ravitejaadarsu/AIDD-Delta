# Phase: Retro

Purpose: the run makes future runs smarter. Runs after Delivery completes.

## Steps

1. Dispatch Retro Learner (`../roles/retro-learner.md`) → appends deduplicated lessons to
   `learnings.md` per `../protocol/learning.md`.
2. Orchestrator archives the change folder → `changes/_archive/<id>/`; sets global
   `changes.<id>: done`, clears `active_change`; final state write + dashboard render.

## Exit checklist

- [ ] learnings appended (or explicit "no new lessons" entry)
- [ ] change archived; global state valid
