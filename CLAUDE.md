# okanjo

Shared-expense splitting app (groups, members, expenses, settlement that minimises transfers), built in Rails 8.

This repo is also a record of how it was built: Luis owns the architecture and design decisions, and Claude implements from them. The design trail in `docs/` matters as much as the code.

## Roles
- **Luis**: architecture, domain modelling, tradeoff decisions, final review of every change.
- **Claude**: proposes options, challenges decisions, implements, tests, and explains Rails idioms along the way.
- Don't make architecture decisions silently. If an implementation choice affects structure, data model, boundaries, dependencies or deployment, stop and raise it as a decision.

## Workflow per feature
1. **Design.** Lay out 2–3 options with concrete tradeoffs and a recommendation. Argue against weak choices; Luis wants the argument, not agreement.
2. **Record.** Once Luis decides, write an ADR in `docs/adr/NNNN-kebab-title.md` (Context, Options, Decision, Consequences). Use `/adr`.
3. **Spec.** Write `docs/specs/<feature>.md`: goal, out of scope, data model changes, routes/interfaces, edge cases, verification steps.
4. **Implement.** Work in small, reviewable steps, with tests in the same step. After each step, summarise the diff and explain any Rails idiom that isn't obvious.
5. **Update docs.** Keep `docs/ARCHITECTURE.md` current: system context, domain model, key flows, deployment. Use Mermaid diagrams.

## Roadmap
1. **Core:** groups, members, expenses, settlement, built-in auth, one Solid Queue job. CI, deployed with Kamal.
2. **Showcase (after core ships):** a JSON API consumed by a small LIFF front end, with LINE login bridged to Rails auth. The same domain serves the Hotwire web UI and LINE.

Keep phase 2 in mind when designing phase 1, and raise it whenever a phase 1 choice would make it harder.

## Rails 8 conventions
- Use Rails 8 defaults unless an ADR says otherwise: Solid Queue/Cache/Cable (not Sidekiq/Redis), Propshaft (not Sprockets), the built-in authentication generator (not Devise), `params.expect` (not `require/permit`), Kamal 2 for deploys, Hotwire (Turbo + Stimulus) for UI, Minitest + fixtures.
- Follow convention over configuration and write idiomatic Ruby, not PHP- or JS-shaped Ruby. Adding a gem needs an ADR.
- Money is integer yen. Never use floats for amounts.

## Verify
- `bin/rails test` for the touched area, `bin/rubocop`, and `bin/brakeman` before calling a step done. Show the results.
