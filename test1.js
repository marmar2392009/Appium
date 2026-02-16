const { remote } = require('webdriverio');

const capabilities={
  "appium:platformName": "Android",
  "appium:deviceName": "127.0.0.1:5555",
  "appium:automationName": "UiAutomator2",
  //"appium:automationName": "UiAutomator2",
  //"appium:app": "path/to/app.apk"
  // "appium:appPackage": "com.facebook.katana",
  // "appium:appActivity": "com.facebook.katana.LoginActivity" // or MainActivity
  //"appium:appPackage": "com.google.android.youtube",
  //"appium:appActivity": "com.google.android.youtube.HomeActivity"
  "appium:appPackage": "com.android.vending",
//"appium:appActivity": "com.google.android.finsky.activities.MainActivity"


};


(async () => {
  const driver = await remote({
    protocol: 'http',
    hostname: '127.0.0.1',
    port: 4723,
    path: '/',
    capabilities: capabilities,
  });

  await driver.pause(30000);
  await driver.$('//android.widget.TextView[@text="Search apps & games"]').click();
  await driver.$('//android.widget.EditText').setValue("Instgram");
  await driver.pressKeyCode(66);
  await driver.pause(10000);
  await driver.$('//androidx.compose.ui.platform.ComposeView/android.view.View/android.view.View/android.view.View[1]/android.view.View[1]/android.view.View[2]/android.widget.Button').click();
await driver.saveScreenshot('./screenshot.png');
await driver.deleteSession();











  



})();

