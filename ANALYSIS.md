# ANALYSIS.md — Анализ приложения-клиента Telegram (Whogram)

Результат изучения кодовой базы клиента `Whogram` (SwiftUI + TDLib) и перечень отсутствующих функций.

---

## 1. Что уже реализовано

| Область | Функции |
| --- | --- |
| Чаты | Список с папками (Все/Личные/Группы/Каналы), поиск, закреп/откреп (с ограничением в папке), mute, прочитано, mark-as-unread, очистить историю |
| Список чатов | Аватары, превью сообщений (с префиксом имени в группах), unread-бейджи, контекстное меню на чате (закрепить/без звука/прочитать/отметить непрочитанным/очистить историю) |
| Чат (деталь) | Сообщения по дням, день над сообщениями, ответ, редактирование (свое текстовое), удаление («удалить у всех»), пересылка, поиск в чате, статусы отправки (clock/check/прочитано), реакции (список с подсветкой и выбранным), статус печатания/записи видеосообщения/голосового (`chatAction*`) |
| Композер | Текст (вертикальный TextField), фото из галереи, файлы, стикеры, тап по смайлу |
| Стикеры | Панель в композере: недавние записи + сетка стикеров (с изображениями), отправка через `sendSticker` (remoteID/fileID), fallback — просто эмодзи. Панель эмодзи при пустых записях |
| Стикеры (в сообщениях) | `messageSticker` парсится: эмодзи, формат, размеры, файл. Пузырь показывает эмодзи 92 + статическое изображение через `TdImage` (только если не TGS/WebM) |
| Медиа (в сообщениях) | Фото/видео/GIF/видеосообщения — `TdImage` + tap → MediaViewer. Голосовые/аудио — воспроизведение через AudioPlayer (play/pause, waveform). Документы — иконка + размер + загрузка. Статус загрузки (арроу-даун или progress) |
| MediaViewer | Фото: пинч-зум, двойной тап, прокрутка для showControls. Видео: AVPlayer. Прогресс загрузки, share, закрытие |
| Настройки | Тема (7 акцентных палитр: neon/ocean/violet/sunset/amber/crimson/mint — зелёный по умолчанию), тёмная/светлая/системная, обои чата (6), стиль пузырей (modern/glass/classic), размер шрифта, крупные эмодзи, анимации, редактор профиля, выход из аккаунта, о приложении |
| Аккаунт | Вход (телефон → код → пароль), смена имени/юзернейма/био, аватар (отображается не подгружаемый новый, старый есть в чате) |
| Поиск | Поиск чатов (`searchChats` + `searchChatIDs`), поиск сообщений в чате (`searchChatMessages`) |
| Прочие | Реакции (add/remove), черновики очищаются, статусы онлайн/офлайн, live-location не используется (не парсится), чат инфо |

## 2. Отсутствующие функции (доработка)

### 2.1 Отображение стикеров ✅ *в плане*
- [ ] Анимированные стикеры (TGS/WebM): в пузырях чата показываются только эмодзи (`shouldRenderStickerImage` выключает TdImage). Показывать статический кадр из preview/thumbnail или TdImage если загрузится.
- [ ] Стикеры в панели: у TGS/WebM показывается только эмодзи, изображения — нет. Показывать превью (thumbnailFileID).
- [ ] Тап по стикеру в чате → открытие просмотрщика пакета (Telegram-like).
- [ ] Поиск стикеров в панели (`searchStickers`) — по префиксу.
- [ ] Отправка стикера из галереи фото (сейчас только inputFileId/remote).

### 2.2 Медиа ✅ *в плане*
- [ ] MediaViewer: видео — play/pause, ползунок прогресса, отображение длительности.
- [ ] MediaViewer: голосовые/аудио (`messageAudio`) — полноценный плеер, имя файла, длительность.
- [ ] MediaViewer: видеокольца (videoNote) — статус (воспроизведено/нет).
- [ ] MediaViewer: имя файла/длительность/размер для документов; кнопка «открыть» (системный файл).
- [ ] Запись голосового сообщения (микрофон в композере) — AVAudioRecorder → inputMessageVoiceNote (TDLib).
- [ ] Запись видеокольца — сложно, пропуск.
- [ ] GIF в пузыре: для `animation` tap открывает MediaViewer — сейчас VideoPlayer не всегда анимирует GIF.

