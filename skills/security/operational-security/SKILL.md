---
name: operational-security
description: Use to run a read-only operational security (OPSEC) audit of the operator's own machines and accounts and write a dated RED/AMBER/GREEN report with ranked fixes - recent security incidents that touch the local stack, this computer's posture (disk encryption, firewall, OS updates, persistence, listening ports, browser extensions, infostealer indicators), AI-agent guardrails (a mechanical destructive-command guard hooked into every coding-agent harness), other owned hosts over existing ssh, VPN/mesh (Tailscale) devices, dependency vulnerabilities, plaintext secrets and password-manager hygiene. Works on macOS, Linux and Windows and on managed work computers. Trigger phrases include "opsec audit", "daily security check", "security sweep", "am I compromised", "check my machine for malware", "infostealer check", "what's exposed", "audit my tailnet", "are my agents guarded", "destructive command guard", "scan for leaked secrets", "any incidents affecting me", "security posture report", "run the opsec skill". Do NOT use for reviewing a code diff or PR for vulnerabilities (use a code security review), for pentesting or scanning networks or hosts you do not own, for incident response on a confirmed breach (escalate to humans / the security team), or for hardening changes (this skill only proposes fixes).
---

# Operational security audit

## Overview

Given a machine (and optionally a local inventory of other owned hosts and repos), produce `reports/YYYYMMDD.md`: TLDR with RED/AMBER/GREEN per area, the top 5 actions ranked, then evidence per area. The run is read-only. It discovers the environment at run time, so the same skill works on a personal laptop, a homelab and a corporate machine. Everything machine-specific lives in the operator's inventory file, never in this skill.

## Outcomes we are looking for

### Outcome 1: the operator knows today's real risk in under a minute
- *Signal:* the TLDR table and top-5 list fit on one screen and each action is a copy-pasteable command or a precise click path.
- *Signal:* every RED is something exploitable or already exploited; noise (test fixtures, dev-only deps) is triaged down, not forwarded.

### Outcome 2: the audit never becomes the incident
- *Signal:* nothing was changed, restarted, rotated, uninstalled or pushed; no secret value appears in the report, transcript or scratch files.
- *Signal:* on a managed machine, nothing ran that the employer's policy would treat as scanning, tampering or exfiltration.

### Outcome 3: the skill stays portable
- *Signal:* the skill and its references contain no hostnames, IPs, usernames, repo paths or findings; a fresh machine runs it with only an inventory file.

## Before you start: environment discovery

Detect, do not assume. Record each answer at the top of the report.

1. **OS and version**: `uname -s` / `sw_vers` / `/etc/os-release` / PowerShell `Get-ComputerInfo`.
2. **Managed?** macOS `profiles status -type enrollment`; Windows `dsregcmd /status` (AzureAdJoined, MDM URL); Linux presence of EDR/agents (CrowdStrike `falcon-sensor`, SentinelOne, Defender `mdatp`, Jamf, Intune, osquery, Kandji, etc. in process list or launch items). See "Managed machines" below.
3. **Tools present**: `command -v` for AI coding agents (claude, codex, gemini, grok, cursor-agent, opencode, hermes, copilot), the guard (dcg or whatever replaced it), tailscale, docker/podman, osv-scanner, cargo-audit, npm/pnpm/bun, uv, pip-audit, gitleaks, trufflehog, op (1Password CLI), gh, lynis, ssh-audit. Missing tools become "not covered", not a failure; suggest the install in the report, do not install.
4. **Ecosystems**: find lockfiles under the inventory's repo roots (`Cargo.lock`, `package-lock.json`, `pnpm-lock.yaml`, `bun.lock`, `yarn.lock`, `uv.lock`, `poetry.lock`, `requirements*.txt`, `go.sum`, `Gemfile.lock`, `pom.xml`).
5. **Inventory**: read `${OPSEC_INVENTORY:-~/.config/opsec/inventory.toml}`. If missing, audit only this machine and offer to create one from `references/inventory.template.toml`.

## Workflow

Run independent checks in parallel; wrap slow ones (`softwareupdate`, scanners, ssh) in timeouts and background them. Never walk the whole home directory: scope file searches to the inventory's repo roots and config dirs, prune `~/Library` (macOS privacy-protected folders hang a walk for hours while it holds thousands of file handles), prefer the OS index (`mdfind -onlyin`) or `rg --files`, and kill anything still running when the audit ends. Anything that hangs waiting for a GUI/TCC/biometric prompt (osascript to System Events, `op`, 1Password ssh agent in BatchMode) is a "needs operator approval" note, not a retry loop.

