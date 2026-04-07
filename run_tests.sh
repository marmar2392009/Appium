#!/usr/bin/env bash
# run_tests.sh — called by android-emulator-runner script: bash run_tests.sh
set -e

# ── 1. Fix ADB offline state ───────────────────────────────────────────────────
echo "=== Restarting ADB server ==="
adb kill-server
sleep 2
adb start-server
sleep 3
adb version
adb devices

# ── 2. Wait until Android has fully booted ────────────────────────────────────
echo "=== Waiting for sys.boot_completed ==="
BOOT_TIMEOUT=300
ELAPSED=0
until adb shell getprop sys.boot_completed 2>/dev/null | grep -q "^1$"; do
  if [ "$ELAPSED" -ge "$BOOT_TIMEOUT" ]; then
    echo "❌ Emulator did not fully boot within ${BOOT_TIMEOUT}s"
    adb devices
    adb logcat -d | tail -n 50 || true
    exit 1
  fi
  echo "  ... still booting (${ELAPSED}s)"
  sleep 5
  ELAPSED=$((ELAPSED + 5))
done
echo "✅ Android fully booted after ${ELAPSED}s"

# ── 3. Let Google services fully settle ───────────────────────────────────────
sleep 10

# ── 4. FIX: Force-launch Play Store via adb BEFORE Appium starts ──────────────
#    Without this, Appium connects but the app never opens → home screen only.
echo "=== Launching Play Store via adb ==="
adb shell am start -n com.android.vending/com.google.android.finsky.activities.MainActivity
sleep 6

# Confirm Play Store is in foreground
echo "=== Current foreground activity ==="
adb shell dumpsys window windows | grep -E "mCurrentFocus|mFocusedApp" || true

echo "=== Android version ==="
adb shell getprop ro.build.version.release

# ── 5. Start Appium ───────────────────────────────────────────────────────────
echo "=== Starting Appium ==="
appium --port 4723 \
       --log appium.log \
       --log-level info \
       --base-path '/' &
APPIUM_PID=$!

# ── 6. Wait until Appium is ready ─────────────────────────────────────────────
npx wait-on tcp:127.0.0.1:4723 --timeout 90000 --interval 2000 || {
  echo "=== Appium failed to start ==="
  cat appium.log || true
  kill "$APPIUM_PID" 2>/dev/null || true
  exit 1
}
echo "✅ Appium server is ready!"

# ── 7. Run the test ───────────────────────────────────────────────────────────
node test_sample.js
TEST_EXIT=$?

if [ $TEST_EXIT -ne 0 ]; then
  echo "=== Appium logs (failure) ==="
  cat appium.log || true
fi

kill "$APPIUM_PID" 2>/dev/null || true
exit $TEST_EXIT
