import SwiftUI

final class AuthViewModel: ObservableObject {
    @Published var phone = "+7"
    @Published var code = ""
    @Published var password = ""

    private var tdlib: TDLibManager { TDLibManager.shared }

    func submitPhone() {
        tdlib.isLoading = true
        tdlib.statusMessage = "Запрос авторизации..."
        tdlib.errorMessage = nil
        tdlib.send([
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": phone,
            "settings": [
                "@type": "phoneNumberAuthenticationSettings",
                "allow_flash_call": false,
                "is_current_phone_number": false,
                "allow_sms_retriever_api": false
            ]
        ])
    }

    func submitCode() {
        tdlib.isLoading = true
        tdlib.statusMessage = "Проверка кода..."
        tdlib.errorMessage = nil
        tdlib.send(["@type": "checkAuthenticationCode", "code": code])
    }

    func submitPassword() {
        tdlib.isLoading = true
        tdlib.statusMessage = "Проверка пароля..."
        tdlib.errorMessage = nil
        tdlib.send(["@type": "checkAuthenticationPassword", "password": password])
    }
}
