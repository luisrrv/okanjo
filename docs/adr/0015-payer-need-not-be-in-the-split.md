# 0015. The payer doesn't have to be in the split

- Status: Accepted
- Date: 2026-10-19
- Decider: Luis

## Context
Each expense has one payer and a set of participants: the members in the split (0007).
Usually the payer is one of them. Sometimes the payer fronts money for something they don't
consume. For example, Dai doesn't drink but puts the ¥8,000 飲み放題 add-on for Aki, Ben and
Chie on his card.

A treat (おごり) is a different case and doesn't need this rule. If Aki treats everyone,
nobody owes anything: the expense isn't entered, or Aki is the only one in the split and her
balance stays at zero.

## Options considered
1. **The payer must be in the split** (a validation). Pros: the payer can't be left out by
   mistake. Cons: Dai's case can't be entered correctly. With him in the split, he pays for
   drinks he didn't have (¥2,000 each instead of ¥2,667). It's also extra code that rejects
   a state the form naturally allows.
2. **The payer may be left out of the split.** Pros: handles every real case, and it's less
   code, since it's the absence of a rule. Cons: if the payer is left out by mistake,
   everyone else pays more and the amounts still look plausible.

## Decision
The payer may be left out of the split (option 2). Mistakes are guarded against in the UI,
not by a model validation.

These validations apply regardless:
- at least one member in the split
- the payer belongs to the expense's group
- every member in the split belongs to the expense's group, so a crafted request can't pull
  in a member from another occasion
- no member is in the split twice: a unique index on `participations [expense_id,
  member_id]` plus a uniqueness validation

## Consequences
- Safeguard: a new expense starts with everyone in the split and the payer defaulting to
  this browser's member (0006). If the payer ends up left out of the split, by either route,
  the form asks for confirmation and states the effect in yen: "Dai won't share this
  ¥8,000. Aki, Ben and Chie will each pay ¥2,667 instead of ¥2,000." Nothing else asks for
  confirmation. The exact behaviour is in the expense spec.
- The confirmation is a small Stimulus controller using the browser's built-in `confirm()`.
  A styled modal is later polish, not core. The numbers in the dialog are a preview, and the
  server still computes shares when the page is read (0008).
- The server accepts a payer who is left out whether or not the confirmation ran, e.g. with
  JavaScript off or in an API request in phase 2.
- With 0008, a payer who is left out is still credited with what's collected: ¥8,001 for
  ¥8,000 spent in the example.
- The four validations are the second model spec, after the 0008 invariants.
- The expense list shows when the payer is left out ("Dai paid · not sharing").
