# OPSEC audit YYYY-MM-DD

Machine: <os/version>, managed: <yes/no>, tools: <present / missing>. No secret values in this file.

## TLDR

| Area | Status | One line |
|---|---|---|
| 1 Incidents | | |
| 2 Mesh/VPN | | |
| 3 This machine | | |
| 4 Other hosts | | |
| 5 Agent guardrails | | |
| 6 Dependencies | | |
| 7 Secrets | | |

### Top 5 actions (ranked)
1. <exact command or click path, target version, why>

## 1. Incidents
| Item | Date | Touches us? (evidence) |
Sources: <links>

## 2. Mesh/VPN
| Node | OS | Owner/tags | State | Key expiry | Notes |

## 3. This machine
Posture, pending updates, exposure, persistence (new in 14d), installs, extensions, infostealer indicators.

## 4. Other hosts
Per host: OS, exposed listeners, firewall, pending security updates, reboot, sshd, containers.

## 5. Agent guardrails
| Host | Harness | Mode (bypass?) | Guard + version | Self-test | Fails closed |

## 6. Dependencies
| Repo | Vuln groups | Worst (KEV first) |

## 7. Secrets
Rule / file / line only. Triage notes for high-signal hits.

Password manager checklist:
- [ ] 2FA on the account, second factor not stored only inside the vault
- [ ] Secret Key / recovery kit offline, location known
- [ ] Health report (e.g. Watchtower): compromised, reused, weak, 2FA-available items at zero
- [ ] Account recovery path set (recovery contact / admin)
- [ ] Authorized devices and CLI/SSH-agent approvals reviewed
- [ ] Current phishing lures for this vendor noted

## Not covered this run
<what and why: needs approval, tool missing, policy>
