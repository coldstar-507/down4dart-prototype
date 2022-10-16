import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data_objects.dart';
import '../themes.dart';

import 'palette.dart';
import 'utils.dart';

class UserPaletteMaker extends StatelessWidget {
  final void Function(Map<String, String>) infoCallBack;
  final Map<String, dynamic> info;
  const UserPaletteMaker(
      {required this.infoCallBack, required this.info, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tec = TextEditingController()
      ..text = info['id'].toLowerCase()
      ..selection = TextSelection.collapsed(offset: info['id'].length);
    return Container(
      height: Palette.height,
      margin: const EdgeInsets.only(left: 22.0, right: 22.0),
      decoration: BoxDecoration(
          boxShadow: const [
            BoxShadow(
                color: Colors.black54,
                blurRadius: 6.0,
                spreadRadius: -6.0,
                offset: Offset(8.0, 8.0),
                blurStyle: BlurStyle.normal)
          ],
          borderRadius: const BorderRadius.all(Radius.circular(6.0)),
          border: Border.all(width: 2.0, color: Colors.transparent)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: () async {
              FilePickerResult? r = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['jpg', 'png', 'jpeg'],
                  withData: true);
              if (r?.files.single.bytes != null) {
                infoCallBack(
                  {...info, 'image': base64Encode(r!.files.single.bytes!)},
                );
              }
            },
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4.0),
                    bottomLeft: Radius.circular(4.0),
                  )),
              width: Palette.height - 2.0, // borderWidth x2
              child: info['image'] == null || info['image'] == ""
                  ? Image.asset(
                'lib/src/assets/picture_place_holder_2.png',
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
                  : Image.memory(
                base64Decode(info['image']!),
                gaplessPlayback: true,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                color: PinkTheme.headerColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4.0),
                  bottomRight: Radius.circular(4.0),
                ),
              ),
              padding: const EdgeInsets.only(left: 10.0, top: 10.0),
              child: TextField(
                controller: tec,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  isDense: true,
                  prefixText: info['id'] == "" ? "" : "@",
                  hintText: "@username",
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.only(bottom: Palette.height / 2),
                ),
                textDirection: TextDirection.ltr,
                onChanged: ((value) {
                  infoCallBack({...info, 'id': value.toLowerCase()});
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UserMakerPalette extends StatelessWidget {
  static const double height = 60.0;
  final String name, lastName, id;
  final List<int> image;
  final void Function() selectFile;

  const UserMakerPalette({
    required this.name,
    required this.lastName,
    required this.id,
    required this.selectFile,
    required this.image,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Palette.height,
      margin: const EdgeInsets.only(left: 22.0, right: 22.0),
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 6.0,
            spreadRadius: -6.0,
            offset: Offset(8.0, 8.0),
            blurStyle: BlurStyle.normal,
          ),
        ],
        borderRadius: const BorderRadius.all(Radius.circular(6.0)),
        border: Border.all(width: 2.0, color: Colors.transparent),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        textDirection: TextDirection.ltr,
        children: [
          GestureDetector(
            onTap: selectFile,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4.0),
                  bottomLeft: Radius.circular(4.0),
                ),
              ),
              width: Palette.height - 2.0, // borderWidth x2
              child: image.isNotEmpty
                  ? Image.memory(
                Uint8List.fromList(image),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
                  : Image.asset(
                'lib/src/assets/picture_place_holder_2.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: PinkTheme.headerColor,
                border: Border(
                  left: BorderSide(color: PinkTheme.headerColor, width: 1.0),
                ),
              ),
              padding: const EdgeInsets.only(left: 6.0, top: 5.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (name == '' ? "Name" : name) +
                        " " +
                        (lastName == '' ? "" : lastName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  Text(
                    "@" + (id == '' ? "username" : id),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.normal),
                  )
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2.0),
            decoration: const BoxDecoration(
              color: PinkTheme.headerColor,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(4.0),
                bottomRight: Radius.circular(4.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PaletteMaker extends StatelessWidget {
  final void Function(String) nameCallBack;
  final void Function(Uint8List) imageCallBack;
  final String name, id;
  final String hintText;
  final Uint8List image;
  final void Function(Identifier)? go;
  final Nodes type;
  final Nodes? parentType;
  final TextEditingController tec;
  const PaletteMaker({
    required this.tec,
    required this.id,
    required this.name,
    required this.nameCallBack,
    required this.imageCallBack,
    required this.image,
    required this.hintText,
    this.go,
    this.type = Nodes.user,
    this.parentType,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        height: Palette.height,
        margin: const EdgeInsets.only(left: 22.0, right: 22.0),
        decoration: BoxDecoration(
            boxShadow: const [
              BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6.0,
                  spreadRadius: -6.0,
                  offset: Offset(8.0, 8.0),
                  blurStyle: BlurStyle.normal)
            ],
            borderRadius: const BorderRadius.all(Radius.circular(6.0)),
            border: Border.all(width: 2.0, color: Colors.transparent)),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: TextDirection.ltr,
            children: [
              GestureDetector(
                onTap: () async {
                  FilePickerResult? r = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'png', 'jpeg'],
                      withData: true);
                  if (r?.files.single.bytes != null) {
                    imageCallBack(r!.files.single.bytes!);
                  }
                },
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4.0),
                        bottomLeft: Radius.circular(4.0),
                      )),
                  width: Palette.height - 2.0, // borderWidth x2
                  child: image.isEmpty
                      ? Image.asset(
                    'lib/src/assets/picture_place_holder_2.png',
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                      : Image.memory(
                    image,
                    gaplessPlayback: true,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                    padding: const EdgeInsets.only(left: 10.0, top: 10.0),
                    color: PinkTheme.nodeColors[type], //PinkTheme.headerColor,
                    child: Down4Input(
                      tec: tec,
                      inputCallBack: nameCallBack,
                      placeHolder: hintText,
                      padding:
                      const EdgeInsets.only(bottom: Palette.height / 2),
                    ) // TextField(
                  //   textAlignVertical: TextAlignVertical.top,
                  //   decoration: InputDecoration(
                  //       hintText: hintText,
                  //       border: InputBorder.none,
                  //       contentPadding: const EdgeInsets.only(
                  //           bottom: (SingleActionPalette.height) / 2)),
                  //   textDirection: TextDirection.ltr,
                  //   onChanged: nameCallBack,
                  // ),
                ),
              ),
              GestureDetector(
                  onTap: () {
                    if (name.isNotEmpty && image.isNotEmpty) {
                      go?.call(id);
                    }
                  },
                  child: Container(
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.all(2.0),
                      width: type != Nodes.user ? Palette.height - 2.0 : 4.0,
                      decoration: BoxDecoration(
                          color: PinkTheme
                              .nodeColors[type], //PinkTheme.headerColor,
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4.0),
                              bottomRight: Radius.circular(4.0))),
                      child: go != null
                          ? Image.asset('lib/src/assets/rightBlackArrow.png')
                          : const SizedBox.shrink()))
            ]));
  }
}

