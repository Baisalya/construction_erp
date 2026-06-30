import 'dart:typed_data';

class ExportDocument {
  const ExportDocument({
    required this.fileName,
    required this.extension,
    required this.bytes,
  });

  final String fileName;
  final String extension;
  final Uint8List bytes;
}
