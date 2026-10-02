#!/usr/bin/env bash
# Harness load proof: install the whole catalog into a scratch project, then
# ask each harness which skills it actually loaded.
#
# Usage: scripts/verify-harness-load.sh [SOURCE]
#   SOURCE  where `skills add` installs from. Defaults to this checkout; a
#           GitHub tree URL proves a published ref.
#
# Needs a logged-in `claude` (one short haiku turn) and a `codex` binary.
# Claude: reads the `skills` list from the stream-json init event, with
#   --setting-sources project so only project skills and built-ins load.
# Codex: renders the model-visible prompt (`codex debug prompt-input`, no
#   model call) and reads the skills listed from the project .agents/skills root.
# Not run in CI: it needs harness credentials.
set -euo pipefail

SKILLS_CLI="skills@1.7.0"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${1:-$repo}"
source_root="${source_root%/}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
project="$work/project"
mkdir -p "$project"
git -C "$project" init -q

expected="$(find "$repo/skills" -mindepth 3 -maxdepth 3 -name SKILL.md \
  | awk -F/ '{print $(NF-2) "/" $(NF-1)}' | LC_ALL=C sort)"

(cd "$project" && npx -y "$SKILLS_CLI" add "$source_root" --skill '*' \
  -a claude-code -a codex --copy -y >"$work/install.log" 2>&1)

claude_loaded="$(cd "$project" && claude -p --model haiku --output-format stream-json \
  --verbose --setting-sources project --max-turns 1 "Reply with the single word ok." \
  </dev/null 2>/dev/null | head -1 | jq -r '.skills[]' | LC_ALL=C sort)"

codex_root="$(cd "$project/.agents/skills" && pwd -P)"
codex_prompt="$(cd "$project" && command codex debug prompt-input "ok" </dev/null 2>/dev/null)"
codex_ref="$(printf '%s' "$codex_prompt" | grep -o '`r[0-9]*` = `[^`]*`' \
  | awk -v root="$codex_root" -F'`' '$4 == root {print $2}' | head -1)"
codex_loaded="$( [ -n "$codex_ref" ] && printf '%s' "$codex_prompt" \
  | grep -o "(file: $codex_ref/[a-z0-9-]*/SKILL.md)" \
  | sed "s#(file: $codex_ref/##; s#/SKILL.md)##" | LC_ALL=C sort -u)"

fail=0
printf '%-15s %-28s %-8s %s\n' MODULE SKILL CLAUDE CODEX
while IFS=/ read -r module skill; do
  c=missing; x=missing
  grep -qx "$skill" <<<"$claude_loaded" && c=loaded
  grep -qx "$skill" <<<"$codex_loaded" && x=loaded
  [ "$c" = loaded ] && [ "$x" = loaded ] || fail=1
  printf '%-15s %-28s %-8s %s\n' "$module" "$skill" "$c" "$x"
done <<<"$expected"

if [ "$fail" -ne 0 ]; then
  echo "harness load proof FAILED (source: $source_root)"
  exit 1
fi
echo "harness load proof passed: $(grep -c . <<<"$expected") skills in both harnesses (source: $source_root)"
