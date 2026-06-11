#!/usr/bin/env bash
# Print SHA-1 fingerprints for the Neshan Android key panel (کلید امضاء).
set -euo pipefail

echo "=== Neshan panel → ANDROID tab → کلید امضاء (SHA-1) ==="
echo ""
echo "Package name (نام باندل): com.example.uzita"
echo ""

DEBUG_KS="${HOME}/.android/debug.keystore"
if [[ -f "$DEBUG_KS" ]]; then
  echo "--- Debug keystore (flutter run / current release APK) ---"
  keytool -list -v -keystore "$DEBUG_KS" -alias androiddebugkey \
    -storepass android -keypass android 2>/dev/null | grep -E "SHA1:|SHA256:" || true
  echo ""
else
  echo "Debug keystore not found at $DEBUG_KS"
fi

if [[ -n "${RELEASE_KEYSTORE:-}" && -f "${RELEASE_KEYSTORE}" ]]; then
  echo "--- Release keystore ($RELEASE_KEYSTORE) ---"
  keytool -list -v -keystore "$RELEASE_KEYSTORE" -alias "${RELEASE_ALIAS:-upload}" \
    | grep -E "SHA1:|SHA256:" || true
  echo ""
fi

cat <<'EOF'
Paste SHA-1 value(s) into Neshan panel → ANDROID → کلید امضاء.
Multiple fingerprints: separate with commas, e.g.:
  AA:BB:..., CC:DD:...

If you publish on Google Play, also add Play App Signing SHA-1 from:
  Play Console → Setup → App integrity → App signing key certificate

Note: com.example.uzita is NOT a domain — do not put it in service-key
"دامنه‌های مجاز". Use device-control.liara.run there instead.
EOF
