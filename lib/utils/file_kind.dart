import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

/// Sohbet balonunda gösterilecek dosya türü.
enum FileKind { pdf, txt, csv, other }

/// Dosya adından tür seçer.
FileKind fileKindFromName(String name) {
  switch (p.extension(name).toLowerCase()) {
    case '.pdf':
      return FileKind.pdf;
    case '.txt':
      return FileKind.txt;
    case '.csv':
      return FileKind.csv;
    default:
      return FileKind.other;
  }
}

/// Türün ikonunu döndürür.
IconData fileKindIcon(FileKind kind) {
  switch (kind) {
    case FileKind.pdf:
      return Icons.picture_as_pdf_outlined;
    case FileKind.txt:
      return Icons.description_outlined;
    case FileKind.csv:
      return Icons.table_chart_outlined;
    case FileKind.other:
      return Icons.insert_drive_file_outlined;
  }
}

/// Türün ayırt edici rengini döndürür.
Color fileKindColor(FileKind kind) {
  switch (kind) {
    case FileKind.pdf:
      return const Color(0xFFE06C75);
    case FileKind.txt:
      return const Color(0xFF61AFEF);
    case FileKind.csv:
      return const Color(0xFF98C379);
    case FileKind.other:
      return const Color(0xFF8B949E);
  }
}

/// Metin okunabilen uzantı mı diye bakar.
bool isReadableDocument(String name) {
  final ext = p.extension(name).toLowerCase();
  return ext == '.txt' || ext == '.csv' || ext == '.pdf';
}
