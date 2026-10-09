# Tajweed AI

Flutter-приложение для обучения чтению на арабском: буквы, их формы,
огласовки и слова. Бэкенд — в соседнем `../tajweed_app_backend_dart`.

## Документация

- [CLAUDE.md](CLAUDE.md) — обязательные правила работы в проекте.
- [SPEC.md](SPEC.md) — оглавление действующего ТЗ; читать связанную с задачей область.
- [Карточки объяснений](docs/EXPLANATION_CARDS.md) — формат YAML и подключение контента.
- [Конспекты букв](docs/letter-definitions/README.md) — редакционные исходники и оригиналы иллюстраций.
- [Общий банк слов](assets/curriculum/words.json) — единый источник для курса и отладки; [редактирование и проверка](docs/word-reading/README.md).
- [Таблица слов для озвучки](docs/word-reading/WORDS.md) — все слова, источники, подборки и имена MP3; создаётся из банка.
- [Проблемные сценарии](docs/PROBLEM_CASES.md) — случаи, защищённые постоянными тестами.
- [TODO.md](TODO.md) — незакрытые задачи, включая подготовку релиза.
- [Авторизация перед выпуском](docs/AUTHORIZATION_TODO.md) — матрица iOS/Android,
  окружения, Google/Apple/email, сертификаты подписи и проверка OAuth.
- [IDEAS.md](IDEAS.md) и [идеи упражнений](docs/harakat-exercises/README.md) — предложения вне действующего ТЗ.

## Локальная работа

Использовать версию Flutter из `.fvmrc` через проектный SDK:

```sh
.fvm/flutter_sdk/bin/flutter pub get
.fvm/flutter_sdk/bin/flutter run
```

Требования к выпуску — в [сборке и выпуске](docs/spec/BUILD_AND_RELEASE.md).

Проверка произношения: приложение → Dart API (`9223`) → приватный
[ML-бэкенд](../tajweed_ml_backend/README.md) (`8765`). Quran Muaalem и веса
хранятся в ML-проекте. Запуск API описан в [README бэкенда](../tajweed_app_backend_dart/README.md).
При ручной настройке адреса на экране Debug указывайте порт Dart API `9223`.
В симуляторе iPhone `http://127.0.0.1:9223` подходит, только если backend
слушает localhost. Если API запущен на сетевом IP Mac, тот же IP нужно указать
и в симуляторе (текущий адрес по умолчанию — `http://192.168.68.56:9223`).
На физическом телефоне нужен текущий IP Mac в общей Wi-Fi сети и backend,
слушающий этот сетевой адрес. После смены Wi-Fi проверяйте сохранённый адрес
в Debug; новый адрес применяется сразу и сохраняется между запусками.

Вход по email подключён к тому же Dart API: профиль → авторизация → email →
6-значный код. Работают повторная отправка, сохранение сессии и выход.
Сервер должен быть запущен с SMTP-настройками; на телефоне адрес из Debug
должен быть доступен по сети. SMTP-пароль и OTP-секрет в приложение не входят.

Вход с Google на iOS и Android подключён через Firebase-проект
`tajweed-ai-a2df4`. Firebase Authentication должен иметь включённый провайдер
Google, а Dart API — настроенный серверный ключ Firebase (см. README бэкенда).
Приложение передаёт Firebase ID token в `POST /auth/google` и сохраняет
полученную сессию API; локальный учебный прогресс при входе не меняется.

Мобильные конфиги: `ios/Runner/GoogleService-Info.plist` (bundle `tajweed.app`)
и `android/app/google-services.json` (package `app.arabic.tajweed`). Для iOS
`Info.plist` содержит `GIDClientID`, `GIDServerClientID` и обратную URL-схему;
при замене Firebase-проекта эти значения тоже нужно обновить.
Для Android подключён Gradle-плагин Google Services. SHA-1 каждого сертификата
подписи нужно добавить в настройки Android-приложения Firebase; сертификат
отладки и сертификат подписи из Google Play регистрируются отдельно.
Debug SHA-1 этого Mac: `6D:77:38:9B:61:E6:6B:EB:2E:56:C2:2C:7A:A3:93:81:EE:42:C7:8D`.
После изменения нативных конфигов нужна полная пересборка приложения.
Google-вход в Web не подключён: для него понадобится отдельное Web-приложение Firebase.

## Иконка приложения

Исходник — [assets/icon/app_icon.png](assets/icon/app_icon.png). После его замены
запустить `python3 tool/generate_app_icons.py` (требуется Pillow).
Скрипт обновляет каталог `AppIcon` для iOS и все плотности Android.
Для [адаптивной иконки Android](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
исходник занимает центральные 72 dp слоя 108 dp; фон продолжается до краёв.
