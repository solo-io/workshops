const chaiHttp = require("chai-http");
const chai = require("chai");
const expect = chai.expect;
chai.use(chaiHttp);
const utils = require('./utils');

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';

global = {
  checkURL: ({ host, path = "", headers = [], retCode }) => {
    let request = chai.request(host).head(path).redirects(0);
    headers.forEach(header => request.set(header.key, header.value));
    return request
      .send()
      .then(async function (res) {
        expect(res).to.have.status(retCode);
      });
  },
  checkBody: ({ host, path = "", headers = [], body = '', match = true }) => {
    let request = chai.request(host).get(path).redirects(0);
    headers.forEach(header => request.set(header.key, header.value));
    return request
      .send()
      .then(async function (res) {
        if (match) {
          expect(res.text).to.contain(body);
        } else {
          expect(res.text).not.to.contain(body);
        }
      });
  },
  checkHeaders: ({ host, path = "", headers = [], expectedHeaders = [] }) => {
    let request = chai.request(host).get(path).redirects(0);
    headers.forEach(header => request.set(header.key, header.value));
    return request
      .send()
      .then(async function (res) {
          expectedHeaders.forEach(header => expect(res.header[header.key]).to.equal(header.value));
      });
  },
  checkWithMethod: ({ host, path, headers = [], method = "get", retCode }) => {
    let request
    if (method === "get") {
      request = chai.request(host).get(path).redirects(0);
    } else if (method === "post") {
      request = chai.request(host).post(path).redirects(0);
    } else if (method === "put") {
      request = chai.request(host).put(path).redirects(0);
    } else {
      throw 'The requested method is not implemented.'
    }
    headers.forEach(header => request.set(header.key, header.value));
    return request
      .send()
      .then(async function (res) {
        expect(res).to.have.status(retCode);
      });
    }
};

module.exports = global;

afterEach(function(done) { utils.waitOnFailedTest(done, this.currentTest.currentRetry())});