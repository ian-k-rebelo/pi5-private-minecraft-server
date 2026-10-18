#!/usr/bin/env bash
# install-server.sh - Install a Modrinth NeoForge modpack server on a Raspberry Pi 5.
#
# Usage:
#   bash install-server.sh [pack-slug] [pack-version]
#
# Examples:
#   bash install-server.sh                               # Better MC BMC5, latest version
#   bash install-server.sh better-mc-neoforge-bmc5 v31   # a specific version
#
# Environment variables (optional):
#   SERVER_DIR   where to install       (default: $HOME/minecraft/<pack-slug>)
#   MAX_RAM      Java max heap, e.g. 8G (default: picked from the Pi's RAM)
#   MIN_RAM      Java min heap          (default: 4G, or MAX_RAM if smaller)
#   SKIP_APT=1   skip the apt step (Java 21, curl, unzip, jq already installed)
#
# What it does:
#   1. Installs Java 21 and a few tools (apt).
#   2. Downloads mrpack-install and deploys the modpack's server files.
#   3. Reads the exact NeoForge version the pack needs and installs it.
#   4. Writes user_jvm_args.txt and asks you to accept the Minecraft EULA.
#
# It never bypasses account checks: online-mode stays as the server default (true).

set -euo pipefail

PACK="${1:-better-mc-neoforge-bmc5}"
PACK_VERSION="${2:-}"
SERVER_DIR="${SERVER_DIR:-$HOME/minecraft/$PACK}"
MRPACK_INSTALL_VERSION="v0.16.10"
TOOLS_DIR="$HOME/minecraft/.tools"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

info()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m!! \033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31mxx \033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -m)" == "aarch64" ]] || warn "This script was written for a 64-bit Raspberry Pi (aarch64). Detected: $(uname -m)."

# --- 1. Dependencies --------------------------------------------------------
if [[ "${SKIP_APT:-}" == "1" ]]; then
  info "SKIP_APT=1: not touching system packages."
  for cmd in java curl unzip jq; do
    command -v "$cmd" >/dev/null || fail "'$cmd' is missing. Install it or run without SKIP_APT=1."
  done
else
  info "Installing Java 21 and tools (sudo needed)..."
  sudo apt-get update -qq
  sudo apt-get install -y openjdk-21-jre-headless curl unzip jq
fi

# --- 2. mrpack-install ------------------------------------------------------
mkdir -p "$TOOLS_DIR"
MRPACK="$TOOLS_DIR/mrpack-install"
if [[ ! -x "$MRPACK" ]]; then
  info "Downloading mrpack-install $MRPACK_INSTALL_VERSION..."
  curl -fsSL -o "$MRPACK" \
    "https://github.com/nothub/mrpack-install/releases/download/${MRPACK_INSTALL_VERSION}/mrpack-install-linux-arm64"
  chmod +x "$MRPACK"
fi

# --- 3. Work out which pack version we are installing ------------------------
info "Looking up '$PACK' on Modrinth..."
VERSIONS_JSON="$(curl -fsSL "https://api.modrinth.com/v2/project/${PACK}/version")" \
  || fail "Could not find '$PACK' on Modrinth. Check the slug (the last part of the modpack's Modrinth URL)."

if [[ -z "$PACK_VERSION" ]]; then
  PACK_VERSION="$(jq -r '.[0].version_number' <<<"$VERSIONS_JSON")"
  info "No version given, using the newest: $PACK_VERSION"
fi

MRPACK_URL="$(jq -r --arg v "$PACK_VERSION" \
  '([.[] | select(.version_number == $v)][0] // empty) | .files | (map(select(.primary)) + .)[0].url // empty' \
  <<<"$VERSIONS_JSON")"
[[ -n "$MRPACK_URL" ]] || fail "Version '$PACK_VERSION' not found for '$PACK'."

# --- 4. Deploy the modpack server files ---------------------------------------
if [[ -e "$SERVER_DIR/mods" ]]; then
  fail "$SERVER_DIR already has a mods folder. Remove it or pick another SERVER_DIR."
fi
mkdir -p "$SERVER_DIR"
info "Deploying $PACK $PACK_VERSION into $SERVER_DIR (this takes a while)..."
"$MRPACK" "$PACK" "$PACK_VERSION" --server-dir "$SERVER_DIR"

