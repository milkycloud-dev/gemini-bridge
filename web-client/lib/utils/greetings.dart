import 'dart:math';

class Greetings {
  static String get(String nickname) {
    final hour = DateTime.now().hour;
    final random = Random();
    
    if (nickname.isEmpty) {
      nickname = 'Друг';
    }

    final morning = [
      'Доброе утро, $nickname! Готовы к новым свершениям?',
      'С добрым утром, $nickname! Чем займемся сегодня?',
      'Приветствую, $nickname! Утро - отличное время для новых идей.',
      'Рад видеть вас этим утром, $nickname. Чем могу помочь?',
      'Удачного начала дня, $nickname! Что обсудим?',
      'Доброе утро, $nickname! Я готов к работе.',
      'Солнечное утро, $nickname! Готов ответить на ваши вопросы.',
    ];

    final day = [
      'Добрый день, $nickname! Как продвигаются дела?',
      'Привет, $nickname! Что у нас на повестке дня?',
      'Рад помочь вам сегодня, $nickname!',
      'Отличный день для продуктивной работы, $nickname. Чем займемся?',
      'Добрый день, $nickname! Я на связи.',
      'Надеюсь, ваш день проходит отлично, $nickname. Чем могу быть полезен?',
      'С возвращением, $nickname! Продолжим?',
      'Приветствую, $nickname! Готов к новым задачам.',
    ];

    final evening = [
      'Добрый вечер, $nickname! Подводим итоги дня?',
      'Приветствую, $nickname! Как прошел ваш день?',
      'Уютного вечера, $nickname. Чем могу помочь?',
      'Добрый вечер, $nickname! Отличная работа сегодня.',
      'Рад видеть вас вечером, $nickname. Что обсудим?',
      'Спокойного вечера, $nickname. Есть вопросы ко мне?',
      'Вечер - время для размышлений. Чем займемся, $nickname?',
    ];

    final night = [
      'Доброй ночи, $nickname! Вы еще не спите?',
      'Ночь - время вдохновения. Чем займемся, $nickname?',
      'Приветствую полуночников! Чем могу помочь, $nickname?',
      'Тихая ночь, $nickname. Самое время для важных задач.',
      'Не спится, $nickname? Я всегда на связи.',
      'Работаете допоздна, $nickname? Я помогу.',
      'Доброй ночи, $nickname. Готов к ночному мозговому штурму.',
    ];

    List<String> pool;
    if (hour >= 6 && hour < 12) {
      pool = morning;
    } else if (hour >= 12 && hour < 18) {
      pool = day;
    } else if (hour >= 18 && hour < 23) {
      pool = evening;
    } else {
      pool = night;
    }

    return pool[random.nextInt(pool.length)];
  }
}
