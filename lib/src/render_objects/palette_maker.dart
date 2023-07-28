import 'package:flutter/material.dart';
import '../data_objects/_data_utils.dart';
import '../data_objects/medias.dart';
import '../data_objects/nodes.dart';
import '../globals.dart';

import '../pages/_page_utils.dart';

import 'palette.dart';
import '_render_utils.dart';

class PaletteMaker extends StatelessWidget implements Down4Widget {
  @override
  final Down4ID id;

  final void Function() imagePress;
  final String name;
  final Down4Image? image;
  final void Function(Down4ID)? go;
  final NodesColor colorCode;
  final Nodes type;
  final Nodes? parentType;
  final MyTextEditor tec;
  final bool fold;
  PaletteMaker({
    required this.fold,
    required this.colorCode,
    required this.tec,
    required this.id,
    required this.name,
    required this.imagePress,
    this.image,
    this.go,
    this.type = Nodes.user,
    this.parentType,
  }) : super(key: GlobalKey());
  
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
      height: Palette.fullHeight,
      padding: EdgeInsets.all(Palette.padding / 2),
      child: Container(
        decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(5)),
            color: g.theme.paletteColor),
        padding: EdgeInsets.all(Palette.padding / 2),
        child: child,
      ),
    );
  }

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
        return down4Logo(Palette.fullHeight - Palette.padding,
            g.theme.down4IconForPaletteColor);
    }
  }

  Widget get paletteImage => GestureDetector(
        onTap: imagePress,
        child: image != null
            ? image!.display(
                key: Key("gmkr-${image?.id.value}"),
                size: Size.square(Palette.fullHeight - (2 * Palette.padding)),
                forceSquare: true)
            : _defaultImage,
      );

  Widget get paletteBody => Expanded(
        child: Container(
            padding: const EdgeInsets.only(left: 8, bottom: 8, top: 1),
            child: tec.basicInput
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
      ),
    );
  }
}
