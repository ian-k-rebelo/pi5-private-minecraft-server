#!/usr/bin/env bash
# find-broken-mods.sh - Read the newest crash report and move the mods that failed
# to load into mods-disabled/. Typical cause: client-only mods (graphics, menus)
# that crash a dedicated server with "invalid dist DEDICATED_SERVER".
#
# Usage:
#   bash find-broken-mods.sh <server-dir>          # show the broken mods and ask before moving
#   bash find-broken-mods.sh <server-dir> --yes    # move without asking
#
# Run it with the server STOPPED. Moved mods are not deleted: put them back
# from mods-disabled/ if the server turns out to need them.
# If the server folder belongs to another user (e.g. Crafty's 'crafty' user),
# run the script with: sudo -u crafty bash find-broken-mods.sh <server-dir>
#
# How mods are found: every "-- Mod loading issue for: <modid> --" section of the
# report is read. If it has a "Mod file:" line, that file name is used; otherwise
# the jar declaring that mod id is searched for in <server-dir>/mods.
# Only <server-dir>/mods is ever touched, whatever paths the report contains.

set -euo pipefail

SERVER_DIR="${1:?Usage: $0 <server-dir> [--yes]}"
AUTO_YES="${2:-}"
MODS_DIR="$SERVER_DIR/mods"

CRASH_DIR="$SERVER_DIR/crash-reports"
[[ -d "$CRASH_DIR" ]] || { echo "No crash-reports folder in $SERVER_DIR. Nothing to do."; exit 0; }
[[ -d "$MODS_DIR" ]]  || { echo "No mods folder in $SERVER_DIR."; exit 1; }

REPORT="$(ls -t "$CRASH_DIR"/*.txt 2>/dev/null | head -1 || true)"
[[ -n "$REPORT" ]] || { echo "No crash reports found."; exit 0; }
echo "Newest crash report: $REPORT"

# One line per issue: "<modid>|<jar file name or empty>"
mapfile -t ISSUES < <(awk '
  /^-- Mod loading issue for: / {
    if (id != "") print id "|" file
    id = $0; sub(/^-- Mod loading issue for: /, "", id); sub(/ --[[:space:]]*$/, "", id)
    file = ""; next
  }
  /^-- / { if (id != "") print id "|" file; id = ""; file = ""; next }
  id != "" && file == "" && /Mod file:/ {
    f = $0; sub(/.*Mod file:[[:space:]]*/, "", f); n = split(f, parts, "/"); file = parts[n]
  }
  END { if (id != "") print id "|" file }
' <(tr -d '\r' < "$REPORT") | sort -u)

if (( ${#ISSUES[@]} == 0 )); then
  echo "The report does not list any mod loading issues."
  echo "Look at the top of the report for the real cause:"
  echo "  head -60 \"$REPORT\""
  exit 0
fi

# Find the jar in mods/ that declares a given mod id.
jar_for_modid() {
  local id="$1" jar
  for jar in "$MODS_DIR"/*.jar; do
    # Read the metadata into a variable first: unzip exits non-zero when one of the
    # two file names is absent, which would break a pipe under "set -o pipefail".
    local meta
    meta="$(unzip -p "$jar" META-INF/neoforge.mods.toml 2>/dev/null || true)"
    [[ -n "$meta" ]] || meta="$(unzip -p "$jar" META-INF/mods.toml 2>/dev/null || true)"
    if grep -Eq "^[[:space:]]*modId[[:space:]]*=[[:space:]]*\"$id\"" <<<"$meta"; then
      echo "${jar##*/}"
      return 0
    fi
  done
  return 1
}

TO_MOVE=()
for issue in "${ISSUES[@]}"; do
  id="${issue%%|*}"
  file="${issue#*|}"
  if [[ -n "$file" && -f "$MODS_DIR/$file" ]]; then
    TO_MOVE+=("$file"); echo "  $id -> $file"
  elif found="$(jar_for_modid "$id")"; then
    TO_MOVE+=("$found"); echo "  $id -> $found"
  else
    echo "  $id -> (no matching jar in $MODS_DIR; already moved or a library inside another mod)"
  fi
done

if (( ${#TO_MOVE[@]} == 0 )); then
  echo
  echo "Nothing left to move. Look at the report for other causes: head -60 \"$REPORT\""
  exit 0
fi

echo
if [[ "$AUTO_YES" != "--yes" ]]; then
  read -r -p "Move the jar(s) above to $SERVER_DIR/mods-disabled/? [y/N] " ANSWER
  [[ "$ANSWER" =~ ^[Yy]$ ]] || { echo "Nothing moved."; exit 0; }
fi

mkdir -p "$SERVER_DIR/mods-disabled"
while IFS= read -r name; do
  mv -v "$MODS_DIR/$name" "$SERVER_DIR/mods-disabled/"
done < <(printf '%s\n' "${TO_MOVE[@]}" | sort -u)

echo
echo "Done. Start the server again; repeat if a new crash report appears."
