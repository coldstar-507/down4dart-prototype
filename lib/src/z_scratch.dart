import 'dart:convert';
import 'dart:math' as math;

Map<String, dynamic> gCache = {
  "jeff": {"name": "jeff"},
  "andrew": {"name": "andrew"},
};

final ll = [
  {"jeff": "jeff"},
  {"andrew": "andrew"},
];

class Jeff {
  int lol;
  Jeff(this.lol);
}



void main() async {

  Jeff? jeff;
  if (2 % 4 == 1) jeff = Jeff(2);


  print(jeff == null || jeff.lol == 2);



}
