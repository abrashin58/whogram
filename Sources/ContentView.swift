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

// 4. Внутренний интерфейс клиента (Список чатов Ghostgram)
struct ChatListView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Верхняя панель управления (Режим невидимки)
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
                        
                        // Скелет списка чатов
                        ForEach(1...5, id: \.self) { index in
                            ChatCellView()
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

// Дизайн отдельного диалога
struct ChatCellView: View {
    var body: some View {
        HStack(spacing: 15) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(Text("T").foregroundColor(.white))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Telegram")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("12:00")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Text("Уведомление о входе с устройства Whogram.")
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
