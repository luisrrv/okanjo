# Architecture Decision Records

- [0008. Round up each share, compute shares on read](0008-round-up-shares-computed-on-read.md): shares round up and aren't stored; the payer is credited with what's collected and keeps the odd yen
- [0013. Settle through a single collector](0013-settle-through-a-collector.md): the member with the largest positive balance settles with everyone else; trust over fewest transfers
- [0014. Test with RSpec and FactoryBot](0014-test-with-rspec-and-factorybot.md): RSpec + FactoryBot to match target Rails shops, with a readable-RSpec rule
