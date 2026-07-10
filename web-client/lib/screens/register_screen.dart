import 'package:flutter/material.dart';
import '../utils/storage_util.dart';
import '../widgets/gemini_hero_animation.dart';
import '../api_service.dart';
import 'waiting_screen.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'terms_screen.dart';
import 'connection_error_screen.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = false;

  void _submit() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = _isLogin 
          ? await ApiService.login(name, password)
          : await ApiService.register(name, password);
          
      final token = res['server_token'];
      await StorageUtil.setServerToken(token);
      await StorageUtil.setNickname(name);
      
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => WaitingScreen(serverToken: token)),
      );
    } catch (e) {
      if (!mounted) return;
      if (ApiService.connectionStatus.value == 'connection_error') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ConnectionErrorScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48.0),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(child: GeminiHeroAnimation(size: 80)),
                        const SizedBox(height: 32),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF4285F4), Color(0xFFA259FF), Color(0xFFEA4335)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            _isLogin ? 'С возвращением' : 'Добро пожаловать',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 32,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isLogin ? 'Войдите в свой аккаунт' : 'Пожалуйста, представьтесь для входа в сеть MilkyCloud',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextField(
                          controller: _nameController,
                          onChanged: (val) => setState(() {}),
                          style: const TextStyle(fontFamily: 'Roboto', fontSize: 16, color: Colors.white),
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Ваше имя',
                            labelStyle: const TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF6B8AFF)),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E1F20),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _passwordController,
                          onChanged: (val) => setState(() {}),
                          obscureText: true,
                          style: const TextStyle(fontFamily: 'Roboto', fontSize: 16, color: Colors.white),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            labelStyle: const TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF6B8AFF)),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF1E1F20),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 54,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(27),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4285F4), Color(0xFFA259FF)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4285F4).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: (_isLoading || _nameController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                            ),
                            child: _isLoading
                                ? const SpinKitThreeBounce(color: Colors.white, size: 24)
                                : Text(
                                    _isLogin ? 'Войти' : 'Продолжить',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => setState(() => _isLogin = !_isLogin),
                          child: Text(
                            _isLogin ? 'Еще нет аккаунта? Зарегистрироваться' : 'Уже есть аккаунт? Войти',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1F20),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.redAccent.withOpacity(0.1),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ]
                          ),
                          child: const Column(
                            children: [
                              Text(
                                'ПРАВИЛА СООБЩЕСТВА',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Работа с MilkyCloud подразумевает строгое соблюдение этики ИИ. Генерация любого запрещенного контента недопустима.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ValueListenableBuilder<String>(
                          valueListenable: ApiService.connectionStatus,
                          builder: (context, status, child) {
                            if (status.contains('Подключено') || status.isEmpty) return const SizedBox.shrink();
                            return Text(
                              status,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            );
                          },
                        ),
                        const SizedBox(height: 40),
                        
                        // Footer
                        const Divider(color: Colors.white12),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen(isPrivacy: false)));
                              },
                              child: const Text('Условия использования', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ),
                            const Text('•', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            TextButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen(isPrivacy: true)));
                              },
                              child: const Text('Политика конфиденциальности', style: TextStyle(color: Colors.white54, fontSize: 12)),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('2026 MilkyCloud by ', style: TextStyle(color: Colors.white38, fontSize: 12)),
                            InkWell(
                              onTap: () {
                                html.window.open('https://github.com/milkycloud-dev', '_blank');
                              },
                              child: const Text(
                                '@milkydev',
                                style: TextStyle(color: Color(0xFF6B8AFF), fontSize: 12, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}