# 4. Let friends in with a private VPN

Your friends join the game through a **private, peer-to-peer VPN** (a "mesh" or "overlay" network): the Pi and each player's PC join the same virtual network and talk as if they were on the same LAN. **No router ports are opened and nothing is exposed to the internet.**

## Choosing a VPN

Any VPN of this kind works. The one hard requirement: **it must run on the Pi (Linux, ARM64)**, because the Pi itself has to be on the virtual network.

| VPN | Runs on the Pi | Notes |
|---|---|---|
| **[Tailscale](https://tailscale.com/)** | Yes | **Used and tested in this guide.** Easiest setup, free personal plan, sign in with an existing Microsoft/Google/GitHub account, per-port access rules. |
| [ZeroTier](https://www.zerotier.com/) | Yes | Very similar. Only the network owner needs an account; players join with a network ID and you approve them. |
| [NetBird](https://netbird.io/) | Yes | Open source, WireGuard-based, cloud or self-hosted, access policies. |
| [Headscale](https://github.com/juanfont/headscale) | Yes | Self-hosted control server for the official Tailscale apps. For people who don't want a third-party coordinator. |
| Plain [WireGuard](https://www.wireguard.com/) | Yes | No accounts or third parties, but you must **forward a UDP port** on your router and manage keys by hand. |
| Radmin VPN | **No** | Windows only, so the Pi can't join. It would need a Windows PC running 24/7 as a relay. |

Whatever you pick, the rest of the guide stays the same. You only need:
1. **The Pi's VPN IP address**: that's what players type in Minecraft (`ip:port` if not 25565).
2. **Ideally, a rule so players can reach only the game port**, not SSH or the Crafty panel. Use your VPN's access-control feature, or a firewall on the Pi (e.g. `ufw`) that only allows the game port on the VPN interface.

The rest of this page walks through **Tailscale**.

## On the Pi

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up            # open the printed link and log in
tailscale ip -4              # the Pi's VPN address, e.g. 100.x.y.z
```
Accounts: you can sign in with an existing Microsoft/Google/GitHub/Apple login; no new password needed. Tailscale starts on boot by itself.

Test from your own PC: install Tailscale, log in with the same account, and join `100.x.y.z` (add `:port` if not 25565) in Minecraft.

## Give your friend access

Two ways:

| | **Share the Pi** (simplest) | **Invite as a user** |
|---|---|---|
| How | Admin console → Machines → `...` on the Pi → **Share** → send link | Admin console → Users → Invite |
| Friend sees | Only the Pi | **Every device on your tailnet** by default, so add the rule below |
| Free plan | Yes | Up to 3 users |

Your friend installs Tailscale on their PC, logs in, opens your link and accepts.

## Restrict friends to the game port (recommended)

**Access controls** in the admin console. By default there is one rule *All users and devices → All → All ports*. Replace it with two:

1. **You** → all devices → all ports.
2. **Friend** → the Pi's **Tailscale IP** → **`tcp:<server-port>`**.

In the visual editor, put the **IP address** in *Destination*; typing the machine name gives "invalid address". The equivalent JSON is in [`examples/tailscale-acl.hujson`](../examples/tailscale-acl.hujson).

Result: your friend can play, but can't reach SSH, VNC or the Crafty panel. If you add players or change the port later, update the rule.

## Verify from the friend's PC

In PowerShell:
```powershell
Test-NetConnection 100.x.y.z -Port 25565
```
Good result: `InterfaceAlias : Tailscale` and `TcpTestSucceeded : True`.

If it shows `InterfaceAlias : Ethernet` (or Wi-Fi) with a `192.168.x.x` source address, **Tailscale is not connected on that PC**: traffic is going to the internet instead of the VPN. A ping may even "succeed" because something else at the ISP answers. Open Tailscale (Start menu → Tailscale; the tray icon may hide behind `^`), log in, make sure it says *Connected*, and that the Pi appears in its machine list.

---
Next: [5. Extras and tuning →](05-extras-and-tuning.md)
