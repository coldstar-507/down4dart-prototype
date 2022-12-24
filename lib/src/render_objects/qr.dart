import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';
import '../themes.dart';

class QrPainter extends CustomPainter {
  final double strokeWidth;
  final List<Offset> points;
  QrPainter({
    required this.strokeWidth,
    required this.points,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print("Painting QRCODE from QrPainter");

    var paint = Paint()
      ..color = PinkTheme.qrColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    //draw points on canvas
    canvas.drawPoints(ui.PointMode.points, points, paint);
  }

  @override
  bool shouldRebuildSemantics(QrPainter oldDelegate) => false;

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    print("Should repaint QRCODE? returning FALSE");
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

  Future<Image?> asImage() async {
    final qrImage = QrImage(qrCode);
    print(0);
    final recorder = ui.PictureRecorder();
    print(1);
    final canvas = Canvas(
      recorder,
    );

    print(2);
    final strokeWidth = dimension / qrImage.moduleCount;
    print(3);
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
    print(4444);
    canvas.drawPoints(ui.PointMode.points, points, paint);

    print(4);
    final picture = recorder.endRecording();
    print(5);
    final dartImage = await picture.toImage(dimension.ceil(), dimension.ceil());
    print(6);
    final bytes = await dartImage.toByteData(format: ui.ImageByteFormat.png);
    print(7);
    if (bytes == null) return null;
    print(8);
    return Image.memory(Uint8List.view(bytes.buffer));
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
  })  : errorCorrectionLevel = errorCorrectionLevel ?? QrErrorCorrectLevel.H,
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
