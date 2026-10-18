# 3. Manage it with Crafty Controller

[Crafty Controller 4](https://craftycontrol.com/) is a free web panel: start/stop buttons, live console, file editor, scheduled backups and tasks, and it **starts the server when the Pi boots**.

## Install

Stop the tmux server first (`stop` in its console). Then, from your home folder (**not** inside the server folder):
```bash
cd ~
git clone https://gitlab.com/crafty-controller/crafty-installer-4.0.git
cd crafty-installer-4.0 && sudo ./install_crafty.sh
```
- Branch: **master** (stable).
- Accept the default install path (`/var/opt/minecraft/crafty`).
- Say yes to installing the **service**.

Enable and start it:
```bash
sudo systemctl enable --now crafty.service
sudo systemctl status crafty --no-pager            # active (running)
```
Initial credentials (the file appears a minute after first start):
```bash
sudo cat /var/opt/minecraft/crafty/crafty-4/app/config/default-creds.txt
```
Open **`https://pi5.local:8443`**. It must be **https**; plain http gives `ERR_CONNECTION_RESET`. Accept the self-signed certificate warning.

Change the password (user menu / **Users** in the panel), log out and back in, then delete the credentials file:
```bash
sudo rm /var/opt/minecraft/crafty/crafty-4/app/config/default-creds.txt
```
> Open the panel from **your PC's browser**, not a browser on the Pi. A Chromium tab with the live console open used more CPU than the Minecraft server itself.

## Import the server

Crafty runs as the `crafty` user, which can't read your home folder. The import form in Crafty 4 takes a **zip**:
```bash
sudo apt install -y zip
cd ~/minecraft/bmc5 && zip -r ~/bmc5.zip .     # the trailing "." puts files at the zip root
```
In Crafty: **Create New Server → Minecraft Java → upload zip**.
- Upload `bmc5.zip` (easiest from a browser on the Pi, since the file is already there; or `scp` it to your PC first).
- **Root dir:** select the top level (`Files`), not a subfolder.
- **Server Executable File:** `run.sh` (temporary, fixed below).
- **Min/Max memory:** 4 / 8 GB (match `user_jvm_args.txt`).
- **Port:** the `server-port` from `server.properties`.
- Roles: leave empty. **Import Server!**

Crafty stores servers in `/var/opt/minecraft/crafty/crafty-4/servers/<uuid>/`.

## Fix the start command (important)

Open the server → **Config → Server Execution Command**. Don't use `bash run.sh nogui`: it works, but Crafty then measures the `bash` process and its **metrics stay at 0%**. Use the Java line from `run.sh` directly:
```
java @user_jvm_args.txt @libraries/net/neoforged/neoforge/21.1.176/unix_args.txt nogui
```
(replace `21.1.176` with your NeoForge version; `install-server.sh` prints this line for you).

Still in **Config**: enable **Start on Crafty launch** / auto start. **Save**, then **Start** and watch the **Terminal** tab.

When everything works, remove the leftovers:
```bash
rm -rf ~/minecraft/bmc5 ~/bmc5.zip ~/crafty-installer-4.0
```

## Backups

**Backups** tab: set **max backups** (e.g. 5) and compression, run **Backup Now** once. Then **Schedules → new task → Backup**, daily at a quiet hour (e.g. 05:00).

Backups live on the same SSD: they protect against mistakes and corruption, not a dead drive. Copy one to another machine now and then (the Pironman 5 Max even has a second M.2 slot).

## Handy Crafty facts

- Changing `server.properties` → stop, edit (Files tab), start. The file is only read at startup.
- **Changing the port?** Set it in Crafty's Config **and** check `server-port=` in `server.properties`: they can disagree. Then update your Tailscale rule.
- Several servers = several ports (`25565`, `25566`, ...). Players type `ip:port` for anything that isn't 25565.
- Files you add over SSH must belong to `crafty`:
  ```bash
  sudo chown crafty:crafty /var/opt/minecraft/crafty/crafty-4/servers/<uuid>/mods/<file>.jar
  ```
- Forgot the panel password: `sudo systemctl stop crafty`, then `sudo su crafty -c "/var/opt/minecraft/crafty/run_crafty.sh"`, type `set_passwd admin`, `exit`, `sudo systemctl start crafty`.

## Test a reboot

```bash
sudo reboot
```
After 3–5 minutes the panel should load and the server should be running on its own.

---
Next: [4. Let friends in with a VPN →](04-vpn-access.md)
