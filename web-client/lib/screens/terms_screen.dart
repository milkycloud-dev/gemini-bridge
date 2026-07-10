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
Мы собираем минимально необходимое количество данных для обеспечения работы сервиса и вашей учетной записи (логин, зашифрованный пароль, и базовые системные идентификаторы для защиты от ботов).

2. Использование данных
Ваши данные используются исключительно для предоставления доступа к сети MilkyCloud, авторизации и предотвращения злоупотреблений сервисом. Мы не продаем и не передаем ваши личные данные третьим лицам.

3. Хранение данных
Ваши учетные данные хранятся на защищенных серверах. Мы предпринимаем все разумные меры безопасности для защиты вашей информации от несанкционированного доступа.

4. Сторонние сервисы
В рамках предоставления услуг мы можем использовать сторонние API (например, Google Gemini). Взаимодействие с ними регулируется их собственными политиками конфиденциальности.
'''
      : '''
1. Общие положения
Используя сервис MilkyCloud Gemini Bridge, вы соглашаетесь с данными условиями. Если вы не согласны, пожалуйста, прекратите использование сервиса.

2. Доступ к сервису
Доступ предоставляется на усмотрение администрации. Мы оставляем за собой право ограничить доступ в случае выявления злоупотреблений, нарушений правил сообщества или подозрительной активности.

3. Правила сообщества
Запрещена генерация контента, нарушающего законодательство, призывы к насилию, экстремизм, порнография и спам. Запрещено использовать автоматизированные скрипты (DDoS) для нагрузки серверов.

4. Отказ от ответственности
Сервис предоставляется "как есть". MilkyCloud не несет ответственности за любые прямые или косвенные убытки, сбои в работе сервиса или временную недоступность сторонних API.
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
