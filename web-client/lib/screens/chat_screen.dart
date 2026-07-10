import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../api_service.dart';
import '../utils/storage_util.dart';
import '../utils/greetings.dart';
import '../widgets/gemini_star.dart';
import '../widgets/gemini_hero_animation.dart';
import '../widgets/bottom_glow_animation.dart';
import 'register_screen.dart';

class ChatScreen extends StatefulWidget {
  final String serverToken;
  const ChatScreen({Key? key, required this.serverToken}) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _chats = [];
  List<Map<String, dynamic>> _messages = [];
  int? _currentChatId;
  bool _isLoading = false;
  PlatformFile? _selectedFile;
  
  int _tokensUsed = 0;
  int _tokensRemaining = 1000000;
  
  String _selectedModel = 'Gemini 2.5 Flash';
  String _nickname = '';
  String _greeting = 'Спросите Gemini';
  
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadChats();
    _loadNickname();
  }

  Future<void> _loadNickname() async {
    final name = await StorageUtil.getNickname();
    setState(() {
      _nickname = name ?? '';
      _greeting = Greetings.get(_nickname);
    });
  }


  Future<void> _loadChats() async {
    try {
      final chats = await ApiService.getChats(widget.serverToken);
      setState(() {
        _chats = chats;
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _loadHistory(int chatId) async {
    setState(() => _isLoading = true);
    try {
      final history = await ApiService.getChatHistory(widget.serverToken, chatId);
      setState(() {
        _currentChatId = chatId;
        _messages = List<Map<String, dynamic>>.from(history['messages']);
      });
      _scrollToBottom();
    } catch (e) {
      print(e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _createNewChat() {
    setState(() {
      _currentChatId = null;
      _messages = [];
    });
    Navigator.pop(context); // Close drawer
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1F20),
          title: const Text('О программе MilkyCloud'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Цель проекта — упростить и сделать максимально удобным доступ к потрясающим возможностям нейросети Gemini.'),
              const SizedBox(height: 16),
              const Text('Версия программы: 1.0', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: ApiService.currentProtocol,
                builder: (context, protocol, _) {
                  return Text('Текущий протокол: $protocol', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent));
                }
              ),
              const SizedBox(height: 16),
              Text('Использовано токенов: $_tokensUsed', style: const TextStyle(color: Colors.white70)),
              Text('Остаток проекта: ~${(_tokensRemaining / 1000000).toStringAsFixed(1)} млн', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text('Используя данное приложение, вы обязуетесь не использовать ИИ в незаконных целях.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Закрыть'),
            ),
          ],
        );
      }
    );
  }

  Future<void> _logout() async {
    await StorageUtil.clearSession();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif', 'pdf', 'txt', 'csv', 'mp3', 'mp4'],
        withData: kIsWeb,
      );
      if (result != null) {
        final file = result.files.single;
        final sizeInBytes = file.size;
        if (sizeInBytes > 20 * 1024 * 1024) { // Gemini limit: 20MB
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Размер файла превышает допустимый лимит (20 МБ)')),
          );
          return;
        }
        setState(() {
          _selectedFile = file;
        });
      }
    } catch (e) {
      print("FilePicker error: $e");
    }
  }

  Future<void> _sendMessage() async {
    if (_cooldownSeconds > 0) return;
    
    String text = _messageController.text.trim();
    if (text.isEmpty && _selectedFile == null) return;
    
    PlatformFile? fileToSend = _selectedFile;

    if (text.length > 2000 && fileToSend == null) {
      bool? convert = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2C),
          title: const Text('Слишком длинный текст', style: TextStyle(color: Colors.white)),
          content: Text('Ваш текст содержит ${text.length} символов. Отправка такого большого объема текста напрямую может вызвать ошибку сервера (макс. рекомендуемый размер 2,000).\n\nХотите автоматически конвертировать его в текстовый файл (.txt) и прикрепить к сообщению?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отправить как есть', style: TextStyle(color: Colors.redAccent)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Конвертировать в TXT', style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      );

      if (convert == true) {
        try {
          final bytes = utf8.encode(text);
          fileToSend = PlatformFile(
            name: 'long_message_${DateTime.now().millisecondsSinceEpoch}.txt',
            size: bytes.length,
            bytes: Uint8List.fromList(bytes),
          );
          text = "Пожалуйста, проанализируй прикрепленный текстовый файл.";
        } catch (e) {
          print("Error converting to txt: $e");
        }
      }
    }

    final promptToSend = text.isEmpty ? '[Пользователь прикрепил файл]' : text;

    setState(() {
      _messages.add({'role': 'user', 'content': promptToSend, 'file': fileToSend?.path});
      _messageController.clear();
      _isLoading = true;
      _selectedFile = null;
    });
    _scrollToBottom();

    try {
      final res = await ApiService.sendMessage(
        widget.serverToken,
        promptToSend,
        _selectedModel,
        _currentChatId,
        fileToSend,
      );
      
      if (!mounted) return;
      setState(() {
        _currentChatId = res['chat_id'];
        _messages.add({
          'role': 'model',
          'content': res['response'],
        });
        if (res.containsKey('tokens_used')) {
           _tokensUsed += (res['tokens_used'] as num).toInt();
           _tokensRemaining = (res['tokens_remaining'] as num).toInt();
        }
      });
      _scrollToBottom();
      _loadChats();
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = 60;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildNetworkFilePreview(String url) {
    if (url.toLowerCase().endsWith('.png') || url.toLowerCase().endsWith('.jpg') || url.toLowerCase().endsWith('.jpeg') || url.toLowerCase().endsWith('.webp')) {
      final fullUrl = url.startsWith('http') ? url : '${ApiService.currentBaseUrl}$url';
      return Image.network(
        fullUrl, 
        height: 150, 
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file, color: Colors.white70),
        const SizedBox(width: 8),
        Text(url.split('/').last, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  Widget _buildFilePreview(String? path, {Uint8List? bytes, String? filename}) {
    final name = filename ?? (path != null ? path.split('\\').last.split('/').last : 'unknown');
    final isImage = name.toLowerCase().endsWith('.png') || name.toLowerCase().endsWith('.jpg') || name.toLowerCase().endsWith('.jpeg') || name.toLowerCase().endsWith('.webp');
    
    if (isImage) {
      if (bytes != null) {
        return Image.memory(bytes, height: 150, fit: BoxFit.cover);
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.insert_drive_file, color: Colors.white70),
        const SizedBox(width: 8),
        Text(name, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MilkyCloud Gemini Bridge (Client)', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF131314),
        child: ListView(
          children: [
            const DrawerHeader(
              child: Center(child: GeminiStar(size: 48)),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Новый чат'),
              onTap: _createNewChat,
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('О программе'),
              onTap: _showAboutDialog,
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
              onTap: _logout,
            ),
            const Divider(color: Colors.white24),
            ..._chats.map((chat) => ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text(chat['title'], maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                _loadHistory(chat['id']);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Background Glow Animation
          if (_messages.isEmpty)
            const Positioned.fill(
              child: BottomGlowAnimation(),
            ),
          
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
              Expanded(
                child: _messages.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const GeminiStar(size: 80),
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              _greeting, 
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isUser = msg['role'] == 'user';
                        
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isUser) ...[
                                  const GeminiStar(size: 24),
                                  const SizedBox(width: 12),
                                ],
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isUser ? const Color(0xFF1E1F20) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: isUser ? Border.all(color: Colors.white10) : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (msg['file'] != null || msg['attachment_url'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: msg['file'] != null 
                                                  ? _buildFilePreview(msg['file']) 
                                                  : _buildNetworkFilePreview(msg['attachment_url']),
                                            ),
                                          ),
                                        if (msg['content'].toString().isNotEmpty)
                                          MarkdownBody(
                                            data: msg['content'],
                                            selectable: true,
                                            styleSheet: MarkdownStyleSheet(
                                              p: const TextStyle(
                                                color: Color(0xFFE3E3E3),
                                                fontSize: 15,
                                                height: 1.5,
                                              ),
                                              code: TextStyle(
                                                color: const Color(0xFFA259FF),
                                                backgroundColor: Colors.black.withOpacity(0.5),
                                                fontFamily: 'Consolas',
                                              ),
                                              codeblockDecoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.white10),
                                              ),
                                            ),
                                            imageBuilder: (uri, title, alt) {
                                              String imageUrl = uri.toString();
                                              if (imageUrl.startsWith('/static/')) {
                                                imageUrl = '${ApiService.currentBaseUrl}$imageUrl';
                                              }
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(12),
                                                  child: Image.network(
                                                    imageUrl,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        const Icon(Icons.broken_image, color: Colors.grey),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                  ),
              ),
              
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Row(
                    children: [
                      const GeminiHeroAnimation(size: 24),
                      const SizedBox(width: 12),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF4285F4), Color(0xFFA259FF), Color(0xFFEA4335)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Text(
                          (_messages.isNotEmpty && _messages.last['file'] != null) ? 'Анализ вложения...' : 'Gemini думает...',
                          style: const TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
              if (_selectedFile != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.white10,
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildFilePreview(_selectedFile?.path, bytes: _selectedFile?.bytes, filename: _selectedFile?.name),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _selectedFile = null),
                      )
                    ],
                  ),
                ),


              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1F20),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white70),
                      onPressed: _pickFile,
                    ),
                    Expanded(
                      child: Focus(
                        onKeyEvent: (FocusNode node, KeyEvent event) {
                          if (event is KeyDownEvent &&
                              event.logicalKey == LogicalKeyboardKey.enter &&
                              !HardwareKeyboard.instance.isShiftPressed) {
                            _sendMessage();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          maxLines: null,
                          enabled: _cooldownSeconds == 0,
                          decoration: InputDecoration(
                            hintText: _cooldownSeconds > 0 ? 'Подождите $_cooldownSeconds сек...' : 'Спросите Gemini...',
                            border: InputBorder.none,
                            hintStyle: const TextStyle(color: Colors.white38),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    _cooldownSeconds > 0
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              '$_cooldownSeconds с',
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: Colors.blueAccent),
                            onPressed: _sendMessage,
                          ),
                  ],
                ),
              ),
            ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
