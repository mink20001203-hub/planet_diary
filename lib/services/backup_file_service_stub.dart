class BackupFileService {
  static Future<void> downloadJson({
    required String fileName,
    required String content,
  }) async {
    throw UnsupportedError('JSON backup download is only supported on web.');
  }

  static Future<String?> pickJsonFile() async {
    throw UnsupportedError('JSON backup restore is only supported on web.');
  }
}
