import 'package:flutter/material.dart';
import '../boxes.dart';
import '../render_objects/console.dart';

class SnipViewPage extends StatelessWidget {
  final Widget displayMedia;
  final String? text;
  final void Function() back;
  final void Function() next;
  const SnipViewPage({
    required this.displayMedia,
    required this.back,
    required this.next,
    this.text,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      SizedBox(
        height: Sizes.fullHeight,
        width: Sizes.w,
        child: displayMedia,
      ),
      text != "" && text != null
          ? Center(
              child: Container(
                width: Sizes.w,
                decoration: const BoxDecoration(
                  // border: Border.symmetric(
                  //   horizontal: BorderSide(color: Colors.black38),
                  // ),
                  color: Colors.black38,
                  // color: PinkTheme.snipRibbon,
                ),
                constraints: BoxConstraints(
                  minHeight: 16,
                  maxHeight: Sizes.fullHeight,
                ),
                child: Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : const SizedBox.shrink(),
      Positioned(
        bottom: 0,
        left: 0,
        child: SizedBox(
          width: Sizes.w,
          child: Console(
            invertedColors: true,
            bottomButtons: [
              ConsoleButton(name: "Back", onPress: back),
              ConsoleButton(name: "Next", onPress: next),
            ],
          ),
        ),
      ),
    ]);
  }
}

// Future<void> snipView(ChatableNode node) async {
//   if (node.snips.isEmpty) {
//     writePalette(node);
//     homePage();
//   } else {
//     final snip = node.snips.first;
//     node.snips.remove(snip); // consume it
//     b.saveNode(node);
//     Down4Media? media;
//     dynamic jsonEncodedMedia;
//     if ((jsonEncodedMedia = b.snips.get(snip)) == null) {
//       media = await r.getMessageMedia(snip);
//     } else {
//       media = Down4Media.fromJson(jsonDecode(jsonEncodedMedia));
//       b.snips.delete(snip); // consume it
//     }
//     if (media == null) {
//       writePalette(node);
//       homePage();
//     }
//     final scale =
//         1 / (media!.metadata.aspectRatio ?? 1.0 * Sizes.fullAspectRatio);
//     if (media.metadata.isVideo) {
//       var f = b.writeMediaToFile(media);
//       var ctrl = VideoPlayerController.file(f);
//       await ctrl.initialize();
//       await ctrl.setLooping(true);
//       await ctrl.play();
//
//       _page = Stack(children: [
//         SizedBox(
//           height: Sizes.fullHeight,
//           width: Sizes.w,
//           child: Transform.scale(
//             scaleX: 1 / scale,
//             child: Transform(
//               alignment: Alignment.center,
//               transform:
//                   Matrix4.rotationY(media.metadata.toReverse ? math.pi : 0),
//               child: VideoPlayer(ctrl),
//             ),
//           ),
//         ),
//         media.metadata.text != "" && media.metadata.text != null
//             ? Center(
//                 child: Container(
//                   width: Sizes.w,
//                   decoration: const BoxDecoration(
//                     // border: Border.symmetric(
//                     //   horizontal: BorderSide(color: Colors.black38),
//                     // ),
//                     color: Colors.black38,
//                     // color: PinkTheme.snipRibbon,
//                   ),
//                   constraints: BoxConstraints(
//                     minHeight: 16,
//                     maxHeight: Sizes.fullHeight,
//                   ),
//                   child: Text(
//                     media.metadata.text!,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 ),
//               )
//             : const SizedBox.shrink(),
//         Positioned(
//           bottom: 0,
//           left: 0,
//           child: Console(bottomButtons: [
//             ConsoleButton(
//               name: "Back",
//               onPress: () async {
//                 await ctrl.dispose();
//                 f.delete();
//                 writePalette(node);
//                 homePage();
//               },
//             ),
//             ConsoleButton(
//               name: "Next",
//               onPress: () async {
//                 await ctrl.dispose();
//                 f.delete();
//                 snipView(node);
//               },
//             ),
//           ]),
//         ),
//       ]);
//     } else {
//       await precacheImage(MemoryImage(media.data), context);
//       _page = Stack(children: [
//         SizedBox(
//           height: Sizes.fullHeight,
//           width: Sizes.w,
//           child: Transform(
//             alignment: Alignment.center,
//             transform:
//                 Matrix4.rotationY(media.metadata.toReverse ? math.pi : 0),
//             child: Image.memory(
//               media.data,
//               fit: BoxFit.cover,
//               gaplessPlayback: true,
//             ),
//           ),
//         ),
//         media.metadata.text != "" && media.metadata.text != null
//             ? Center(
//                 child: Container(
//                   width: Sizes.w,
//                   decoration: const BoxDecoration(
//                     // border: Border.symmetric(
//                     //   horizontal: BorderSide(color: Colors.black38),
//                     // ),
//                     color: Colors.black38,
//                     // color: PinkTheme.snipRibbon,
//                   ),
//                   constraints: BoxConstraints(
//                     minHeight: 16,
//                     maxHeight: Sizes.fullHeight,
//                   ),
//                   child: Text(
//                     media.metadata.text!,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(color: Colors.white),
//                   ),
//                 ),
//               )
//             : const SizedBox.shrink(),
//         Positioned(
//             bottom: 0,
//             left: 0,
//             child: SizedBox(
//               width: Sizes.w,
//               child: Console(
//                 invertedColors: true,
//                 bottomButtons: [
//                   ConsoleButton(
//                       name: "Back",
//                       onPress: () {
//                         writePalette(node);
//                         homePage();
//                       }),
//                   ConsoleButton(name: "Next", onPress: () => snipView(node)),
//                 ],
//               ),
//             ))
//       ]);
//     }
//     setState(() {});
//   }
// }
