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
- [IDEAS.md](IDEAS.md) и [идеи упражнений](docs/harakat-exercises/README.md) — предложения вне действующего ТЗ.

## Локальная работа

Использовать версию Flutter из `.fvmrc` через проектный SDK:

```sh
.fvm/flutter_sdk/bin/flutter pub get
.fvm/flutter_sdk/bin/flutter run
```

Требования к выпуску — в [сборке и выпуске](docs/spec/BUILD_AND_RELEASE.md).

## Иконка приложения

Исходник — [assets/icon/app_icon.png](assets/icon/app_icon.png). После его замены
запустить `python3 tool/generate_app_icons.py` (требуется Pillow).
Скрипт обновляет каталог `AppIcon` для iOS и все плотности Android.
Для [адаптивной иконки Android](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
исходник занимает центральные 72 dp слоя 108 dp; фон продолжается до краёв.
