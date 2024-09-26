const chaiHttp = require("chai-http");
const chai = require("chai");
const expect = chai.expect;
chai.use(chaiHttp);
const utils = require('./utils');
const fs = require("fs");

process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
chai.config.truncateThreshold = 4000; // length threshold for actual and expected values in assertion errors

global = {
  checkURL: ({ host, path = "", headers = [], certFile = '', keyFile = '', retCode }) => {
    let cert = certFile ? fs.readFileSync(certFile) : '';
    let key = keyFile ? fs.readFileSync(keyFile) : '';
    let request = chai.request(host).head(path).redirects(0).cert(cert).key(key);
    headers.forEach(header => request.set(header.key, header.value));
    return request
      .send()
      .then(async function (res) {
        expect(res).to.have.status(retCode);
      });
  },
  checkBody: ({ host, path = "", headers = [], body = '', certFile = '', keyFile = '', method = "get", data = "", match = true }) => {
    let cert = certFile ? fs.readFileSync(certFile) : '';
    let key = keyFile ? fs.readFileSync(keyFile) : '';
    let request = chai.request(host);
    if (method === "get") {
      request = request.get(path).redirects(0).cert(cert).key(key);
    } else if (method === "post") {
      request = request.post(path).redirects(0);
    } else if (method === "put") {
      request = request.put(path).redirects(0);
    } else if (method === "head") {
      request = request.head(path).redirects(0);
    } else {
      throw 'The requested method is not implemented.'
    }
    headers.forEach(header => request.set(header.key, header.value));
    return request
      .send(data)
      .then(async function (res) {
        if (match) {
          expect(res.text).to.contain(body);
        } else {
          expect(res.text).not.to.contain(body);
        }
      });
  },
  checkHeaders: ({ host, path = "", headers = [], certFile = '', keyFile = '', expectedHeaders = [] }) => {
    let cert = certFile ? fs.readFileSync(certFile) : '';
    let key = keyFile ? fs.readFileSync(keyFile) : '';
    let request = chai.request(host).get(path).redirects(0).cert(cert).key(key);
    headers.forEach(header => request.set(header.key, header.value));
    return request
      .send()
      .then(async function (res) {
        expectedHeaders.forEach(header => {
          if (header.value === '*') {
            expect(res.header).to.have.property(header.key);
          } else {
            expect(res.header[header.key]).to.equal(header.value);
          }
        });
      });
  },
  checkWithMethod: ({ host, path, headers = [], method = "get", certFile = '', keyFile = '', retCode }) => {
    let cert = certFile ? fs.readFileSync(certFile) : '';
    let key = keyFile ? fs.readFileSync(keyFile) : '';
    var request = chai.request(host);
    switch (method) {
      case 'get':
        request = request.get(path);
        break;
      case 'post':
        request = request.post(path);
        break;
      case 'put':
        request = request.put(path);
        break;
      default:
        throw 'The requested method is not implemented.'
    }
    request.cert(cert).key(key).redirects(0);
    headers.forEach(header => request.set(header.key, header.value));
    return request
      .send()
      .then(async function (res) {
        expect(res).to.have.status(retCode);
      });
  }
};

module.exports = global;

afterEach(function (done) {
  if (this.currentTest.currentRetry() > 0 && this.currentTest.currentRetry() % 5 === 0) {
    console.log(`Test "${this.currentTest.fullTitle()}" retry: ${this.currentTest.currentRetry()}`);
  }
  utils.waitOnFailedTest(done, this.currentTest.currentRetry())
});