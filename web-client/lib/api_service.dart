import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'utils/storage_util.dart';
import 'main.dart'; // navigatorKey
import 'screens/banned_screen.dart';

class ApiService {
  static final String baseUrl = 'https://gemini.milkycloud.online';
  static String get currentBaseUrl => baseUrl;
  
  static final ValueNotifier<String> connectionStatus = ValueNotifier<String>('Подключено');
  static final ValueNotifier<String> currentProtocol = ValueNotifier<String>('HTTPS');

  static String get appSecret {
    final parts = [71, 101, 109, 105, 110, 105, 66, 114, 105, 100, 103, 101, 45, 83, 101, 99, 117, 114, 101, 67, 108, 105, 101, 110, 116, 45, 50, 48, 50, 54, 33];
    return String.fromCharCodes(parts);
  }

  static Future<String> getHardwareId() async {
    try {
      var saved = await StorageUtil.getHwid();
      if (saved != null && saved.isNotEmpty) return saved;

      // Generate a simple random HWID instead of using device_info_plus which crashes on some browsers
      final random = DateTime.now().millisecondsSinceEpoch.toString();
      final newHwid = 'Web-Device-$random';
      await StorageUtil.setHwid(newHwid);
      return newHwid;
    } catch (e) {
      return 'UnknownWebDevice-Fallback';
    }
  }

  static bool _hasPreloaded = false;
  static Future<void> preload() async {
    if (_hasPreloaded) return;
    _hasPreloaded = true;
    try {
      // Warm up HWID generation
      getHardwareId();
      // Warm up DNS, TCP and TLS connection
      _getClient().get(Uri.parse('$baseUrl/api/version')).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  static http.Client _getClient() {
    return http.Client();
  }

  static void _handleBan(http.Response res) {
    if (res.statusCode == 403) {
      if (res.body.contains("banned") || res.body.contains("blocked") || res.body.contains("IP address")) {
        if (navigatorKey.currentContext != null) {
           Navigator.pushReplacement(
             navigatorKey.currentContext!,
             MaterialPageRoute(builder: (_) => BannedScreen(message: res.body))
           );
        }
        throw Exception("banned_global");
      }
    }
  }

  static Future<http.Response> _executeRequest(
      Future<http.Response> Function(String baseUrl) requestFunc) async {
    try {
      connectionStatus.value = 'Подключение к серверу...';
      final res = await requestFunc(baseUrl);
      _handleBan(res);
      connectionStatus.value = 'Подключено';
      currentProtocol.value = baseUrl.startsWith('https') ? 'HTTPS' : 'HTTP';
      return res;
    } catch (e) {
      if (e.toString().contains("banned_global")) rethrow;
      connectionStatus.value = 'connection_error';
      throw Exception('Ошибка подключения к серверу');
    }
  }

  static Future<Map<String, dynamic>> register(String name, String password) async {
    final response = await _executeRequest((baseUrl) {
      return _getClient().post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Secret': appSecret,
        },
        body: jsonEncode({'name': name, 'password': password, 'hwid': 'Pending', 'device_info': 'Pending'}),
      ).timeout(const Duration(seconds: 10));
    });
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> login(String name, String password) async {
    final response = await _executeRequest((baseUrl) {
      return _getClient().post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
          'X-App-Secret': appSecret,
        },
        body: jsonEncode({'name': name, 'password': password, 'hwid': 'Pending'}),
      ).timeout(const Duration(seconds: 10));
    });
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }

  static Future<void> sendHardwareId(String serverToken) async {
    try {
      final hwid = await getHardwareId();
      await _executeRequest((baseUrl) {
        return _getClient().post(
          Uri.parse('$baseUrl/api/update_hwid'),
          headers: {
            'Content-Type': 'application/json',
            'server-token': serverToken,
            'X-App-Secret': appSecret,
          },
          body: jsonEncode({'hwid': hwid}),
        ).timeout(const Duration(seconds: 15));
      });
    } catch (_) {}
  }

  static Future<List<dynamic>> getChats(String serverToken) async {
    final response = await _executeRequest((baseUrl) {
      return _getClient().get(
        Uri.parse('$baseUrl/chats'),
        headers: {
          'server-token': serverToken,
          'X-App-Secret': appSecret,
        },
      ).timeout(const Duration(seconds: 45));
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chats');
    }
  }

  static Future<Map<String, dynamic>> getChatHistory(String serverToken, int chatId) async {
    final response = await _executeRequest((baseUrl) {
      return _getClient().get(
        Uri.parse('$baseUrl/chats/$chatId/history'),
        headers: {
          'server-token': serverToken,
          'X-App-Secret': appSecret,
        },
      ).timeout(const Duration(seconds: 45));
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load chat history');
    }
  }

  static Future<Map<String, dynamic>> sendMessage(
      String serverToken, String prompt, String model, int? chatId, PlatformFile? file) async {
    final response = await _executeRequest((baseUrl) async {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/chat'));
      request.headers.addAll({
        'server-token': serverToken,
        'X-App-Secret': appSecret,
      });
      request.fields['prompt'] = prompt;
      request.fields['model'] = model;
      if (chatId != null) {
        request.fields['chat_id'] = chatId.toString();
      }
      if (file != null && file.bytes != null) {
        final filename = file.name;
        final mimeTypeData = lookupMimeType(filename, headerBytes: [0xFF, 0xD8])?.split('/');
        MediaType? mediaType;
        if (mimeTypeData != null && mimeTypeData.length == 2) {
          mediaType = MediaType(mimeTypeData[0], mimeTypeData[1]);
        }
        
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: filename,
          contentType: mediaType,
        ));
      }

      var streamedResponse = await _getClient().send(request).timeout(const Duration(seconds: 300));
      return await http.Response.fromStream(streamedResponse);
    });

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  static Future<String> checkStatus(String serverToken) async {
    try {
      final response = await _executeRequest((baseUrl) {
        return _getClient().get(
          Uri.parse('$baseUrl/api/status'),
          headers: {
            'server-token': serverToken,
            'X-App-Secret': appSecret,
          },
        ).timeout(const Duration(seconds: 45));
      });
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['has_token'] == true ? "granted" : "waiting";
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return "deleted";
      }
      return "error";
    } catch (e) {
      if (e.toString().contains("banned_global")) {
        return "banned";
      }
      return "error";
    }
  }

  static Future<bool> assignCustomToken(String serverToken, String customToken) async {
    try {
      final response = await _executeRequest((baseUrl) {
        return _getClient().post(
          Uri.parse('$baseUrl/api/set_custom_token'),
          headers: {
            'Content-Type': 'application/json',
            'server-token': serverToken,
            'X-App-Secret': appSecret,
          },
          body: jsonEncode({'gemini_token': customToken}),
        ).timeout(const Duration(seconds: 45));
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> activateDemo(String serverToken) async {
    try {
      final response = await _executeRequest((baseUrl) {
        return _getClient().post(
          Uri.parse('$baseUrl/api/cheat_demo'),
          headers: {
            'server-token': serverToken,
            'X-App-Secret': appSecret,
          },
        ).timeout(const Duration(seconds: 10));
      });
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
