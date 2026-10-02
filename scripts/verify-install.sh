#!/usr/bin/env bash
# Install proof: every module, into Claude Code and Codex, diffed against source.
#
# Usage: scripts/verify-install.sh [SOURCE]
#   SOURCE  where `skills add` installs from. Defaults to this checkout.
#           A GitHub tree URL (for example
#           https://github.com/AgentParadise/agentic-skills/tree/v0.2.0)
#           proves a published ref; run it from a checkout of that same ref,
#           because installed files are compared against ./skills.
#
# For each module: installs with --skill '*' -a claude-code -a codex --copy,
# then asserts the installed set equals the module's skill set, each installed
# directory is byte-identical to its source (executable bits included), and
# each installed SKILL.md has parseable frontmatter whose name matches its
# directory. Also asserts whole-catalog discovery finds every skill.
set -euo pipefail

SKILLS_CLI="skills@1.7.0"
PYYAML="pyyaml==6.0.3"
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="${1:-$repo}"
source_root="${source_root%/}"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fail=0

strip_ansi() { sed $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g'; }
exec_files() { (cd "$1" && find . -type f -perm -u+x | LC_ALL=C sort); }

expected_total="$(find "$repo/skills" -mindepth 3 -maxdepth 3 -name SKILL.md | wc -l | tr -d ' ')"
dupes="$(find "$repo/skills" -mindepth 2 -maxdepth 2 -type d -exec basename {} \; | sort | uniq -d)"
if [ -n "$dupes" ]; then
  echo "FAIL duplicate skill names: $dupes"
  fail=1
fi

found="$(cd "$work" && npx -y "$SKILLS_CLI" add "$source_root" --list 2>&1 | strip_ansi \
  | sed -n 's/.*Found \([0-9][0-9]*\) skills.*/\1/p' | head -1)"
if [ "$found" = "$expected_total" ]; then
  echo "ok   catalog --list discovers $found/$expected_total skills"
else
  echo "FAIL catalog --list discovers '${found:-none}', expected $expected_total"
  fail=1
fi

printf '\n%-15s %-12s %-8s %s\n' MODULE HARNESS SKILLS RESULT
for module_dir in "$repo"/skills/*/; do
  module="$(basename "$module_dir")"
  consumer="$work/$module"
  mkdir -p "$consumer"
  log="$work/$module.log"
  if ! (cd "$consumer" && npx -y "$SKILLS_CLI" add "$source_root/skills/$module" \
      --skill '*' -a claude-code -a codex --copy -y >"$log" 2>&1); then
    echo "FAIL $module: install exited non-zero"
    strip_ansi <"$log" | tail -20
    fail=1
    continue
  fi
  expected="$(cd "$module_dir" && find . -mindepth 2 -maxdepth 2 -name SKILL.md \
    | sed 's#^\./##; s#/SKILL.md$##' | LC_ALL=C sort)"
  count="$(printf '%s\n' "$expected" | grep -c .)"
  for harness in claude-code codex; do
    case "$harness" in
      claude-code) dest="$consumer/.claude/skills" ;;
      codex) dest="$consumer/.agents/skills" ;;
    esac
    result=ok
    # Every entry under the destination, not only dirs holding SKILL.md, so a
    # stray or half-installed skill fails the set comparison.
    installed="$( [ -d "$dest" ] && (cd "$dest" && find . -mindepth 1 -maxdepth 1 \
      | sed 's#^\./##' | LC_ALL=C sort) )"
    if [ "$installed" != "$expected" ]; then
      echo "     $module/$harness installed set differs:"
      diff <(printf '%s\n' "$expected") <(printf '%s\n' "$installed") || true
      result=FAIL
    fi
    while IFS= read -r skill; do
      [ -n "$skill" ] || continue
      [ -d "$dest/$skill" ] || continue
      if [ ! -f "$dest/$skill/SKILL.md" ]; then
        echo "     $module/$harness/$skill has no SKILL.md"
        result=FAIL
      fi
      if ! diff -r "$module_dir$skill" "$dest/$skill" >/dev/null; then
        echo "     $module/$harness/$skill content differs from source"
        diff -r "$module_dir$skill" "$dest/$skill" | head -10 || true
        result=FAIL
      fi
      if [ "$(exec_files "$module_dir$skill")" != "$(exec_files "$dest/$skill")" ]; then
        echo "     $module/$harness/$skill executable bits differ"
        result=FAIL
      fi
    done <<<"$expected"
    if [ -d "$dest" ] && ! uv run --quiet --no-project --with "$PYYAML" python - "$dest" <<'PY'
import pathlib, sys, yaml
bad = 0
for skill_md in sorted(pathlib.Path(sys.argv[1]).glob("*/SKILL.md")):
    text = skill_md.read_text(encoding="utf-8")
    parts = text.split("---", 2)
    try:
        if not text.startswith("---") or len(parts) < 3:
            raise ValueError("no frontmatter block")
        meta = yaml.safe_load(parts[1])
        if not isinstance(meta, dict):
            raise ValueError("frontmatter is not a mapping")
        if meta.get("name") != skill_md.parent.name:
            raise ValueError(f"name {meta.get('name')!r} != dir {skill_md.parent.name!r}")
        if not isinstance(meta.get("description"), str) or not meta["description"].strip():
            raise ValueError("missing description")
    except Exception as exc:  # report every bad file, not only the first
        print(f"     frontmatter {skill_md}: {exc}")
        bad = 1
sys.exit(bad)
PY
    then
      result=FAIL
    fi
    [ "$result" = ok ] || fail=1
    printf '%-15s %-12s %-8s %s\n' "$module" "$harness" "$count" "$result"
  done
done

if [ "$fail" -ne 0 ]; then
  echo "install proof FAILED (source: $source_root)"
  exit 1
fi
echo "install proof passed (source: $source_root)"