# --- 5. Install the exact NeoForge version the pack expects ------------------
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
curl -fsSL -o "$WORK/pack.mrpack" "$MRPACK_URL"
unzip -p "$WORK/pack.mrpack" modrinth.index.json > "$WORK/index.json"

MC_VERSION="$(jq -r '.dependencies.minecraft // empty' "$WORK/index.json")"
NEOFORGE_VERSION="$(jq -r '.dependencies.neoforge // empty' "$WORK/index.json")"
info "Pack needs Minecraft $MC_VERSION, NeoForge ${NEOFORGE_VERSION:-<none>}"

if [[ -z "$NEOFORGE_VERSION" ]]; then
  warn "This pack does not use NeoForge. mrpack-install may already have set up the loader;"
  warn "check $SERVER_DIR and the docs before starting the server."
elif [[ -f "$SERVER_DIR/run.sh" ]]; then
  info "run.sh already exists, NeoForge seems installed. Skipping."
else
  info "Installing NeoForge $NEOFORGE_VERSION..."
  (
    cd "$SERVER_DIR"
    curl -fsSL -o neoforge-installer.jar \
      "https://maven.neoforged.net/releases/net/neoforged/neoforge/${NEOFORGE_VERSION}/neoforge-${NEOFORGE_VERSION}-installer.jar"
    java -jar neoforge-installer.jar --installServer > neoforge-install.log 2>&1 \
      || fail "NeoForge install failed, see $SERVER_DIR/neoforge-install.log"
    rm -f neoforge-installer.jar neoforge-installer.jar.log
    # mrpack-install drops a vanilla server.jar; NeoForge does not use it.
    if [[ -f server.jar ]] && unzip -p server.jar META-INF/MANIFEST.MF 2>/dev/null | grep -q 'net.minecraft.bundler'; then
      rm -f server.jar
    fi
  )
fi

# --- 6. JVM memory -------------------------------------------------------------
if [[ -z "${MAX_RAM:-}" ]]; then
  TOTAL_GB="$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)"
  if   (( TOTAL_GB >= 15 )); then MAX_RAM=8G
  elif (( TOTAL_GB >= 7  )); then MAX_RAM=5G
  else MAX_RAM=3G; warn "Less than 8 GB of RAM: big modpacks will struggle."
  fi
fi
MIN_RAM="${MIN_RAM:-4G}"
if (( ${MIN_RAM%G} > ${MAX_RAM%G} )); then MIN_RAM="$MAX_RAM"; fi
printf -- '-Xms%s\n-Xmx%s\n' "$MIN_RAM" "$MAX_RAM" > "$SERVER_DIR/user_jvm_args.txt"
info "Memory set to -Xms$MIN_RAM -Xmx$MAX_RAM ($SERVER_DIR/user_jvm_args.txt)"

# --- 7. EULA ---------------------------------------------------------------------
echo
echo "Running a Minecraft server requires accepting the Minecraft EULA:"
echo "  https://aka.ms/MinecraftEULA"
read -r -p "Do you accept it? [y/N] " ANSWER
if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
  echo "eula=true" > "$SERVER_DIR/eula.txt"
  info "EULA accepted."
else
  warn "EULA not accepted. The server will not start until eula.txt contains eula=true."
fi

# --- Done ----------------------------------------------------------------------
JAVA_CMD="java @user_jvm_args.txt @libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt nogui"
cat <<EOF

$(info "Done!")
  Server folder : $SERVER_DIR
  Pack version  : $PACK $PACK_VERSION  <- players must install exactly this version
  Test start    : cd "$SERVER_DIR" && ./run.sh nogui
  Crafty command: $JAVA_CMD

Next steps (see docs/02-install-the-server.md):
  1. First start crashes with "invalid dist DEDICATED_SERVER"?
       bash "$SCRIPT_DIR/find-broken-mods.sh" "$SERVER_DIR"
  2. Players get "Channel ... missing on the server side"? Some packs (BMC5 included)
     do not ship every mod jar in the .mrpack. Copy them from a player's Modrinth profile:
       sync-missing-mods.ps1 from this repo's scripts folder, run on the Windows PC
       that has the Modrinth App (see docs/02-install-the-server.md)
EOF
