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

                statusView

                inputSection

                if tdlib.isLoading {
                    ProgressView()
                        .tint(.green)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if let error = tdlib.errorMessage {
            Text(error)
                .font(.callout.bold())
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        } else {
            Text(tdlib.statusMessage)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 16) {
            switch tdlib.authorizationState {
            case "authorizationStateWaitPassword":
                SecureField("Облачный пароль", text: $vm.password)
                    .textContentType(.password)
                    .padding()
                    .liquidGlass()

                Button("Подтвердить") { vm.submitPassword() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(tdlib.isLoading)

            case "authorizationStateWaitCode":
                TextField("Код из Telegram", text: $vm.code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .liquidGlass()

                Button("Проверить") { vm.submitCode() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(tdlib.isLoading)

                Button("Отправить код ещё раз") { tdlib.resendCode() }
                    .font(.footnote)
                    .foregroundColor(.green)
                    .disabled(tdlib.isLoading)

            case "authorizationStateWaitPhoneNumber":
                TextField("Номер телефона", text: $vm.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                    .padding()
                    .liquidGlass()

                Button("Далее") { vm.submitPhone() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(tdlib.isLoading)

            default:
                EmptyView()
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 30)
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
