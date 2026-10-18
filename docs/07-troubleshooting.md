# 7. Troubleshooting

Every problem below actually happened during the build of this setup.

## Pi and OS

| Symptom | Cause | Fix |
|---|---|---|
| Booting from a USB stick still loads the old system | Boot order puts NVMe/SD first | `sudo rpi-eeprom-config --edit` → `BOOT_ORDER=0xf614`, reboot ([doc 1](01-prepare-the-pi.md)) |
| `raspi-config` "USB boot" doesn't help on Pi 5 | Its option groups NVMe and USB with NVMe first | Edit `BOOT_ORDER` directly |
| Black screen "trying USB" on every boot, then NVMe | USB still first | `raspi-config` → Boot Order → **NVMe/USB Boot**; check `rpi-eeprom-config` ends in `6` |
| Imager doesn't list the SSD | It's marked as a system drive | Untick **Exclude system drives**, type the drive name to confirm |
| Windows offers to format the freshly written stick | Windows can't read the Linux partition | Click **Cancel** |
| Forgot the sudo password | | Try `sudo -n true && echo NO_PASSWORD`: often none is needed |
| Can't type `~` over VNC | Dead key or wrong keyboard layout | Press `~` then Space, set the layout in Control Centre, or use `$HOME` |
| `scp`/`ssh` refused | SSH disabled | `sudo systemctl enable --now ssh` |
| VNC viewer asks for an account | RealVNC Viewer requires one now | Use **TigerVNC Viewer** |

## Server install

| Symptom | Cause | Fix |
|---|---|---|
| No `run.sh` after mrpack-install, only `server.jar` | mrpack-install deployed vanilla, not NeoForge | Install NeoForge with the version from the pack's `modrinth.index.json` ([doc 2](02-install-the-server.md)), or use `install-server.sh` |
| `grep` on `modpack.json` finds every mod | Mod file names contain "neoforge" | Read `modrinth.index.json` from the `.mrpack` instead |
| Crash: `Attempted to load class ... for invalid dist DEDICATED_SERVER` | Client-only mod on the server | `bash scripts/find-broken-mods.sh <server-dir>` |
| `grep: ... binary file matches` | Crash report has odd characters | `grep -a` |
| Player: *Channel of mod "X" failed to connect: missing on the server side* | Server lacks mods the client has | `scripts/sync-missing-mods.ps1` ([doc 2](02-install-the-server.md#problem-2-players-get-channel-of-mod-x-failed-to-connect-missing-on-the-server-side)) |
| No GUI window without `nogui` | Headless Java has no GUI libraries | Expected. Use the console or Crafty |
| Big red `packanalytics` stack trace | Mod can't reach its stats server | Harmless; can be moved to `mods-disabled/` |
| Repeated `Connection reset by peer` / `PacketEncoder` errors | Crafty's periodic status checks (and open server lists) are logged by the Connectivity mod; a server started outside Crafty shows it only once | Harmless; filter the log view ([doc 5](05-extras-and-tuning.md#quieter-console)) |
| `randomenchantfix-common.toml is not correct. Correcting` repeating non-stop | Server still missing mods the client has | Run `sync-missing-mods.ps1`; afterwards it appears at most once at startup |

## Crafty

| Symptom | Cause | Fix |
|---|---|---|
| `ERR_CONNECTION_RESET` on port 8443 | Using http | Use **https**://...:8443 |
| Import only offers a zip | That's how Crafty 4 imports | Zip the server folder **contents** (`zip -r ../x.zip .`), root dir = top level |
| Metrics stuck at 0% | Start command is `bash run.sh` | Use the `java @user_jvm_args.txt @libraries/.../unix_args.txt nogui` line |
| Server "won't start" after a port change | `server-port` in `server.properties` still old | Make Crafty's port and `server-port=` match |
| Files added over SSH ignored or unreadable | Owned by root | `sudo chown crafty:crafty <file>` |
| High CPU on the Pi | A browser on the Pi with the panel open | Open the panel from your PC instead |

## Connecting

| Symptom | Cause | Fix |
|---|---|---|
| Friend sees the server, then **Failed to log in: Invalid session** | Stale login in the launcher | Fully quit game + Modrinth App, sign the account out and in again in the Modrinth App; check the PC clock is set automatically; confirm the account can join any public server from the official launcher |
| **Can't connect to server**, but ping to `100.x.y.z` works | Friend's Tailscale isn't connected; ping answered by something else | `Test-NetConnection 100.x.y.z -Port <port>` must show `InterfaceAlias : Tailscale`. Open Tailscale, log in, *Connected* ([doc 4](04-vpn-access.md#verify-from-the-friends-pc)) |
| `TcpTestSucceeded : False` via Tailscale | ACL blocks the port, or wrong port | Rule must allow `tcp:<server-port>` to the Pi's IP |
| Tailscale rule shows "invalid address" | Machine name typed as text | Use the Pi's 100.x IP |
| Address without port fails | Non-default port | `ip:port` in the server list |
| Skins not showing | `online-mode=false` | Use `online-mode=true` (changes player UUIDs, so do it before playing) |

## Gameplay

| Symptom | Fix |
|---|---|
| `/sethome` says limit reached | Raise `max` in `config/ftbessentials.snbt` ([doc 5](05-extras-and-tuning.md#homes-teleport-requests-back-spawn-ftb-essentials)) |
| Lag when exploring new areas | Pre-generate with Chunky |
| Low client FPS with shaders | Lower render distance and shader shadow settings ([doc 6](06-player-setup.md#client-performance-tips)) |
