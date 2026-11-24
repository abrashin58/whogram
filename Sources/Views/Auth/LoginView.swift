import SwiftUI
import UIKit
import CoreImage

struct LoginView: View {
    @EnvironmentObject var tdlib: TDLibManager
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = AuthViewModel()

    @State private var appeared = false
    @State private var editingIdentity = false
    @State private var editingProfile: UUID?
    @State private var adoptLegacy = false
    @State private var apiID = ""
    @State private var apiHash = ""
    @State private var confirmConnection = false
    @State private var confirmReauthentication = false
    @State private var requestedProfile: UUID?
    @State private var showDiagnostics = false
    @State private var acceptedTerms = false

    private var isPublicIdentity: Bool {
        if let requestedProfile {
            return tdlib.profiles.first { $0.id == requestedProfile }?.identity.apiID == TelegramAppIdentity.previouslyPublicID
        }
        return Int32(apiID.trimmingCharacters(in: .whitespacesAndNewlines)) == TelegramAppIdentity.previouslyPublicID
    }

    var body: some View {
        ZStack {
            ThemeBackdrop()

            ScrollView {
                VStack(spacing: 22) {
                    Spacer(minLength: 44)
                    logo
                    titleBlock
                    statusBlock
                    if let code = tdlib.sessionSecurityCode {
                        Text("Код диагностики: \(code)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(theme.textSecondary)
                            .textSelection(.enabled)
                    }
                    formBlock
                    Button("Диагностика входа") { showDiagnostics = true }
                        .font(theme.smallFont)
                        .frame(minHeight: 44)
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
        .onDisappear {
            apiHash = ""
            viewModel.clear()
        }
        .onChange(of: tdlib.authPhase) { _ in acceptedTerms = false }
        .onChange(of: tdlib.registrationTerms) { _ in acceptedTerms = false }
        .sheet(isPresented: $showDiagnostics) { AuthDiagnosticsView() }
        .alert(isPublicIdentity ? "Ранее опубликованный API ID" : "Подключиться к Telegram?", isPresented: $confirmConnection) {
            Button("Отмена", role: .cancel) {}
            Button(isPublicIdentity ? "Понимаю риск, подключиться" : "Подключиться") {
                if let requestedProfile {
                    tdlib.connectProfile(requestedProfile, acknowledgePublicIdentity: isPublicIdentity)
                } else {
                    let saved = if let editingProfile {
                        tdlib.updateProfileIdentity(editingProfile, id: apiID, hash: apiHash,
                                                    acknowledgePublicIdentity: isPublicIdentity)
                    } else {
                        tdlib.addProfile(id: apiID, hash: apiHash, acknowledgePublicIdentity: isPublicIdentity, adoptLegacy: adoptLegacy)
                    }
                    if saved {
                        apiID = ""
                        apiHash = ""
                        editingIdentity = false
                        editingProfile = nil
                        adoptLegacy = false
                    }
                }
                viewModel.clear()
            }
        } message: {
            Text(adoptLegacy
                 ? "TDLib откроет старую базу на месте без переноса. Если Telegram отозвал сеанс, база не вернёт авторизацию."
                    + (isPublicIdentity ? " Вы ввели ранее опубликованный API ID. Не используйте основной аккаунт." : "")
                 : isPublicIdentity
                    ? "Эта пара ранее была в открытом репозитории. Telegram может отклонить вход или завершить сеансы. Не используйте основной аккаунт."
                    : editingProfile != nil ? "Новая пара будет сохранена для этого профиля. Его база и ключ шифрования не изменятся."
                        : "Сохранённый сеанс будет открыт из локальной базы, если он доступен.")
        }
        .alert("Начать новую авторизацию?", isPresented: $confirmReauthentication) {
            Button("Отмена", role: .cancel) {}
            Button("Продолжить") { tdlib.allowReauthentication() }
        } message: {
            Text("TDLib запросила вход после открытия базы. Прежде чем запрашивать новый код, проверьте активные сеансы в официальном Telegram.")
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
            if tdlib.needsConnectionApproval {
                connectionForm
            } else if tdlib.closeRequested {
                if tdlib.isLoading { ProgressView().tint(theme.accent.main) }
                Text("Закрываем соединение без выхода из аккаунта…")
            } else {
                authenticationForm
                if !tdlib.isLoading || tdlib.authorizationState == "authorizationStateWaitTdlibParameters" {
                    Button("К выбору аккаунта") { tdlib.disconnectToAccounts() }
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(18)
        .liquidGlass(corner: theme.radius)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
    }

    private var connectionForm: some View {
        VStack(spacing: 12) {
            if tdlib.catalogUnavailable {
                primaryButton("Повторить чтение аккаунтов", loading: false) { tdlib.loadAndResume() }
            } else if editingIdentity || tdlib.profiles.isEmpty {
                if adoptLegacy {
                    Text("Используется существующая база прежнего Whogram: без копирования, переноса или обнуления. Ранее опубликованный API ID не подставляется.")
                        .font(theme.smallFont)
                } else if tdlib.profiles.isEmpty && tdlib.canAdoptLegacy {
                    legacyButton
                }
                Text("Whogram не использует общий API ID. Введите данные своего приложения Telegram; они хранятся только в связке ключей этого iPhone.")
                    .font(theme.smallFont)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
                Link("Открыть my.telegram.org", destination: URL(string: "https://my.telegram.org")!)
                    .frame(minHeight: 44)
                TextField("API ID", text: $apiID)
                    .keyboardType(.numberPad)
                    .textContentType(nil)
                    .accessibilityLabel("API ID приложения Telegram")
                    .padding(12)
                    .background(theme.field, in: RoundedRectangle(cornerRadius: 12))
                SecureField("API Hash", text: $apiHash)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("API Hash приложения Telegram")
                    .padding(12)
                    .background(theme.field, in: RoundedRectangle(cornerRadius: 12))
                primaryButton("Сохранить и подключиться", loading: false) {
                    requestedProfile = nil
                    confirmConnection = true
                }
                    .disabled(apiID.isEmpty || apiHash.isEmpty)
                if !tdlib.profiles.isEmpty || adoptLegacy {
                    Button("Назад к аккаунтам") {
                        apiID = ""
                        apiHash = ""
                        editingIdentity = false
                        editingProfile = nil
                        adoptLegacy = false
                    }
                    .frame(minHeight: 44)
                }
            } else {
                Text("Выберите аккаунт").font(theme.font(16, weight: .semibold))
                ForEach(tdlib.profiles) { profile in
                    HStack {
                        Button {
                            requestedProfile = profile.id
                            confirmConnection = true
                        } label: {
                            HStack {
                                Image(systemName: profile.wasAuthorized ? "person.crop.circle.fill" : "person.crop.circle")
                                Text(profile.title).lineLimit(1)
                                Spacer()
                                if profile.id == tdlib.selectedProfileID {
                                    Image(systemName: "checkmark").accessibilityLabel("Последний выбранный")
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Button {
                            adoptLegacy = false
                            editingProfile = profile.id
                            apiID = String(profile.identity.apiID)
                            apiHash = ""
                            editingIdentity = true
                        } label: {
                            Image(systemName: "key.horizontal")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Изменить API профиля \(profile.title)")
                    }
                    Divider()
                }
                Button("Добавить аккаунт") {
                    adoptLegacy = false
                    editingProfile = nil
                    editingIdentity = true
                }
                    .frame(minHeight: 44)
                if tdlib.canAdoptLegacy { legacyButton }
            }
        }
    }

    private var legacyButton: some View {
        Button("Открыть базу прежнего Whogram…") {
            requestedProfile = nil
            editingProfile = nil
            adoptLegacy = true
            apiID = ""
            apiHash = ""
            editingIdentity = true
        }
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var authenticationForm: some View {
        if tdlib.sessionSecurityCode != nil {
            Text("Вход приостановлен. Проверьте сеансы в официальном Telegram. Не запрашивайте код повторно.")
                .font(theme.smallFont)
        } else if tdlib.authTimedOut {
            Text("Повторная отправка отключена, пока TDLib может обрабатывать предыдущий запрос.")
                .font(theme.smallFont)
        } else if tdlib.requiresReauthentication && tdlib.authorizationState == "authorizationStateWaitPhoneNumber" {
            Button("Начать новую авторизацию…") { confirmReauthentication = true }
                .frame(minHeight: 44)
        } else {
            authenticationStep
        }
    }

    @ViewBuilder
    private var authenticationStep: some View {
        switch tdlib.authPhase {
            case .phone:
                inputField("Номер телефона", text: $viewModel.phone, keyboard: .phonePad)

                primaryButton("Продолжить", loading: tdlib.isLoading) {
                    viewModel.submitPhone()
                }

                Text("Номер вводится в международном формате: +7 999 123-45-67")
                    .font(theme.font(10))
                    .foregroundColor(theme.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Войти по QR-коду") { tdlib.requestQRLogin() }
                    .disabled(tdlib.isLoading)
                    .frame(minHeight: 44)

            case .code:
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

            case .email:
                inputField("Почта", text: $viewModel.email, keyboard: .emailAddress)
                primaryButton("Отправить код", loading: tdlib.isLoading) { viewModel.submitEmail() }

            case .emailCode:
                if let email = tdlib.authCodePhone {
                    Text(email).font(theme.font(12)).foregroundColor(theme.textSecondary)
                }
                inputField("Код из письма", text: $viewModel.emailCode, keyboard: .numberPad)
                primaryButton("Подтвердить почту", loading: tdlib.isLoading) { viewModel.submitEmailCode() }
                Button("Отправить код ещё раз") { tdlib.resendCode() }.disabled(tdlib.isLoading).frame(minHeight: 44)

            case .password:
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
                Text("Если забыли пароль, восстановите его в официальном Telegram, затем вернитесь в Whogram.")
                    .font(theme.smallFont)
                    .foregroundStyle(theme.textSecondary)

            case .initializing:
                if tdlib.isLoading { ProgressView().tint(theme.accent.main) }
            case .parameters:
                if tdlib.isLoading {
                    ProgressView().tint(theme.accent.main)
                } else {
                    primaryButton("Повторить подключение", loading: false) { tdlib.retrySession() }
                }
            case .closed:
                if tdlib.isLoading { ProgressView().tint(theme.accent.main) }
                else if tdlib.recoveryNeedsRetry {
                    primaryButton("Восстановить соединение", loading: false) { tdlib.retrySession() }
                }

            case .deviceConfirmation:
                if let url = tdlib.confirmationLink, let image = qrImage(for: url) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 196, height: 196)
                        .padding(12)
                        .background(.white)
                        .accessibilityLabel("QR-код для входа в Telegram")
                    Text("На другом устройстве откройте Telegram → Настройки → Устройства → Подключить устройство.")
                        .font(theme.smallFont)
                } else {
                    Text("QR-код недоступен. Вернитесь к выбору аккаунта и попробуйте ещё раз.")
                        .font(theme.smallFont)
                }

            case .registration:
                if let terms = tdlib.registrationTerms {
                    Text(terms).font(theme.smallFont).textSelection(.enabled)
                    if tdlib.registrationMinimumAge > 0 {
                        Text("Минимальный возраст: \(tdlib.registrationMinimumAge)").font(theme.smallFont)
                    }
                    Toggle("Я принимаю условия и соответствую возрастным требованиям", isOn: $acceptedTerms)
                    TextField("Имя", text: $viewModel.firstName).textContentType(.givenName).padding(12).background(theme.field)
                    TextField("Фамилия (необязательно)", text: $viewModel.lastName).textContentType(.familyName).padding(12).background(theme.field)
                    primaryButton("Создать аккаунт", loading: tdlib.isLoading) { viewModel.register() }
                        .disabled(!acceptedTerms || viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Text("Условия регистрации недоступны. Зарегистрируйтесь в официальном Telegram.").font(theme.smallFont)
                }

            default:
                if tdlib.isLoading { ProgressView().tint(theme.accent.main) }
        }
    }

    private func qrImage(for url: URL) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
        guard let output = filter.outputImage, let rendered = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: rendered)
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
