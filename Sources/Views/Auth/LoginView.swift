import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = AuthViewModel()

    @State private var appeared = false

    var body: some View {
        ZStack {
            ThemeBackdrop()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 44)
                    logo
                    titleBlock
                    statusBlock
                    formBlock
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(theme.animation(.spring(response: 0.55, dampingFraction: 0.82), reduced: reduceMotion)) {
                appeared = true
            }
        }
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: 96, height: 96)
                .accentSurface(Circle())

            Image(systemName: "paperplane.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(theme.accent.onAccent)
                .offset(x: -2, y: 1)
        }
        .scaleEffect(appeared ? 1 : 0.8)
        .opacity(appeared ? 1 : 0)
    }

    private var titleBlock: some View {
        VStack(spacing: 6) {
            Text("Whogram")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent.gradient)

            Text("Войдите в свой аккаунт Telegram")
                .font(theme.font(12))
                .foregroundColor(theme.textSecondary)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
    }

    @ViewBuilder
    private var statusBlock: some View {
        if let error = tdlib.errorMessage {
            Text(error)
                .font(theme.font(12, weight: .medium))
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.12))
                )
        } else {
            Text(tdlib.statusMessage)
                .font(theme.font(12))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var formBlock: some View {
        VStack(spacing: 12) {
            switch tdlib.authorizationState {
            case "authorizationStateWaitPhoneNumber":
                inputField("Номер телефона", text: $viewModel.phone, keyboard: .phonePad)

                primaryButton("Продолжить", loading: tdlib.isLoading) {
                    viewModel.submitPhone()
                }

                Text("Номер вводится в международном формате: +7 999 123-45-67")
                    .font(theme.font(10))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)

            case "authorizationStateWaitCode":
                if let phone = tdlib.authCodePhone {
                    Text("Код отправлен на \(phone)")
                        .font(theme.font(12))
                        .foregroundColor(theme.textSecondary)
                }

                inputField("Код из Telegram", text: $viewModel.code, keyboard: .numberPad)

                primaryButton("Войти", loading: tdlib.isLoading) {
                    viewModel.submitCode()
                }

                Button {
                    tdlib.resendCode()
                } label: {
                    Text("Отправить код ещё раз")
                        .font(theme.font(12, weight: .semibold))
                        .foregroundColor(theme.accent.main)
                }
                .buttonStyle(.plain)
                .disabled(tdlib.isLoading)

            case "authorizationStateWaitEmailAddress":
                inputField("Почта", text: $viewModel.email, keyboard: .emailAddress)
                primaryButton("Отправить код", loading: tdlib.isLoading) { viewModel.submitEmail() }

            case "authorizationStateWaitEmailCode":
                if let email = tdlib.authCodePhone {
                    Text(email).font(theme.font(12)).foregroundColor(theme.textSecondary)
                }
                inputField("Код из письма", text: $viewModel.emailCode, keyboard: .numberPad)
                primaryButton("Подтвердить почту", loading: tdlib.isLoading) { viewModel.submitEmailCode() }

            case "authorizationStateWaitPassword":
                if let hint = tdlib.passwordHint, !hint.isEmpty {
                    Text("Подсказка: \(hint)")
                        .font(theme.font(12))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                SecureField("Облачный пароль", text: $viewModel.password)
                    .textContentType(.password)
                    .font(theme.textFont)
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(theme.field)
                    )

                primaryButton("Подтвердить", loading: tdlib.isLoading) {
                    viewModel.submitPassword()
                }

            case "authorizationStateWaitTdlibParameters", "authorizationStateClosed":
                if tdlib.isLoading {
                    ProgressView().tint(theme.accent.main)
                } else {
                    primaryButton("Повторить подключение", loading: false) { tdlib.retrySession() }
                }

            default:
                if tdlib.isLoading { ProgressView().tint(theme.accent.main) }
            }
        }
        .padding(18)
        .liquidGlass(corner: theme.radius)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private func inputField(
        _ placeholder: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        TextField(placeholder, text: text)
            .textContentType(keyboard == .phonePad ? .telephoneNumber : keyboard == .emailAddress ? .emailAddress : .oneTimeCode)
            .keyboardType(keyboard)
            .font(theme.textFont)
            .foregroundColor(theme.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.field)
            )
    }

    private func primaryButton(_ title: String, loading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if loading {
                    ProgressView()
                        .tint(theme.accent.onAccent)
                } else {
                    Text(title)
                        .font(theme.font(15, weight: .semibold))
                }
            }
            .foregroundColor(theme.accent.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .accentSurface(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        }
        .buttonStyle(ThemePressStyle())
        .disabled(loading)
    }
}
