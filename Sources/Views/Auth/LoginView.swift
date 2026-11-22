import SwiftUI

struct LoginView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)

                Text("Вход")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)

                if let error = tdlib.errorMessage {
                    Text(error)
                        .font(.callout.bold())
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                } else {
                    Text(tdlib.statusMessage)
                        .foregroundColor(.gray)
                }

                VStack(spacing: 16) {
                    if tdlib.authorizationState == "authorizationStateWaitPassword" {
                        SecureField("Облачный пароль", text: $vm.password)
                            .textContentType(.password)
                            .padding()
                            .liquidGlass()

                        Button("Подтвердить", action: vm.submitPassword)
                            .buttonStyle(PrimaryButtonStyle())
                    } else if tdlib.authorizationState == "authorizationStateWaitCode" {
                        TextField("Код", text: $vm.code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .padding()
                            .liquidGlass()

                        Button("Проверить", action: vm.submitCode)
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        TextField("Номер телефона", text: $vm.phone)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .padding()
                            .liquidGlass()

                        Button("Далее", action: vm.submitPhone)
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 30)

                if tdlib.isLoading {
                    ProgressView()
                        .tint(.green)
                }

                Spacer()
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.green)
            .cornerRadius(14)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
