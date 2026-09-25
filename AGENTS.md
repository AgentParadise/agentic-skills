# Agentic Skills contributor guide

This repo is a catalog of agent skills. [Vercel Skills](https://github.com/vercel-labs/skills) discovers `SKILL.md` files and installs them into the chosen harness. There is no Cargo build or collection installer.

## Structure

- Put each skill at `skills/<module>/<skill>/SKILL.md`. A module folder is an installable group.
- Set the frontmatter `name` to the leaf directory name. Names must be unique across the repo.
- Keep scripts, references, assets, and resources inside the owning skill.
- To add a module, create `skills/<module>/` and list it in `README.md`. No manifest is needed.
- Keep workspace lifecycle, Docker images, exporters, hooks, provider SDKs, and secrets in their owning repos.

## Installation model

- `npx skills add AgentParadise/agentic-skills` discovers the whole catalog.
- `--skill <name>` selects one skill by its frontmatter name.
- A GitHub tree URL ending in `skills/<module>` limits discovery to that module. Add `--skill '*'` to install all of it.
- `-a claude-code`, `-a codex`, or another [supported agent](https://github.com/vercel-labs/skills#supported-agents) chooses the destination. Omit `-a` for interactive choice.
- `-g` installs across projects. Project installation is the default.

## Validate

Run `npx skills add . --list` for catalog discovery and `npx skills add ./skills/<module> --list` for one module. CI also installs a module into Claude Code, Codex, and Gemini CLI destinations.

Write harness-neutral instructions where possible. State any harness requirement inside the skill. Do not use em dashes.

- Never commit absolute home paths or real infrastructure hostnames. See [docs/PII-HYGIENE.md](docs/PII-HYGIENE.md).
