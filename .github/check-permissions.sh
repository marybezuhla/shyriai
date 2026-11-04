#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Every permission in the APK must be on this list; anything else (internet above all) fails.
# The manifest is checked too: no backups, no debugging, no cleartext, nothing exported by accident.
set -euo pipefail
APK="$1"
AAPT=$(ls "$ANDROID_HOME"/build-tools/*/aapt2 | sort -V | tail -1)
"$AAPT" dump permissions "$APK" > permissions.txt
cat permissions.txt
grep -q '^package:' permissions.txt || { echo "::error::Could not read permissions"; exit 1; }
ALLOWED=" ua.shyriai.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION "
# Every line after the package line must be one we can read, so nothing slips past unchecked.
while IFS= read -r line; do
  case "$line" in
    package:*) ;;
    uses-permission:\ name=\'*\'*|permission:\ *) ;;
    *) echo "::error::Unrecognised line in the permission dump: $line"; exit 1 ;;
  esac
done < permissions.txt
for p in $(grep -oE "name='[^']+'" permissions.txt | sed "s/name='//;s/'//"); do
  case "$ALLOWED" in
    *" $p "*) ;;
    *) echo "::error::Unexpected permission: $p"; exit 1 ;;
  esac
done
python3 -I "$(dirname "$0")/check-manifest.py" "$APK"
echo "Permissions OK"
