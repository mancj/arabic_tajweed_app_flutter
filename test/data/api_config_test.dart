import 'package:flutter_test/flutter_test.dart';
import 'package:arabic_tajweed_app/data/rest/api_config.dart';

void main() {
  test('адрес сервера принимает IP с портом и добавляет схему', () {
    expect(
      ApiConfig.normalizeBaseUrl(' 192.168.1.10:8765 '),
      'http://192.168.1.10:8765',
    );
    expect(
      ApiConfig.normalizeBaseUrl('https://tajweed.example'),
      'https://tajweed.example',
    );
  });

  test('адрес сервера отклоняет путь и параметры', () {
    expect(
      () => ApiConfig.normalizeBaseUrl('192.168.1.10:8765/api'),
      throwsFormatException,
    );
    expect(
      () => ApiConfig.normalizeBaseUrl('192.168.1.10:8765?debug=true'),
      throwsFormatException,
    );
  });
}
