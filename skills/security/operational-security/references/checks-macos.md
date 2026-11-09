# macOS read-only checks

Run as the user. Commands needing root or TCC (Automation, Full Disk Access) are marked; on failure, note "needs operator" and move on.

## Posture
```bash
sw_vers
fdesetup status
/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate --getstealthmode --getallowsigned
spctl --status
csrutil status
softwareupdate --list          # slow; background with a timeout
defaults read /Library/Preferences/com.apple.SoftwareUpdate | grep -Ei 'Automatic|Critical|ConfigData'
profiles status -type enrollment   # MDM
launchctl print-disabled system | grep -Ei 'ssh|screensharing|smbd'   # remote services
```

## Exposure
```bash
lsof -nP -iTCP -sTCP:LISTEN | awk 'NR>1{print $1,$2,$3,$9}' | sort -u -k4
lsof -nP -iUDP | grep -v -E '127.0.0.1|\[::1\]|->'
```
Flag listeners on `*`/`0.0.0.0` and on mesh IPs; name the owning process.

## Persistence
```bash
ls -lT ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons
find ~/Library/LaunchAgents /Library/LaunchAgents /Library/LaunchDaemons -newermt "$(date -v-14d +%F)" -type f
plutil -extract ProgramArguments json -o - <plist>    # what each new item runs; mask tokens/keys in args before quoting
launchctl list | awk '$3 !~ /^com\.apple\./'
sudo sfltool dumpbtm                                   # login items / BTM (root)
```
Flag: items running from /tmp, /Users/Shared, hidden dirs, `sh -c curl ...`, unsigned binaries, remote-access tools (RustDesk, AnyDesk, TeamViewer, ScreenConnect, Chrome Remote Desktop) the operator did not mention.

## Installs and downloads
```bash
system_profiler SPInstallHistoryDataType -json | jq ...    # last 14d
find /Applications ~/Applications -maxdepth 1 -name '*.app' -newermt <date>
sqlite3 ~/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2 \
  "select datetime(LSQuarantineTimeStamp+978307200,'unixepoch'), LSQuarantineAgentName from LSQuarantineEvent order by 1 desc limit 40"
```

## Browser extensions
Chromium family: `~/Library/Application Support/<Browser>/<Profile>/Extensions/<id>/<ver>/manifest.json` (resolve `__MSG_` names via `_locales/en*/messages.json`). Use `setopt nullglob` in zsh. Flag wallets sharing a profile with broad-permission or monetized extensions, and extensions with known ownership changes.

## Infostealer indicators (AMOS, MacSync, SHub class)
```bash
ps axo pid,user,args | grep -Ei 'osascript|curl .*\| *(ba|z)?sh|base64 -d|/tmp/|/Users/Shared/' | cut -c1-160   # args can hold credentials: mask before quoting
find /tmp /private/var/tmp /Users/Shared ~/Library/Application\ Support -maxdepth 2 -name '.*' -type f -perm -u+x
ps axo comm= | sort -u | grep '^/' | while read p; do codesign -v "$p" 2>/dev/null || echo "$p"; done
```
Also: unexpected `.dmg`/`.pkg` in Downloads, password prompts from osascript reported by the user, new LaunchAgents with random names.
