import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../globals.dart';

import '../data_objects.dart';
import '../pages/_page_utils.dart';
import '../themes.dart';

import 'palette.dart';
import '_render_utils.dart';

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
      height: Palette.paletteHeight,
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
              width: Palette.paletteHeight - 2.0, // borderWidth x2
              child: info['image'] == null || info['image'] == ""
                  ? Image.asset(
                      'assets/images/picture_place_holder_2.png',
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
                // color: PinkTheme.headerColor,
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
                      EdgeInsets.only(bottom: Palette.paletteHeight / 2),
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
  final String name, lastName, id;
  final FireMedia? media;
  final void Function() selectFile;

  const UserMakerPalette({
    required this.name,
    required this.lastName,
    required this.id,
    required this.selectFile,
    required this.media,
    Key? key,
  }) : super(key: key);

  Widget get placeHolderImage => GestureDetector(
        onTap: selectFile,
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.horizontal(
              left: Radius.circular(4.0),
            ),
          ),
          height: Palette.paletteHeight,
          width: Palette.paletteHeight, // borderWidth x2
          child: media != null
              ? FireImageDisplay(
                  media!,
                  Size.square(Palette.paletteHeight),
                  true,
                )
              : g.ph,
        ),
      );

  Widget get body => Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: g.theme.nodeColors[NodesColor.self],
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(4.0),
            ),
          ),
          padding: const EdgeInsets.only(left: 6.0, top: 5.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${name == "" ? "Name" : name} ${lastName == "" ? "" : lastName}",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
              Text(
                "@${id == '' ? "username" : id}",
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.normal),
              )
            ],
          ),
        ),
      );

  Widget mainContainer({required Widget child}) => Container(
      height: Palette.paletteHeight,
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: Palette.gapSize),
      decoration: BoxDecoration(
        // borderRadius: BorderRadius.circular(4.0),
        boxShadow: [
          BoxShadow(
            color: Palette.shadowColor,
            blurRadius: Palette.blurRadius,
            spreadRadius: Palette.spreadRadius,
            offset: Palette.shadowOffset,
            blurStyle: BlurStyle.normal,
          ),
        ],
        // borderRadius: const BorderRadius.all(Radius.circular(6.0)),
        border: Border.all(width: 2.0, color: Colors.transparent),
      ),
      child: child);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
          height: Palette.paletteHeight,
          margin: EdgeInsets.symmetric(horizontal: Palette.paletteMargin),
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
            children: [placeHolderImage, body], //end],
          )),
      const SizedBox(height: 8)
    ]);
  }
}

