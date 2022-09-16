
class Jeff {
  List<String>? caca;
  Jeff([this.caca]);
}


void main() {

  var jeff = Jeff();

  var caca = jeff.caca;

  print(caca);
  print(jeff.caca);

  caca = <String>["what", "are", "you", "talking", "about"];

  print(caca);
  print(jeff.caca);


  return;
}
