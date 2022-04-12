void Function(String)? caca;

jeff(int niggerIQ, void Function()? j) {
  print("nigger has $niggerIQ IQ");
  j?.call();
}

Function? j = (args) => print(args ?? "default");

Function g = () => print("FJSKDLFJKL");

void main() {
  //j?.call();
  j?.call(null);
  j?.call("Jeff");

  g(2);
}
