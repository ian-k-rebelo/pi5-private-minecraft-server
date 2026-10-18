#!/usr/bin/env bash
# compare-mods.sh - List mods a player has that the server does not.
#
# Usage:
#   bash compare-mods.sh <client-mod-list.txt> <server-dir>
#
# <client-mod-list.txt> is a plain list of .jar names, one per line. On Windows,
# create it from the Modrinth profile folder with:
#   Get-ChildItem mods -Name | Out-File -Encoding ascii clientmods.txt
#
# Mods already parked in <server-dir>/mods-disabled/ are treated as known
# client-only mods and are not reported.
# Prefer scripts/sync-missing-mods.ps1, which does the comparison AND the copy
# from Windows in one go. This script is the manual / read-only alternative.

set -euo pipefail

CLIENT_LIST="${1:?Usage: $0 <client-mod-list.txt> <server-dir>}"
SERVER_DIR="${2:?Usage: $0 <client-mod-list.txt> <server-dir>}"

server_mods() {
  ls "$SERVER_DIR/mods" 2>/dev/null
  ls "$SERVER_DIR/mods-disabled" 2>/dev/null || true
}

MISSING="$(comm -23 \
  <(tr -d '\r' < "$CLIENT_LIST" | grep -E '\.jar$' | sort -u) \
  <(server_mods | grep -E '\.jar$' | sort -u))"

if [[ -z "$MISSING" ]]; then
  echo "The server has every mod from the client list (or it is parked in mods-disabled)."
  exit 0
fi

echo "Mods on the client but NOT on the server:"
sed 's/^/  /' <<<"$MISSING"
echo
echo "Copy the content mods to $SERVER_DIR/mods/ (skip purely visual / client-only ones)."
echo "If a copied mod then crashes the server, run scripts/find-broken-mods.sh."
