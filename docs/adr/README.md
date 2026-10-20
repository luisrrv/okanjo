# Architecture Decision Records

- [0001. Record architecture decisions](0001-record-architecture-decisions.md): ADRs in the repo; the AI-assisted workflow is public
- [0002. Rails 8 defaults as the baseline](0002-rails-8-defaults-as-the-baseline.md): Solid trio, Propshaft/importmap, Kamal 2; a gem needs an ADR
- [0003. Hotwire monolith, not an API](0003-hotwire-monolith-not-an-api.md): no `--api`; ERB, Turbo and Stimulus; Tailwind without Node
- [0004. Core domain model](0004-core-domain-model.md): Group, Member, Expense, Participation; no Invitation, Calculation or Payment
- [0005. A group is an occasion](0005-a-group-is-an-occasion.md): a new group for every calculation; the token URL is the invite
- [0006. Members belong to one occasion; anonymous identity via a signed cookie](0006-group-scoped-members-and-cookie-identity.md): no identity across occasions; the cookie maps browser to member
- [0007. Split rules](0007-split-rules.md): equal splits, one payer per expense, integer yen
- [0008. Round up each share, compute shares on read](0008-round-up-shares-computed-on-read.md): shares round up and aren't stored; the payer is credited with what's collected and keeps the odd yen
- [0009. Where the split logic lives](0009-where-the-split-logic-lives.md): per-expense logic on the model; balance sheet and settlement as plain Ruby objects
- 0010, 0011: not written; replaced by 0016 before the backfill (auth in the core, the `Member.user_id` link)
- [0012. Background job: purge stale occasions](0012-background-job-purge-stale-occasions.md): a recurring Solid Queue task, not a summary job with no recipient
- [0013. Settle through a single collector](0013-settle-through-a-collector.md): the member with the largest positive balance settles with everyone else; trust over fewest transfers
- [0014. Test with RSpec and FactoryBot](0014-test-with-rspec-and-factorybot.md): RSpec + FactoryBot to match target Rails shops, with a readable-RSpec rule
- [0015. The payer doesn't have to be in the split](0015-payer-need-not-be-in-the-split.md): allowed, with a confirmation when the payer is left out; group-integrity validations
- [0016. Anonymous core with 30-day retention and receipts](0016-anonymous-core-with-30-day-retention.md): no login in the core; occasions deleted 30 days after the last change; printable receipt; auth generator moves to the start of phase 2
- [0017. CI, and a Kamal deploy to warikan.lrod.dev](0017-ci-and-kamal-deploy-to-warikan-lrod-dev.md): Kamal to a Tokyo VPS; warikan is the product name, okanjo the codebase name
