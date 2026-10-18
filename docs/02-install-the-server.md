# 2. Install the modpack server

This guide uses **Better MC [NEOFORGE] BMC5** (Minecraft 1.21.1, NeoForge) from Modrinth, but the same steps work for most **Modrinth NeoForge modpacks**: just change the slug.

> **Pick the pack version first.** The server and every player must run the **exact same pack version** (e.g. `v31`). The easiest way is to use the newest version available *in the Modrinth App*, since that's what your friends will install.

## Choosing a pack for a Pi

| Pack | Loader / MC | Notes |
|---|---|---|
| BMC5 | NeoForge 1.21.1 | Java 21 (one `apt` command), newer vanilla content. Used in this guide. |
| BMC4 | Forge 1.20.1 | More mods exist for 1.20.1, but needs Java 17 and Forge instead. |

Hosting companies recommend **6–8 GB of RAM** for packs this size. A 16 GB Pi 5 handles it comfortably for a few players; 8 GB works with care; 4 GB is not enough for big packs.

## Option 1: use the script

```bash
git clone https://github.com/<you>/<this-repo>.git
cd <this-repo>/scripts
SERVER_DIR=$HOME/minecraft/bmc5 bash install-server.sh better-mc-neoforge-bmc5 v31
```

It installs Java 21, deploys the pack with [mrpack-install](https://github.com/nothub/mrpack-install), reads the **NeoForge version the pack requires** from the `.mrpack`, installs that NeoForge, writes `user_jvm_args.txt`, and asks you to accept the [Minecraft EULA](https://aka.ms/MinecraftEULA). The server ends up in `~/minecraft/bmc5`, the folder used in the rest of this guide (without `SERVER_DIR` it would be `~/minecraft/<slug>`). Then jump to [First start](#first-start).

Useful options (environment variables in front of the command):
```bash
# Install somewhere else, e.g. a test folder next to a running server
SERVER_DIR=$HOME/minecraft/test-server bash install-server.sh better-mc-neoforge-bmc5 v31

# Don't touch system packages (e.g. while another server is running).
# Java 21, curl, unzip and jq must already be installed; jq is often missing:
sudo apt install -y jq
SKIP_APT=1 bash install-server.sh better-mc-neoforge-bmc5 v31

# Choose the memory yourself (default: 8G on a 16 GB Pi, 5G on 8 GB)
MAX_RAM=6G bash install-server.sh better-mc-neoforge-bmc5 v31
```

## Option 2: by hand (what the script does)

```bash
# Java 21 for Minecraft 1.21.x
sudo apt install -y openjdk-21-jre-headless unzip jq
java -version

mkdir -p ~/minecraft && cd ~/minecraft

# mrpack-install (check https://github.com/nothub/mrpack-install/releases for the newest)
curl -L -o mrpack-install https://github.com/nothub/mrpack-install/releases/download/v0.16.10/mrpack-install-linux-arm64
chmod +x mrpack-install
./mrpack-install better-mc-neoforge-bmc5 v31 --server-dir ~/minecraft/bmc5
```

**mrpack-install does not install NeoForge.** It leaves a *vanilla* `server.jar`. Check: `unzip -p server.jar META-INF/MANIFEST.MF` showing `net.minecraft.bundler.Main` means vanilla.

Find the NeoForge version the pack wants and install it:
```bash
cd ~/minecraft
URL=$(curl -s https://api.modrinth.com/v2/project/better-mc-neoforge-bmc5/version \
  | jq -r '.[] | select(.version_number=="v31") | .files[0].url')
curl -L -o pack.mrpack "$URL"
unzip -p pack.mrpack modrinth.index.json | jq .dependencies
# -> { "neoforge": "21.1.176", "minecraft": "1.21.1" }

cd ~/minecraft/bmc5
NF=21.1.176
curl -L -o neoforge-installer.jar https://maven.neoforged.net/releases/net/neoforged/neoforge/$NF/neoforge-$NF-installer.jar
java -jar neoforge-installer.jar --installServer      # ends with "The server installed successfully"
rm neoforge-installer.jar server.jar ~/minecraft/pack.mrpack
ls     # you should now see run.sh and libraries/
```

Memory and EULA:
```bash
printf -- "-Xms4G\n-Xmx8G\n" > user_jvm_args.txt     # 16 GB Pi; use ~5G max on an 8 GB Pi
echo "eula=true" > eula.txt                          # only if you accept https://aka.ms/MinecraftEULA
```

Sanity checks:
```bash
ls mods/*.jar | wc -l                    # a few hundred for BMC5
find mods -name "*.jar" -size -1k        # must print nothing (no empty downloads)
```

## First start

Start the server by hand once, to fix any problems before moving it to Crafty:
```bash
cd ~/minecraft/bmc5 && ./run.sh nogui
```
> **Optional: `tmux`.** If you're connected over SSH and want the server to keep running after you close the terminal, start it inside `tmux` instead: `sudo apt install -y tmux`, `tmux new -s mc`, then the command above. Detach with **Ctrl+B then D**, reattach with `tmux attach -t mc`, close it with `exit` once the server is stopped. Not needed once the server runs under Crafty, which keeps it running and starts it on boot. If you'd rather **not use Crafty at all**, `tmux` is also how you keep the server running long-term, but then you start it by hand after every reboot and have no web panel or scheduled backups.

The first start takes several minutes. It's ready when you see `Done (...)! For help, type "help"`. Type `list` to confirm, `stop` to shut down.

> We installed the *headless* Java, so `./run.sh` without `nogui` will not open a GUI window either. That's fine: use the console, or the Crafty web panel ([next chapter](03-crafty-controller.md)).

### Problem 1: crash with `invalid dist DEDICATED_SERVER`

Some mods in the pack are **client-only** (visual tweaks) and crash a dedicated server. The crash report names them:
```
-- Mod loading issue for: bettergrass --
    Mod file: .../mods/BetterGrassify-1.6.1+neoforge.1.21.1.jar
    ... Attempted to load class net/minecraft/client/gui/screens/Screen for invalid dist DEDICATED_SERVER
```
Run the helper (it parks them in `mods-disabled/`, nothing is deleted). The installer prints this exact command, with full paths, at the end:
```bash
bash ~/<this-repo>/scripts/find-broken-mods.sh ~/minecraft/bmc5
```
Answer `y`, start again, and repeat if a new crash report appears. For BMC5 v31 one round is enough: it moves **BetterGrassify** and **Distraction Free Recipes**.

> `grep` says "binary file matches" on crash reports? Use `grep -a`.

### Problem 2: players get "Channel of mod X failed to connect: missing on the server side"

The server is **missing mods the client has**. With BMC5 v31, about 20 real content mods (Twilight Forest, Deeper Darker, Deep Aether, Supplementaries, FTB Quests, Backpacked...) are **not inside the `.mrpack` file at all**: neither in its download list nor in its bundled files. Only their config files are. The Modrinth App still ends up with them on players' PCs, but no server installer can get them from the pack.

You can check this yourself (download the `.mrpack` as in [Option 2](#option-2-by-hand-what-the-script-does)):
```bash
unzip -l pack.mrpack | grep -i backpack                 # only config files
unzip -p pack.mrpack modrinth.index.json | grep -i backpack   # nothing
```

Fix: copy them from a player's Modrinth profile (guarantees identical versions).

1. Install the same pack version in the **Modrinth App** on your PC and launch it once.
2. Stop the server.
3. On Windows, from the repo's `scripts` folder:
   ```powershell
   .\sync-missing-mods.ps1 -ProfileName "Better MC [NEOFORGE] BMC5" `
       -PiHost <user>@pi5.local -ServerDir /home/<user>/minecraft/bmc5
   ```
   It lists the server's mods over SSH, shows what's missing (ignoring anything already in `mods-disabled/`), asks, then copies with `scp`.
   > Windows says "running scripts is disabled on this system"? Allow scripts **for this PowerShell window only** (nothing changes permanently): `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, then run the script again.
4. Start the server. If a copied mod is client-only and crashes, `find-broken-mods.sh` parks it.
   > Before this step you may see `randomenchantfix-common.toml is not correct. Correcting` repeating endlessly. It's a side effect of the missing mods and stops once they are copied.

Manual alternative: export the list (`Get-ChildItem mods -Name | Out-File -Encoding ascii clientmods.txt` in the profile folder; profiles live in `%APPDATA%\ModrinthApp\profiles`), copy it to the Pi, run `bash scripts/compare-mods.sh clientmods.txt ~/minecraft/bmc5`, and `scp` the listed jars.

### Join from your PC

In the Modrinth App, install the **same pack version** and launch it. **Multiplayer → Add Server → `pi5.local`** (or the Pi's IP). If you can walk around, the server works. Do this before setting up Crafty and the VPN, so you know any later problem is not the server itself.

### Check `server.properties`

```bash
grep -E "online-mode|white-list|server-port|motd" server.properties
```
Keep **`online-mode=true`**: it verifies every player's Microsoft account, and it is also what makes **skins and capes** show up. With a private VPN, the whitelist is optional.

> Switching `online-mode` later changes every player's UUID: existing inventories, homes, quests and claims look like they belong to someone else. Decide before you start playing.

---
Next: [3. Manage it with Crafty →](03-crafty-controller.md)
