import SwiftUI

struct ChatPickerView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let title: String
    let onSelect: (RealChat) -> Void

    @State private var query = ""

    private var chats: [RealChat] {
        guard !query.isEmpty else { return tdlib.mainChats }
        return tdlib.chats.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(chats) { chat in
                        Button {
                            onSelect(chat)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(
                                    title: chat.title,
                                    fileID: chat.photoFileID ?? tdlib.user(chat.userID)?.photoFileID,
                                    preview: chat.photoPreview ?? tdlib.user(chat.userID)?.photoPreview,
                                    size: 44
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chat.title)
                                        .font(theme.font(15, weight: .semibold))
                                        .foregroundColor(theme.textPrimary)
                                        .lineLimit(1)
                                    Text(chat.kindTitle)
                                        .font(theme.font(11))
                                        .foregroundColor(theme.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
            }
            .background(ThemeBackdrop())
            .searchable(text: $query, prompt: "Поиск чата")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(theme.accent.main)
                }
            }
        }
    }
}
