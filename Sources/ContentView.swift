import SwiftUI
import TDLibKit

// Структура для реального чата
struct RealChat: Identifiable {
    let id: Int64
    let title: String
    let lastMessage: String
}

class TelegramAuth: ObservableObject {
    private var client: TdClient!
    
    @Published var statusMessage = "Подключение к серверам..."
    @Published var showCodeField = false
    @Published var isAuthorized = false
    @Published var chats: [RealChat] = [] // Массив твоих настоящих диалогов
    
    init() {
        client = TdClientImpl(completionQueue: .main)
        
        client.run { [weak self] data in
            if let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    // Обработка статусов входа
                    if response.contains("authorizationStateWaitTdlibParameters") {
                        self?.sendParameters()
                    } else if response.contains("authorizationStateWaitPhoneNumber") {
                        self?.statusMessage = "Приватный клиент Telegram"
                    } else if response.contains("authorizationStateWaitCode") {
                        self?.statusMessage = "СМС отправлено! Введите код."
                        self?.showCodeField = true
                    } else if response.contains("authorizationStateReady") {
                        self?.isAuthorized = true
                        self?.loadChats() // Запускаем скачивание твоих чатов!
                    }
                    
                    // Парсинг входящих данных о чатах
                    if response.contains("\"@type\":\"updateNewChat\"") {
                        self?.parseChat(jsonString: response)
                    }
                }
            }
        }
    }
    
    func send(json: String) {
        if let data = json.data(using: .utf8) {
            client.send(query: data)
        }
    }
    
    func sendParameters() {
        let request = """
        {
          "@type": "setTdlibParameters",
          "api_id": 94575,
          "api_hash": "a3406de8d171bb422bb6ddf3bbd800e2",
          "system_language_code": "ru",
          "device_model": "iPhone 14 Pro",
          "system_version": "iOS 16.0",
          "application_version": "1.0",
          "use_secret_chats": false,
          "use_message_database": false,
          "use_file_database": false,
          "use_chat_info_database": false,
          "use_test_dc": false,
          "database_directory": "tdlib",
          "files_directory": "tdlib_files",
          "enable_storage_optimizer": true,
          "ignore_file_names": false
        }
        """
        send(json: request)
    }
    
    func sendPhoneNumber(_ phone: String) {
        statusMessage = "Запрос СМС от Telegram..."
        let request = """
        {
          "@type": "setAuthenticationPhoneNumber",
          "phone_number": "\(phone)"
        }
        """
        send(json: request)
    }
    
    func sendAuthCode(_ code: String) {
        statusMessage = "Проверка кода на сервере..."
        let request = """
        {
          "@type": "checkAuthenticationCode",
          "code": "\(code)"
        }
        """
        send(json: request)
    }
    
    func loadChats() {
        // Просим сервер отдать 30 последних диалогов
        let request = """
        {
          "@type": "loadChats",
          "chat_list": {"@type": "chatListMain"},
          "limit": 30
        }
        """
        send(json: request)
    }
    
    func parseChat(jsonString: String) {
        // Вытаскиваем названия из JSON ответа
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chat = json["chat"] as? [String: Any],
              let id = chat["id"] as? Int64,
              let title = chat["title"] as? String else { return }
        
        let newChat = RealChat(id: id, title: title, lastMessage: "Зашифрованное сообщение...")
        
        if !self.chats.contains(where: { $0.id == id }) {
            self.chats.append(newChat)
        }
    }
}

struct ContentView: View {
    @StateObject private var auth = TelegramAuth()
    
    var body: some View {
        if auth.isAuthorized {
            ChatListView(auth: auth) // Передаем данные в экран чатов
        } else {
            LoginView(auth: auth)
        }
    }
}

struct LoginView: View {
    @ObservedObject var auth: TelegramAuth
    @State private var phoneNumber: String = "+7"
    @State private var code: String = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                Text("Whogram")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(auth.statusMessage)
                    .font(.subheadline)
                    .foregroundColor(auth.statusMessage.contains("СМС") ? .green : .gray)
                
                VStack(spacing: 20) {
                    if !auth.showCodeField {
                        TextField("Номер телефона", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 30)
                        
                        Button(action: { auth.sendPhoneNumber(phoneNumber) }) {
                            Text("Получить код")
                                .font(.headline).foregroundColor(.black).frame(maxWidth: .infinity)
                                .padding().background(Color(red: 50/255, green: 215/255, blue: 75/255)).cornerRadius(12).padding(.horizontal, 30)
                        }
                    } else {
                        TextField("Код из СМС", text: $code)
                            .keyboardType(.numberPad)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 30)
                        
                        Button(action: { auth.sendAuthCode(code) }) {
                            Text("Войти")
                                .font(.headline).foregroundColor(.black).frame(maxWidth: .infinity)
                                .padding().background(Color(red: 50/255, green: 215/255, blue: 75/255)).cornerRadius(12).padding(.horizontal, 30)
                        }
                    }
                }
                Spacer()
            }
        }
    }
}

struct ChatListView: View {
    @ObservedObject var auth: TelegramAuth
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if auth.chats.isEmpty {
                    ProgressView("Загрузка ваших чатов...")
                        .foregroundColor(.white)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Ghost Mode")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "eye.slash.fill")
                                    .foregroundColor(.green)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .padding()
                            
                            // Вывод реальных чатов!
                            ForEach(auth.chats) { chat in
                                ChatCellView(chat: chat)


}
                        }
                    }
                }
            }
            .navigationTitle("Чаты")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

struct ChatCellView: View {
    let chat: RealChat // Получаем данные реального чата
    
    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(Text(String(chat.title.prefix(1))).foregroundColor(.white)) // Первая буква названия
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title) // Настоящее имя собеседника или группы
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                }
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        Divider().background(Color.gray.opacity(0.2)).padding(.leading, 80)
    }
}