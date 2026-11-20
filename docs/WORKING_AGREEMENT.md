# Working agreement

How okanjo is built: who decides what, the workflow each feature follows, and the conventions
the code keeps to. okanjo is a shared-expense splitting app (groups, members, expenses,
settlement through a single collector), built in Rails 8. Users see it as warikan (割り勘) at
warikan.lrod.dev; okanjo is the codebase name (ADR 0017).

This repo is also a record of how it was built: Luis owns the architecture and design
decisions, and Claude implements from them. The design trail in `docs/` matters as much as the
code. Claude's own configuration files are kept local and aren't committed
([ADR 0001, update of 2026-11-20](adr/0001-record-architecture-decisions.md)); this document is
the public version of the agreement.

## Roles
- **Luis:** architecture, domain modelling, tradeoff decisions, final review of every change.
- **Claude:** proposes options, challenges decisions, implements, tests, and explains Rails
  idioms along the way.
- Claude doesn't make architecture decisions silently. If an implementation choice affects
  structure, data model, boundaries, dependencies or deployment, it stops and raises it as a
  decision.

## Workflow per feature
1. **Design.** Claude lays out 2–3 options with concrete tradeoffs and a recommendation, and
   argues against weak choices: Luis wants the argument, not agreement.
2. **Record.** Once Luis decides, the decision is written as an ADR in
   `docs/adr/NNNN-kebab-title.md` (Context, Options, Decision, Consequences), indexed in
   [`docs/adr/README.md`](adr/README.md).
3. **Spec.** `docs/specs/<feature>.md`: goal, out of scope, data model changes,
   routes/interfaces, edge cases, verification steps.
4. **Implement.** Small, reviewable steps, with tests in the same step. After each step, Claude
   summarises the diff and explains any Rails idiom that isn't obvious.
5. **Update docs.** [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) stays current: system context,
   domain model, key flows, deployment. Mermaid diagrams.

## Roadmap
The status of the core and phase 2 is in the [README's Status section](../README.md#status).
All three phases (core, the phase 2 showcase, phase 3 security and limits), including the
planned phase 3, are in [`docs/ARCHITECTURE.md`](ARCHITECTURE.md) (status table, "Phase 2",
"Phase 3").

## Rails 8 conventions
- Rails 8 defaults unless an ADR says otherwise: Solid Queue/Cache/Cable (not Sidekiq/Redis),
  Propshaft (not Sprockets), the built-in authentication generator (not Devise),
  `params.expect` (not `require/permit`), Kamal 2 for deploys, Hotwire (Turbo + Stimulus) for
  UI. Tests use RSpec + FactoryBot ([ADR 0014](adr/0014-test-with-rspec-and-factorybot.md)) and
  follow its readable-RSpec rule.
- Convention over configuration, and idiomatic Ruby, not PHP- or JS-shaped Ruby. Adding a gem
  needs an ADR.
- Money is integer yen. Floats are never used for amounts.

## Verify
A step is done when `bundle exec rspec` (for the touched area), `bin/rubocop` and
`bin/brakeman` pass.
