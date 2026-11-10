import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:banhang_app/core/storage/secure_storage_service.dart';
import 'package:dio/dio.dart';

/// Kho an toan trong bo nho (thay SecureStorageService that, khong dung platform channel).
class FakeSecureStorage extends SecureStorageService {
  final Map<String, String> data = {};

  FakeSecureStorage([Map<String, String>? initial]) {
    if (initial != null) data.addAll(initial);
  }

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<void> deleteAll() async => data.clear();

  @override
  Future<bool> containsKey(String key) async => data.containsKey(key);

  @override
  Future<void> writeObject(String key, Map<String, dynamic> value) async =>
      data[key] = jsonEncode(value);

  @override
  Future<Map<String, dynamic>?> readObject(String key) async {
    final v = data[key];
    if (v == null) return null;
    return jsonDecode(v) as Map<String, dynamic>;
  }
}

/// HttpClientAdapter gia: tra loi theo ham [handler], khong dung mang.
class FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
