import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:longyunvpn/common/common.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Picker {
  Future<PlatformFile?> pickerFile({bool withData = true}) async {
    final filePickerResult = await FilePicker.pickFiles(
      withData: withData,
      allowMultiple: false,
      initialDirectory: await appPath.downloadDirPath,
    );
    return filePickerResult?.files.first;
  }

  Future<String?> saveFile(String fileName, Uint8List bytes) async {
    final path = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    if (!system.isAndroid && path != null) {
      final file = File(path);
      await file.safeWriteAsBytes(bytes);
    }
    return path;
  }

  /// Saves [localPath] to a location the user picks, returning that path, or
  /// null if they cancelled.
  ///
  /// [deleteSource] removes the local file afterwards and defaults to **off**.
  /// It used to be unconditional, which was right for the only caller at the
  /// time — a temp file written purely to be exported — and quietly wrong for
  /// every caller added since. Exporting the effective config deleted the live
  /// config the core reads; exporting the crash log deleted the crash log. Both
  /// vanished even when the save dialog was cancelled, because the delete ran
  /// regardless of the outcome. A function named "save" must not destroy its
  /// own input, so removal is now something a caller opts into.
  Future<String?> saveFileWithPath(
    String fileName,
    String localPath, {
    bool deleteSource = false,
  }) async {
    final localFile = File(localPath);
    // Missing means there is nothing to export. This used to create the file so
    // the save could proceed, which handed the user an empty one and called it
    // a success.
    if (!await localFile.exists()) {
      return null;
    }
    final bytes = Platform.isAndroid ? await localFile.readAsBytes() : null;
    final path = await FilePicker.saveFile(
      fileName: fileName,
      initialDirectory: await appPath.downloadDirPath,
      bytes: bytes,
    );
    if (path != null && bytes == null) {
      await localFile.copy(path);
    }
    if (deleteSource) {
      await localFile.safeDelete();
    }
    return path;
  }

  Future<String?> pickerConfigQRCode() async {
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xFile == null) {
      return null;
    }
    final controller = MobileScannerController();
    final capture = await controller.analyzeImage(
      xFile.path,
      formats: [BarcodeFormat.qrCode],
    );
    final result = capture?.barcodes.first.rawValue;
    if (result == null || !result.isUrl) {
      throw currentAppLocalizations.pleaseUploadValidQrcode;
    }
    return result;
  }
}

final picker = Picker();
