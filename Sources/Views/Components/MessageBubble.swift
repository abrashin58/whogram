import SwiftUI

struct MessageBubble: View {
    let message: RealMessage

    var body: some View {
        HStack {
            if message.isOutgoing { Spacer(minLength: 40) }

            VStack(alignment: .trailing, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(message.formattedTime)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(12)
            .background(message.isOutgoing ? Color.green.opacity(0.3) : Color.white.opacity(0.15))
            .cornerRadius(16)

            if !message.isOutgoing { Spacer(minLength: 40) }
        }
    }
}
