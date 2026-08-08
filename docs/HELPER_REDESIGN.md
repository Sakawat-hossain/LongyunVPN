# macOS / Linux privileged-helper redesign

## Status

- **Done (shipped):** the Linux elevation no longer passes the admin password on a
  shell command line. It now uses **pkexec** (polkit), so the system auth agent
  collects the password and the app never sees it or exposes it via `/proc`
  (`lib/common/system.dart`, `authorizeCore`). macOS already used the secure
  `osascript … with administrator privileges` dialog (no command-line password).
- **Not done (this doc):** removing the **setuid-root core** itself. Both macOS and
  Linux still do `chmod +sx` on the Go core, so the large core binary runs as root
  for any local user. Replacing that with a privileged helper daemon is the real
  redesign — and it must be built and tested on the target OS, because if it breaks,
  TUN won't start at all and there's no in-app toggle to recover.

## Why setuid is the problem

`authorizeCore` does `chown root … && chmod +sx <core>`. That leaves a ~30 MB Go
binary setuid-root: any local user can execute it as root, and any code-exec bug in
the core is an instant local privilege escalation. Windows already avoids this — it
runs a tiny **privileged helper service** that launches the core as admin over an
authenticated localhost IPC. macOS/Linux should adopt the same model.

## Target architecture (mirror the Windows helper)

The Rust helper in `services/helper/` already has a non-Windows code path:
`main.rs` runs `run_service()` (the same warp server, now token-authenticated — see
`hub.rs`) when the `windows-service` feature is off. So most of the daemon already
exists; the work is packaging and wiring it as a root daemon on Unix.

1. **Run the helper as root via the OS service manager**
   - **macOS:** a LaunchDaemon plist in `/Library/LaunchDaemons/com.longyunvpn.helper.plist`
     (`RunAtLoad`, `KeepAlive`), helper binary in `/Library/Application Support/LongyunVPN/`.
   - **Linux:** a systemd unit `longyunvpn-helper.service` (`User=root`,
     `WantedBy=multi-user.target`), helper binary in `/usr/local/lib/longyunvpn/`.
2. **One-time privileged install** (replaces the `chmod +sx` step in `authorizeCore`):
   copy the helper, write the plist/unit, `launchctl bootstrap` / `systemctl enable --now`.
   Run this once through the existing elevation (`osascript` on macOS, `pkexec` on Linux).
3. **IPC:** switch the helper's transport from a TCP port to a **Unix domain socket**
   with restrictive ownership/permissions (root:staff / mode 0660) so only the app's
   user group can talk to it. Keep the `Authorization: <core SHA256>` token check
   already implemented in `hub.rs`. (TCP-on-loopback also works but a permissioned
   Unix socket is stronger on multi-user machines.)
4. **Dart client:** on Unix, route `CoreService.start()` through the helper exactly
   like Windows does today (`request.startCoreByHelper` / `stopCoreByHelper`), instead
   of `Process.start(core)`. The `authorizeCore`/`checkIsAdmin` desktop branches
   become "is the helper installed & healthy?" (mirror `windows.checkService`).
5. **Build:** have `build_tool` produce the Unix helper (`helperName`) alongside the
   core, and bundle it in the `.app` / `.deb` / AppImage / rpm.
6. **Migration & uninstall:** on first run of the new build, `chmod -s` the old core
   to drop the setuid bit; provide an uninstall that removes the daemon + files.

## Test plan (per OS, before shipping)

1. Fresh install → enable TUN → confirm the helper installs and the core starts as
   root (`ps -o user= -p <core pid>` shows `root`), and the app is **not** setuid.
2. Kill the core → confirm auto-reconnect still works through the helper.
3. Confirm a non-privileged local process **cannot** drive the socket without the
   token, and cannot read it (socket perms).
4. Uninstall → confirm daemon and files are gone and normal networking is restored.

## Priority

Medium-high (security), but **do not ship without the per-OS test pass above** — a
broken helper means the VPN can't start. The pkexec fix already closes the most
concrete issue (password exposure); the setuid removal is the architectural follow-up.
