import 'dart:convert';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// txt, csv ve pdf içeriğini düz metne çevirir. Diğer türlerde null döner.
String? extractDocumentText(String fileName, List<int> bytes) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.txt') || lower.endsWith('.csv')) {
    return _decodeText(bytes);
  }
  if (lower.endsWith('.pdf')) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return PdfTextExtractor(document).extractText().trim();
    } finally {
      document.dispose();
    }
  }
  return null;
}

/// Baytları metne çevirir ve BOM varsa temizler.
String _decodeText(List<int> bytes) {
  String text;
  try {
    text = utf8.decode(bytes);
  } catch (_) {
    text = latin1.decode(bytes);
  }
  if (text.startsWith('\uFEFF')) return text.substring(1);
  return text;
}