1. **Incidents (last 24-48h)**. Web-search per stack component discovered in step 0: package registries present (npm, PyPI, crates.io, Go, Maven), GitHub Actions, the OS, password manager, VPN/mesh, container runtime, AI coding agents/CLIs in use, browsers. Separate searches per vendor; one combined query returns generic news. For each item: date, source link, and **does it touch us** (check the exact package/version in lockfiles, installed versions, images). Cross-check runtime versions against vendor security-release feeds (e.g. Node `dist/index.json` `security=true`).
2. **Mesh/VPN** (if Tailscale present): `tailscale status`, `status --json` (OS, online, LastSeen, KeyExpiry, tags, exit nodes), `serve status`, `funnel status`, `debug prefs`. Flag unknown device names, devices offline > 30d, untagged servers with key expiry disabled, any public Funnel, CLI/daemon version skew, versions below the latest bulletin fix.
3. **This machine**: `references/checks-macos.md`, `checks-linux.md`, `checks-windows.md`. Covers encryption, firewall, OS integrity, pending updates, listeners and owners, persistence (flag added in last 14d), recent installs, browser extensions, remote-access tools, infostealer indicators.
4. **Other owned hosts** (inventory `[[hosts]]`, existing ssh config only, `-o BatchMode=yes -o ConnectTimeout=10`): OS, exposed listeners (not loopback), firewall, pending security updates, reboot-required, unattended-upgrades, sshd effective auth settings, containers with published ports or docker.sock mounts, stale images. If the inventory names an owner agent/person to ask for access, ask; never guess credentials or keys.
5. **Agent guardrails**. Instructions and skills are probabilistic; an agent that can run shell commands can delete data even when told not to. Each harness found in step 0 needs a deterministic pre-execution hook that blocks destructive commands (recursive deletes, `git reset --hard`/`clean`/force push, `DROP`/`TRUNCATE`, volume/cluster/infra deletes, disk writes). For every harness on every host:
   - **Hooked?** Read its hook config (Claude `~/.claude/settings.json` plus enabled plugins' `hooks/hooks.json`, Codex `~/.codex/hooks.json`, Gemini `~/.gemini/settings.json`, Grok `~/.grok/hooks/`, others per the guard's docs). A harness with no guard is a finding.
   - **Evaluator works?** Feed the guard known-bad payloads directly (evaluation only, nothing executes), e.g. a Bash tool call for `rm -rf ./src` on stdin must be denied; repeat for `git reset --hard`, `docker volume rm x`, and an executable SQL-client call such as `psql -c 'DROP TABLE x'`. Run these with the guard's self-repair and update checks off (dcg: `DCG_NO_SELF_HEAL=1 DCG_NO_UPDATE_CHECK=1`) so the audit writes nothing.
   - **Harness enforces it?** A passing evaluator does not prove the harness calls it. Check the harness version meets the guard's documented minimum, the hook command path resolves to the pinned binary, the hook is trusted/enabled (some harnesses skip untrusted project hooks), and the guard's docs list no known bypass path for that harness. Without that evidence, mark the harness "integration unverified" (AMBER).
   - **Fails closed?** Malformed input, unverified evaluations and guard crashes must deny. Read the hook code and effective config (dcg: `general.fail_closed = true` and `unverified_decision = "deny"`; note it still allows on stdin I/O errors). An `except: pass  # allow` handler is AMBER.
   - **Coverage?** List the enabled rule packs, policy modes and allowlists. Database, container, cloud and Kubernetes packs are usually opt-in; a host running those tools without the pack is AMBER.
   - **Tamper-resistant?** The guard binary, its config and the harness hook files should not be writable by the agent user, or an agent can disable its own guard. Agent-writable guard files are AMBER.
   - **Pinned and owned?** Guard version pinned in IaC with a verified checksum or signature, self-update disabled, same version on every host.
   - **Permission mode**: note harnesses running in bypass/auto-approve mode; there the guard is the only control.
   A guard is one layer: agents can still write a script that deletes data, so least-privilege users, sandboxes and backups remain required. Read-only: report gaps, do not install or edit hooks.
