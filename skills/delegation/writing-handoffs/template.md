<!--
Handoff template. Copy this file, fill every <placeholder>, and write the result
to docs/handoffs/YYYYMMDD-handoff_<name>.md (path configurable; <name> defaults
to the branch slug). Aim for 100-300 lines; 1000 is the hard ceiling. Reference
artifacts by path/URL; do not duplicate them. Redact secrets and PII. Delete
this comment in the finished doc.
-->

# Handoff: <title>

**Date:** YYYY-MM-DD
**Repo:** <url>   **Branch:** <branch>
**Status:** <in-progress | blocked | ready-for-review>

## Session & Agent Identity

- **Harness:** <Claude Code | Codex | other>
- **Session ID:** <value of $CLAUDE_CODE_SESSION_ID or $CODEX_THREAD_ID, or `unknown`: why>
- **Transcript:** <~/.claude/projects/<cwd-slug>/<id>.jsonl | ~/.codex/sessions/YYYY/MM/DD/rollout-*-<id>.jsonl>
- **Agent name/address:** <how peers address this agent, or `none`>

## Pickup Instructions (for the receiving agent)

Do these before other work, without waiting for the user:

1. Verify branch and `git status` match this header; note drift.
2. Message each peer in **Peer Agents** over its channel: "I am <your
   name/ID>, the new agent picking up from <agent name/address above>. I am
   not that agent; it has handed off. Please continue this thread with me.
   Open item: <thread>."
3. If context is missing, search the transcript above by session ID before
   asking the user.
4. Invoke **Suggested Skills**, then continue from **Current State**.

## Peer Agents

<Every agent this session was messaging that is still relevant, or `none`.
Copy names/IDs exactly as the channel addresses them.>

| Name / ID | Channel | Role | Open thread | Waiting on / owed |
|-----------|---------|------|-------------|-------------------|
| <name> | <SendMessage / NTM / agent mail / codex exec> | <role> | <topic> | <state> |

## Purpose & Vision

<The why: what this work is for and the end goal it serves. One short
paragraph. If a PRD/spec covers this, summarize in two sentences and link it.>

## Current State

<What's done, what's in flight, what's next. A short bulleted list the next
agent can act on immediately.>

## Files Affected

<One line per path describing its role in this change. Reference the diff
(`git diff <base>`) rather than pasting it.>

- `path/to/file`: <role / what changed and why>

## Rationale & Key Decisions

<Why it was built this way. Decisions made, alternatives considered and
rejected, and the reasoning. This is the context a fresh agent cannot
reconstruct from the diff.>

## Do's and Don'ts (learned this session)

<Hard-won, session-specific guidance.>

- **Do:** <…>
- **Don't:** <…: dead ends, things that looked right but weren't>

## Important Context to Keep in Mind

<Constraints, environment quirks, flaky steps, ordering requirements: anything
non-obvious that will bite the next agent.>

## Suggested Skills

<Skills the next agent should invoke on pickup, with a word on why.>

- `<skill-name>`: <why>

## References

<PRDs, ADRs, specs, plans, issues, PRs: by path or URL. Do not duplicate their
content here.>

- <path-or-url>: <what it is>
