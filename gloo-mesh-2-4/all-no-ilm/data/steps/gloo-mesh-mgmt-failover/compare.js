var fs = require('fs');
var util = require('util');
var hash = require('object-hash');
var jsonDiff = require('json-diff')

const myArgs = process.argv.slice(2);

const first = JSON.parse(fs.readFileSync(myArgs[0], 'utf8'));
const second = JSON.parse(fs.readFileSync(myArgs[1], 'utf8'));

let first_by_metadata = {};
let second_by_metadata = {};

first.forEach(element => {
  first_by_metadata[element.apiVersion + "|" + element.kind + "|" + element.metadata.clusterName + "|" + element.metadata.namespace + "|" + element.metadata.name] = element;
});

second.forEach(element => {
  second_by_metadata[element.apiVersion + "|" + element.kind + "|" + element.metadata.clusterName + "|" + element.metadata.namespace + "|" + element.metadata.name] = element;
});

let in_both_snapshots = {};
let only_in_first_snapshot = {};
let only_in_second_snapshot = {};

Object.keys(first_by_metadata).forEach(key => {
  if(key in second_by_metadata) {
    in_both_snapshots[key] = first_by_metadata[key];
  } else {
    only_in_first_snapshot[key] = first_by_metadata[key];
  }
});

Object.keys(second_by_metadata).forEach(key => {
  if(key in first_by_metadata) {
    in_both_snapshots[key] = second_by_metadata[key];
  } else {
    only_in_second_snapshot[key] = second_by_metadata[key];
  }
});

console.log("In both snapshots");
Object.keys(in_both_snapshots).forEach(key => {
  if(util.isDeepStrictEqual(first_by_metadata[key], second_by_metadata[key])) {
    console.log(key);
  } else {
    console.log("DIFFERENT", key);
    console.log(jsonDiff.diffString(first_by_metadata[key], second_by_metadata[key]));
    console.log(JSON.stringify(first_by_metadata[key], null, 2));
    console.log(JSON.stringify(second_by_metadata[key], null, 2));
  }
});

console.log("Only in first snapshot");
Object.keys(only_in_first_snapshot).forEach(key => {
  console.log(key);
  console.log(JSON.stringify(only_in_first_snapshot[key], null, 2));
});

console.log("Only in second snapshot");
Object.keys(only_in_second_snapshot).forEach(key => {
  console.log(key);
  console.log(JSON.stringify(only_in_second_snapshot[key], null, 2));
});
