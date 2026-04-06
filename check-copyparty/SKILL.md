---
name: check-copyparty
description: End-to-end troubleshooting and recovery for Copyparty service issues on Linux, including boot autostart, process health, HTTP/FTP/SMB accessibility, Samba conflicts on port 445, credential mismatches, and post-change verification. Use when users report Copyparty cannot start after reboot, cannot be accessed, SMB login/share errors, or ask to run check_copyparty/check-copyparty diagnostics.
---

# Check Copyparty

Use this workflow to diagnose quickly, then apply the smallest safe fix and re-verify.

## 1) Baseline Snapshot

Run these first:

```bash
systemctl show copyparty.service -p LoadState -p ActiveState -p UnitFileState
systemctl show smbd.service -p LoadState -p ActiveState -p UnitFileState
systemctl show napcat.service -p LoadState -p ActiveState -p UnitFileState
systemctl cat copyparty.service
ss -lntup | rg -n '(:3923|:2121|:445|copyparty|smbd)'
journalctl -u copyparty.service -n 150 --no-pager
```

Interpret:

- `UnitFileState=enabled` means autostart on reboot is configured.
- `ActiveState=active` means currently running.
- `:3923` should be Copyparty HTTP/WebDAV.
- `:2121` should be Copyparty FTP when enabled.
- `:445` should be owned by only one stack: either Copyparty SMB or Samba `smbd`.

## 2) Fast Health Checks

```bash
curl -s -o /dev/null -w 'http_code=%{http_code}\n' -u <user>:<pass> http://127.0.0.1:3923/
```

If SMB is required, test login/share listing:

```bash
python3 - <<'PY'
from impacket.smbconnection import SMBConnection
from impacket import smb3structs

host='127.0.0.1'
user='<user>'
pwd='<pass>'

c=SMBConnection(host, host, sess_port=445, preferredDialect=smb3structs.SMB2_DIALECT_311, timeout=5)
c.login(user, pwd)
print('dialect', hex(c.getDialect()))
print('shares', [s['shi1_netname'][:-1] for s in c.listShares()])
c.logoff()
PY
```

## 3) Symptom-to-Fix Playbook

### A) Service does not autostart

```bash
sudo systemctl enable copyparty.service
sudo systemctl enable smbd.service
sudo systemctl disable nmbd.service samba-ad-dc.service
```

### B) Copyparty runs but SMB login fails

Check for `--usernames` in `copyparty.service`. With `--usernames`, effective SMB password can differ from expected plain password logic. Prefer native Samba when stable SMB2/SMB3 behavior is required.

### C) Port 445 conflict (Copyparty SMB vs Samba)

Pick one SMB owner:

- Keep Samba for native SMB2/SMB3: remove `--smb --smbw --smb-port 445` from Copyparty `ExecStart`.
- Or keep Copyparty SMB only: stop/disable `smbd`.

Then:

```bash
sudo systemctl daemon-reload
sudo systemctl restart copyparty.service smbd.service
ss -lntup | rg -n ':445'
```

### D) Need native SMB3 + simple password

Use Samba:

- Share name example: `share` (path `/home/<user>/share`)
- Credential: `<user>/<password>`
- Connect path: `\\<server-ip>\share`

Minimum Samba policy:

- `server min protocol = SMB2`
- `disable netbios = yes`
- `security = user`
- `valid users = <user>`

## 4) Safe Edit Rules

- Back up files before edits:
  - `/etc/systemd/system/copyparty.service`
  - `/etc/samba/smb.conf`
- After any unit edit, run `systemctl daemon-reload`.
- After any Samba config edit, run `testparm -s` before restart.

## 5) Exit Criteria

Consider issue closed only when all are true:

1. `copyparty.service` expected `UnitFileState`/`ActiveState` are correct.
2. `smbd.service` expected `UnitFileState`/`ActiveState` are correct.
3. No port conflict on `445`.
4. HTTP check on `3923` returns expected code.
5. SMB login + share listing succeeds when SMB is in scope.
