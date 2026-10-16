# 0014. Test with RSpec and FactoryBot

- Status: Accepted
- Date: 2026-10-16
- Decider: Luis

## Context
okanjo is built in Rails in order to show Rails shops, mainly in Tokyo, that I can design
and ship a system in their stack. The test framework sends the same signal. Most of those
shops' job posts ask for RSpec, usually with FactoryBot.

Rails ships with Minitest and fixtures: `rails new` already created `test/` and the
generators write Minitest files. Switching needs the `rspec-rails` and `factory_bot_rails`
gems, and adding a gem needs an ADR. The workflow puts tests in every implementation step,
so this has to be settled before the first model test.

I have only brief, years-old exposure to RSpec, so the specs have to stay readable enough
for me to review and defend them in an interview.

## Options considered
1. **Minitest + fixtures.** Pros: no setup or new gems, it's what the generators write,
   and it's plain classes and methods that are easy to trace. Cons: it shows target shops
   the dialect they don't use.
2. **Minitest in okanjo, RSpec + FactoryBot later in the timed take-home dry run.** Pros:
   okanjo stays at zero setup. Cons: RSpec gets learned under a timer, the worst place to
   learn it, and the total work is greater than learning it here.
3. **RSpec + FactoryBot.** Pros: matches target shops, and I learn RSpec by reviewing specs
   in code I designed. Cons: about 30 minutes of setup, two gems, and an RSpec DSL I don't
   read fluently yet.
4. **RSpec + fixtures.** Pros: one gem fewer. Cons: an uncommon pairing at the shops this
   project is aimed at.

## Decision
RSpec with FactoryBot (option 3), for the same reason the project is in Rails: to show
target shops their own stack.

Specs follow a readable-RSpec rule:
- at most two levels of `describe` / `context`
- setup goes inside the example unless several examples share it; `let` only for shared
  setup, and no `let!` chains
- no implicit `subject`
- `shared_examples` only when duplication actually hurts

## Consequences
- Add `rspec-rails` and `factory_bot_rails`, run `rails g rspec:install`, and remove
  `test/`. Capybara and Selenium are already in the Gemfile, so system specs need no
  further gems.
- Generators write specs instead of Minitest files.
- Spec types: model specs (including the 0008 invariants), request specs, and system specs.
- Open check: the built-in auth generator (0010) may still write Minitest files with
  `rspec-rails` installed. If it does, port the generated tests to specs by hand rather
  than keeping two frameworks.
- Factories that silently create associated records can slow the suite. That doesn't
  matter at okanjo's size; revisit if the suite gets slow.
- The readable-RSpec rule means some specs repeat setup that idiomatic RSpec would hoist
  into `let`. The repetition is accepted so each example reads on its own.
