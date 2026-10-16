---
name: writing-handoffs
description: Use when you need to compact the current conversation into a handoff document so a fresh session or agent can continue a branch or task with full context. Trigger phrases include "write a handoff", "hand this off", "compact this for a fresh agent", "handoff doc", "summarize this branch's context", "I'll pick this up later", "create a handoff for the next session". Also use when picking up a handoff ("pick up this handoff", "continue from this handoff", "resume from handoff"). Produces a structured Markdown doc (from a template) capturing purpose, current state, files affected, rationale, do's-and-don'ts learned, suggested skills, the writer's own session ID (Claude Code or Codex) for transcript search, and any peer agents it was messaging so the next agent can re-introduce itself and continue those threads. Do NOT use to author PRDs, ADRs, plans, or specs; those are separate durable artifacts that a handoff references by path, not reproduces. Do NOT use for a routine end-of-task summary message; a handoff is a written file for a different session to load.
placement: "Domain skill. Lives at `skills/delegation/writing-handoffs/` in agentic-skills; install with `npx skills add AgentParadise/agentic-skills --skill writing-handoffs`. NOT a meta skill."
---

# Writing Handoffs

## Purpose

Invoke this skill when a conversation has accumulated context that a fresh
session or another agent will need to continue the work: typically when you're
pausing a branch, switching machines, hitting a context limit, or handing a task
to a teammate's agent.

A handoff is the agent's own compaction: a written file that preserves the
**irrecoverable context**: *why* the work is shaped the way it is, what was
tried and abandoned, the gotchas learned along the way. A fresh agent can read
the diff and the commits; it cannot reconstruct the reasoning. That reasoning is
what this document carries.

## Procedure

1. **Gather context from the repo, not from memory.** Run, don't recall:
   - `git rev-parse --abbrev-ref HEAD`: current branch
   - `git remote get-url origin`: repository URL
   - `git status --short` and `git diff --stat`: files touched
   - `git log --oneline -10`: recent commits
   Use these to fill the factual header fields exactly.

2. **Record your own session identity.** The next agent uses it to search your
   transcript when the handoff is not enough. Read it, don't guess:
   - Claude Code: `echo "$CLAUDE_CODE_SESSION_ID"`. Transcript:
     `~/.claude/projects/<cwd-slug>/<session-id>.jsonl` (slug is the cwd with
     `/` and `.` replaced by `-`).
   - Codex: `echo "$CODEX_THREAD_ID"`. Transcript:
     `~/.codex/sessions/YYYY/MM/DD/rollout-*-<thread-id>.jsonl`.
   - Also record your own agent name or address if peers know you by one
     (for example a `ListAgents` row name, an NTM pane, an agent-mail handle).
   - If no ID is available, write `unknown` and say why. Never invent one.

3. **Record peer agents.** If this session used agent-to-agent messaging
   (`SendMessage`/`ListAgents`, NTM, agent mail, a workflow, a delegated
   `codex exec` or `claude -p` run), list every peer still relevant: its
   name or ID exactly as the channel addresses it, the channel, its role,
   what the open thread is about, and what you were waiting on or owe it.
   Drop finished one-shot delegates unless their transcript matters. This is
   what lets the next agent continue those conversations without the user
   relaying anything.

4. **Resolve the output path.**
   - Default: `docs/handoffs/YYYYMMDD-handoff_<name>.md`
   - `<name>` **defaults to the current branch slug** when the user does not
     supply one (e.g. on branch `handoff-skill` →
     `docs/handoffs/20260608-handoff_handoff-skill.md`).
   - The path is **configurable**: if the user names a different directory,
     file name, or descriptor, honor it. Create the directory if it is missing.

5. **Fill the template.** Copy `template.md` (in this skill directory) and
   replace every placeholder with real content drawn from the conversation and
   the gathered git facts.

6. **Write the file and report the path back** so the user can open or commit it.
   If peers are listed, tell each one a handoff is coming and that a new agent
   will contact them (optional but cuts confusion).

## Picking Up a Handoff

When you are the receiving agent, the handoff is your full brief. Do not ask
the user to restate it.

1. Read the whole handoff and every path it references that you need.
2. Verify repo facts (`git status`, branch, `git log`) still match the header.
   Note any drift before acting.
3. **Re-introduce yourself to each listed peer** over the listed channel, using
   the exact name or ID given. Say, in substance: "I am <your name/ID>, the new
   agent picking up from <previous agent name/ID>. I am not <previous agent>.
   It has handed off; please continue this thread with me. Last open item:
   <thread summary>." Skip peers that are no longer reachable and note that.
4. If context is missing, search the previous session transcript by its
   recorded ID before asking the user.
5. Invoke the Suggested Skills, then continue from Current State.


## Discipline (the rules that make a handoff worth reading)

- **Don't duplicate existing artifacts.** PRDs, plans, ADRs, specs, issues,
  commits, and diffs already exist: reference them by path or URL. Re-pasting
  them bloats the doc and goes stale.
- **Redact secrets.** No API keys, tokens, passwords, connection strings, or
  PII in the handoff. Replace with `<redacted>` and note where the real value
  lives (e.g. "in macOS Keychain under `…`").
- **Length: 1000-line hard ceiling, aim 100–300.** Concise beats exhaustive. A
  handoff nobody reads is worthless; trim anything the next agent can recover
  from the code itself.
- **Capture the irrecoverable, not the obvious.** Prioritize: the *why*,
  decisions and rejected alternatives, do's-and-don'ts learned this session,
  dead ends, non-obvious constraints and environment quirks. Skip restating what
  the diff plainly shows.
- **Always include Suggested Skills** so the next agent knows what to invoke on
  pickup.
- **Always include Session & Agent Identity and Peer Agents** (write `none` if
  there were no peers). IDs must come from the environment or the channel's
  own listing, copied exactly.

## Template

See `template.md` in this directory. Sections:
Title · Date · Repo/Branch/Status · Session & Agent Identity · Pickup
Instructions · Peer Agents · Purpose & Vision · Current State · Files Affected ·
Rationale & Key Decisions · Do's and Don'ts · Important Context · Suggested
Skills · References.
