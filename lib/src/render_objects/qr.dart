import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';
import '../themes.dart';
import '../_down4_dart_utils.dart' show golden;
import 'chat_message.dart' show ChatMessage;

class QrPainter extends CustomPainter {
  final double strokeWidth;
  final List<Offset> points;
  const QrPainter({
    required this.strokeWidth,
    required this.points,
  });

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = PinkTheme.qrColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawPoints(ui.PointMode.points, points, paint);
  }

  @override
  bool shouldRebuildSemantics(QrPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class Down4Qr2 {
  final String data;
  final double dimension;
  final QrCode qrCode;
  Down4Qr2({
    required this.data,
    required this.dimension,
    int? qrErrorCorrectLevel,
    Key? key,
  }) : qrCode = QrCode.fromData(
          data: data,
          errorCorrectLevel: qrErrorCorrectLevel ?? QrErrorCorrectLevel.H,
        );

  Future<Uint8List?> asImage() async {
    final qrImage = QrImage(qrCode);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
    );

    final strokeWidth = dimension / qrImage.moduleCount;
    var paint = Paint()
      ..color = PinkTheme.qrColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    //list of points
    var points = <Offset>[];
    for (var i = 0; i < qrImage.moduleCount; i++) {
      for (var j = 0; j < qrImage.moduleCount; j++) {
        if (qrImage.isDark(i, j)) {
          points.add(Offset(i * strokeWidth, j * strokeWidth));
        }
      }
    }
    //draw points on canvas
    canvas.drawPoints(ui.PointMode.points, points, paint);

    final picture = recorder.endRecording();
    final picDimension = (dimension * golden).ceil();
    final dartImage = await picture.toImage(picDimension, picDimension);
    final bytes = await dartImage.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    return Uint8List.view(bytes.buffer);
  }
}

class Down4Qr extends StatefulWidget {
  final String data;
  final double dimension;
  final int errorCorrectionLevel;
  const Down4Qr({
    required this.data,
    required this.dimension,
    int? errorCorrectionLevel,
    Key? key,
  })  : errorCorrectionLevel = errorCorrectionLevel ?? QrErrorCorrectLevel.L,
        super(key: key);

  @override
  State<Down4Qr> createState() => _Down4QrState();
}

class _Down4QrState extends State<Down4Qr> {
  List<Offset> points = [];
  late QrCode qrCode = QrCode.fromData(
    data: widget.data,
    errorCorrectLevel: widget.errorCorrectionLevel,
  );
  late QrImage qrImage = QrImage(qrCode);
  late double strokeWidth = widget.dimension / qrImage.moduleCount;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < qrImage.moduleCount; i++) {
      for (var j = 0; j < qrImage.moduleCount; j++) {
        if (qrImage.isDark(i, j)) {
          points.add(Offset(i * strokeWidth, j * strokeWidth));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print("Building QRCODE from Down4Qr");
    return RepaintBoundary(
      child: CustomPaint(
        painter: QrPainter(points: points, strokeWidth: strokeWidth),
        size: Size.square(widget.dimension),
        isComplex: true,
      ),
    );
  }
}
