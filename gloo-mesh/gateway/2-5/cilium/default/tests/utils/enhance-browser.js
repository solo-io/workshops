const fs = require('fs');
const path = require('path');

function enhanceBrowser(browser, testId = 'test') {
  let recorder;
  let page;
  let sanitizedTestId = testId.replace(/ /g, '_');
  const downloadPath = path.resolve('./ui-test-data');
  fs.mkdirSync(downloadPath, { recursive: true });

  const enhancedBrowser = new Proxy(browser, {
    get(target, prop) {
      if (prop === 'newPage') {
        return async function (...args) {
          page = await target.newPage(...args);
          await page.setViewport({ width: 1500, height: 1000 });

          recorder = await page.screencast({ path: `./ui-test-data/${sanitizedTestId}-recording.webm` });
          return page;
        };
      } else if (prop === 'close') {
        return async function (...args) {
          if (page && recorder) {
            const client = await page.target().createCDPSession();

            const fileName = `${sanitizedTestId}-dump-swr-cache.txt`;
            const fullDownloadPath = path.join(downloadPath, fileName);

            await client.send('Page.setDownloadBehavior', {
              behavior: 'allow',
              downloadPath: downloadPath,
            });

            try {
              if (window.__DUMP_SWR_CACHE__) {
                await page.evaluate(function () {
                  window.__DUMP_SWR_CACHE__("dump-swr-cache.txt");
                });

                // waiting for the file to be saved
                await new Promise((resolve) => setTimeout(resolve, 5000));
                fs.renameSync(path.join(downloadPath, "dump-swr-cache.txt"), fullDownloadPath);
                console.debug('UI dump of swr cache:', fullDownloadPath);
              }
            } catch (e) {
              console.error('Failed to dump swr cache');
            }

            await recorder.stop();
          }

          await target.close(...args);
        };
      } else {
        const value = target[prop];
        if (typeof value === 'function') {
          return value.bind(target);
        } else {
          return value;
        }
      }
    },
  });

  return enhancedBrowser;
}

module.exports = { enhanceBrowser };
