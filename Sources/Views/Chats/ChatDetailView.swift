import SwiftUI

struct ChatDetailView: View {
    @EnvironmentObject var tdlib: TDLibManager
    let chat: RealChat
    @State private var messageText = ""

    var chatMessages: [RealMessage] {
        tdlib.messages[chat.id] ?? []
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatMessages) { message in
                            MessageBubble(message: message)
                                .scaleEffect(y: -1)
                        }
                    }
                    .padding()
                }
                .scaleEffect(y: -1)

                HStack(spacing: 12) {
                    TextField("Сообщение...", text: $messageText)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)

                    Button {
                        tdlib.sendMessage(chatID: chat.id, text: messageText)
                        messageText = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.green)
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(10)
                .background(Color(white: 0.05).ignoresSafeArea(edges: .bottom))
            }
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            tdlib.openChat(chat.id)
        }
        .onDisappear {
            tdlib.closeChat(chat.id)
        }
    }
}
