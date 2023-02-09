import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../boxes.dart';

import '../data_objects.dart';
import '../themes.dart';

import 'palette.dart';
import '_down4_flutter_utils.dart';

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
  final String name, lastName, id, imagePath;
  final void Function() selectFile;

  const UserMakerPalette({
    required this.name,
    required this.lastName,
    required this.id,
    required this.selectFile,
    required this.imagePath,
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
          height: Palette.paletteHeight - 4.0,
          width: Palette.paletteHeight - 4.0, // borderWidth x2
          child: imagePath.isNotEmpty
              ? Image.file(
                  File(imagePath),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                )
              : Image.asset(
                  'assets/images/picture_place_holder_2.png',
                  fit: BoxFit.cover,
                ),
        ),
      );

  Widget get body => Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: PinkTheme.nodeColors[NodesColor.self],
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

class PaletteMaker extends StatelessWidget {
  final void Function(String)? nameCallBack;
  final void Function() imagePress;
  final String name, id;
  final String hintText;
  final NodeMedia? image;
  final void Function(Identifier)? go;
  final NodesColor colorCode;
  final Nodes type;
  final Nodes? parentType;
  final TextEditingController tec;
  final bool fold;
  const PaletteMaker({
    required this.fold,
    required this.colorCode,
    required this.tec,
    required this.id,
    required this.name,
    this.nameCallBack,
    required this.imagePress,
    this.image,
    required this.hintText,
    this.go,
    this.type = Nodes.user,
    this.parentType,
    Key? key,
  }) : super(key: key);

  Widget mainContainer({required Widget child}) => AnimatedOpacity(
      opacity: fold ? 0 : 1,
      duration: const Duration(milliseconds: 600),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        height: fold ? 0 : Palette.paletteHeight,
        margin: EdgeInsets.only(
          left: Palette.paletteMargin,
          right: Palette.paletteMargin,
          bottom: fold ? 0 : Sizes.h * 0.02,
        ),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                  color: Palette.shadowColor,
                  blurRadius: Palette.blurRadius,
                  spreadRadius: Palette.spreadRadius,
                  offset: Palette.shadowOffset,
                  blurStyle: BlurStyle.normal)
            ],
            borderRadius: const BorderRadius.all(Radius.circular(6.0)),
            border: Border.all(width: 2.0, color: Colors.transparent)),
        child: child,
      ));

  Widget customRow({required List<Widget> children}) => Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: PinkTheme.nodeColors[colorCode],
          borderRadius: const BorderRadius.all(Radius.circular(4.0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          textDirection: TextDirection.ltr,
          children: children,
        ),
      );

  Widget get _defaultImage {
    switch (type) {
      case Nodes.user:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.hyperchat:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.group:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.self:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.root:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.market:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.checkpoint:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.journal:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.item:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.event:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.ticket:
        return Image.asset(
          'assets/images/picture_place_holder_2.png',
          fit: BoxFit.cover,
          gaplessPlayback: true,
          width: Palette.paletteHeight - 4,
          height: Palette.paletteHeight - 4,
        );

      case Nodes.payment:
        throw 'We are not going to be paletteMaking payments';
    }
  }

  Widget get paletteImage => GestureDetector(
        onTap: imagePress,
        child: SizedBox(
          width: Palette.paletteHeight - 4.0, // borderWidth x2
          child: image == null
              ? _defaultImage
              : Image.memory(
                  image!.data,
                  gaplessPlayback: true,
                  fit: BoxFit.cover,
                ),
        ),
      );

  Widget get paletteBody => Expanded(
        child: Container(
          padding: const EdgeInsets.only(left: 10.0, top: 10.0),
          child: Down4Input(
            tec: tec,
            inputCallBack: nameCallBack,
            placeHolder: hintText,
            padding: EdgeInsets.only(bottom: Palette.paletteHeight / 2),
          ),
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
    return Column(
      children: [
        mainContainer(
          child: customRow(
            children: [paletteImage, paletteBody, paletteAction],
          ),
        ),
        const SizedBox(height: 0)
      ],
    );
  }
}
