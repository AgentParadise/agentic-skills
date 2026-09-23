# Agentic Skills

Portable skills for agent harnesses supported by the Vercel Skills CLI.

## Rules

- Keep canonical skills under `skills/<module>/<skill>/SKILL.md`.
- Every skill name must equal its leaf directory name and be globally unique.
- Keep scripts, references, assets, and resources inside the owning skill.
- A collection lists only skills in its matching module.
- Do not add hooks, secrets, workspace lifecycle code, or provider SDKs here.
- Prefer Rust for repository tooling.
- Pin external tooling and GitHub Actions versions.
- Run `cargo fmt --all --check`, `cargo clippy --all-targets -- -D warnings`, `cargo test`, and `cargo run -p agentic-skills -- validate` before committing.
- Do not use em dashes.
