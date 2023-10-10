var fs = require('fs');

var stdin = fs.readFileSync(0, 'utf-8');
var arr = []

let data = Object.values(JSON.parse(stdin)).reduce(
    function(a, b) {
        return {...a, ...b};
    },
    []
);
let keys = Object.keys(data);
for (let i = 0; i < keys.length; i++) {
    let sub_keys = Object.keys(data[keys[i]]);
    for (let j = 0; j < sub_keys.length; j++) {
        let outputs = data[keys[i]][sub_keys[j]].Outputs;
        if(!("Outputs" in data[keys[i]][sub_keys[j]])) {
            outputs = data[keys[i]][sub_keys[j]];
        }
        if(Array.isArray(outputs)){ // && "kind" in outputs[0]) {
            outputs.forEach(element => {
                let apiVersion = sub_keys[j].split(",")[0].replace(/^\/+/, "");
                let kind = sub_keys[j].split(",")[1].split("=")[1];
                let obj1 = {apiVersion: apiVersion, kind: kind}
                arr.push({...obj1, ...element});
                
            });
            break;
        }
        if(outputs && Object.keys(outputs).length > 0) {
            let obj_keys = Object.keys(outputs);
            for (let k = 0; k < obj_keys.length; k++) {
                let apiVersion = obj_keys[k].split(",")[0].replace(/^\/+/, "");
if(!obj_keys[k].split(",")[1]) {
  console.log(outputs);
  console.log(k, obj_keys);
}
                let kind = obj_keys[k].split(",")[1].split("=")[1];
                let obj1 = {apiVersion: apiVersion, kind: kind}
                for (let l = 0; l < outputs[obj_keys[k]].length; l++) {
                    let obj2 = outputs[obj_keys[k]][l];
                    arr.push({...obj1, ...obj2});
                }
            }
        }
    }
}
console.log(JSON.stringify(arr));
