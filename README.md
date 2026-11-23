# Whogram

iOS-клиент Telegram на SwiftUI + [TDLib](https://github.com/tdlib/td) через [TDLibKit](https://github.com/Swiftgram/TDLibKit).
Автор: whomakson.

## Что было сломано и что исправлено

| Проблема | Исправление |
| --- | --- |
| Сборка в Actions падала (exit code 65) | `TDLibManager` использовал `ObservableObject`/`@Published` без `import Combine` — файл не компилировался. Добавлен импорт |
| В `project.yml` не было `Info.plist` | Теперь он генерируется XcodeGen (`Support/Info.plist`) |
| `xcodebuild -scheme Whogram` мог не найти схему | Схема `Whogram` явно объявлена в `project.yml` |
| Сообщения в чате показывались вверх ногами (трюк с `scaleEffect(y: -1)`) | Нормальный `ScrollView` + `ScrollViewReader` с автопрокруткой вниз |
| Чаты шли в случайном порядке | Сортировка по дате последнего сообщения |
| Вкладки «Личное / Работа / Каналы» ничего не фильтровали | Реальные папки: Все / Личные / Группы / Каналы |
| `loadChats` отвечает `404 Not Found`, и это показывалось как ошибка | Ответ 404 игнорируется |
| Не было выхода из аккаунта | Кнопка «Выйти из аккаунта» в настройках (`logOut`) |
| Нет понятного лога при падении CI | Билд-лог и `.xcresult` выгружаются артефактом `build-logs` |

## Требования для сборки

- macOS с Xcode 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Интернет: TDLibKit тянет ~300 МБ бинарный TDLibFramework

## Локальная сборка (macOS)

```bash
xcodegen generate
open Whogram.xcodeproj
```

Дальше — обычный запуск на симуляторе/устройстве из Xcode.
Для устройства нужен свой Apple ID в *Signing & Capabilities*.

## GitHub Codespaces

**Собрать iOS-приложение в Codespaces нельзя**: Codespaces — это Linux-контейнер,
там нет Xcode и iOS SDK. Поэтому `xcodebuild` там не запустится никогда.

Что в Codespaces реально работает:

- редактирование кода (полноценный Swift-язык через расширение);
- проверка синтаксиса:

```bash
bash scripts/check-syntax.sh
```

В репозитории есть `.devcontainer/devcontainer.json` — Codespace сам поднимет
образ со Swift и выполнит проверку синтаксиса при создании.

Сборка `.ipa` делается в **GitHub Actions** на macOS-раннере (см. ниже).

## Сборка через GitHub Actions

1. Сделайте push в `main` (или запустите workflow вручную: *Actions → Build iOS App → Run workflow*).
2. Дождитесь зелёного билда.
3. Скачайте артефакт **Whogram-IPA** (внизу страницы запуска).
4. Если билд упал — скачайте артефакт **build-logs** и смотрите `build.log`.

`.ipa` неподписанный: установить на iPhone можно через AltStore / Sideloadly
со своим Apple ID (срок жизни подписи — 7 дней на бесплатном аккаунте).

## Структура

```
Sources/
  App/          точка входа, RootView
  Core/         TDLibManager (обёртка над TDLib), константы
  Models/       RealChat, RealMessage
  ViewModels/   AuthViewModel
  Views/        экраны: Auth, Chats, Settings, Components
project.yml     описание проекта для XcodeGen
scripts/        проверка синтаксиса
```

## Важно про безопасность

`api_id` и `api_hash` лежат в `Sources/Core/Constants.swift` открытым текстом.
Репозиторий публичный, значит ими может воспользоваться кто угодно — за это
Telegram может заблокировать `api_id`. Перед публикацией лучше:

1. получить свою пару на <https://my.telegram.org/apps>;
2. не коммитить её, а подставлять из конфигурации/CI-секрета.
