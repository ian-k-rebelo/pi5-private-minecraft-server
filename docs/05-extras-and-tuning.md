# 5. Extras and tuning

Everything here is **server-side only**: players don't install anything extra.

In the paths below, `SRV=/var/opt/minecraft/crafty/crafty-4/servers/<uuid>` (the Crafty server folder):
```bash
SRV=$(echo /var/opt/minecraft/crafty/crafty-4/servers/*)    # if you only have one server
```

## Before adding any mod: check compatibility

A mod's jar declares what it needs. Download it first (e.g. to `~/Downloads`), then:
```bash
unzip -p ~/Downloads/<mod>.jar META-INF/neoforge.mods.toml | grep -A4 -E 'modId *= *"(minecraft|neoforge|<dependency>)"'
```
- `minecraft` `versionRange` must include your version (e.g. `[1.21,1.22)` includes 1.21.1).
- `neoforge` range must start at or below your NeoForge version.
- For dependencies the pack already has (e.g. `ftblibrary`), the range must start at or below **the version in the pack**. Never update a pack library on the server only, or clients stop matching.

Install with the server stopped:
```bash
sudo cp ~/Downloads/<mod>.jar "$SRV/mods/" && sudo chown crafty:crafty "$SRV/mods/<mod>.jar"
```

## Chunky: pre-generate the world (big win on a Pi)

Generating new terrain, with dozens of biome and structure mods, is the heaviest work the server does, and it is what causes lag while exploring. [Chunky](https://modrinth.com/plugin/chunky) generates it **in advance**, while nobody plays. It's a one-off job that stops at 100%; the world stays infinite beyond the radius.

```bash
URL=$(curl -sG https://api.modrinth.com/v2/project/chunky/version \
  --data-urlencode 'loaders=["neoforge"]' --data-urlencode 'game_versions=["1.21.1"]' \
  | jq -r '.[0].files[0].url')
echo "$URL"                                   # ...Chunky-NeoForge-x.y.z.jar
sudo -u crafty curl -L -o "$SRV/mods/Chunky-NeoForge.jar" "$URL"
```
Start the server, then in the console:
```
chunky spawn
chunky radius 2000
chunky start
```
Radius 2000 = a 4000 × 4000 block square, several hours on a Pi. Check with `chunky progress`; `chunky pause` / `chunky continue` if you want to play meanwhile. You can extend later (`chunky radius 4000`); already generated chunks are skipped. Other dimensions: `chunky world minecraft:the_nether` before `start`.

## Homes, teleport requests, /back, /spawn: FTB Essentials

[FTB Essentials](https://www.curseforge.com/minecraft/mc-mods/ftb-essentials) is server-side and uses FTB Library, which FTB-based packs already include. Pick a version whose `ftblibrary` requirement fits the pack (BMC5 v31 has FTB Library `2101.1.13`; **FTB Essentials 2101.1.6** needs `[2101.1.4,)` and works).

Commands: `/sethome <name>`, `/home <name>`, `/delhome`, `/listhomes`, `/back`, `/spawn`, `/tpa <player>`, `/tpaccept`, `/tpdeny`, `/rtp`, `/trashcan`. If a name clashes with another mod: `/ftbessentials home`.

**More than one home** (default is 1). The setting is in `$SRV/config/ftbessentials.snbt`, block `home { ... max: 1 }`:
```bash
sudo grep -n -A20 'home: {' "$SRV/config/ftbessentials.snbt" | grep -E 'max:|cooldown:'
sudo sed -i '/home: {/,/}/ s/max: [0-9]*/max: 5/' "$SRV/config/ftbessentials.snbt"
```
Restart the server.

Alternative without dependencies: **xiaozhitpa** (`/tpa`, `/sethome`, `/home`, `/back`, no `/spawn`).

## Server icon and MOTD

- **Icon:** 64×64 PNG named `server-icon.png` in the server folder.
  ```bash
  sudo apt install -y imagemagick
  convert my-image.png -resize 64x64! server-icon.png
  sudo mv server-icon.png "$SRV/" && sudo chown crafty:crafty "$SRV/server-icon.png"
  ```
- **MOTD** (grey line in the server list): `motd=` in `server.properties`. Colours use `§` codes, e.g. `motd=§6§lMy Server §r§7- BMC5`.
- The bold name in the list is chosen by each player, not the server.
- Restart, then *Refresh* the server list.

## Chat announcements

Crafty → **Schedules** → new task, action **Command**, every N minutes:
```
tellraw @a ["",{"text":"[Server] ","color":"aqua","bold":true},{"text":"Daily backup at 05:00","color":"white"}]
```
Test it in the console first. `say <text>` is the plain version.

## Useful game rules (console)

```
gamerule playersSleepingPercentage 50     # one of two players can skip the night
gamerule keepInventory true               # optional
op <your-player-name>                     # admin rights for yourself
```

## Performance notes

- Check health: `spark tps` (aim for ~20) and `spark health` in the console (BMC5 includes spark).
- Look at the **process** line, not *system*, to see what the server itself uses. Use `htop` (press `H` to hide threads) to find other hogs. On our Pi it was a browser on the Pi's own desktop.
- Java grows into its `-Xmx` over time; high "used" RAM is not a leak.
- Close VNC sessions when you're not using them.

## Quieter console

With some packs (the **Connectivity** mod), every server-list ping or panel status check logs a `Connection reset by peer` stack trace. Under Crafty it repeats constantly because the panel checks the server's status regularly; started by hand, the same server logs it only once. It's harmless and can't be turned off in that mod's config. To *view* a clean log:
```bash
sudo tail -f "$SRV/logs/latest.log" | grep --line-buffered -E '^\[' | grep --line-buffered -vE 'Connectivity|PacketEncoder'
```
Save it as an alias:
```bash
echo "alias mclog=\"sudo tail -f $SRV/logs/latest.log | grep --line-buffered -E '^\[' | grep --line-buffered -vE 'Connectivity|PacketEncoder'\"" >> ~/.bashrc
source ~/.bashrc
```

The BMC5 mod **packanalytics** prints a big red error when it can't reach its stats server. Moving it to `mods-disabled/` cleared it for us; if players then get a "channel missing" error, put it back.

---
Next: [6. Player setup →](06-player-setup.md)
