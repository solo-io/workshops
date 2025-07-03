const fs = require('fs');
const path = require('path');
const { debugLog } = require('./logging');

function enhanceBrowser(browser, testId = 'test', shouldRecord = true) {
  let recorder;
  let page;
  let sanitizedTestId = testId.replace(/ /g, '_');
  const downloadPath = path.resolve('./ui-test-data');
  fs.mkdirSync(downloadPath, { recursive: true });

  async function withTimeout(promise, ms, errorMessage) {
    let timeoutId;
    const timeoutPromise = new Promise((_, reject) => {
      timeoutId = setTimeout(() => reject(new Error(errorMessage)), ms);
    });
    const result = await Promise.race([promise, timeoutPromise]);
    clearTimeout(timeoutId);
    return result;
  }

  function enhancePage(page) {
    const methodsToWrap = ['waitForSelector', 'click', 'goto', 'type'];
    return new Proxy(page, {
      get(target, prop) {
        const originalMethod = target[prop];
        if (typeof originalMethod === 'function' && methodsToWrap.includes(prop)) {
          return async function (...args) {
            try {
              return await originalMethod.apply(target, args);
            } catch (error) {
              const pageContent = await target.content();
              console.error(`Error in page method '${prop}':`, error);
              debugLog('Page content at the time of error:');
              debugLog(pageContent);
              throw error;
            }
          };
        } else if (typeof originalMethod === 'function') {
          return originalMethod.bind(target);
        } else {
          return originalMethod;
        }
      },
    });
  }

  const enhancedBrowser = new Proxy(browser, {
    get(target, prop) {
      if (prop === 'newPage') {
        return async function (...args) {
          page = await target.newPage(...args);
          await page.setViewport({ width: 1500, height: 1000 });
          if (shouldRecord) {
            recorder = await page.screencast({ path: `./ui-test-data/${sanitizedTestId}-recording.webm` });
          }

          // Enhance the page here
          page = enhancePage(page);

          return page;
        };
      } else if (prop === 'close') {
        return async function (...args) {
          if (page) {
            if (shouldRecord && recorder) {
              debugLog('Stopping recorder...');
              try {
                await withTimeout(recorder.stop(), 2000, 'Recorder stop timed out');
                debugLog('Recorder stopped.');
              } catch (e) {
                debugLog('Failed to stop recorder:', e);
              }
            }
            try {
              debugLog('Checking if page has __DUMP_SWR_CACHE__');
              const hasDumpSWRCache = await page.evaluate(() => !!window.__DUMP_SWR_CACHE__);
              if (hasDumpSWRCache) {
                debugLog('Dumping SWR cache...');
                const client = await page.target().createCDPSession();
                const fileName = `${sanitizedTestId}-dump-swr-cache.txt`;
                const fullDownloadPath = path.join(downloadPath, fileName);

                await client.send('Page.setDownloadBehavior', {
                  behavior: 'allow',
                  downloadPath: downloadPath,
                });
                await page.evaluate(() => {
                  window.__DUMP_SWR_CACHE__("dump-swr-cache.txt");
                });

                // waiting for the file to be saved
                await new Promise((resolve) => setTimeout(resolve, 5000));
                fs.renameSync(path.join(downloadPath, "dump-swr-cache.txt"), fullDownloadPath);
                debugLog('UI dump of SWR cache:', fullDownloadPath);
              } else {
                debugLog('__DUMP_SWR_CACHE__ not found on window object.');
              }
            } catch (e) {
              debugLog('Failed to dump SWR cache:', e);
            }
          }
          try {
            await new Promise((resolve) => setTimeout(resolve, 7100));
            await target.close(...args);
          } catch (error) {
            console.error('Error closing browser:', error);
          }
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
