import SwiftUI

struct StickerPanel: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    let onSticker: (RealSticker) -> Void
    let onEmoji: (String) -> Void

    private let emojis = [
        "😀", "😂", "🥰", "😎", "🔥", "👍",
        "❤️", "🎉", "😭", "🤔", "🙏", "💯",
        "✨", "😴", "🤯", "🥳", "😍", "🤝",
        "👀", "💔", "😅", "🙈", "🤍", "⚡️"
    ]

    private let columns = [GridItem(.adaptive(minimum: 62), spacing: 10)]

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

            Divider()
                .overlay(theme.separator)

            if tdlib.recentStickers.isEmpty {
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
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(tdlib.recentStickers) { sticker in
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
        .frame(height: 272)
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
    }
}

struct StickerTile: View {
    @EnvironmentObject var tdlib: TDLibManager
    let sticker: RealSticker

    var body: some View {
        ZStack {
            Text(sticker.emoji)
                .font(.system(size: 30))

            if !sticker.isPlayable {
                TdImage(
                    fileID: sticker.fileID == 0 ? nil : sticker.fileID,
                    previewFileID: sticker.thumbnailFileID,
                    previewData: nil,
                    priority: 32,
                    showsPlaceholder: false
                )
                .frame(width: 56, height: 56)
            }
        }
        .frame(width: 62, height: 62)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}
