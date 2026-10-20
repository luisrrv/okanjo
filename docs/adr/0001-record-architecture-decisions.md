# 0001. Record architecture decisions

- Status: Accepted
- Date: 2026-10-20 (backfilled from the design plan)
- Decider: Luis

## Context
okanjo is a system-design showcase first: proof that I can design a system and ship it in
any stack with AI. Rails fluency is the second goal. Luis owns the architecture, domain
model and every design decision. Claude proposes options, argues with the design,
implements decisions and explains the Rails idioms it uses.

The early design lived in a private plan outside the repo. A reviewer looking at the repo
would see the code but not the reasoning behind it, or who made which call.

## Options considered
1. **Keep decisions in the private plan.** Pros: no extra writing. Cons: the reasoning is
   invisible to reviewers, and the plan mixes settled and open decisions.
2. **Record each decision as an ADR in the repo, and make the AI-assisted workflow
   public.** Pros: the design trail is part of the showcase, and each decision is
   reviewable on its own. Cons: writing time on top of the code.

## Decision
Option 2. Decisions are recorded as numbered ADRs in `docs/adr/` (Context, Options
considered, Decision, Consequences), indexed in `docs/adr/README.md`. The project
`CLAUDE.md`, the ADRs and the feature specs are all committed. This replaces an earlier
rule that Luis writes all the code by hand.

## Consequences
- Every structural choice goes through design, ADR, spec, implementation and docs.
- Numbers 0001–0012 were assigned to decisions from the original plan and backfilled.
  0008 and 0013 onwards were written first, as decisions were reopened or made. 0010 and
  0011 were never written, because 0016 replaced them first.
- An ADR overrides the original plan where they differ.