// class LocalPaletteMaker extends StatelessWidget {
//   final void Function(String) nameCallBack;
//   final void Function(Uint8List) imageCallBack;
//   final String name, id;
//   final String hintText;
//   final Uint8List image;
//   final LocalNodes type;
//   const LocalPaletteMaker({
//     required this.id,
//     required this.name,
//     required this.nameCallBack,
//     required this.imageCallBack,
//     required this.image,
//     required this.hintText,
//     required this.type,
//     Key? key,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: Palette.height,
//       margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//       decoration: BoxDecoration(
//           boxShadow: const [
//             BoxShadow(
//                 color: Colors.black54,
//                 blurRadius: 6.0,
//                 spreadRadius: -6.0,
//                 offset: Offset(8.0, 8.0),
//                 blurStyle: BlurStyle.normal)
//           ],
//           borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//           border: Border.all(width: 2.0, color: Colors.transparent)),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         textDirection: TextDirection.ltr,
//         children: [
//           GestureDetector(
//             onTap: () async {
//               FilePickerResult? r = await FilePicker.platform.pickFiles(
//                   type: FileType.custom,
//                   allowedExtensions: ['jpg', 'png', 'jpeg'],
//                   withData: true);
//               if (r?.files.single.bytes != null) {
//                 imageCallBack(r!.files.single.bytes!);
//               }
//             },
//             child: Container(
//               clipBehavior: Clip.hardEdge,
//               decoration: const BoxDecoration(
//                   borderRadius: BorderRadius.only(
//                 topLeft: Radius.circular(4.0),
//                 bottomLeft: Radius.circular(4.0),
//               )),
//               width: Palette.height - 2.0, // borderWidth x2
//               child: image.isEmpty
//                   ? Image.asset(
//                       'lib/src/assets/picture_place_holder_2.png',
//                       fit: BoxFit.cover,
//                       gaplessPlayback: true,
//                     )
//                   : Image.memory(
//                       image,
//                       gaplessPlayback: true,
//                       fit: BoxFit.cover,
//                     ),
//             ),
//           ),
//           Expanded(
//             child: Container(
//                 padding: const EdgeInsets.only(left: 10.0, top: 10.0),
//                 color: PinkTheme.nodeColors[type], //PinkTheme.headerColor,
//                 child: Down4Input(
//                   inputCallBack: nameCallBack,
//                   placeHolder: hintText,
//                   padding: const EdgeInsets.only(bottom: Palette.height / 2),
//                 ) // TextField(
//                 //   textAlignVertical: TextAlignVertical.top,
//                 //   decoration: InputDecoration(
//                 //       hintText: hintText,
//                 //       border: InputBorder.none,
//                 //       contentPadding: const EdgeInsets.only(
//                 //           bottom: (SingleActionPalette.height) / 2)),
//                 //   textDirection: TextDirection.ltr,
//                 //   onChanged: nameCallBack,
//                 // ),
//                 ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class LocalPalette extends StatelessWidget {
//   static const double height = 60.0;
//   final LocalNode node;
//   final void Function(String)? imPress,
//       bodyPress,
//       imLongPress,
//       bodyLongPress,
//       goPress,
//       goLongPress;
//   final bool selected;

