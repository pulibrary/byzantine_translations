const PercyScript = require('@percy/script');

PercyScript.run(async (page, percySnapshot) => {
  await page.goto('http://byzantine.lndo.site');
  // ensure the page has loaded before capturing a snapshot
  await page.waitFor('.title');
  await percySnapshot('homepage');
});
