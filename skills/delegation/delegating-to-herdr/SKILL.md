---
name: delegating-to-herdr
description: Use when an orchestrator or PM agent needs to start, brief, watch or hand off long-running interactive agent sessions (Claude Code, Codex and others) in herdr panes, so work continues unattended while the operator can see every session in herdr's UI. Covers install, the start-a-session recipe (workspace, launch, wait for idle, prompt with a committed handoff), monitoring by agent state, guardrails for agent-started sessions, and failure modes. Trigger phrases include "herdr", "start a session in herdr", "kick off a session with a handoff", "spawn an orchestrator", "start the architect session", "run agents overnight", "herdr agent prompt", "herdr workspace create", "watch agent status", "is the agent blocked". Do NOT use for one-shot non-interactive runs (use `delegating-to-claude-p` or `delegating-to-codex`), for writing the handoff itself (use `writing-handoffs`), or for in-process subagents.
placement: "Domain skill. Lives at `skills/delegation/delegating-to-herdr/` in agentic-skills; install with `npx skills add AgentParadise/agentic-skills --skill delegating-to-herdr`. NOT a meta skill."
---

# Delegating to herdr

## Overview

[herdr](https://herdr.dev) is a terminal workspace for coding agents (Apache-2.0).
It runs a persistent server with workspaces, tabs and panes, recognises agents
running in panes, and exposes everything through a CLI and a local socket API.
That makes it the bridge between "an agent writes a handoff" and "a fresh,
long-lived session picks it up": an orchestrator can open a pane, start an
interactive agent, give it the handoff, then watch its state, while the human
sees and steers every session in herdr's UI.

`delegating-to-claude-p` and `delegating-to-codex` dispatch **one-shot** runs
that exit. This skill is for **interactive sessions that live for hours**:
orchestrators, leads, architects, reviewers that keep a context and talk to
peers.

## Outcomes we are looking for

1. **Work continues without the human in the loop.** *Signal:* a session
   started from a committed handoff reports to its orchestrator on its own,
   within minutes of launch, naming its session and first task.
2. **The human can always see and stop what runs.** *Signal:* every started
   session appears as a labelled workspace in herdr's UI; nothing runs
   headless where the human cannot reach it.
3. **Agent-started sessions are bounded and auditable.** *Signal:* each start
   is logged (who, when, which handoff, which pane), and the number of
   concurrent agent-started sessions never exceeds the agreed cap.
4. **No session starts from context that only lives in someone's head.**
   *Signal:* every launch prompt points at a handoff file committed to git.

## Install and check

```sh
brew install herdr            # prefer a package manager over curl | sh
herdr --version
herdr status                  # "server: status: running" means the socket is live
```

The human usually runs `herdr` once in a terminal, which starts the server and
its UI. The CLI then talks to that server over its socket
(`~/.config/herdr/herdr.sock`, or `--session <name>`).

Load herdr's own built-in agent guide with `herdr --skill`. It is the
authority for command syntax; this skill adds the orchestration pattern.

## Workflow: start a session from a handoff

1. **The handoff is committed.** Commit and push it before launch. An
   untracked handoff in a shared checkout can vanish in a cleanup.
2. **Open a labelled workspace in the right repo, without stealing focus:**

   ```sh
   R=$(herdr workspace create --cwd ~/Code/<repo> --label <role> --no-focus)
   P=$(echo "$R" | jq -r '.result.root_pane.pane_id')     # e.g. w3:p1
   ```

3. **Launch the agent in that pane.** The permission mode is the human's
   decision. Use the mode they already run their own sessions in; an
   unattended session in an approval-prompting mode stalls at the first
   prompt.

   ```sh
   herdr pane run "$P" "claude"            # add flags only as the human directs
   ```

4. **Wait until herdr sees the agent idle,** then name it so later commands
   can target a stable name instead of a pane ID:

   ```sh
   herdr agent get "$P" | jq -r '.result.agent.agent_status'   # wait for idle
   herdr agent rename "$P" <role>
   ```

5. **Brief it with the handoff and a check-in instruction:**

   ```sh
   herdr agent prompt <role> "Read <path/to/handoff.md> and start as <role>. \
   First message <orchestrator-session> with your session name. Priorities: ..."
   ```

   Put the current priorities in the prompt when they changed after the
   handoff was written. The handoff carries the irrecoverable context, and the
   prompt carries what is new.

6. **Log the start** wherever your program keeps its record (a capture, a
   handoff note, a bead comment): role, pane, handoff path, time.

## Watch without polling the model

```sh
herdr agent list                              # name, pane, idle|working|blocked|done|unknown
herdr agent wait <role> --until blocked       # returns when it hits an approval or question
herdr agent read <role> --lines 30            # recent terminal output
```

`blocked` means herdr recognised an approval or question UI. `idle` and `done`
mean it is ready for input. `unknown` proves nothing. Use these from shell
loops or event subscriptions (`events.subscribe` on the socket), never from a
model loop that rereads a long context every tick.

## Guardrails for agent-started sessions

Agree these with the human before the first launch, and restate them in each
launch prompt:

- **Role:** start orchestrators and leads, not implementers. Leads spawn their
  own workers, which keeps one accountable owner per lane.
- **Source:** only from handoffs committed to git.
- **Cap:** a fixed number of concurrent agent-started sessions (for example 4).
- **Record:** every start is logged; the human can see and stop each one in herdr.
- **Permissions:** never escalate beyond the human's stated mode, and never
  start a session to do something your own session was denied.

## Anti-patterns (observed)

- **The launch prompt refers to context that only the parent knows.** The new
  session starts confused and spends its first hour rediscovering it. Commit
  a handoff; reference it by path.
- **Prompting before the agent is idle.** The text lands in the shell or a
  boot screen and is lost. Wait for `idle` first.
- **Driving herdr from an agent that isn't inside it, without the human's
  approval.** herdr's own guide tells agents outside a herdr pane to stop. The
  socket has no password, so outside control is technically possible, and it
  needs explicit human approval.
- **Watching sessions with a model polling loop.** A 30-minute cron that
  rereads a huge context each tick burns budget for nothing. Use
  `agent wait`, event subscriptions or a plain shell loop.
- **Reusing a session name and assuming continuity.** A replacement session
  may reuse a name (for example `dream-ship-v0-17`), but it is a new context.
  Confirm it read the handoff before treating it as the old owner.

## Recommended tools and practices (as of 2026-10-17)

### Outcome: work continues without the human

- **`herdr workspace create --cwd --label --no-focus` + `pane run` + `agent prompt`**
  as one recipe. Serves outcome 1, because it gives every lead a stable,
  labelled home and a deterministic briefing.
- **A check-in line in every prompt** ("first message <orchestrator> with your
  session name"). Serves outcome 1: the orchestrator learns the new address
  without polling.

### Outcome: the human can see and stop everything

- **herdr's UI plus `agent list`.** Serves outcome 2: one view of every pane
  and its state.
- **Homebrew install (herdr 0.9.x).** Serves outcome 2 by keeping installs
  updatable through the package manager rather than a piped script.

### Outcome: bounded and auditable

- **A start log in the program's own record** (KMS capture or bead comment).
  Serves outcome 3: an audit trail that outlives the session.
- **A usage pager** (for example an ntfy page when the weekly budget runs
  low). Serves outcome 3: overnight sessions spend real budget, and the human
  needs a page before it runs out, not after.

## References

- herdr docs: https://herdr.dev/docs/ (socket and CLI API: `/docs/socket-api/`)
- `herdr --skill`: herdr's built-in agent guide, the syntax authority
- [`writing-handoffs`](../writing-handoffs/SKILL.md): what the handoff must carry
- [`delegating-to-claude-p`](../delegating-to-claude-p/SKILL.md), [`delegating-to-codex`](../delegating-to-codex/SKILL.md): one-shot peers