// class PaletteMaker extends StatelessWidget {
//   final void Function(String)? nameCallBack;
//   final void Function() imagePress;
//   final String name, id;
//   final String hintText;
//   final FireMedia? image;
//   final void Function(ID)? go;
//   final NodesColor colorCode;
//   final Nodes type;
//   final Nodes? parentType;
//   final TextEditingController tec;
//   final bool fold;
//   const PaletteMaker({
//     required this.fold,
//     required this.colorCode,
//     required this.tec,
//     required this.id,
//     required this.name,
//     this.nameCallBack,
//     required this.imagePress,
//     this.image,
//     required this.hintText,
//     this.go,
//     this.type = Nodes.user,
//     this.parentType,
//     Key? key,
//   }) : super(key: key);
//
//   Widget mainContainer({required Widget child}) => AnimatedOpacity(
//       opacity: fold ? 0 : 1,
//       duration: const Duration(milliseconds: 600),
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 600),
//         height: fold ? 0 : Palette.paletteHeight,
//         margin: EdgeInsets.only(
//           left: Palette.paletteMargin,
//           right: Palette.paletteMargin,
//           bottom: fold ? 0 : Palette.gapSize,
//         ),
//         clipBehavior: Clip.hardEdge,
//         decoration: BoxDecoration(
//             boxShadow: [
//               BoxShadow(
//                   color: Palette.shadowColor,
//                   blurRadius: Palette.blurRadius,
//                   spreadRadius: Palette.spreadRadius,
//                   offset: Palette.shadowOffset,
//                   blurStyle: BlurStyle.normal)
//             ],
//             borderRadius: const BorderRadius.all(Radius.circular(6.0)),
//             border: Border.all(width: 2.0, color: Colors.transparent)),
//         child: child,
//       ));
//
//   Widget customRow({required List<Widget> children}) => Container(
//         clipBehavior: Clip.hardEdge,
//         decoration: BoxDecoration(
//           color: g.theme.nodeColors[colorCode],
//           borderRadius: const BorderRadius.all(Radius.circular(4.0)),
//         ),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           textDirection: TextDirection.ltr,
//           children: children,
//         ),
//       );
//
//   Widget get _defaultImage {
//     switch (type) {
//       case Nodes.user:
//         return g.ph;
//
//       case Nodes.hyperchat:
//         return g.ph;
//
//       case Nodes.group:
//         return g.ph;
//
//       case Nodes.self:
//         return g.ph;
//
//       case Nodes.root:
//         return g.ph;
//
//       case Nodes.market:
//         return g.ph;
//
//       case Nodes.checkpoint:
//         return g.ph;
//
//       case Nodes.journal:
//         return g.ph;
//
//       case Nodes.item:
//         return g.ph;
//
//       case Nodes.event:
//         return g.ph;
//
//       case Nodes.ticket:
//         return g.ph;
//
//       case Nodes.payment:
//         throw 'We are not going to be paletteMaking payments';
//     }
//   }
//
//   Widget get paletteImage => GestureDetector(
//         onTap: imagePress,
//         child: SizedBox(
//           width: Palette.paletteHeight, // borderWidth x2
//           child: image != null
//               ? image!.display(
//                   size: Size.square(Palette.paletteHeight), forceSquare: true)
//               : _defaultImage,
//         ),
//       );
//
//   Widget get paletteBody => Expanded(
//         child: Container(
//           padding: const EdgeInsets.only(left: 10.0, top: 10.0),
//           child: Down4Input(
//             tec: tec,
//             inputCallBack: nameCallBack,
//             placeHolder: hintText,
//             padding: EdgeInsets.only(bottom: Palette.paletteHeight / 2),
//           ),
//         ),
//       );
//
//   Widget get paletteAction => GestureDetector(
//       onTap: () {
//         if (name.isNotEmpty && image != null) {
//           go?.call(id);
//         }
//       },
//       child: Container(
//           padding: const EdgeInsets.all(2.0),
//           width: Palette.paletteHeight - 4,
//           height: Palette.paletteHeight - 4,
//           child: go != null
//               ? Image.asset('assets/images/filled.png')
//               : const SizedBox.shrink()));
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         mainContainer(
//           child: customRow(
//             children: [paletteImage, paletteBody, paletteAction],
//           ),
//         ),
//         const SizedBox(height: 0)
//       ],
//     );
//   }
// }

class PaletteMaker extends StatelessWidget {
  // final void Function(String)? nameCallBack;
  final void Function() imagePress;
  final String name, id;
  // final String hintText;
  final FireMedia? image;
  final void Function(ID)? go;
  final NodesColor colorCode;
  final Nodes type;
  final Nodes? parentType;
  final MyTextEditor tec;
  final bool fold;
  const PaletteMaker({
    required this.fold,
    required this.colorCode,
    required this.tec,
    required this.id,
    required this.name,
    // this.nameCallBack,
    required this.imagePress,
    this.image,
    // required this.hintText,
    this.go,
    this.type = Nodes.user,
    this.parentType,
    Key? key,
  }) : super(key: key);

  // Widget get body => Expanded(
  //   child: GestureDetector(
  //     onTap: bodyPress,
  //     behavior: HitTestBehavior.opaque,
  //     onLongPress: bodyLongPress,
  //     child: Padding(
  //       padding: const EdgeInsets.only(left: 8, bottom: 8, top: 1),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.stretch,
  //         children: [
  //           Text(node.displayName,
  //               maxLines: 1,
  //               overflow: TextOverflow.clip,
  //               style: TextStyle(
  //                   overflow: TextOverflow.ellipsis,
  //                   fontSize: 16,
  //                   color: g.theme.paletteTextColor,
  //                   fontWeight:
  //                   selected ? FontWeight.bold : FontWeight.normal)),
  //           Text(node.displayID,
  //               maxLines: 1,
  //               overflow: TextOverflow.clip,
  //               style: TextStyle(
  //                   fontSize: 8,
  //                   color: g.theme.idColor,
  //                   fontStyle: FontStyle.italic,
  //                   fontWeight:
  //                   selected ? FontWeight.bold : FontWeight.normal)),
  //           const Spacer(),
  //           messagePreview != null
  //               ? Text(messagePreview!,
  //               overflow: TextOverflow.ellipsis,
  //               maxLines: 1,
  //               style: TextStyle(
  //                   fontSize: 13,
  //                   color: g.theme.paletteTextColor,
  //                   fontWeight: !selected
  //                       ? FontWeight.normal
  //                       : FontWeight.bold))
  //               : const SizedBox.shrink()
  //         ],
  //       ),
  //     ),
  //   ),
  // );
  //
  Widget imageContainer({required Widget image}) {
    return Container(
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        child: image);
  }

  Widget mainContainer({required Widget child}) {
    return Container(
      height: Palette2.fullHeight,
      // width: squish ? 0 : null,
      // clipBehavior: Clip.hardEdge,
      color: g.theme.backGroundColor,
      padding: EdgeInsets.all(Palette2.padding / 2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(5)),
          color: g.theme.backGroundColor,
        ),
        padding: EdgeInsets.all(Palette2.padding / 2),
        child: child,
      ),
    );
  }

  ///////////

  // Widget mainContainer({required Widget child}) => AnimatedOpacity(
  //     opacity: fold ? 0 : 1,
  //     duration: const Duration(milliseconds: 600),
  //     child: AnimatedContainer(
  //       duration: const Duration(milliseconds: 600),
  //       height: fold ? 0 : Palette.paletteHeight,
  //       margin: EdgeInsets.only(
  //         left: Palette.paletteMargin,
  //         right: Palette.paletteMargin,
  //         bottom: fold ? 0 : Palette.gapSize,
  //       ),
  //       clipBehavior: Clip.hardEdge,
  //       decoration: BoxDecoration(
  //           boxShadow: [
  //             BoxShadow(
  //                 color: Palette.shadowColor,
  //                 blurRadius: Palette.blurRadius,
  //                 spreadRadius: Palette.spreadRadius,
  //                 offset: Palette.shadowOffset,
  //                 blurStyle: BlurStyle.normal)
  //           ],
  //           borderRadius: const BorderRadius.all(Radius.circular(6.0)),
  //           border: Border.all(width: 2.0, color: Colors.transparent)),
  //       child: child,
  //     ));
  //
  // Widget customRow({required List<Widget> children}) => Container(
  //   clipBehavior: Clip.hardEdge,
  //   decoration: BoxDecoration(
  //     color: g.theme.nodeColors[colorCode],
  //     borderRadius: const BorderRadius.all(Radius.circular(4.0)),
  //   ),
  //   child: Row(
  //     crossAxisAlignment: CrossAxisAlignment.stretch,
  //     textDirection: TextDirection.ltr,
  //     children: children,
  //   ),
  // );

  Widget get _defaultImage {
    switch (type) {
      case Nodes.user:
        return g.ph;

      case Nodes.hyperchat:
        return g.ph;

      case Nodes.group:
        return g.ph;

      case Nodes.self:
        return g.ph;

      case Nodes.root:
        return g.ph;

      case Nodes.market:
        return g.ph;

      case Nodes.checkpoint:
        return g.ph;

      case Nodes.journal:
        return g.ph;

      case Nodes.item:
        return g.ph;

      case Nodes.event:
        return g.ph;

      case Nodes.ticket:
        return g.ph;

      case Nodes.payment:
        throw 'We are not going to be paletteMaking payments';
      case Nodes.theme:
        return down4Logo(Palette2.fullHeight - Palette2.padding,
            g.theme.down4IconForPaletteColor);
    }
  }

  Widget get paletteImage => GestureDetector(
        onTap: imagePress,
        child: image != null
            ? image!.display(
                size: Size.square(Palette2.fullHeight - (2 * Palette2.padding)),
                forceSquare: true)
            : _defaultImage,
      );

  Widget get paletteBody => Expanded(
        child: Container(
            padding: const EdgeInsets.only(left: 8, bottom: 8, top: 1),
            child: tec.basicInput
            // Down4Input(
            //   tec: tec,
            //   inputCallBack: nameCallBack,
            //   placeHolder: hintText,
            //   padding: EdgeInsets.only(bottom: Palette.paletteHeight / 2),
            // ),
            ),
      );

  Widget get paletteAction => GestureDetector(
      onTap: () {
        if (name.isNotEmpty && image != null) {
          go?.call(id);
        }
      },
      child: Container(
          padding: const EdgeInsets.all(2.0),
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
          child: go != null
              ? Image.asset('assets/images/filled.png')
              : const SizedBox.shrink()));

  @override
  Widget build(BuildContext context) {
    return mainContainer(
        child: Row(
      children: [
        imageContainer(image: paletteImage),
        paletteBody,
      ],
    ));

    // return Column(
    //   children: [
    //     mainContainer(
    //       child: customRow(
    //         children: [paletteImage, paletteBody, paletteAction],
    //       ),
    //     ),
    //     const SizedBox(height: 0)
    //   ],
    // );
  }
}
