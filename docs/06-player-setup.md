# 6. Player setup

Copy this, fill in the blanks, and send it to your friends.

---

### Joining the server 🎮

**1. The game**
- Buy **Minecraft: Java & Bedrock Edition for PC** at minecraft.net (or have PC Game Pass).
- Open the **official Minecraft Launcher** once and start **Java Edition**, so your Java profile and player name exist.

**2. The modpack**
- Install the **Modrinth App**: <https://modrinth.com/app>. Sign in with your Microsoft account.
- Search **`<PACK NAME>`** and install version **`<PACK VERSION>`**. It must be exactly this version.

**3. The VPN** (this guide uses Tailscale; if your host picked another VPN, install that one instead)
- Install **Tailscale**: <https://tailscale.com/download> and log in.
- Open the invite link I sent you and accept it.
- Make sure the Tailscale icon (near the clock, maybe behind `^`) says **Connected**.

**4. Join**
- Launch the game from the modpack's profile in the Modrinth App.
- Multiplayer → Add Server → **`<PI TAILSCALE IP>:<PORT>`**

**5. Optional: make it pretty** (client-side only, safe to add)
In the Modrinth App, open the pack's profile → **Add content**:
- Shader: e.g. **Complementary Reimagined** → in game: Options → Video Settings → Shader Packs.
- Resource packs: e.g. **Stay True**, **Better Leaves**, **Fresh Animations** → Options → Resource Packs (top of the list wins).

⚠️ **Don't add or remove *mods***, only shaders and resource packs, or you won't be able to join.

---

## Client performance tips

Press **F3** in game to see FPS, GPU usage and memory (`Mem:`).

- **GPU at ~100%** → lower **Render Distance** (12–16; 25 is very heavy with shaders) and the shader's **shadow distance/quality**, or use a lighter shader profile.
- **`Mem:` often above ~85% with stutters** → give the game more RAM in the Modrinth App (6–8 GB on a 16 GB PC, ~4–5 GB on 8 GB). More RAM does not raise FPS otherwise.
- **Laptop showing the Intel GPU in F3** → Windows Settings → System → Display → Graphics → add `javaw.exe` → High performance.
- Sodium video options: Fast graphics, fewer particles, clouds off, entity shadows off.

## Skins and capes

With `online-mode=true`, players' own skins and capes show up automatically. Change them in the official launcher (Skins tab) or the Modrinth App; capes are picked in the launcher's skin editor. Rejoin if the change doesn't appear right away.
