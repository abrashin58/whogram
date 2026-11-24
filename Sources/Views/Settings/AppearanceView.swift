import SwiftUI

struct AppearanceView: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    previewCard

                    card(title: "Акцентный цвет") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 12)], spacing: 14) {
                            ForEach(AccentPalette.allCases) { palette in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        theme.accent = palette
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(palette.gradient)
                                                .frame(width: 44, height: 44)

                                            if theme.accent == palette {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(palette.onAccent)
                                            }
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(theme.accent == palette ? palette.main : Color.clear, lineWidth: 2)
                                                .padding(-4)
                                        )

                                        Text(palette.title)
                                            .font(theme.font(9, weight: .medium))
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                    }

                    card(title: "Тема") {
                        HStack(spacing: 6) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        theme.appearance = mode
                                    }
                                } label: {
                                    Text(mode.title)
                                        .font(theme.font(12, weight: .semibold))
                                        .foregroundColor(theme.appearance == mode ? theme.accent.onAccent : theme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(theme.appearance == mode ? AnyShapeStyle(theme.accent.gradient) : AnyShapeStyle(Color.clear))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(theme.field)
                        )
                        .padding(14)
                    }

                    card(title: "Обои чата") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(ChatWallpaper.allCases) { wallpaper in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        theme.wallpaper = wallpaper
                                    }
                                } label: {
                                    ZStack(alignment: .bottomLeading) {
                                        LinearGradient(
                                            colors: wallpaper.colors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )

                                        Text(wallpaper.title)
                                            .font(theme.font(9, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.9))
                                            .padding(6)

                                        if theme.wallpaper == wallpaper {
                                            VStack {
                                                HStack {
                                                    Spacer()
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.white)
                                                        .padding(5)
                                                }
                                                Spacer()
                                            }
                                        }
                                    }
                                    .frame(height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                theme.wallpaper == wallpaper ? theme.accent.main : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                    }

                    card(title: "Стиль сообщений") {
                        HStack(spacing: 8) {
                            ForEach(BubbleStyle.allCases) { style in
                                Button {
                                    theme.bubbleStyle = style
                                } label: {
                                    Text(style.title)
                                        .font(theme.font(11, weight: .semibold))
                                        .foregroundColor(theme.bubbleStyle == style ? theme.accent.onAccent : theme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(theme.bubbleStyle == style ? AnyShapeStyle(theme.accent.gradient) : AnyShapeStyle(theme.field))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(14)
                    }

                    card(title: "Размер текста") {
                        VStack(spacing: 10) {
                            HStack(spacing: 12) {
                                Text("A")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(theme.textSecondary)

                                Slider(value: $theme.fontScale, in: 0.85...1.3, step: 0.05)
                                    .tint(theme.accent.main)

                                Text("A")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(theme.textPrimary)
                            }

                            Text("Так будет выглядеть текст сообщения в чате.")
                                .font(theme.textFont)
                                .foregroundColor(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                    }

                    card(title: "Эффекты") {
                        VStack(spacing: 0) {
                            Toggle(isOn: $theme.largeEmoji) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Крупные эмодзи")
                                        .font(theme.font(14))
                                        .foregroundColor(theme.textPrimary)
                                    Text("Сообщение из 1–3 эмодзи показывается без пузыря")
                                        .font(theme.font(11))
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                            .tint(theme.accent.main)
                            .padding(14)

                            Divider().overlay(theme.separator)

                            Toggle(isOn: $theme.animations) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Анимации")
                                        .font(theme.font(14))
                                        .foregroundColor(theme.textPrimary)
                                    Text("Плавные переходы и пружины")
                                        .font(theme.font(11))
                                        .foregroundColor(theme.textSecondary)
                                }
                            }
                            .tint(theme.accent.main)
                            .padding(14)
                        }
                    }

                    Text("Настройки сохраняются автоматически")
                        .font(theme.font(10))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                        .padding(.top, 2)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Тема")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var previewCard: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Circle()
                    .fill(theme.accent.gradient)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(theme.accent.onAccent)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("Whogram")
                        .font(theme.font(13, weight: .semibold))
                        .foregroundColor(.white)
                    Text("предпросмотр темы")
                        .font(theme.font(9))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "ellipsis")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack {
                Text("Привет! Как тебе новая тема?")
                    .font(theme.font(13))
                    .foregroundColor(theme.textPrimary)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: theme.bubbleCorner, style: .continuous)
                            .fill(theme.incomingBubble)
                    )
                Spacer(minLength: 30)
            }

            HStack {
                Spacer(minLength: 30)
                Text("Огонь 🔥")
                    .font(theme.font(13))
                    .foregroundColor(theme.outgoingText)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: theme.bubbleCorner, style: .continuous)
                            .fill(theme.accent.gradient)
                    )
            }
        }
        .padding(14)
        .background(
            ZStack {
                LinearGradient(
                    colors: theme.wallpaper.colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(theme.accent.main.opacity(0.25))
                    .frame(width: 160, height: 160)
                    .blur(radius: 60)
                    .offset(x: 80, y: -50)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func card<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(theme.font(10, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .padding(.leading, 6)
                .padding(.bottom, 5)

            VStack(spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(theme.separator.opacity(0.6), lineWidth: 1)
            )
        }
    }
}
