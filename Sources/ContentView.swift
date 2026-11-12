import SwiftUI
import TDLibKit

struct ContentView: View {
    @State private var phoneNumber: String = "+7"
    @State private var isConnecting = false
    @State private var statusMessage = "Приватный клиент Telegram"
    
    // Тестовые ключи от серверов Telegram
    let apiId = 94575
    let apiHash = "a3406de8d171bb422bb6ddf3bbd800e2"
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Whogram")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(statusMessage.contains("Ошибка") ? .red : .gray)
                
                VStack(spacing: 20) {
                    TextField("Номер телефона", text: $phoneNumber)
                        .keyboardType(.numberPad) // Исправленная компактная клавиатура
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 30)
                    
                    Button(action: {
                        isConnecting = true
                        statusMessage = "Авторизация в TDLib..."
                        connectToTelegram()
                    }) {
                        Text(isConnecting ? "Соединение..." : "Войти")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(red: 50/255, green: 215/255, blue: 75/255))
                            .cornerRadius(12)
                            .padding(.horizontal, 30)
                    }
                }
                Spacer()
            }
        }
    }
    
    func connectToTelegram() {
        // Здесь TDLib получает наши ключи apiId и apiHash
        // Пока делаем визуальную проверку, что интерфейс реагирует
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            statusMessage = "Ключи приняты! Ожидание СМС-кода..."
            isConnecting = false
        }
    }
}





