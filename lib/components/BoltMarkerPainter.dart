import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BoltMarkerPainter {
  /// Genera un PNG (`Uint8List`) estilo Bolt: píldora con nombre de calle + ícono customizado.
  static Future<Uint8List> buildMarkerBytes({
    required String streetName,
    required bool isOrigin,
    String? assetIconPath,
  }) async {
    final String label = _sanitizeStreetName(streetName);

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '...',
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 25,
          fontWeight: FontWeight.w700,
          fontFamily: 'Roboto',
        ),
      ),
    )..layout(maxWidth: 420);

    const double horizontalPadding = 24;
    const double pillHeight = 52;
    const double gapBetweenPillAndIcon = 10;
    const double iconDiameter = 46;
    const double shadowPadding = 14;

    final double pillWidth =
        (textPainter.width + horizontalPadding * 2).clamp(110.0, 468.0);
    final double totalWidth =
        (pillWidth > iconDiameter ? pillWidth : iconDiameter) + shadowPadding * 2;
    final double totalHeight =
        pillHeight + gapBetweenPillAndIcon + iconDiameter + shadowPadding * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final double centerX = totalWidth / 2;
    final double pillLeft = centerX - pillWidth / 2;
    const double pillTop = shadowPadding;

    // 1. Sombra suave y píldora blanca con el nombre de la calle
    final RRect pillRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pillLeft, pillTop, pillWidth, pillHeight),
      const Radius.circular(26),
    );

    canvas.drawShadow(
      Path()..addRRect(pillRRect),
      const Color(0x66000000),
      8,
      false,
    );

    canvas.drawRRect(
      pillRRect,
      Paint()..color = Colors.white,
    );

    canvas.drawRRect(
      pillRRect,
      Paint()
        ..color = isOrigin ? const Color(0xFF10B981) : const Color(0xFFEF4444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Texto centrado dentro de la píldora
    final double textX = pillLeft + (pillWidth - textPainter.width) / 2;
    final double textY = pillTop + (pillHeight - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));

    // 2. Ícono customizado debajo de la píldora
    final double iconCenterY =
        pillTop + pillHeight + gapBetweenPillAndIcon + iconDiameter / 2;
    final Offset iconCenter = Offset(centerX, iconCenterY);

    final Color accentColor =
        isOrigin ? const Color(0xFF059669) : const Color(0xFFDC2626);

    // Halo / sombra del ícono
    canvas.drawCircle(
      iconCenter + const Offset(0, 3),
      iconDiameter / 2 + 2,
      Paint()..color = const Color(0x33000000),
    );

    // Círculo base con borde blanco
    canvas.drawCircle(
      iconCenter,
      iconDiameter / 2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      iconCenter,
      iconDiameter / 2 - 4,
      Paint()..color = accentColor,
    );

    // Si hay un asset customizado, lo dibujamos encima; si no, dibujamos un punto/anillo interior
    if (assetIconPath != null && assetIconPath.isNotEmpty) {
      final ByteData data = await rootBundle.load(assetIconPath);
      final ui.Codec codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 24,
        targetHeight: 24,
      );
      final ui.FrameInfo frame = await codec.getNextFrame();
      final ui.Image customImg = frame.image;

      canvas.drawImage(
        customImg,
        Offset(centerX - customImg.width / 2, iconCenterY - customImg.height / 2),
        Paint(),
      );
    } else {
      canvas.drawCircle(
        iconCenter,
        7,
        Paint()..color = Colors.white,
      );
    }

    final ui.Image finalImage = await recorder
        .endRecording()
        .toImage(totalWidth.ceil(), totalHeight.ceil());

    final ByteData? pngBytes =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);

    if (pngBytes == null) {
      throw StateError('No se pudo convertir el marcador a PNG.');
    }

    return pngBytes.buffer.asUint8List();
  }

  static String _sanitizeStreetName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Ubicación';
    // Si viene "Av. Mariscal López 123, Asunción", tomamos la primera parte más limpia
    final firstSegment = trimmed.split(',').first.trim();
    return firstSegment.isEmpty ? trimmed : firstSegment;
  }
}