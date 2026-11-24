import SwiftUI

struct StickerPanel: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    @State private var searchQuery = ""

    let onSticker: (RealSticker) -> Void
    let onEmoji: (String) -> Void

    private let emojis = [
        "😀", "😂", "🥰", "😎", "🔥", "👍",
        "❤️", "🎉", "😭", "🤔", "🙏", "💯",
        "✨", "😴", "🤯", "🥳", "😍", "🤝",
        "👀", "💔", "😅", "🙈", "🤍", "⚡️"
    ]

    private let columns = [GridItem(.adaptive(minimum: 62), spacing: 10)]

    private var stickersToShow: [RealSticker] {
        if searchQuery.isEmpty {
            return tdlib.recentStickers
        }
        return tdlib.stickerSets
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Стикеры")
                    .font(theme.font(14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button {
                    tdlib.loadRecentStickers()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            searchField

            Divider()
                .overlay(theme.separator)

            if stickersToShow.isEmpty {
                if !searchQuery.isEmpty {
                    Text("Стикеры не найдены")
                        .font(theme.font(12))
                        .foregroundColor(theme.textSecondary)
                        .padding(.top, 20)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 8)], spacing: 8) {
                            ForEach(emojis, id: \.self) { emoji in
                                Button {
                                    onEmoji(emoji)
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 30))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 46)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)

                        Text("Недавних стикеров нет. Эмодзи тоже отправляются как сообщение.")
                            .font(theme.font(11))
                            .foregroundColor(theme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 16)
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(stickersToShow) { sticker in
                            Button {
                                onSticker(sticker)
                            } label: {
                                StickerTile(sticker: sticker)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(height: 310)
        .background(theme.elevated)
        .overlay(
            Rectangle()
                .fill(theme.separator)
                .frame(height: 1),
            alignment: .top
        )
        .onAppear {
            if tdlib.recentStickers.isEmpty {
                tdlib.loadRecentStickers()
            }
        }
        .onChange(of: searchQuery) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                tdlib.loadRecentStickers()
            } else {
                tdlib.searchStickers(trimmed)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)

            TextField("Поиск стикеров", text: $searchQuery)
                .font(theme.font(12))
                .foregroundColor(theme.textPrimary)
                .autocorrectionDisabled()

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.field))
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}

struct StickerTile: View {
    @EnvironmentObject var tdlib: TDLibManager
    let sticker: RealSticker

    var body: some View {
        ZStack {
            if sticker.isPlayable {
                // Анимированный стикер: показываем превью/статический кадр
                if let thumbnailFileID = sticker.thumbnailFileID, thumbnailFileID != 0 {
                    TdImage(
                        fileID: nil,
                        previewFileID: thumbnailFileID,
                        previewData: nil,
                        priority: 16,
                        showsPlaceholder: false
                    )
                    .frame(width: 56, height: 56)
                } else if sticker.fileID != 0 {
                    TdImage(
                        fileID: sticker.fileID,
                        previewFileID: sticker.thumbnailFileID,
                        previewData: nil,
                        priority: 16,
                        showsPlaceholder: false
                    )
                    .frame(width: 56, height: 56)
                }
            } else {
                TdImage(
                    fileID: sticker.fileID == 0 ? nil : sticker.fileID,
                    previewFileID: sticker.thumbnailFileID,
                    previewData: nil,
                    priority: 32,
                    showsPlaceholder: false
                )
                .frame(width: 56, height: 56)
            }

            if !sticker.emoji.isEmpty {
                Text(sticker.emoji)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 2)
            }
        }
        .frame(width: 62, height: 62)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
