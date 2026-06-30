import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class LocalFileService {
  const LocalFileService();

  Future<String?> save({
    required String fileName,
    required String extension,
    required Uint8List bytes,
  }) async {
    return FilePicker.saveFile(
      dialogTitle: 'Save $fileName',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
  }

  Future<Uint8List?> pick({required String extension}) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose backup file',
      type: FileType.custom,
      allowedExtensions: [extension],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final selected = result.files.single;
    if (selected.bytes != null) return selected.bytes;
    if (selected.path == null) return null;
    return File(selected.path!).readAsBytes();
  }
}
