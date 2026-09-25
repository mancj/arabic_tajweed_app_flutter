# Сборка и выпуск

[← Оглавление ТЗ](../../SPEC.md)

## iOS и Rive

В конфигурациях `Profile` и `Release` цели `Runner` параметр Xcode
`STRIP_STYLE` обязан иметь значение `non-global` (`Non-Global Symbols`).

Rive 0.14 использует нативные символы через Dart FFI. При стандартном для
архива значении `all` Xcode удаляет, в частности, `makeFlutterFactory` из IPA:
локальная Debug-сборка продолжает работать, но TestFlight показывает серый
прямоугольник вместо анимации.

Нельзя удалять эту настройку при обновлении или пересоздании iOS-проекта.
После изменения проекта или Flutter перед выпуском нужно проверить итоговые
настройки обеих конфигураций:

```sh
xcodebuild -project ios/Runner.xcodeproj -target Runner \
  -configuration Release -showBuildSettings | grep STRIP_STYLE
xcodebuild -project ios/Runner.xcodeproj -target Runner \
  -configuration Profile -showBuildSettings | grep STRIP_STYLE
```

Обе команды должны вывести `STRIP_STYLE = non-global`.
