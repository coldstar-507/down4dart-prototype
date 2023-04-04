import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:base85/base85.dart';
import 'package:image/image.dart' as IMG;

abstract class Jeff {
  int caca = 0;
  void lol();
}

mixin David on Jeff {
  void calisse() => print("CALISSE");
}

mixin Andrew on David {
  void redAlert() => print("RED ALERT");
}

class Helene extends Jeff with David {
  @override
  lol() => print("HAHA");
}

class Scott extends Jeff with David, Andrew {
  @override
  lol() => print("lol");
}

extension on Iterable<Jeff> {
  Iterable<T> asNiggers<T extends Jeff>() => where((e) => e.caca == 0).cast();
}

class Palette<T extends Jeff> {
  T jeff;
  Palette(this.jeff);
}

extension on Iterable<Palette> {
  Iterable<Palette<T>> thoseNiggas<T extends Jeff>() => whereType<Palette<T>>();
  Iterable<Palette<T>> those<T extends Jeff>() =>
      where((e) => e.jeff is T).cast<Palette<T>>();
}

void main() async {
  List<Palette<David>> cacas = [
    Palette<David>(Scott()),
    Palette<David>(Helene()),
  ];

  print(cacas.those<Andrew>());
}
