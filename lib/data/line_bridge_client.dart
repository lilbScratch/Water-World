// Calls the optional LINE bridge API and maps pending stock requests.
import 'dart:convert';
import 'dart:io';

import '../models.dart';

class LineStockCommand {
  const LineStockCommand({
    required this.id,
    required this.rawText,
    required this.code,
    required this.itemName,
    required this.delta,
  });

  final String id;
  final String rawText;
  final String code;
  final String itemName;
  final double delta;

  factory LineStockCommand.fromJson(Map<String, dynamic> value) =>
      LineStockCommand(
        id: value['id'] as String,
        rawText: value['raw_text'] as String,
        code: value['code'] as String,
        itemName: value['item_name'] as String,
        delta: (value['delta'] as num).toDouble(),
      );
}

class LineBridgeClient {
  LineBridgeClient(String baseUrl, this.token)
    : base = Uri.parse(baseUrl.trim()) {
    if (base.scheme != 'https' &&
        !(base.scheme == 'http' &&
            {'localhost', '127.0.0.1', '10.0.2.2'}.contains(base.host))) {
      throw const FormatException('ใช้ HTTPS หรือ localhost สำหรับการทดสอบ');
    }
    if (token.trim().isEmpty) throw const FormatException('กรอกรหัสเชื่อมต่อ');
  }

  final Uri base;
  final String token;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, [
    Object? body,
  ]) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client
          .openUrl(method, base.resolve(path))
          .timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final content = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('เซิร์ฟเวอร์ตอบ ${response.statusCode}', uri: base);
      }
      return jsonDecode(content) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> syncCatalog(List<Item> items) async {
    await _request('POST', '/api/catalog', {
      'items': items
          .map(
            (item) => {'code': item.code, 'name': item.name, 'unit': item.unit},
          )
          .toList(),
    });
  }

  Future<List<LineStockCommand>> pending() async {
    final result = await _request('GET', '/api/pending');
    final commands = result['commands'] as List<dynamic>;
    return commands
        .map(
          (entry) => LineStockCommand.fromJson(entry as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> resolve(String id, String status) async {
    await _request('POST', '/api/resolve', {'id': id, 'status': status});
  }
}
