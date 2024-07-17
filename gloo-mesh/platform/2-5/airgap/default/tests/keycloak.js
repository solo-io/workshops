const puppeteer = require('puppeteer');
//const utils = require('./utils');

global = {
    getKeyCloakCookie: async (url, user) => {
        const browser = await puppeteer.launch({
            headless: "new",
            ignoreHTTPSErrors: true,
            args: ['--no-sandbox', '--disable-setuid-sandbox'], // needed for instruqt
        });
        const page = await browser.newPage();
        await page.goto(url);
        await page.waitForNetworkIdle({ options: { timeout: 1000 } });
        //await utils.sleep(1000);

        // Enter credentials
        //await page.waitForSelector('#username');
        //await page.waitForSelector('#password');
        await page.type('#username', user);
        await page.type('#password', 'password');
        await page.click('#kc-login');
        await page.waitForNetworkIdle({ options: { timeout: 1000 } });
        //await utils.sleep(1000);

        // Retrieve session cookie
        const cookies = await page.cookies();
        const sessionCookie = cookies.find(cookie => cookie.name === 'keycloak-session');
        let ret;
        if (sessionCookie) {
            ret = `${sessionCookie.name}=${sessionCookie.value}`; // Construct the cookie string
        } else {
            // console.error(await page.content()); // very verbose
            // await page.screenshot({path: 'screenshot.png'});
            console.error(`    No session cookie found for ${user}`);
            ret = "keycloak-session=dummy";
        }
        await browser.close();
        console.log(ret);
        return ret;
    }
};

module.exports = global;
