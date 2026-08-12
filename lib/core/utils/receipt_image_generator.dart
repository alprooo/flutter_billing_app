import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/transactions/domain/entities/sale_transaction.dart';
import 'currency_formatter.dart';

class ReceiptImageGenerator {
  const ReceiptImageGenerator._();

  static Future<Uint8List> generate(SaleTransaction transaction) async {
    const width = 720;
    const horizontalPadding = 48.0;
    final height = 330 + transaction.items.length * 58;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const textDirection = ui.TextDirection.ltr;
    final background = Paint()..color = Colors.white;
    canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), background);

    void drawText(
      String text,
      double y, {
      double fontSize = 24,
      FontWeight fontWeight = FontWeight.normal,
      TextAlign textAlign = TextAlign.left,
      Color color = Colors.black,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
            height: 1.2,
          ),
        ),
        textAlign: textAlign,
        textDirection: textDirection,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: width - horizontalPadding * 2);
      final x = switch (textAlign) {
        TextAlign.center => (width - painter.width) / 2,
        TextAlign.right ||
        TextAlign.end =>
          width - horizontalPadding - painter.width,
        _ => horizontalPadding,
      };
      painter.paint(canvas, Offset(x, y));
    }

    final shopName = transaction.shopName?.trim();
    drawText(
      shopName?.isNotEmpty == true ? shopName! : 'ANUGRAH FOTO',
      34,
      fontSize: 34,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );
    drawText(
      'STRUK DIGITAL',
      80,
      fontSize: 18,
      fontWeight: FontWeight.w600,
      textAlign: TextAlign.center,
      color: Colors.grey.shade700,
    );
    drawText(
      DateFormat('d MMM y, HH:mm').format(transaction.completedAt),
      116,
      fontSize: 19,
      textAlign: TextAlign.center,
      color: Colors.grey.shade700,
    );

    final dividerPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(horizontalPadding, 158),
        const Offset(width - horizontalPadding, 158), dividerPaint);

    var y = 180.0;
    for (final item in transaction.items) {
      drawText('${item.quantity} × ${item.productName}', y,
          fontSize: 21, fontWeight: FontWeight.w500);
      drawText(formatRupiah(item.total), y,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          textAlign: TextAlign.right);
      y += 58;
    }

    canvas.drawLine(Offset(horizontalPadding, y - 10),
        Offset(width - horizontalPadding, y - 10), dividerPaint);
    drawText('TOTAL', y + 16, fontSize: 26, fontWeight: FontWeight.bold);
    drawText(formatRupiah(transaction.total), y + 16,
        fontSize: 26, fontWeight: FontWeight.bold, textAlign: TextAlign.right);
    drawText('Struk #${transaction.id.substring(0, 8).toUpperCase()}', y + 72,
        fontSize: 16, textAlign: TextAlign.center, color: Colors.grey.shade700);

    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) {
      throw StateError('Gagal membuat gambar struk.');
    }
    return bytes.buffer.asUint8List();
  }
}
