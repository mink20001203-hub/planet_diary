import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class BackupFileService {
  static Future<void> downloadJson({
    required String fileName,
    required String content,
  }) async {
    final bytes = utf8.encode(content);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  static Future<String?> pickJsonFile() async {
    final input = html.FileUploadInputElement()
      ..accept = '.json,application/json';
    input.click();

    await input.onChange.first;
    final file = input.files?.isNotEmpty == true ? input.files!.first : null;
    if (file == null) return null;

    final completer = Completer<String>();
    final reader = html.FileReader();
    reader.onLoad.first.then((_) {
      completer.complete(reader.result as String);
    });
    reader.onError.first.then((_) {
      completer.completeError(reader.error ?? StateError('File read failed'));
    });
    reader.readAsText(file);
    return completer.future;
  }
}
