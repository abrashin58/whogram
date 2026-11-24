import SwiftUI
import UIKit
import PhotosUI

struct AppearanceView: View {
    enum Destination: String { case themes, wallpaper, typography }

    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @State private var confirmReset = false
    @State private var confirmCopy = false
    @State private var wallpaperItem: PhotosPickerItem?
    @State private var wallpaperFailure: String?
    @State private var loadingPhoto = false
    var destination: Destination = .themes

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    section("Коллекция тем", icon: "square.grid.2x2") { presets }
                        .id(Destination.themes)
                    if theme.preset != .custom { copyControl }
                    Group {
                        section("Цвета", icon: "paintpalette") { colors }
                        section("Поверхности и сообщения", icon: "square.stack.3d.up") { surfaces }
                        section("Фон чата", icon: "photo") { wallpapers }
                            .id(Destination.wallpaper)
                        section("Типографика", icon: "textformat.size") { typography }
                            .id(Destination.typography)
                        section("Движение и плотность", icon: "waveform.path") { effects }
                    }
                    .disabled(theme.preset != .custom)

                    if theme.preset == .custom {
                        Button("Сбросить Custom", role: .destructive) { confirmReset = true }
                            .font(theme.font(14, weight: .semibold))
                            .frame(minHeight: 44)
                    }
                }
                .padding(16)
            }
            .onAppear {
                if destination != .themes { proxy.scrollTo(destination, anchor: .top) }
            }
        }
        .background(ThemeBackdrop())
        .navigationTitle("Design Lab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .confirmationDialog("Сбросить пользовательскую тему?", isPresented: $confirmReset) {
            Button("Сбросить", role: .destructive) { theme.resetCustom() }
        } message: {
            Text("В Custom будут восстановлены настройки Neon Pulse.")
        }
        .confirmationDialog("Заменить сохранённую тему Custom?", isPresented: $confirmCopy) {
            Button("Заменить", role: .destructive) { theme.copyToCustom() }
        } message: {
            Text("Настройки текущего пресета станут основой для Custom.")
        }
        .alert("Не удалось сохранить обои", isPresented: Binding(
            get: { wallpaperFailure != nil }, set: { if !$0 { wallpaperFailure = nil } }
        )) {
            Button("Закрыть", role: .cancel) { wallpaperFailure = nil }
        } message: {
            Text(wallpaperFailure ?? "")
        }
        .task(id: wallpaperItem) {
            guard let item = wallpaperItem else { return }
            loadingPhoto = true
            defer {
                if wallpaperItem == item {
                    loadingPhoto = false
                    wallpaperItem = nil
                }
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ThemeManager.WallpaperError.invalidImage
                }
                let jpeg = await Task.detached(priority: .userInitiated) { ThemeManager.wallpaperJPEG(data) }.value
                try Task.checkCancellation()
                guard theme.preset == .custom else { return }
                guard let jpeg else { throw ThemeManager.WallpaperError.invalidImage }
                try theme.saveWallpaper(jpeg)
            } catch is CancellationError {
                return
            } catch {
                wallpaperFailure = error.localizedDescription
            }
        }
    }

    private var copyControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Готовая тема").font(theme.font(16, weight: .semibold)).foregroundStyle(theme.textPrimary)
            Text("Скопируйте пресет в Custom, чтобы настроить его. Готовые темы остаются неизменными.")
                .font(theme.smallFont).foregroundStyle(theme.textSecondary)
            Button {
                if theme.customProfile != nil { confirmCopy = true } else { theme.copyToCustom() }
            } label: {
                Label("Копировать в Custom", systemImage: "square.on.square")
                    .font(theme.font(13, weight: .semibold))
                    .foregroundStyle(theme.accent.onAccent)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .accentSurface(Capsule())
            }
            .buttonStyle(ThemePressStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .liquidGlass(corner: theme.radius)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: theme.preset.icon)
                    .frame(width: 42, height: 42)
                    .foregroundStyle(theme.accent.onAccent)
                    .accentSurface(Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("ЖИВОЙ ПРЕДПРОСМОТР")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(theme.textSecondary)
                    Text(theme.preset.title)
                        .font(theme.font(21, weight: .bold))
                        .foregroundStyle(theme.textPrimary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .liquidGlass(corner: 15)
            VStack(spacing: theme.compact ? 4 : 9) {
                Text("Как выглядит новая тема?")
                    .font(theme.textFont)
                    .foregroundStyle(theme.textPrimary)
                    .padding(10)
                    .background(MessageSurface(outgoing: false))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Цвет, стекло и детали на твой вкус.")
                    .font(theme.textFont)
                    .foregroundStyle(theme.outgoingText)
                    .padding(10)
                    .background(MessageSurface(outgoing: true))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .accessibilityHidden(true)
        }
        .padding(14)
        .background(WallpaperView().clipped())
        .clipShape(RoundedRectangle(cornerRadius: theme.radius))
        .overlay(RoundedRectangle(cornerRadius: theme.radius).strokeBorder(theme.separator))
    }

    private var presets: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 8)], spacing: 8) {
            ForEach(ThemePreset.allCases) { preset in
                let profile = preset == .custom ? (theme.customProfile ?? preset.profile) : preset.profile
                let selected = theme.preset == preset
                Button {
                    withAnimation(theme.animation(.spring(response: 0.32, dampingFraction: 0.86), reduced: reducedMotion)) {
                        theme.select(preset)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: preset.icon)
                                .foregroundStyle(Color(hex: ThemeContrast.readable(profile.accentStart, on: profile.darkSurface)))
                            Spacer()
                            if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: profile.accentStart)) }
                        }
                        Text(preset.title)
                            .font(theme.font(12, weight: .semibold))
                            .foregroundStyle(Color(hex: ThemeContrast.foreground(on: profile.darkSurface)))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                    .background(
                        LinearGradient(colors: [Color(hex: profile.darkBackground), Color(hex: profile.darkSurface)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 13)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 13)
                        .strokeBorder(Color(hex: profile.accentStart).opacity(selected ? 0.9 : 0.25), lineWidth: selected ? 2 : 1))
                }
                .buttonStyle(ThemePressStyle())
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private var colors: some View {
        VStack(spacing: 12) {
            Picker("Режим", selection: bind(\.appearance)) {
                ForEach(AppearanceMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 4)], spacing: 6) {
                ForEach(AccentPalette.allCases) { palette in
                    Button {
                        theme.edit { $0.accentStart = palette.rgb[0]; $0.accentEnd = palette.rgb[1] }
                    } label: {
                        Circle()
                            .fill(palette.tint.gradient)
                            .frame(width: 32, height: 32)
                            .overlay {
                                if palette.rgb == [theme.profile.accentStart, theme.profile.accentEnd] {
                                    Image(systemName: "checkmark").foregroundStyle(palette.tint.onAccent)
                                }
                            }
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(ThemePressStyle())
                    .accessibilityLabel(palette.title)
                }
            }
            color("Акцент: начало", \.accentStart)
            color("Акцент: конец", \.accentEnd)
            DisclosureGroup("Фоны и поверхности") {
                VStack(spacing: 12) {
                    color("Фон в тёмном режиме", \.darkBackground)
                    color("Панели в тёмном режиме", \.darkSurface)
                    color("Фон в светлом режиме", \.lightBackground)
                    color("Панели в светлом режиме", \.lightSurface)
                }
                .padding(.top, 10)
            }
        }
    }

    private var surfaces: some View {
        VStack(spacing: 12) {
            Picker("Панели", selection: bind(\.surface)) {
                ForEach(SurfaceStyle.allCases) { Text($0.title).tag($0) }
            }
            Picker("Входящие сообщения", selection: bind(\.bubble)) {
                ForEach(BubbleStyle.allCases) { Text($0.title).tag($0) }
            }
            slider("Скругление", value: \.radius, range: 8...32, step: 1, format: { "\(Int($0)) pt" })
            slider("Свечение", value: \.glow, range: 0...0.4, step: 0.02)
            Toggle("Отдельный цвет исходящих", isOn: Binding(
                get: { theme.profile.outgoingStart != nil },
                set: { enabled in
                    theme.edit {
                        $0.outgoingStart = enabled ? $0.accentStart : nil
                        $0.outgoingEnd = enabled ? $0.accentEnd : nil
                    }
                }
            ))
            if theme.profile.outgoingStart != nil {
                color("Исходящие: начало", \.outgoingStart, fallback: theme.profile.accentStart)
                color("Исходящие: конец", \.outgoingEnd, fallback: theme.profile.accentEnd)
            }
        }
    }

    private var wallpapers: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 83), spacing: 8)], spacing: 8) {
                ForEach(ChatWallpaper.allCases) { wallpaper in
                    Button {
                        theme.edit { $0.wallpaper = wallpaper; $0.usesLocalPhoto = nil }
                    } label: {
                        VStack(spacing: 4) {
                            LinearGradient(colors: wallpaper.rgb.map { Color(hex: $0) },
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                                .frame(height: 42)
                                .overlay {
                                    if wallpaper == theme.wallpaper && theme.profile.usesLocalPhoto != true {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.separator))
                            Text(wallpaper.title).font(theme.smallFont)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ThemePressStyle())
                    .accessibilityAddTraits(wallpaper == theme.wallpaper && theme.profile.usesLocalPhoto != true ? .isSelected : [])
                }
            }
            slider(theme.profile.usesLocalPhoto == true ? "Видимость фото" : "Насыщенность фона",
                   value: \.wallpaperStrength, range: 0...1, step: 0.05)
                .disabled(theme.wallpaper == .plain && theme.profile.usesLocalPhoto != true)
            PhotosPicker(selection: $wallpaperItem, matching: .images) {
                Label(loadingPhoto ? "Подготовка фото…" : "Выбрать фото из галереи", systemImage: "photo.badge.plus")
                    .font(theme.font(14, weight: .semibold))
                    .frame(minHeight: 44)
            }
            .disabled(loadingPhoto)
            if theme.wallpaperImage != nil {
                if theme.profile.usesLocalPhoto != true {
                    Button("Вернуть выбранное фото") { theme.edit { $0.usesLocalPhoto = true } }.frame(minHeight: 44)
                }
                Button("Удалить сохранённое фото", role: .destructive) {
                    do { try theme.removeWallpaper() } catch { wallpaperFailure = error.localizedDescription }
                }
                .frame(minHeight: 44)
            }
            Text("Фото остаётся на этом устройстве и не отправляется в Telegram.")
                .font(theme.smallFont)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var typography: some View {
        VStack(spacing: 12) {
            Picker("Шрифт", selection: bind(\.typeface)) {
                ForEach(ThemeTypeface.allCases) { Text($0.title).tag($0) }
            }
            slider("Размер текста", value: \.fontScale, range: 0.85...1.3, step: 0.05)
            Toggle("Крупные эмодзи", isOn: bind(\.largeEmoji))
        }
    }

    private var effects: some View {
        VStack(spacing: 12) {
            Toggle("Пружины и переходы", isOn: bind(\.motion))
            Toggle("Компактный список чатов", isOn: bind(\.compact))
        }
    }

    private func section<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(theme.font(16, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            content()
                .font(theme.font(14))
        }
        .foregroundStyle(theme.textPrimary)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(corner: theme.radius)
    }

    private func bind<Value>(_ key: WritableKeyPath<ThemeProfile, Value>) -> Binding<Value> {
        Binding(get: { theme.profile[keyPath: key] }, set: { value in theme.edit { $0[keyPath: key] = value } })
    }

    private func slider(
        _ title: String, value: WritableKeyPath<ThemeProfile, Double>, range: ClosedRange<Double>,
        step: Double, format: @escaping (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                Spacer()
                Text(format(theme.profile[keyPath: value])).monospacedDigit().foregroundStyle(theme.textSecondary)
            }
            .accessibilityHidden(true)
            Slider(value: bind(value), in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(format(theme.profile[keyPath: value]))
        }
    }

    private func color(_ title: String, _ key: WritableKeyPath<ThemeProfile, UInt32>) -> some View {
        ColorPicker(title, selection: Binding(
            get: { Color(hex: theme.profile[keyPath: key]) },
            set: { value in if let rgb = value.rgb { theme.edit { $0[keyPath: key] = rgb } } }
        ), supportsOpacity: false)
    }

    private func color(_ title: String, _ key: WritableKeyPath<ThemeProfile, UInt32?>, fallback: UInt32) -> some View {
        ColorPicker(title, selection: Binding(
            get: { Color(hex: theme.profile[keyPath: key] ?? fallback) },
            set: { value in if let rgb = value.rgb { theme.edit { $0[keyPath: key] = rgb } } }
        ), supportsOpacity: false)
    }
}

private extension Color {
    var rgb: UInt32? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        func byte(_ value: CGFloat) -> UInt32 { UInt32((min(max(value, 0), 1) * 255).rounded()) }
        return (byte(r) << 16) | (byte(g) << 8) | byte(b)
    }
}
