import 'dart:convert';

var nigger = ["jeff", null, "shitfuck", null, "nigger"].join("\$");
var nigger2 = [].join(" ");
var nigger8 = ["", "", "", ""].join("^");


var jsonString = '[ {"jeff": 3}, {"nigger": true} ]';


var nigg = '{"jj": [1,2,3,4,5], "fuck": false }';

void main() {
  var dec = jsonDecode(nigg);

  for ( var i in dec["jj"]) {
    print(i);
  }

  if(!dec["fuck"]) {
    print("nigger");
  } else {
    print("lol");
  }

}
