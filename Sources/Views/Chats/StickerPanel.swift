import SwiftUI

struct StickerPanel: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager

    let onSticker: (RealSticker) -> Void
    let onEmoji: (String) -> Void
    @State private var query = ""
    @State private var results: [RealSticker] = []
    @State private var resultQuery = ""
    @State private var failure: String?
    @State private var retry = 0

    private struct SearchKey: Equatable { let query: String; let retry: Int }
    private var term: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

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
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(ThemePressStyle())
                .accessibilityLabel("Обновить недавние стикеры")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").accessibilityHidden(true)
                TextField("Стикеры по слову или эмодзи", text: $query)
                    .font(theme.textFont)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").padding(8)
                    }
                    .accessibilityLabel("Очистить поиск")
                }
            }
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(theme.field, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Divider()
                .overlay(theme.separator)

            if !term.isEmpty && resultQuery != term {
                ProgressView("Поиск стикеров")
                    .frame(maxHeight: .infinity)
            } else if !term.isEmpty && results.isEmpty {
                VStack(spacing: 9) {
                    Text(failure ?? "Стикеры не найдены").font(theme.smallFont).foregroundStyle(theme.textSecondary)
                    if failure != nil {
                        Button("Повторить") { resultQuery = ""; retry += 1 }.frame(minHeight: 44)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .frame(maxHeight: .infinity)
            } else if term.isEmpty && tdlib.recentStickers.isEmpty {
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
                        ForEach(term.isEmpty ? tdlib.recentStickers : results) { sticker in
                            Button {
                                onSticker(sticker)
                            } label: {
                                StickerTile(sticker: sticker)
                            }
                            .buttonStyle(ThemePressStyle())
                            .accessibilityLabel(sticker.emoji.isEmpty ? "Стикер" : "Стикер \(sticker.emoji)")
                        }
                    }
                    .padding(14)
                }
            }
        }
        .frame(idealHeight: 272, maxHeight: 292)
        .liquidGlass(corner: theme.radius)
        .padding(.horizontal, 8)
        .onAppear {
            if tdlib.recentStickers.isEmpty {
                tdlib.loadRecentStickers()
            }
        }
        .task(id: SearchKey(query: term, retry: retry)) {
            let searchTerm = term
            guard !searchTerm.isEmpty else {
                resultQuery = ""
                results = []
                failure = nil
                return
            }
            do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
            guard !Task.isCancelled else { return }
            tdlib.searchStickers(searchTerm) { result in
                guard term == searchTerm else { return }
                switch result {
                case .success(let stickers):
                    results = stickers
                    failure = nil
                case .failure(let error):
                    results = []
                    failure = error.localizedDescription
                }
                resultQuery = searchTerm
            }
        }
    }
}

struct StickerTile: View {
    @EnvironmentObject private var theme: ThemeManager
    let sticker: RealSticker

    var body: some View {
        TdImage(fileID: sticker.isPlayable || sticker.fileID == 0 ? nil : sticker.fileID,
                previewFileID: sticker.thumbnailFileID, previewData: nil, priority: 16,
                showsPlaceholder: false, contentMode: .fit, fallbackEmoji: sticker.emoji)
        .frame(width: 56, height: 56)
        .frame(width: 62, height: 62)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.field)
        )
    }
}

struct StickerPackView: View {
    @EnvironmentObject private var tdlib: TDLibManager
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @State private var pack: RealStickerPack?
    @State private var failure: String?
    @State private var loading = false
    let setID: Int64
    let onSticker: (RealSticker) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                ThemeBackdrop()
                if let pack {
                    if pack.stickers.isEmpty {
                        ThemeEmptyState(icon: "face.smiling", title: "Пустой набор", detail: "В этом наборе нет доступных стикеров.")
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 10)], spacing: 10) {
                                ForEach(pack.stickers) { sticker in
                                    Button {
                                        onSticker(sticker)
                                        dismiss()
                                    } label: {
                                        StickerTile(sticker: sticker)
                                    }
                                    .buttonStyle(ThemePressStyle())
                                    .accessibilityLabel("Отправить стикер \(sticker.emoji)")
                                }
                            }
                            .padding(16)
                        }
                    }
                } else if let failure {
                    VStack(spacing: 9) {
                        ThemeEmptyState(icon: "exclamationmark.triangle", title: "Набор не загружен", detail: failure)
                        Button("Повторить", action: load).frame(minHeight: 44)
                    }
                } else {
                    ProgressView("Загрузка набора")
                }
            }
            .navigationTitle(pack?.title ?? "Набор стикеров")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } }
            }
            .onAppear { if pack == nil && failure == nil { load() } }
        }
    }

    private func load() {
        guard !loading else { return }
        loading = true
        failure = nil
        tdlib.loadStickerPack(setID) { result in
            loading = false
            switch result {
            case .success(let pack): self.pack = pack
            case .failure(let error): failure = error.localizedDescription
            }
        }
    }
}
