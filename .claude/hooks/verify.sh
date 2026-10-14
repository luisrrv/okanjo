#!/usr/bin/env bash
# Stop hook: before Claude finishes, run RuboCop and the test suite if Ruby/ERB files changed.
# Exit 2 sends the failures back to Claude to fix. Exit 0 lets it stop.

input=$(cat)

# Loop guard: if this hook already sent Claude back once this turn, let it stop.
# (Claude Code also caps consecutive Stop-hook blocks.)
if grep -q '"stop_hook_active": *true' <<<"$input"; then
  exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

changed=$(git status --porcelain -- '*.rb' '*.erb' '*.rake' 2>/dev/null)
[ -z "$changed" ] && exit 0

if ! out=$(bin/rubocop 2>&1); then
  { echo "RuboCop failed. Fix these before finishing:"; echo "$out" | tail -40; } >&2
  exit 2
fi

if ! out=$(bin/rails test 2>&1); then
  { echo "Tests failed. Fix these before finishing:"; echo "$out" | tail -60; } >&2
  exit 2
fi

exit 0
