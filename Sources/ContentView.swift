import SwiftUI
import TDLibKit

class TelegramAuth: ObservableObject {
    private var client: TdClient!
    
    @Published var statusMessage = "Подключение к серверам..."
    @Published var showCodeField = false
    
    init() {
        client = TdClientImpl(completionQueue: .main)
        
        // Слушаем реальные ответы от Telegram
        client.run { [weak self] data in
            if let response = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    if response.contains("authorizationStateWaitTdlibParameters") {
                        self?.sendParameters()
                    } else if response.contains("authorizationStateWaitPhoneNumber") {
                        self?.statusMessage = "Приватный клиент Telegram"
                    } else if response.contains("authorizationStateWaitCode") {
                        self?.statusMessage = "СМС отправлено! Введите код."
                        self?.showCodeField = true
                    } else if response.contains("authorizationStateReady") {
                        self?.statusMessage = "Успешный вход в аккаунт!"
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
        // Отправляем тестовые ключи разработчика
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
}

struct ContentView: View {
    @StateObject private var auth = TelegramAuth()
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
                        // Экран ввода номера
                        TextField("Номер телефона", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 30)
                        
                        Button(action: {
                            auth.sendPhoneNumber(phoneNumber)
                        }) {
                            Text("Получить код")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
client.run
client.run


.background(Color(red: 50/255, green: 215/255, blue: 75/255))
                                .cornerRadius(12)
                                .padding(.horizontal, 30)
                        }
                    } else {
                        // Экран ввода кода из СМС
                        TextField("Код из СМС", text: $code)
                            .keyboardType(.numberPad)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal, 30)
                        
                        Button(action: {
                            // Логику отправки кода добавим на следующем шаге
                            auth.statusMessage = "Проверка кода..."
                        }) {
                            Text("Войти")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 50/255, green: 215/255, blue: 75/255))
                                .cornerRadius(12)
                                .padding(.horizontal, 30)
                        }
                    }
                }
                Spacer()
            }
        }
    }
}
