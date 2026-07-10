import 'dart:html' as html;

class StorageUtil {
  static Future<String?> getServerToken() async {
    return _getCookie('server_token');
  }

  static Future<void> setServerToken(String token) async {
    _setCookie('server_token', token);
  }

  static Future<String?> getNickname() async {
    return _getCookie('nickname');
  }

  static Future<void> setNickname(String nickname) async {
    _setCookie('nickname', nickname);
  }

  static Future<String?> getHwid() async {
    return _getCookie('hwid');
  }

  static Future<void> setHwid(String hwid) async {
    _setCookie('hwid', hwid);
  }

  static Future<String?> getWaitingStart() async {
    return _getCookie('waiting_start');
  }

  static Future<void> setWaitingStart(String time) async {
    _setCookie('waiting_start', time);
  }

  static Future<void> clearSession() async {
    html.document.cookie = 'server_token=; max-age=0; path=/';
    html.document.cookie = 'nickname=; max-age=0; path=/';
  }

  static String? _getCookie(String name) {
    String? cookieString = html.document.cookie;
    if (cookieString == null || cookieString.isEmpty) return null;
    var cookies = cookieString.split(';');
    for (var cookie in cookies) {
      cookie = cookie.trim();
      if (cookie.startsWith('$name=')) {
        return cookie.substring(name.length + 1);
      }
    }
    return null;
  }

  static void _setCookie(String name, String value) {
    html.document.cookie = '$name=$value; max-age=31536000; path=/';
  }
}