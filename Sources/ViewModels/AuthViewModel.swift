import SwiftUI

final class AuthViewModel: ObservableObject {
    @Published var phone = "+7"
    @Published var code = ""
    @Published var password = ""
    @Published var email = ""
    @Published var emailCode = ""

    private var tdlib: TDLibManager { TDLibManager.shared }

    func clear() {
        phone = "+7"
        code = ""
        password = ""
        email = ""
        emailCode = ""
    }

    func submitPhone() {
        tdlib.submitAuthentication([
            "@type": "setAuthenticationPhoneNumber",
            "phone_number": phone,
            "settings": [
                "@type": "phoneNumberAuthenticationSettings",
                "allow_flash_call": false,
                "allow_missed_call": false,
                "is_current_phone_number": false,
                "has_unknown_phone_number": false,
                "allow_sms_retriever_api": false,
                "firebase_authentication_settings": NSNull(),
                "authentication_tokens": []
            ]
        ], status: "Запрос авторизации…")
    }

    func submitCode() {
        tdlib.submitAuthentication(["@type": "checkAuthenticationCode", "code": code.trimmingCharacters(in: .whitespacesAndNewlines)],
                                    status: "Проверка кода…")
    }

    func submitPassword() {
        tdlib.submitAuthentication(["@type": "checkAuthenticationPassword", "password": password], status: "Проверка пароля…")
    }

    func submitEmail() {
        tdlib.submitAuthentication(["@type": "setAuthenticationEmailAddress", "email_address": email],
                                    status: "Отправляем код на почту…")
    }

    func submitEmailCode() {
        tdlib.submitAuthentication([
            "@type": "checkAuthenticationEmailCode",
            "code": ["@type": "emailAddressAuthenticationCode", "code": emailCode.trimmingCharacters(in: .whitespacesAndNewlines)]
        ], status: "Проверка кода…")
    }
}