### 2.3 Настройки с изменением дизайна с зелёного цвета на другие и разные темы ✅ *существуют*
- [ ] Проверить, что accent picker (green→others) работает: `AccentPalette` — палитры neon(green), ocean, violet, sunset, amber, crimson, mint. В AppearanceView есть выбор по цвету.
- [ ] Показывать название цвета на карточке «Тема и цвета» в SettingsView — уже (`theme.accent.title`).
- [ ] Добавить "Тёмная/светлая" — уже есть. Проверить работу.

### 2.4 Telegram-паритет (добавить, если время)
- [ ] Перевод сообщений (translateMessageText).
- [ ] Admin-действия (chatMemberInfo, promoteMember).
- [ ] Профиль контакта (contact карточка с звонком).
- [ ] Live location.
- [ ] Опросы отправка (sendPoll).
- [ ] Double-tap → реакция.
- [ ] Эмодзи-клавиатура.

## 3. Замечания по коду («доделать»)

1. `TdImage.load()` — при отсутствии пути в `filePaths` вызывается `downloadFile` каждый раз, когда `onAppear`/`onChange` триггерится повторно. Запрос идемпотентен, но `filePaths[fileID] != nil` guard уже есть в `downloadFile`. ОК.
2. `VoiceRecorder` — новый файл.
3. `MediaViewerView` — `VideoPlayer` без play/pause прогресса — добавить.
4. `StickerPanel` — улучшить `StickerTile` для Playable (показывать previewFileID).
5. `AppTheme` — `avatarColor` сумма скаляров — мелкий баг (сумма UnicodeScalars `$1.value` — `value` — String.UnicodeScalarView.Element — правильно).
6. `ChatDetailView.showStickers` — панель не закрывается при отправке стикера? (нужно проверить — `replyTo = nil` есть, но `showStickers` не reset).
7. `updateChatLastMessage` — при `last_message == nil` не обнуляет `lastMessageSenderID` (есть).
8. `searchMessages` — `topic_id: NSNull()` — старый API? (TDLib 1.8.70 — уже topic_id, OK).
9. `MessageBubble.mediaWidth` — `UIScreen.main.bounds.width * 0.62` без `DeviceScreen` — OK для iOS.
10. В `parseMessage` не читается `reply_to.input_message`/`can_be_forwarded`? (есть `state`, OK).
11. `handleChatAction` — сообщение о пользователях, но не показывается в списке чатов (Telegram показывает). Можно добавить `lastMessageText`.
12. `MessageBubble.voiceContent` — у исходящих voice messages отображение — OK.
13. `AppTheme.bubbleCorner` — `bubbleStyle == .classic ? 14 : 20`.
14. `StickerPanel` — при отсутствии недавних стикеров показывает только эмодзи — OK.
15. `updateMessageContent` (`messageText` edit) — обновление `text` при edit — OK, но `message.canBeEdited` — `isOutgoing && kind == .text && state == .sent` — при редактировании мы передаем old id, OK.
16. `ChatInfoView` — нет показа `recent activity` и `members online` для приватных.
17. `TdImage.placeholder` — `showsPlaceholder` параметр — OK.
18. `MediaViewerView.content` — для `animation` используется VideoPlayer — проверить GIF.

## 4. Порядок работы (приоритет)

1. Стикеры: показ в пузырях + панель + поиск.
2. Медиа: контролы плеера в MediaViewer.
3. Запись голосовых.
4. Настройки: проверка/полировка.
5. Паритет: сообщения чат-акций, admin-действия, перевод.

---

*Сгенерировано после анализа кодовой базы Whogram.*
