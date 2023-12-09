import 'dart:math';

import 'package:down4/src/pages/_page_utils.dart';
import 'package:down4/src/render_objects/_render_utils.dart';
import 'package:down4/src/render_objects/console.dart';
import 'package:down4/src/render_objects/navigator.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/plugin_api.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:latlong2/latlong.dart';

import '../_dart_utils.dart' show ListExtensions, calcDistance2, golden;

import '../globals.dart' show g;

class MapPage extends StatefulWidget with Down4PageWidget {
  final void Function() back;

  @override
  String get id => "map";

  const MapPage({required this.back, super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class MyCircle extends StatefulWidget {
  final LatLng spot, topSpot;
  final double rad;
  final void Function(bool) movingTarget;
  final void Function(LatLng center, double radius) onLift;

  MyCircle updatedRad(double rad_) => MyCircle(
      spot: spot,
      topSpot: topSpot,
      rad: rad_,
      onLift: onLift,
      movingTarget: movingTarget);

  const MyCircle({
    required this.onLift,
    required this.movingTarget,
    required this.spot,
    required this.topSpot,
    required this.rad,
    super.key,
  });

  @override
  State<MyCircle> createState() => _MyCircleState();
}

extension on Offset {
  CustomPoint<double> get cp => CustomPoint(dx, dy);
}

extension on CustomPoint<double> {
  Offset get ofs => Offset(x, y);
}

class _MyCircleState extends State<MyCircle> {
  double scale = 1.0;
  double prevScale = 1.0;

  late LatLng topSpot = widget.topSpot;
  late LatLng realSpot = widget.spot;
  FlutterMapState fms(BuildContext context) => FlutterMapState.of(context);

  Offset tempdt = Offset.zero;

  double get dzoom => 2.0;

  List<(int, Offset)> pointers = [];

  late Offset rad = Offset(widget.rad, widget.rad);

  double prev = 1.0;
  double cur = 1.0;

  Widget listener(FlutterMapState st, {Widget? child}) {
    return Listener(
      onPointerDown: (d) {
        if (pointers.length == 2) return;
        final (n, p) = (d.pointer, d.localPosition);
        pointers.add((n, p));
        if (pointers.length == 1) {
          final realPoint = st.latLngToScreenPoint(realSpot);
          final dif = p - realPoint.ofs;
          tempdt = dif;
          realSpot = st.pointToLatLng(p.cp);
          setState(() {});
        } else if (pointers.length == 2) {
          final (p1, p2) = (pointers[0].$2, pointers[1].$2);
          final dist = calcDistance2(p1, p2);
          cur = dist;
        }
        widget.movingTarget(true);
      },
      onPointerMove: (d) {
        if (!pointers.containsWhere((p0) => p0.$1 == d.pointer)) return;
        final (n, p) = (d.pointer, d.localPosition);
        pointers.updateWhere((n, p), (p0) => p0.$1 == n);
        if (pointers.length > 1) {
          prev = cur;
          final (p1, p2) = (pointers[0].$2, pointers[1].$2);
          cur = calcDistance2(p1, p2);
          scale *= cur / prev;
        } else {
          realSpot = st.pointToLatLng(p.cp);
        }
        setState(() {});
      },
      onPointerUp: (u) {
        if (!pointers.containsWhere((p0) => p0.$1 == u.pointer)) return;
        final (_, p) = pointers.popWhere((p0) => p0.$1 == u.pointer)!;
        widget.movingTarget(pointers.isNotEmpty);
        final curPoint = st.latLngToScreenPoint(realSpot);
        if (pointers.isNotEmpty) {
          final (_, p) = pointers.first;
          tempdt += p - curPoint.ofs;
        } else {
          final realPoint = p - tempdt;
          realSpot = st.pointToLatLng(realPoint.cp);
          tempdt = Offset.zero;
          widget.onLift(realSpot, widget.rad * scale);
        }
        setState(() {});
      },
      child: child,
    );
  }

  Size get hss => (g.sizes.snipSize / 2);
  Offset get hs => Offset(hss.width, hss.height);
  @override
  Widget build(BuildContext context) {
    final ms = fms(context);
    final gp = ms.latLngToScreenPoint(realSpot);
    final ofs = gp - hs.cp - tempdt.cp;
    return listener(ms,
        child: Center(
          child: Container(
            height: 1,
            width: 1,
            transformAlignment: FractionalOffset.center,
            transform: Matrix4.identity()
              ..translate(ofs.x, ofs.y)
              ..scale(scale * widget.rad),
            decoration: BoxDecoration(
              color: g.theme.mapCircleArea,
              shape: BoxShape.circle,
            ),
          ),
        ));
  }
}

class _MapPageState extends State<MapPage> with Pager2 {
  final MapController ctrl = MapController();

  @override
  List<String> currentConsolesName = ["base"];

  @override
  List<Extra> extras = [];

  @override
  void setTheState() => setState(() {});

  LatLng get pos => ctrl.center;
  double get zoom => ctrl.zoom;
  double zoomer = 2.0;

  Style get style => g.theme.mapStyle!;
  final double drad = g.sizes.w / pow(golden, 2);

  (LatLng, double) topSpotter(LatLng pos) {
    final point = ctrl.latLngToScreenPoint(pos);
    final p = point - CustomPoint(0, drad);
    final topSpot = ctrl.pointToLatLng(p);
    final rad = (point.y - p.y).abs();
    return (topSpot, rad);
  }

  double radBro(LatLng pos, LatLng top) {
    final centerPoint = ctrl.latLngToScreenPoint(pos);
    final topPoint = ctrl.latLngToScreenPoint(top);
    return (centerPoint.y - topPoint.y).abs();
  }

  List<bool?> moving = [];
  List<MyCircle?> circles = [];
  List<(LatLng, LatLng)?> positions = [];
  List<(LatLng center, double scrad)?> truepos = [];

  @override
  Console get console => Console(rows: [
        {
          "base": ConsoleRow(widgets: [
            ConsoleButton(
                name: "+AREA",
                onPress: () {
                  final int i = circles.length;
                  final (top, rad) = topSpotter(pos);
                  final c = MyCircle(
                      spot: pos,
                      movingTarget: (b) => setState(() => moving[i] = b),
                      rad: rad,
                      topSpot: top,
                      onLift: (pos_, scrad_) {
                        final spos = ctrl.latLngToScreenPoint(pos_).ofs;
                        final pixelDist = calcDistance2(xWidgetPos, spos);
                        if (pixelDist < 60) {
                          circles[i] = null;
                          moving[i] = null;
                          truepos[i] = null;
                          positions[i] = null;
                          setState(() {});
                        } else {
                          truepos[i] = (pos_, scrad_);
                          print("==truePos==\npos=$pos_,scrad=$scrad_");
                        }
                      });
                  truepos.add((pos, drad));
                  moving.add(false);
                  positions.add((pos, top));
                  circles.add(c);
                  setState(() {});
                }),
            ConsoleButton(name: "-ZOOM", onPress: () {}),
            ConsoleButton(name: "+ZOOM", onPress: () {})
          ], extension: null, widths: null, inputMaxHeight: null)
        }
      ], currentConsolesName: currentConsolesName, currentPageIndex: 0);

  Offset get xWidgetPos {
    final rb = xKey.currentContext!.findRenderObject() as RenderBox;
    return rb.localToGlobal(Offset.zero);
  }

  GlobalKey xKey = GlobalKey();
  Widget get xWidget {
    return AnimatedOpacity(
      key: xKey,
      opacity: moving.any((e) => e ?? false) ? 1 : 0,
      duration: Console.animationDuration,
      child: Icon(
        Icons.block,
        color: Colors.white,
        size: g.sizes.headerHeight / 2,
      ),
    );
  }

  int get flags => moving.any((b) => b ?? false)
      ? InteractiveFlag.none
      : InteractiveFlag.drag | InteractiveFlag.pinchZoom;

  Widget map() {
    print(flags);
    return SizedBox.fromSize(
      size: g.sizes.snipSize,
      child: FlutterMap(
        mapController: ctrl,
        options: MapOptions(
          maxZoom: 14.0,
          minZoom: 2.0,
          onTap: (tp, ll) => print("MAP TAP"),
          onPositionChanged: (p, b) {
            final updateRadiuses = p.zoom != zoomer;
            zoomer = p.zoom ?? zoom;
            if (updateRadiuses) setState(() {});
          },
          zoom: 2.0,
          center: LatLng(g.self.latitude ?? 0.0, g.self.longitude ?? 0.0),
          interactiveFlags: flags,
        ),
        children: [
          VectorTileLayer(
              tileProviders: style.providers,
              theme: style.theme,
              sprites: style.sprites),
          Stack(children: [
            Center(
                child: Container(
              width: 20,
              height: 2,
              color: Colors.black54,
            )),
            Center(
                child: Container(
              width: 2,
              height: 20,
              color: Colors.black54,
            ))
          ]),
          ...circles.indexed.map((e) {
            final (i, c) = e;
            if (c == null) return const SizedBox.shrink();
            if (zoomer != zoom) return c;
            final (center, top) = positions[i]!;
            final rad = radBro(center, top);
            return c.updatedRad(rad);
          }),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ctrl;

    return Andrew(
      backFunction: widget.back,
      transparentHeader: true,
      extraHeaderWidgets: [xWidget],
      pages: [
        Down4Page(title: "", console: console, simplePageWidget: map()),
      ],
    );
  }
}
