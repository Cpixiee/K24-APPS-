import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class HttpLogItem {
  final String id;
  final String method;
  final String url;
  final Map<String, String>? requestHeaders;
  final String? requestBody;
  final int? statusCode;
  final Map<String, String>? responseHeaders;
  final String? responseBody;
  final String? errorMessage;
  final DateTime timestamp;
  final int durationMs;

  HttpLogItem({
    required this.id,
    required this.method,
    required this.url,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    this.errorMessage,
    required this.timestamp,
    required this.durationMs,
  });

  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300;
  bool get isError => !isSuccess;
}

class HttpDebugLogger {
  static final ValueNotifier<List<HttpLogItem>> logsNotifier = ValueNotifier<List<HttpLogItem>>([]);
  static const int _maxLogs = 100;

  static void clearLogs() {
    logsNotifier.value = [];
  }

  static void addLog(HttpLogItem log) {
    if (!kDebugMode) return;
    final currentList = List<HttpLogItem>.from(logsNotifier.value);
    currentList.insert(0, log); // Newest first
    if (currentList.length > _maxLogs) {
      currentList.removeLast();
    }
    logsNotifier.value = currentList;
  }

  /// Helper to record an HTTP request and its response/error
  static Future<http.Response> wrapRequest({
    required String method,
    required Uri url,
    Map<String, String>? headers,
    Object? body,
    required Future<http.Response> Function() requestFn,
  }) async {
    if (!kDebugMode) {
      return await requestFn();
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final stopwatch = Stopwatch()..start();
    final startTime = DateTime.now();

    String? requestBodyStr;
    if (body != null) {
      if (body is String) {
        requestBodyStr = body;
      } else if (body is Map || body is List) {
        try {
          requestBodyStr = jsonEncode(body);
        } catch (_) {
          requestBodyStr = body.toString();
        }
      } else {
        requestBodyStr = body.toString();
      }
    }

    try {
      final response = await requestFn();
      stopwatch.stop();

      addLog(HttpLogItem(
        id: id,
        method: method,
        url: url.toString(),
        requestHeaders: headers,
        requestBody: requestBodyStr,
        statusCode: response.statusCode,
        responseHeaders: response.headers,
        responseBody: response.body,
        timestamp: startTime,
        durationMs: stopwatch.elapsedMilliseconds,
      ));

      return response;
    } catch (e) {
      stopwatch.stop();

      addLog(HttpLogItem(
        id: id,
        method: method,
        url: url.toString(),
        requestHeaders: headers,
        requestBody: requestBodyStr,
        statusCode: null,
        responseHeaders: null,
        responseBody: null,
        errorMessage: e.toString(),
        timestamp: startTime,
        durationMs: stopwatch.elapsedMilliseconds,
      ));

      rethrow;
    }
  }

  /// Helper to format raw JSON string into pretty-printed JSON string
  static String prettyJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '(Kosong / Null)';
    try {
      final object = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(object);
    } catch (_) {
      return raw; // Return raw string if not JSON
    }
  }
}
