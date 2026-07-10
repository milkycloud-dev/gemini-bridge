import 'package:flutter/material.dart';

class BannedScreen extends StatelessWidget {
  final String message;

  const BannedScreen({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          padding: EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            border: Border.all(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(20),
          ),
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sentiment_very_dissatisfied, color: Colors.red, size: 80),
              SizedBox(height: 20),
              Text(
                'ДОСТУП ОГРАНИЧЕН',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 20),
              Text(
                message.contains('IP') 
                    ? 'Ваш IP-адрес был заблокирован за нарушение правил сервиса.'
                    : 'Ваш аккаунт был заблокирован за нарушение правил сервиса.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 30),
              Text(
                'Если вы считаете, что это ошибка, свяжитесь с администрацией.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
