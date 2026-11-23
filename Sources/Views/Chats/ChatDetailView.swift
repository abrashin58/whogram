import SwiftUI

struct ChatDetailView: View {
    @EnvironmentObject var tdlib: TDLibManager
    let chat: RealChat

    @State private var messageText = ""

    private var chatMessages: [RealMessage] {
        tdlib.messages[chat.id] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            inputBar
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            tdlib.openChat(chat.id)
        }
        .onDisappear {
            tdlib.closeChat(chat.id)
        }
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if chatMessages.isEmpty {
                        Text("Сообщений пока нет")
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                    }

                    ForEach(chatMessages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: chatMessages.count) { _ in
                scrollToBottom(proxy, animated: true)
            }
            .onAppear {
                scrollToBottom(proxy, animated: false)
            }
        }
    }

    private var inputBar: some View {
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

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let last = chatMessages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
