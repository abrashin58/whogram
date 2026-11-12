import SwiftUI
import TDLibKit // Подключаем библиотеку Telegram

struct ContentView: View {
    @State private var phoneNumber: String = ""
    @State private var isConnecting = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                Text("Whogram")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("Приватный клиент Telegram")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Панель ввода номера
                VStack(spacing: 20) {
                    TextField("Номер телефона", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 30)
                    
                    Button(action: {
                        isConnecting = true
                        // Здесь будет вызов функции TDLib для отправки СМС
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
                
                Text("Powered by TDLib")
                    .font(.caption)
                    .foregroundColor(Color.gray.opacity(0.5))
            }
        }
    }
}