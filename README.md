# Agentic Skills

Portable, modular agent skills installable into any harness supported by [Vercel Skills](https://github.com/vercel-labs/skills).

## Install one skill

```bash
npx -y skills@1.7.0 add AgentParadise/agentic-skills --skill review --agent codex --yes
```

The repository is private initially. Authenticate Git or GitHub CLI before installation.

## Install a module

Named collections preserve the former plugin modules while keeping every skill independently installable.

```bash
cargo run --quiet -p agentic-skills -- install sdlc --agent codex
```

Preview the exact pinned Vercel Skills command without executing it:

```bash
cargo run --quiet -p agentic-skills -- command sdlc --agent codex --ref v0.1.0
```

Available collections:

```bash
cargo run --quiet -p agentic-skills -- list
```

## Layout

```text
skills/<module>/<skill>/SKILL.md
collections/<module>.json
crates/agentic-skills/
```

Canonical content came from Agentic Primitives with filtered commit history. Runtime hooks and workspace infrastructure are intentionally excluded.
