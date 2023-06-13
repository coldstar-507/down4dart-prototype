abstract class David {
  String a = "a";
  String b = "b";

  Map toJson() => {
        "a": a,
        "b": b,
      };
}

class Jeff extends David {
  String j = "j";

  @override
  Map toJson() => {
        ...super.toJson(),
        "j": j,
      };
}

void main() async {
  print(["1", "2", "5", "4", "3"]..sort((a, b) => b.compareTo(a)));
}