6. **Dependencies**: `osv-scanner scan source -r --format json` per repo; then ecosystem tools only if already installed (`cargo audit`, `npm audit --omit=dev`, `pip-audit`). Avoid runners that download tools or sync environments (`uvx`, `uv run`, `npx`); if the tool is missing, mark the ecosystem not covered. Cross-reference CVE aliases against the CISA KEV feed. Rank: KEV > CVSS >= 9 in prod deps > dev-only. Note public repos separately.
7. **Secrets**: gitleaks with full redaction (`--redact=100`), or trufflehog with `--no-verification` (by default it sends found credentials to the provider's API to verify them) and its output reduced to detector, file and line before it reaches the transcript, over shell rc files, `~/.config`, registry rc files (`.npmrc`, `.pypirc`, `.netrc`, docker config), cloud CLI dirs, AI-agent dirs (session transcripts and shell snapshots often capture tokens), and repo history. Triage each high-signal hit (cloud keys, private keys, PATs, refresh tokens) by checking the masked line context; placeholders and fixtures are GREEN. Report rule, file and line only. Password manager: app/CLI version and the hygiene checklist in `references/report-template.md`.
8. **Report**: write `reports/YYYYMMDD.md` from `references/report-template.md`. If any area is RED, notify the operator through whatever channel the inventory's `[notify]` names; otherwise just tell them in the session.

## Grading

- **RED**: active compromise indicator; a compromised package/version actually installed; KEV-listed or remotely exploitable vuln on an internet-exposed service; plaintext credential in a public repo or world-readable place; unknown device in the mesh; public exposure nobody intended; an agent harness in bypass/auto-approve mode with no destructive-command guard.
- **AMBER**: missing security updates, stale exposed services, plaintext long-lived tokens on disk, unverified persistence or remote-access tools, critical CVEs in deps without known exploitation, areas that could not be audited; a guard that fails open, is unpinned, misses a harness, or fails a known-bad self-test.
- **GREEN**: checked, nothing actionable.

## Managed machines (work computers)

When step 0 finds MDM/EDR/domain join, the employer owns the security posture. Then: run only local, read-only, user-level checks on this machine; skip host/network sweeps beyond the inventory's explicitly owned targets; do not run secret scanners over employer repos or shared drives unless policy allows it; do not disable, probe or "test" the EDR; do not upload findings, hashes or file lists to any third-party service. Anything that looks like compromise goes to the employer's security team per their process, not into a self-remediation list. Note "managed: defer to IT" in the TLDR.

## Anti-patterns

- Searching "security news today" once and reporting generic headlines; the operator needs "does it touch us", which only version checks answer.
- Forwarding raw scanner counts (hundreds of generic-api-key hits) without triage; the operator stops reading.
- Printing a secret to "prove" a finding; masking after the fact does not unprint it from the transcript.
- Hardcoding hostnames or repo paths into the skill; the next machine silently audits nothing.
- Retrying an approval-gated command in a loop; it is an operator action, note it and move on.
- Proposing fixes as vague advice ("update Node"); give the exact command and target version.
- Applying a "quick" runtime upgrade in place when the toolchain is pinned and owned by IaC or another team; it breaks their checks. Find the owner (IaC repo, version pin, managing agent/team) and route the bump there.

## Recommended tools and practices (as of 2026-11-08)

### For: the operator knows today's real risk
- **osv-scanner**: one tool across most lockfile formats; JSON output is easy to rank. Pair with the **CISA KEV** JSON feed for "known exploited".
- **gitleaks** (`dir` and `git` modes, `--redact=100`): fast, offline, redacts at source.
- Vendor feeds over aggregators for "is my version fixed": Tailscale security bulletins, Docker security announcements, Node.js dist index, GitHub Advisory DB.

### For: agents are mechanically stopped from common destructive commands
- Requirement, not product: every coding-agent harness on every host runs a deterministic pre-execution guard that blocks destructive commands and fails closed. Swap the implementation freely; keep the self-test. It narrows risk, it does not remove it: pair it with least-privilege agent users, sandboxes and backups.
- **Current pick: dcg** (`Dicklesworthstone/destructive_command_guard`, Rust). One binary and rule set hooks Claude Code, Codex, Gemini, Grok, Copilot, Cursor, OpenCode and Hermes; rule packs for git, databases, containers, k8s, cloud and disk; allow-once codes for human approval. Set `general.fail_closed = true`, `unverified_decision = "deny"`, and explicitly enable the packs for the tools each host runs (database, container, cloud and Kubernetes packs are opt-in).
- dcg is not low-dependency (~370 runtime crates, including a self-updater, an MCP server, a TUI and bundled SQLite). Mitigate: install a pinned release binary verified by its minisign/Sigstore signature through IaC, never self-update or pipe an installer to a shell, and run `cargo audit` on its `Cargo.lock` at each pin bump. License is MIT with a rider barring OpenAI/Anthropic entities.
- Rejected 2026-11-08: SigmaShake SSG (closed-source binary that sees every tool call, metered free tier, org created 2026-03).
- Harness-native hook plugins (e.g. a Claude-only PreToolUse plugin) are fine as a second layer but cover one harness each.

### For: the audit never becomes the incident
- Scratch output in a session temp dir, deleted with the session; reports contain rule/file/line only.
- `ssh -o BatchMode=yes` so nothing prompts or falls back to passwords.

### For: the skill stays portable
- `~/.config/opsec/inventory.toml` (override with `OPSEC_INVENTORY`) holds hosts, repo roots, notify channel and owner contacts.

## References

- `references/inventory.template.toml`: local inventory schema with comments.
- `references/checks-macos.md`, `references/checks-linux.md`, `references/checks-windows.md`: per-OS read-only command sets.
- `references/report-template.md`: report skeleton and password-manager checklist.

## Continual improvement

Canonical copy: `skills/security/operational-security` in the agentic-skills repo. Keep it portable: machine-specific hosts, findings and baselines belong in the operator's private inventory and report repo, never here.
