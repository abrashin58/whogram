import SwiftUI

struct ContentView: View {
    @State private var ghostModeActive = true
    
    var body: some View {
        ZStack {
            // Идеально черный фон для OLED-экрана айфона
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Whogram")
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                Spacer()
                
                // Стеклянная панель Phantom Glass
                VStack(spacing: 20) {
                    HStack {
                        Text(ghostModeActive ? "Ghost Mode: ON" : "Ghost Mode: OFF")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $ghostModeActive)
                            .labelsHidden()
                            .tint(Color(red: 50/255, green: 215/255, blue: 75/255))
                    }
                    
                    HStack {
                        Text("Скрытие онлайна")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Spacer()
                        Image(systemName: ghostModeActive ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(ghostModeActive ? .green : .gray)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial) // Эффект матового стекла
                .cornerRadius(20)
                .colorScheme(.dark)
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
}