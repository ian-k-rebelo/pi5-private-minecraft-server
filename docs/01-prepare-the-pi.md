# 1. Prepare the Pi

Goal: a clean **Raspberry Pi OS (64-bit)** on the NVMe SSD, reachable from your PC by SSH and, optionally, by remote desktop (VNC).

> Want the lightest setup? Use **Raspberry Pi OS Lite (64-bit)** and manage everything over SSH and the Crafty web panel. Choose the desktop version only if you want to see the Pi's desktop from your PC. The desktop costs roughly 300–500 MB of RAM.

## Option A: flash the SSD directly (easiest)

If you can connect the SSD to your PC (USB-NVMe enclosure), or the Pi has nothing on it yet:

1. Install **Raspberry Pi Imager** on your PC: <https://www.raspberrypi.com/software/>
2. Choose **Device:** Raspberry Pi 5 · **OS:** Raspberry Pi OS (64-bit) or Lite (64-bit) · **Storage:** the SSD.
3. When asked, **Edit settings** (OS customisation):
   - **Hostname:** something generic, e.g. `pi5`, since the Pi can do more than Minecraft.
   - **Username and password**: write them down.
   - **Wi-Fi** (if not using Ethernet) and the **Wi-Fi country**.
   - **Locale**: your time zone and keyboard layout.
   - **Services tab:** **enable SSH** (password authentication).
4. Write, put the SSD back, power on, wait 2–3 minutes for the first boot.

## Option B: reinstall an SSD that is already inside the case (no enclosure)

The Pi does not boot an "installer". A USB stick flashed with Imager **is** a running system. So we use a stick as a temporary system and flash the SSD from it.

1. On your PC, flash a **USB stick** with **Raspberry Pi OS (64-bit) with desktop** (it includes Imager). Set a user, password and Wi-Fi in *Edit settings*.
   - Windows may offer to "format" the stick after writing: click **Cancel**.
2. Boot the old system on the Pi and make **USB boot first**:
   ```bash
   sudo rpi-eeprom-config --edit
   ```
   Set (or add) `BOOT_ORDER=0xf614`, save (Ctrl+O, Enter, Ctrl+X). The digits are read **right to left**: 4 = USB, 1 = SD card, 6 = NVMe.
   > Forgot the old password? Check whether `sudo` needs one at all: `sudo -n true && echo NO_PASSWORD`. On many Pi OS images it doesn't.
3. Plug the stick into a **blue USB 3 port** and `sudo reboot`. Confirm you booted from the stick:
   ```bash
   lsblk     # the line with "/" must be under sda, not nvme0n1
   ```
4. Open **Raspberry Pi Imager** on the stick's desktop and flash the **SSD**. In *Storage* it may only appear after unticking **Exclude system drives**, and Imager asks you to type the drive name to confirm. Use the final settings this time (hostname, user, Wi-Fi, **SSH on**).
5. Put **NVMe first** again, still on the stick's system:
   ```bash
   sudo raspi-config     # Advanced Options -> Boot Order -> NVMe/USB Boot
   ```
   or set `BOOT_ORDER=0xf416` with `rpi-eeprom-config --edit`.
6. Power off, **remove the stick**, power on. Check:
   ```bash
   lsblk                         # "/" under nvme0n1
   rpi-eeprom-config | grep BOOT_ORDER    # ends in 6 = NVMe first
   ```
   If boot still shows "trying USB" with a black screen before falling back to NVMe, the order was not saved; repeat step 5 from the new system.

## Connect from your PC

**SSH** is built into Windows 10/11. In PowerShell:
```powershell
ssh <user>@pi5.local        # or ssh <user>@<pi-ip>
```
Find the Pi's IP on the Pi with `hostname -I`, or in your router. Reserving that IP in the router (DHCP reservation) is a good idea.

If SSH isn't enabled yet:
```bash
sudo systemctl enable --now ssh
```

**Copying files** from Windows: `scp file.zip <user>@pi5.local:/home/<user>/` or use WinSCP.

**Remote desktop (optional, desktop OS only):**
1. On the Pi: `sudo raspi-config` → **Interface Options → VNC → Yes**.
2. On your PC: a VNC viewer. **TigerVNC Viewer** works without an account; RealVNC Viewer now requires one.
3. Connect to `pi5.local` with the Pi's username and password.
4. Headless (no monitor)? Set a resolution: `raspi-config` → **Display Options → VNC Resolution**.

> Keyboard tip: on some layouts `~` is a dead key (press it, then Space). You can always write `$HOME` instead of `~`.

## Update the system

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

## Optional: passwordless sudo

Convenient on a home server; it means anyone with your login has full root access.
```bash
echo "$USER ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/010_$USER-nopasswd
sudo chmod 440 /etc/sudoers.d/010_$USER-nopasswd
sudo visudo -c     # must say "parsed OK"
```

## Optional: case software (Pironman 5 / 5 Max / Mini / Pro Max)

A clean install removes the SunFounder case software (fan control, OLED, RGB). Reinstall it; the installer asks which model you have:
```bash
curl -sSL "https://raw.githubusercontent.com/sunfounder/sunfounder-installer-scripts/main/pironman5/install.sh" | sudo bash
sudo reboot
```
Its dashboard is at `http://pi5.local:34001`. Check SunFounder's docs for the current command.

---
Next: [2. Install the modpack server →](02-install-the-server.md)