//   const LocalPalette({
//     required this.node,
//     this.imPress,
//     this.bodyPress,
//     this.imLongPress,
//     this.bodyLongPress,
//     this.goLongPress,
//     this.goPress,
//     this.selected = false,
//     Key? key,
//   }) : super(key: key);

//   LocalPalette invertedSelection() {
//     return LocalPalette(
//       node: node,
//       selected: !selected,
//       imPress: imPress,
//       imLongPress: imLongPress,
//       bodyPress: bodyPress,
//       bodyLongPress: bodyLongPress,
//       goPress: goPress,
//       goLongPress: goLongPress,
//     );
//   }

//   LocalPalette deactivated() {
//     return LocalPalette(
//       node: node,
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: Palette.height,
//       margin: const EdgeInsets.only(left: 22.0, right: 22.0),
//       decoration: BoxDecoration(
//         boxShadow: !selected
//             ? [
//                 const BoxShadow(
//                   color: Colors.black54,
//                   blurRadius: 6.0,
//                   spreadRadius: -6.0,
//                   offset: Offset(8.0, 8.0),
//                   blurStyle: BlurStyle.normal,
//                 )
//               ]
//             : null,
//         borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//         border: Border.all(
//           width: 2.0,
//           color: selected ? PinkTheme.black : Colors.transparent,
//         ),
//       ),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.stretch,
//         textDirection: TextDirection.ltr,
//         children: [
//           GestureDetector(
//             onTap: () => imPress?.call(node.id),
//             onLongPress: () => imLongPress?.call(node.id),
//             child: Container(
//               clipBehavior: Clip.hardEdge,
//               decoration: const BoxDecoration(
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(4.0),
//                   bottomLeft: Radius.circular(4.0),
//                 ),
//               ),
//               width: Palette.height - 2.0, // borderWidth x2
//               child: Image.memory(
//                 node.image.data,
//                 fit: BoxFit.cover,
//               ),
//             ),
//           ),
//           Expanded(
//             child: GestureDetector(
//               onTap: () => bodyPress?.call(node.id),
//               onLongPress: () => bodyLongPress?.call(node.id),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: PinkTheme.nodeColors[node.type],
//                   border: Border(
//                     left: BorderSide(
//                       color: selected
//                           ? PinkTheme.black
//                           : PinkTheme.nodeColors[node.type]!,
//                       width: 1.0,
//                     ),
//                   ),
//                 ),
//                 padding: const EdgeInsets.only(left: 6.0, top: 5.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.start,
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       node.name + " " + (node.lastName ?? ""),
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight:
//                             selected ? FontWeight.bold : FontWeight.normal,
//                       ),
//                     ),
//                     node.type == Nodes.user
//                         ? Text(
//                             "@" + node.id,
//                             style: TextStyle(
//                               fontSize: 10,
//                               fontWeight: selected
//                                   ? FontWeight.bold
//                                   : FontWeight.normal,
//                             ),
//                           )
//                         : const SizedBox.shrink(),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           goPress != null
//               ? GestureDetector(
//                   onTap: () => goPress!.call(node.id),
//                   onLongPress: () => goLongPress?.call(node.id),
//                   child: Container(
//                     padding: const EdgeInsets.all(2.0),
//                     decoration: BoxDecoration(
//                       color: PinkTheme.nodeColors[node.type],
//                       borderRadius: const BorderRadius.only(
//                         topRight: Radius.circular(4.0),
//                         bottomRight: Radius.circular(4.0),
//                       ),
//                     ),
//                     child: Image.asset(
//                       "lib/src/assets/rightBlackArrow.png",
//                       fit: BoxFit.cover,
//                     ),
//                   ),
//                 )
//               : Container(
//                   padding: const EdgeInsets.all(2.0),
//                   decoration: BoxDecoration(
//                     color: PinkTheme.nodeColors[node.type],
//                     borderRadius: const BorderRadius.only(
//                       topRight: Radius.circular(4.0),
//                       bottomRight: Radius.circular(4.0),
//                     ),
//                   ),
//                 ),
//         ],
//       ),
//     );
//   }
// }