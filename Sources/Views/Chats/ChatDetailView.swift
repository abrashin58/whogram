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
                // ПЕРЕВЕРНУТЫЙ СКОЛЛ
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatMessages) { message in
                            MessageBubble(message: message)
                                .scaleEffect(y: -1) // Переворачиваем баблы обратно
                        }
                    }
                    .padding()
                }
                .scaleEffect(y: -1) // Переворачиваем скролл, чтобы новые были внизу
                
                // ПАНЕЛЬ ВВОДА
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "paperclip")
                            .font(.title2)
                            .foregroundColor(.gray)
                    }
                    
                    TextField("Сообщение...", text: $messageText)
                        .padding(12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                        .foregroundColor(.white)
                    
                    if !messageText.isEmpty {
                        Button {
                            tdlib.sendMessage(chatID: chat.id, text: messageText)
                            messageText = ""
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.green)
                        }
                    } else {
                        Button(action: {}) {
                            Image(systemName: "mic")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(10)
                .background(Color(white: 0.05).ignoresSafeArea(edges: .bottom))
            }
        }
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar) // Прячем нижний TabBar в чате
        .onAppear {
            tdlib.openChat(chat.id)
        }
        .onDisappear {
            tdlib.closeChat(chat.id)
        }
    }
}
