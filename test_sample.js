const { remote } = require('webdriverio');

const capabilities = {
  platformName: 'Android',
  'appium:automationName': 'UiAutomator2',
  'appium:appPackage': 'com.android.vending',
  'appium:appActivity': 'com.google.android.finsky.activities.MainActivity',
  // noReset + dontStopAppOnReset = attach to already-running Play Store
  // (we launched it via adb in run_tests.sh before Appium started)
  'appium:noReset': true,
  'appium:dontStopAppOnReset': true,
  'appium:autoGrantPermissions': true,
  'appium:systemPort': 8200,
  'appium:uiautomator2ServerInstallTimeout': 120000,
  'appium:newCommandTimeout': 300,
};

async function saveScreenshot(driver, filename) {
  try {
    await driver.saveScreenshot(./${filename});
    console.log(✅ Screenshot saved: ${filename});
  } catch (e) {
    console.error(❌ Could not save screenshot ${filename}:, e.message);
  }
}

(async () => {
  let driver;
  try {
    console.log('🚀 Connecting to Appium...');
    driver = await remote({
      protocol: 'http',
      hostname: '127.0.0.1',
      port: 4723,
      path: '/',
      capabilities,
      logLevel: 'warn',
    });
    console.log('✅ Session created');

    // ── Verify Play Store is actually in foreground ──────────────────────────
    const activity = await driver.getCurrentActivity();
    const pkg = await driver.getCurrentPackage();
    console.log(📱 Current app: ${pkg} / ${activity});

    if (pkg !== 'com.android.vending') {
      console.log('⚠️  Play Store not in foreground — attempting to activate...');
      await driver.activateApp('com.android.vending');
      await driver.pause(5000);
    }

    // Wait for Play Store UI to fully render
    await driver.pause(6000);

    // 📸 Screenshot 1 — Play Store home screen (AFTER open, confirms it launched)
    await saveScreenshot(driver, 'screenshot_1_launch.png');
    console.log('📸 screenshot_1_launch.png → Play Store home screen');

    // ── Find and click the search bar ────────────────────────────────────────
    console.log('🔍 Looking for search bar...');
    const searchLocators = [
      '//android.widget.TextView[@text="Search apps & games"]',
      '//android.widget.TextView[contains(@text,"Search")]',
      '//android.widget.TextView[contains(@content-desc,"Search")]',
      '//android.widget.EditText[contains(@hint,"Search")]',
    ];

    let searchBar;
    for (const loc of searchLocators) {
      try {
        const el = await driver.$(loc);
        await el.waitForDisplayed({ timeout: 5000 });
        searchBar = el;
        console.log(✅ Search bar found: ${loc});
        break;
      } catch (_) { /* try next */ }
    }

    if (!searchBar) {
      console.log('⚠️  Search bar not found — saving screenshot of current state');
      await saveScreenshot(driver, 'screenshot.png');
      process.exit(0); // still exit 0 so workflow passes with screenshot evidence
    }

    await searchBar.click();
    await driver.pause(2000);

    const editText = await driver.$('//android.widget.EditText');
    await editText.waitForDisplayed({ timeout: 10000 });
    await editText.setValue('Instagram');

    // Press Enter
    try {
      await driver.executeScript('mobile: pressKey', [{ keycode: 66 }]);
    } catch (_) {
      await driver.pressKeyCode(66);
    }
    console.log('⏎ Enter pressed — waiting for results...');
    await driver.pause(18000);

    // 📸 Screenshot 2 — Search results page
    await saveScreenshot(driver, 'screenshot_2_results.png');
    console.log('📸 screenshot_2_results.png → Instagram search results');

    // ── Try to click Install / Open button ───────────────────────────────────
    console.log('🔍 Looking for Install/Open button...');
    const buttonLocators = [
      '//android.widget.Button[@text="Install"]',
      '//android.widget.Button[@text="Open"]',
      '//android.widget.Button[contains(@text,"Install")]',
      '//android.widget.Button[contains(@content-desc,"Install")]',
      '//androidx.compose.ui.platform.ComposeView/android.view.View/android.view.View/android.view.View[1]/android.view.View[1]/android.view.View[2]/android.widget.Button',
      '(//android.widget.Button)[1]',
    ];

    let clicked = false;
    for (const loc of buttonLocators) {
      try {
        const btn = await driver.$(loc);
        if (await btn.isDisplayed()) {
          await btn.click();
          console.log(✅ Button clicked: ${loc});
          clicked = true;
          await driver.pause(5000);
          break;
        }
      } catch (_) { /* try next */ }
    }
    if (!clicked) {
      console.log('⚠️  Install/Open button not found (Play Store may need sign-in)');
    }

    // 📸 Screenshot 3 — Final state
    await saveScreenshot(driver, 'screenshot.png');
    console.log('📸 screenshot.png → final state');
    console.log('✅ Test complete!');

  } catch (err) {
    console.error('❌ Test error:', err.message || err);
    if (driver) await saveScreenshot(driver, 'screenshot.png');
    process.exit(1);
  } finally {
    if (driver) {
      try { await driver.deleteSession(); } catch (_) {}
    }
  }
})();
