---
name: adr
description: Record an architecture decision as a numbered ADR in docs/adr
disable-model-invocation: true
---

Decision to record: $ARGUMENTS

1. Look in `docs/adr/` for the next number (start at 0001). Create the folder if it doesn't exist.
2. Write `docs/adr/NNNN-kebab-case-title.md`:

   ```
   # NNNN. Title

   - Status: Accepted
   - Date: YYYY-MM-DD
   - Decider: Luis

   ## Context
   The problem and the forces at play (constraints, scale, team, timeline).

   ## Options considered
   1. Option — pros / cons
   2. ...

   ## Decision
   What was chosen and the main reason.

   ## Consequences
   What gets easier, what gets harder, what we'd revisit and when.
   ```

3. Use only what Luis and you actually discussed. Don't invent rationale; ask if the reasoning is unclear.
4. If this supersedes an earlier ADR, set that ADR's status to `Superseded by NNNN`.
5. Add a one-line entry to the index at `docs/adr/README.md`.
