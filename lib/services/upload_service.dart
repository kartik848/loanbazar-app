import 'dart:io';
import 'package:dio/dio.dart';

class UploadService {
  static final Dio _dio = Dio();
  static const String _apiKey = '25e095528c5557feb19816be007bf2ee';

  static Future<String?> uploadImage(File file) async {
    try {
      FormData formData = FormData.fromMap({
        'key': _apiKey,
        'image': await MultipartFile.fromFile(file.path),
      });
      var response = await _dio.post('https://api.imgbb.com/1/upload', data: formData);
      if (response.statusCode == 200 && response.data['data'] != null) {
        return response.data['data']['url'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
