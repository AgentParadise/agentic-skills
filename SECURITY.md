# Security Policy

## Reporting a vulnerability

Please report security issues **privately**, through GitHub's private
vulnerability reporting on this repository: open the **Security** tab and choose
**Report a vulnerability**. That keeps the report confidential until a fix is
available.

Please do not open a public issue for a vulnerability, and please do not
disclose it elsewhere before a fix ships.

We aim to acknowledge a report within a few days.

## What is in scope

This repository contains **skills**: Markdown instructions, plus a small number
of shell and Python helper files, that an AI agent reads and may execute. The
interesting risks are therefore about what a skill causes an agent to do:

- a skill that instructs an agent to exfiltrate data, weaken a security
  control, or run something destructive
- a helper script with a command-injection or path-traversal flaw
- an instruction that would lead an agent to commit a credential, or to print
  one into a transcript
- a supply-chain problem in the tooling these skills install

## What is not in scope

- An agent choosing to do something unsafe that no skill here told it to do.
- Findings that require an already-compromised host or an already-leaked
  credential.
- The example hostnames, paths and keys used throughout these skills as
  placeholders. They are deliberately fictional: `example.com`,
  `/path/to/...`, `/Users/yourname/...` and `example-vps` are not real
  targets.

## Supported versions

Only the latest commit on `main` is supported. There are no backports.
