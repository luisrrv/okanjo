# 0018. Japanese UI with Rails I18n and rails-i18n

- Status: Accepted
- Date: 2026-11-02
- Decider: Luis

## Context
warikan's users are in Japan (0017), so the UI is in Japanese. Rails' own messages, such
as validation errors ("has already been taken") and date formats, are English out of the
box. Reviewers of the repo may not read Japanese, so adding English later should be cheap.

## Options considered
1. **Japanese typed directly into views.** Pros: quickest to write. Cons: Rails' own
   messages stay English, and adding English later means editing every view.
2. **All copy in `config/locales/ja.yml`, with Rails' messages translated by hand.**
   Pros: no gem. Cons: every new validation needs its message added, and a missed one
   shows "translation missing".
3. **All copy in `config/locales/ja.yml`, plus the `rails-i18n` gem** for Rails' own
   messages and formats. Pros: complete translations, the standard choice at Japanese
   Rails companies, and English can be added later as one more locale file. Cons: a gem.

## Decision
Option 3. The default and only locale is `ja`. Every piece of user-facing text goes through
`t(...)` and lives in `config/locales/`. `rails-i18n` supplies Japanese for Rails' built-in
messages and formats. The README and `docs/` stay in English.

## Consequences
- No user-facing string is typed directly into a view or controller.
- The test environment sets `config.i18n.raise_on_missing_translations = true`, so a
  missing key fails a spec instead of reaching a user.
- Model and attribute names used in error messages (e.g. 名前, 金額) are defined under
  `activerecord.models` and `activerecord.attributes` in `ja.yml`.
- English, if it's ever wanted, is an `en.yml` plus locale switching, with no view
  changes.
- Japanese copy is reviewed by a native speaker before launch. The specs list it with
  English glosses.
