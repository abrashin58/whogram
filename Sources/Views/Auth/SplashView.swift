import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                Text("Whogram")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 10)
            }
        }
    }
}
