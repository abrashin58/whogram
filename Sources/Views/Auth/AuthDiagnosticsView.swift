import SwiftUI

struct AuthDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tdlib: TDLibManager
    @State private var snapshot = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Журнал содержит время, состояния TDLib и безопасные метки ошибок. В нём нет номера, кодов, пароля, API Hash, путей к базе или сообщений.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(snapshot.isEmpty ? "Пока нет событий." : snapshot)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .navigationTitle("Диагностика входа")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Menu("Действия") {
                        if !snapshot.isEmpty { ShareLink(item: snapshot) { Label("Поделиться журналом", systemImage: "square.and.arrow.up") } }
                        Button { snapshot = tdlib.authJournalText } label: { Label("Обновить", systemImage: "arrow.clockwise") }
                        Button(role: .destructive) {
                            tdlib.clearAuthJournal()
                            snapshot = ""
                        } label: { Label("Очистить только журнал", systemImage: "trash") }
                    }
                }
            }
        }
        .onAppear { snapshot = tdlib.authJournalText }
    }
}
