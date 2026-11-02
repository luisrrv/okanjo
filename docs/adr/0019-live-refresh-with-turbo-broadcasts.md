# 0019. Live refresh with Turbo page-refresh broadcasts

- Status: Accepted
- Date: 2026-11-02
- Decider: Luis

## Context
The plan called for one Turbo Stream interaction: adding an expense updates the balances
without a full reload. Since the session 2 decision, the expense form is on its own page
and saving redirects back to the occasion page, so the person adding the expense already
sees fresh balances. The real gap is everyone else: an occasion is shared through a link,
and when Ben adds an expense, Aki's open page doesn't change.

Every change to an occasion's members, expenses or splits already updates the group's
`updated_at` through `touch` (0004, 0016).

## Options considered
1. **An inline expense form with a Turbo Stream response.** Pros: the plan's literal
   reading. Cons: reverses the session 2 page layout, and still doesn't update anyone
   else's screen.
2. **Hand-written Turbo Stream broadcasts** that replace specific parts of the page (the
   balance panel, the expense list). Pros: precise. Cons: a broadcast and a partial target
   per changing part, more code for the same visible result.
3. **Turbo 8 page-refresh broadcasts.** `broadcasts_refreshes` on `Group`,
   `turbo_stream_from` on the occasion page, and morphing. Pros: one line covers every
   change, because children already touch the group. Other viewers' pages re-render by
   morphing, which keeps their scroll position. Uses Action Cable over Solid Cable, the
   Rails 8 default. Cons: a WebSocket connection per open occasion page.

## Decision
Option 3. `Group` broadcasts page refreshes on every change, the occasion page subscribes
to its group's stream, and the layout uses `turbo_refreshes_with method: :morph, scroll:
:preserve`.

## Consequences
- Action Cable runs on Solid Cable in production (already configured in `config/cable.yml`
  and `config/database.yml`) and on the async adapter in development. kamal-proxy has to
  pass WebSockets, which it supports.
- The stream name is signed by `turbo_stream_from`, so a client can only subscribe to an
  occasion whose page it has loaded.
- Turbo ignores refreshes caused by the viewer's own request, so the person making the
  change doesn't get a second reload.
- Relies on `touch` triggering the group's commit callbacks. A spec confirms this before
  anything depends on it.
- The purge job's `delete_all` skips callbacks, so a purged occasion doesn't broadcast.
  Nobody is viewing a 30-day-old occasion, so that's fine.
- Risk to check manually: a refresh that arrives while someone is typing in a form on the
  occasion page (adding a member) could reset what they typed. If it does, mark that form
  `data-turbo-permanent`.
- First on the cut list if time runs short (plan: the Turbo interaction goes before
  settlement).
