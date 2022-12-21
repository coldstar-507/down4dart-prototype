import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:qr/qr.dart';
import '../themes.dart';

class QrPainter extends CustomPainter {
  final QrImage qr;
  const QrPainter(this.qr);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width / qr.moduleCount;

    var paint = Paint()
      ..color = PinkTheme.qrColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    //list of points
    var points = <Offset>[];
    for (var i = 0; i < qr.moduleCount; i++) {
      for (var j = 0; j < qr.moduleCount; j++) {
        if (qr.isDark(i, j)) {
          points.add(Offset(i * strokeWidth, j * strokeWidth));
        }
      }
    }
    //draw points on canvas
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Down4Qr extends StatelessWidget {
  final String data;
  final double dimension;
  final int errorCorrectionLevel;
  const Down4Qr({
    required this.data,
    required this.dimension,
    this.errorCorrectionLevel = QrErrorCorrectLevel.H,
    Key? key,
  }) : super(key: key);

  QrCode get qrCode => QrCode.fromData(
        data: data,
        errorCorrectLevel: errorCorrectionLevel,
      );

  QrImage get qrImage => QrImage(qrCode);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: QrPainter(qrImage),
      size: Size.square(dimension),
    );
  }
}
