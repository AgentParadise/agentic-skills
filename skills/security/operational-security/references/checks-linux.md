# Linux read-only checks (local or over ssh)

Prefer commands that work without sudo; use `sudo -n` so nothing prompts.

## Posture
```bash
cat /etc/os-release | grep PRETTY; uname -r; uptime
lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINT | grep -i crypt      # disk encryption
systemctl is-active ufw nftables firewalld fail2ban
sudo -n ufw status 2>&1 | head
apt list --upgradable 2>/dev/null | grep -c upgradable     # dnf check-update / pacman -Qu on others
apt list --upgradable 2>/dev/null | grep -- -security
[ -f /var/run/reboot-required ] && echo REBOOT-REQUIRED
systemctl is-enabled unattended-upgrades
```

## sshd effective config
`sudo -n sshd -T | grep -E '^(passwordauthentication|permitrootlogin|pubkeyauthentication) '`. Without sudo: `grep -n` sshd_config and `sshd_config.d/*`; first value wins and the `Include` line position decides order.

## Exposure
```bash
ss -tlnpH | awk '{print $4,$6}' | grep -v -E '^(127\.|\[::1\])'
ip -4 -o addr | awk '{print $2,$4}'     # is there a public address?
```

## Containers
```bash
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}'
docker inspect --format '{{.Name}} priv={{.HostConfig.Privileged}} {{range .Mounts}}{{.Source}} {{end}}' $(docker ps -q) | grep -E 'priv=true|docker.sock'
```
Flag ports published on `0.0.0.0`, privileged containers, docker.sock mounts, images far behind upstream (databases, caches, dashboards).

## Persistence and indicators
```bash
systemctl list-unit-files --state=enabled --no-pager
find /etc/systemd/system ~/.config/systemd/user /etc/cron* /var/spool/cron -newermt "-14 days" -type f 2>/dev/null
cat ~/.ssh/authorized_keys | awk '{print $1, $NF}'      # key types + comments only
last -n 20; journalctl -u ssh --since -2d | grep -c 'Accepted'
```
