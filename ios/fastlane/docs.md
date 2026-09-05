# Заливка в TestFlight

Приложение: **Tajweed AI**, bundle id `tajweed.app`, team `W875G9YWT7`.

## Первая настройка

Ключ App Store Connect API уже лежит в `private_keys/` и прописан в `.env`
(файл в .gitignore). Ключ общий на весь аккаунт — тот же, что у Арабиста.
Если понадобится завести заново: App Store Connect → Users and Access →
Integrations → App Store Connect API, роль App Manager, скачать `.p8`
(даётся один раз), положить в `private_keys/`, заполнить `.env` по образцу
`.env.example`.

## Команды

Все запускать из `ios/`.

```sh
fastlane ios check       # ключ рабочий? какой номер сборки уже в TestFlight?
fastlane ios build_only  # собрать ipa, не отправляя — проверка, что сборка проходит
fastlane ios beta        # собрать и отправить в TestFlight
fastlane ios upload_ipa  # отправить уже собранный ipa без пересборки
```

С текстом «что нового» (тогда fastlane ждёт обработки на стороне Apple,
10–20 минут):

```sh
fastlane ios beta changelog:"Первая сборка"
```

## Версия

Версия и номер сборки берутся **только из `pubspec.yaml`** (`version: 1.0.0+1`).
Fastfile проверяет это дважды: после `flutter build` сверяет
`Generated.xcconfig`, а после экспорта распаковывает готовый ipa и сверяет
`Info.plist`. Apple не примет номер сборки, который уже есть в TestFlight —
перед каждой заливкой поднимать число после `+`.

## Имя приложения

`CFBundleDisplayName` локализовано: `ru.lproj/InfoPlist.strings` → «Таджвид AI»,
`en.lproj` и запасное значение в `Info.plist` → «Tajweed AI».
