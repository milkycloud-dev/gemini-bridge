import 'package:flutter/material.dart';
import 'utils/storage_util.dart';
import 'screens/register_screen.dart';
import 'screens/waiting_screen.dart';
import 'screens/chat_screen.dart';
import 'api_service.dart';
import 'screens/banned_screen.dart';
import 'screens/connection_error_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final serverToken = await StorageUtil.getServerToken();

  runApp(GeminiBridgeApp(initialToken: serverToken));
}

class GeminiBridgeApp extends StatelessWidget {
  final String? initialToken;

  const GeminiBridgeApp({Key? key, this.initialToken}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasToken = initialToken != null && initialToken!.isNotEmpty;
    return MaterialApp(
      title: 'MilkyCloud Gemini Bridge (Web)',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF131314),
        primaryColor: const Color(0xFF6B8AFF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6B8AFF),
          secondary: Color(0xFFA259FF),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: hasToken
          ? _TokenRouter(serverToken: initialToken!)
          : const RegisterScreen(),
    );
  }
}

class _TokenRouter extends StatefulWidget {
  final String serverToken;
  const _TokenRouter({required this.serverToken});
  @override
  State<_TokenRouter> createState() => _TokenRouterState();
}

class _TokenRouterState extends State<_TokenRouter> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    try {
      final status = await ApiService.checkStatus(widget.serverToken);
      if (!mounted) return;

      Widget target;
      if (status == "granted") {
        target = ChatScreen(serverToken: widget.serverToken);
      } else if (status == "waiting") {
        target = WaitingScreen(serverToken: widget.serverToken);
      } else if (status == "banned") {
        target = const BannedScreen(message: "banned");
      } else {
        await StorageUtil.setServerToken('');
        target = const RegisterScreen();
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => target),
      );
    } catch (e) {
      if (!mounted) return;
      if (ApiService.connectionStatus.value == 'connection_error') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConnectionErrorScreen()),
        );
      } else {
        await StorageUtil.setServerToken('');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF131314),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF6B8AFF))),
    );
  }
}
