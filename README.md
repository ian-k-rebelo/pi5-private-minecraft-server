# Private Modded Minecraft Server on a Raspberry Pi 5

Host a **modded Minecraft Java server** (a full Modrinth modpack such as Better MC) on a **Raspberry Pi 5** and play with friends, **without exposing anything to the internet**.

Most guides tell you to open port 25565 on your router. This one doesn't. The server is reachable only from your home network and from a **private VPN**, and your friends can reach **the game port and nothing else** on the Pi. Security is the starting point of the design, not an add-on.

This repo is a tested, step-by-step guide plus a few helper scripts. It was written while setting up a real server for two players, including every problem that came up and how it was fixed.

```
 Friend's PC ──┐                       ┌───────────── Raspberry Pi 5 ─────────────┐
               │   Private VPN         │  Crafty Controller  (web panel, :8443)    │
 Your PC ──────┼──────────────────────►│     └─ NeoForge server (modpack, :25565)  │
  (LAN or VPN) │  friend: game port    │  VPN client ·  Chunky pre-generation      │
               │  only (ACL)           │  daily backups                            │
               └───────────────────────┴───────────────────────────────────────────┘
```

## Security by design

| Risk | How this setup handles it |
|---|---|
| Server open to the whole internet (scans, bots, DDoS, griefers) | **No port forwarding.** Nothing on the router is opened; the Pi is not reachable from the internet. |
| Friends getting into your home network | Friends join through a **private VPN** and only ever see **the Pi**, not your other devices. |
| Friends reaching SSH, the desktop or the admin panel | A VPN **access rule allows only the game port** (`tcp:<port>`) for them. |
| Fake players or impersonation | `online-mode=true`: every player is verified with their **Microsoft account**. |
| Admin panel exposed | The Crafty panel uses HTTPS and is reachable only from your LAN and your own VPN devices. |
| Losing the world | **Daily automatic backups** in Crafty, plus a reminder to keep a copy off the Pi. |
| Leaking secrets in this repo | No IPs, accounts, passwords or server files are committed; `.gitignore` blocks worlds, logs, mods and credential files. |

**What it does not cover:** devices on your own home network can still reach the Pi (SSH, VNC, the panel), protected only by their passwords. Use strong, unique passwords, keep the Pi updated (`sudo apt update && sudo apt full-upgrade`), and only share VPN access with people you trust.

## What you get

- A **NeoForge modpack server** installed with the *exact* loader version the pack expects.
- **Players install the same pack in the Modrinth App** and join. Nothing else to copy around.
- **Crafty Controller**: start/stop, console, file editor, scheduled backups, auto-start on boot.
- **Private access only**: a VPN (Tailscale in this guide; ZeroTier, NetBird, WireGuard... also work) with an access rule that lets friends reach **only the game port**.
- **Performance tips** for the Pi: Chunky pre-generation, memory sizing, what actually uses CPU.
- Quality-of-life: `/home`, `/tpa`, `/back`, `/spawn` with a **server-side-only** mod.

## Requirements

| | |
|---|---|
| **Board** | Raspberry Pi 5, **8 GB minimum, 16 GB recommended** for big modpacks |
| **Storage** | NVMe SSD strongly recommended (SD cards and USB sticks are slow and wear out) |
| **Cooling** | Active cooler or a case with a fan; generating terrain is CPU-heavy |
| **Power** | Official 27 W USB-C supply |
| **Network** | Ethernet preferred; Wi-Fi works |
| **Players** | **Each player needs a legitimate copy of Minecraft: Java Edition** |
| **Your PC** | Windows / macOS / Linux with an SSH client (built into Windows 10/11) |

Tested with: Raspberry Pi 5 (16 GB) in a Pironman 5 Max case with a 512 GB NVMe SSD, Raspberry Pi OS (64-bit, Bookworm-based), Better MC [NEOFORGE] BMC5 v31 (Minecraft 1.21.1, NeoForge 21.1.176), Java 21, Crafty Controller 4, Tailscale. Two players ran smoothly at ~20 TPS.

## Guide

Follow in order:

1. [Prepare the Pi](docs/01-prepare-the-pi.md): clean OS install on the SSD, SSH, remote desktop (VNC).
2. [Install the modpack server](docs/02-install-the-server.md): Java, the modpack, NeoForge, first start, fixing missing/broken mods.
3. [Manage it with Crafty](docs/03-crafty-controller.md): web panel, auto-start, backups.
4. [Let friends in with a VPN](docs/04-vpn-access.md): Tailscale (tested) or any similar VPN, plus a "game port only" rule.
5. [Extras and tuning](docs/05-extras-and-tuning.md): Chunky, homes/teleports, server icon and MOTD, chat announcements.
6. [Player setup](docs/06-player-setup.md): the checklist to send to your friends.
7. [Troubleshooting](docs/07-troubleshooting.md): every error we hit, and the fix.

## Quick start (if you already know your way around)

```bash
# On the Pi (Raspberry Pi OS 64-bit), as your normal user:
git clone https://github.com/ian-k-rebelo/pi5-private-minecraft-server.git
cd pi5-private-minecraft-server/scripts
SERVER_DIR=$HOME/minecraft/bmc5 bash install-server.sh better-mc-neoforge-bmc5 v31   # any Modrinth NeoForge pack slug + version
cd ~/minecraft/bmc5 && ./run.sh nogui
# Crashed on first start? Park client-only mods:
bash ~/pi5-private-minecraft-server/scripts/find-broken-mods.sh ~/minecraft/bmc5
```

Then: [Crafty](docs/03-crafty-controller.md) → [VPN](docs/04-vpn-access.md) → send [player setup](docs/06-player-setup.md) to your friends.

## Scripts

| Script | Runs on | What it does |
|---|---|---|
| [`install-server.sh`](scripts/install-server.sh) | Pi | Installs Java 21, deploys a Modrinth modpack server, installs the matching NeoForge version, sets memory, asks for the EULA. |
| [`find-broken-mods.sh`](scripts/find-broken-mods.sh) | Pi | Reads the newest crash report and moves mods that failed to load into `mods-disabled/`. |
| [`sync-missing-mods.ps1`](scripts/sync-missing-mods.ps1) | Windows | Copies mods your Modrinth profile has but the server is missing (fixes "channel missing on the server side"). |
| [`compare-mods.sh`](scripts/compare-mods.sh) | Pi | Read-only version of the above: lists client mods the server lacks. |
| [`examples/tailscale-acl.hujson`](examples/tailscale-acl.hujson) | Tailscale admin | Access policy: you get everything, friends get the game port only. |

## Important notes

- **Legit accounts only.** This guide keeps `online-mode=true`, so every player needs their own Minecraft: Java Edition account. It does not cover cracked/offline setups.
- **No third-party files are included.** Minecraft server files, NeoForge, the modpack and its mods are downloaded from their official sources by you. Modpacks often have restrictive licenses (Better MC is "All Rights Reserved"), so don't re-upload them.
- **Everything stays private.** The server is never port-forwarded; only devices on your LAN and on your private VPN can reach it.
- **Use at your own risk.** Always keep backups of your world and server folder before running scripts or changing configs. Read a script before you run it.
- Not affiliated with Mojang, Microsoft, Raspberry Pi Ltd, Modrinth, Crafty or Tailscale.

## License

The guides and scripts in this repository are released under the [MIT License](LICENSE).
