import 'package:flutter/material.dart';
import 'src/data_objects.dart';
import 'src/render_objects.dart';
import 'src/scratch.dart';


void caca() => print("NIGGGGGGGGGGGGER!!!");

const Console c = Console(
  bottomButtons: [
    ConsoleButton(
      name: "Browse",
      onTap: caca,
    ),
    ConsoleButton(
      name: "Add Friend",
      onTap: caca,
    ),
    ConsoleButton(
      name: "Favorite",
      onTap: caca,
    ),
  ],
  topButtons: [
    ConsoleButton(
      name: "Hyperchat",
      onTap: caca,
    ),
    ConsoleButton(
      name: "Money",
      onTap: caca,
    ),
  ],
);

const t = "I like trains";
const t2 = """
My name is Jeff and one of my favorite activity is to eat cake,
I also like to eat chips and other very tasty food. Luckly for me,
my mom always buy cake and chips and other tasty food because she love me more
than anybody. One of the reason I eat so much is to please my mom.
She loves to see me feeding on the food she gives me.
""";

Message m = const Message("niga", "niga", "niga", "Jeff", 23, t: t2, p: p);
Node jeff = Node(NodeTypes.usr, 'dsf', 'Jeff', 'nigger');
const Color mainBackgroundColor = Color.fromARGB(255, 255, 241, 242);

void main() {
  print("Jeff is a nigger");
  runApp(Container(
    color: const Color.fromARGB(255, 255, 241, 242),
    padding: const EdgeInsets.all(16.0),
    child: Column(textDirection: TextDirection.ltr, children: [
      Palette(jeff, true, caca, caca, caca),
      Container(
        height: 16.0,
      ),
      ChatMessage(
          message: m,
          headerColor: Colors.pink,
          bodyColor: buttonColor,
          myMessage: true,
          selected: true,
          select: caca),
      Expanded(
        child: Container(),
      ),
      c
    ]),
  ));
}

