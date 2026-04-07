[20:25, 07/04/2026] +20 15 58057234: name: Appium Android Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      # ── 1. Checkout ──────────────────────────────────────────────────────────
      - name: Checkout code
        uses: actions/checkout@v4

      # ── 2. Java ──────────────────────────────────────────────────────────────
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      # ── 3. Node.js ───────────────────────────────────────────────────────────
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      # ── 4. KVM acceleration ───────────────────────────────────────────────────
      - name: Enable KVM
        run: |
          echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | \
            sudo tee /etc/udev/rules.d/99-kvm4all.rules
          sudo udevadm control --reload-rules
          sudo udevadm trigger --name-match=kvm

      # ── 5. Appium + UiAutomator2 ─────────────────────────────────────────────
      - name: Install Appium + UiAutomator2 driver
        env:
          APPIUM_HOME: /home/runner/.appium
        run: |
          npm install -g appium@next
          appium driver install uiautomator2
          appium driver list --installed

      # ── 6. Project dependencies ───────────────────────────────────────────────
      - name: Install project dependencies
        run: npm install --legacy-peer-deps

      # ── 7. Make the test runner script executable ─────────────────────────────
      - name: Make run_tests.sh executable
        run: chmod +x run_tests.sh

      # ── 8. Run tests inside Android emulator ──────────────────────────────────
      #
      #    KEY FIX: android-emulator-runner runs each line of script: as its
      #    own /usr/bin/sh -c call. This means multi-line constructs like
      #    until...done and if...fi break with "Syntax error: end of file".
      #
      #    Solution: put ALL shell logic in run_tests.sh (committed to repo),
      #    and script: just calls it with bash. Bash runs the whole file as
      #    one process, so loops and conditionals work perfectly.
      #
      - name: Run Appium tests on emulator
        uses: reactivecircus/android-emulator-runner@v2
        env:
          APPIUM_HOME: /home/runner/.appium
        with:
          api-level: 34
          arch: x86_64
          profile: pixel_6
          target: google_apis_playstore
          avd-name: test_avd
          force-avd-creation: false
          emulator-options: >-
            -no-snapshot-save
            -no-window
            -gpu swiftshader_indirect
            -noaudio
            -no-boot-anim
            -no-metrics
          disable-animations: true
          script: bash run_tests.sh

      # ── 9. Upload screenshots ─────────────────────────────────────────────────
      - name: Upload screenshots
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: screenshots
          path: |
            screenshot.png
            screenshot_1_launch.png
            screenshot_2_results.png
          if-no-files-found: warn
          retention-days: 14

      # ── 10. Upload Appium logs ────────────────────────────────────────────────
      - name: Upload Appium logs
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: appium-logs
          path: appium.log
          if-no-files-found: warn
          retention-days: 14
[20:27, 07/04/2026] +20 15 58057234: run_tests.sh
[20:27, 07/04/2026] +20 15 58057234: #!/usr/bin/env bash
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
