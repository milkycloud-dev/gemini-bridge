import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  final bool isPrivacy;

  const TermsScreen({Key? key, this.isPrivacy = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final title = isPrivacy ? 'Политика конфиденциальности' : 'Условия использования';
    final content = isPrivacy 
      ? '''
1. Сбор данных
Мы собираем минимально необходимое количество данных для обеспечения работы сервиса. Включает в себя ваш IP-адрес, данные об устройстве (HWID) и историю запросов.

2. Использование данных
Ваши данные используются исключительно для предоставления доступа к сети MilkyCloud и предотвращения злоупотреблений сервисом (боты, спам).

3. Хранение данных
История ваших чатов хранится на защищенных серверах и не передается третьим лицам без вашего согласия, за исключением случаев, предусмотренных законодательством.

4. Сторонние сервисы
Мы используем Google Gemini API. Ваши запросы (текст, изображения) отправляются на серверы Google для обработки. Пожалуйста, не отправляйте конфиденциальную личную информацию.
'''
      : '''
1. Общие положения
Используя сервис MilkyCloud Gemini Bridge, вы соглашаетесь с данными условиями. Если вы не согласны, пожалуйста, прекратите использование сервиса.

2. Доступ к сервису
Доступ предоставляется на усмотрение администрации. Мы оставляем за собой право ограничить доступ (бан аккаунта или IP) в случае нарушения правил сообщества.

3. Правила сообщества
Запрещена генерация контента, нарушающего законодательство, призывы к насилию, экстремизм, порнография и спам. Запрещено использовать автоматизированные скрипты (DDoS) для нагрузки серверов.

4. Отказ от ответственности
Сервис предоставляется "как есть". MilkyCloud не несет ответственности за любые сбои в работе сервиса или временную недоступность API Google Gemini.
''';

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E20),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Text(
              content,
              style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}
