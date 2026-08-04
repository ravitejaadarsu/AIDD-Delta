# Negotiation Protocol

The Auditor negotiates a DISPUTED acceptance criterion with the Master Agent when the
Master Agent's own monitoring already accepted the work the Auditor is disputing —
bounded position/response exchanges, never live dialogue. Artifacts are the only
inter-agent channel.

## Trigger

Negotiation opens for an AC when both hold: the Auditor's verdict marks the AC
**DISPUTED** (`interrogation.md`), and the Master Agent's monitoring notes **accept**
the work covering that AC.

**Short-circuit.** If the Master Agent's monitoring notes instead concur the work is
deficient, negotiation is skipped — the DISPUTED AC becomes a fix-loop defect directly,
with no position, no response, no adjudication. The skip is still exactly one log line
in `negotiation-log.md`, mirrored to change state: no disputed AC's fate goes untracked.

## Artifact layout

Written under `.aidd/changes/<id>/audit/`:

```text
negotiation-log.md
```

One file for the whole change. Every disputed AC that reaches this protocol — whether
it negotiates or short-circuits — appends its own section; never a separate file, never
an overwrite.

Template: `templates/negotiation-log.md`.

## Position

The Auditor's position names, for the disputed AC: the AC id, the evidence its verdict
already cites, and the exact reason the Master Agent's acceptance doesn't close the
gap. Evidence follows the mandatory block format from `../protocol/evidence.md`.

## Response

The Master Agent is re-dispatched to answer the position with exactly one of:

- **accept** — concurs the work is deficient. The AC becomes a fix-loop defect
  immediately; no adjudication follows.
- **contest** — stands by the work, backed by counter-evidence in the same
  `../protocol/evidence.md` block format.

## Dispatch

The orchestrator dispatches every party; agents never talk live. The Auditor writes the
position. The orchestrator re-dispatches the Master Agent to write the response. A
**contest** with exchange budget remaining lets the Auditor write the next exchange's
position, addressing the counter-evidence directly. A **contest** at budget exhaustion
routes to Supervisor adjudication.

## Budget

Max **2 exchanges** per disputed AC. One exchange is one position artifact plus its
response, as a pair. Exchanges used are tracked in change-state
`audit.negotiation.exchanges_used` against `audit.negotiation.max` (schema shipped).
The counter tracks only the AC currently in negotiation: the orchestrator resets
`exchanges_used` to 0 each time a new AC enters negotiation.

## Adjudication

Exhaustion — budget spent and the Master Agent still contesting — escalates to the
Supervisor (`../roles/supervisor.md`). The Supervisor issues a per-AC ruling from its
super-context (every artifact the phase produced, not only the exchanged positions and
responses), never live dialogue with either party. The ruling is exactly one of
`PROVEN | DEFECT | UNRESOLVABLE`:

- **PROVEN** — the dispute doesn't hold; the Master Agent's work stands.
- **DEFECT** — the work is deficient; the AC becomes a fix-loop defect.
- **UNRESOLVABLE** — the super-context doesn't settle it. Forced-human gate in both
  autonomy modes, take-care included.

The final ruling on a disputed AC is always exactly one of `PROVEN | DEFECT |
UNRESOLVABLE`, whoever produces it: an **accept** resolves the AC as `DEFECT` with `who
ruled: negotiation`; a Supervisor adjudication may rule any of the three with `who
ruled: Supervisor adjudication`.

## Routing

`DEFECT` (by accept or by Supervisor) feeds the fix loop, same as an executed FAIL.
`PROVEN` needs no further action — the AC stands proven. `UNRESOLVABLE` forces a human
stop in both autonomy modes, take-care included, before the change can proceed.

Every outcome — short-circuit, accept, or Supervisor ruling — is exactly one log line
appended to `negotiation-log.md` and mirrored to change state (`audit.negotiation`);
each is itself a history event. Nothing exits this protocol unlogged.
