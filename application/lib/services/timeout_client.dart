import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

Future<http.Response> getWithTimeout(
    Uri uri, {
      Duration timeout = const Duration(seconds: 5),
    }) async {
  try {
    return await http.get(uri).timeout(timeout);
  } on TimeoutException {
    throw Exception('连接超时，请检查地址是否正确或服务是否启动');
  } on SocketException {
    throw Exception('无法连接到服务器，请检查地址或网络');
  }
}