import SwiftUI

/// Settings in the same plain style as the rest of Kumo: three cards, one row per thing.
struct SettingsView: View {
    @AppStorage(Preference.persona) private var persona = Persona.student
    @AppStorage(Preference.transcriptionLocale) private var localeIdentifier = ""
    @AppStorage(Preference.writesNotes) private var writesNotes = true
    @AppStorage(Appearance.key) private var appearance = Appearance.system
    @Environment(Updater.self) private var updater
    @State private var locales: [Locale] = []
    @State private var installed: Bool?
    @State private var installing = false
    @State private var failure: String?
    @State private var checksAutomatically = true
    @State private var installsFixes = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Settings")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.9)
                    .foregroundStyle(Palette.ink)

                section("Transcription") {
                    row("Language", detail: "The language people speak.") {
                        Picker("Language", selection: $localeIdentifier) {
                            Text("System (\(Locale.preferredSpeech.localizedName))").tag("")
                            ForEach(locales, id: \.identifier) { locale in
                                Text(locale.localizedName).tag(locale.identifier)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    row("Speech model", detail: failure ?? (installed == true ? "Downloaded. Works offline." : "Downloaded once, then everything runs on this Mac.")) {
                        if installing {
                            ProgressView().controlSize(.small)
                        } else if installed == true {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Palette.green)
                        } else if installed == false {
                            pill("Download") { Task { await install() } }
                        }
                    }
                    row("Write notes afterwards", detail: "Listens again with a more accurate model, fixes hard words and writes notes with Apple Intelligence. A little battery, once, right after you stop.", last: true) {
                        Toggle("", isOn: $writesNotes)
                            .toggleStyle(.switch)
                            .labelsHidden()
                    }
                }

                section("General") {
                    row("Use Kumo as", detail: "Shapes the notes: flashcards, or action items.") {
                        Picker("Use Kumo as", selection: $persona) {
                            ForEach(Persona.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    row("Appearance", last: true) {
                        Picker("Appearance", selection: $appearance) {
                            ForEach(Appearance.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 210)
                        .onChange(of: appearance) { _, value in value.apply() }
                    }
                }

                section("Updates") {
                    row("Kumo \(Updater.currentVersion)", detail: status) { updateControl }
                    row("Check automatically", detail: "Every time Kumo opens.") {
                        Toggle("", isOn: $checksAutomatically)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: checksAutomatically) { _, value in updater.checksAutomatically = value }
                    }
                    row("Install small fixes automatically", detail: "In the background, when you are not recording.") {
                        Toggle("", isOn: $installsFixes)
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .onChange(of: installsFixes) { _, value in updater.installsFixesAutomatically = value }
                    }
                    row("Backups", detail: "Saved before every update and once a day.", last: true) {
                        pill("Show in Finder") {
                            try? FileManager.default.createDirectory(at: Backup.directory, withIntermediateDirectories: true)
                            NSWorkspace.shared.open(Backup.directory)
                        }
                    }
                }

                Text("© 2026 Salise Studio. Free for personal use.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .padding(.horizontal, 28)
            .padding(.top, 36)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.never)
        .background(Palette.canvas)
        .frame(width: 560, height: 700)
        .task(id: localeIdentifier) {
            if locales.isEmpty { locales = await Transcription.supportedLocales() }
            failure = nil
            installed = await Transcription.isInstalled(.speech(localeIdentifier))
        }
        .onAppear {
            checksAutomatically = updater.checksAutomatically
            installsFixes = updater.installsFixesAutomatically
        }
    }

    // MARK: Pieces

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
                .padding(.leading, 6)
            VStack(spacing: 0) { content() }
                .background(Palette.surface, in: .rect(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        }
    }

    private func row<Trailing: View>(_ title: String, detail: String? = nil, last: Bool = false, @ViewBuilder trailing: () -> Trailing) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                trailing()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            if !last {
                Rectangle()
                    .fill(Palette.hairline)
                    .frame(height: 1)
                    .padding(.leading, 18)
            }
        }
    }

    private func pill(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(prominent ? Palette.canvas : Palette.ink)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(prominent ? Palette.ink : Site.row, in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }

    private var status: String {
        if updater.isQuiet { return "You have the latest version." }
        return switch updater.state {
        case .checking: "Checking…"
        case .upToDate: "You have the latest version."
        case .available(let release): "Version \(release.version) is available."
        case .downloading(let fraction): "Downloading… \(Int(fraction * 100))%"
        case .ready(let url): url.pathExtension == "app" ? "Ready. Kumo restarts with the new version." : "Downloaded."
        case .failed(let message): message
        case .idle: "Free for personal use."
        }
    }

    @ViewBuilder
    private var updateControl: some View {
        if updater.isQuiet {
            pill("Check Now") { Task { await updater.check(userInitiated: true) } }
        } else if case .downloading(let fraction) = updater.state {
            ProgressView(value: fraction).frame(width: 120)
        } else if case .ready(let url) = updater.state {
            pill(url.pathExtension == "app" ? "Restart and Update" : "Install and Quit", prominent: true) { updater.openInstaller(url) }
        } else if let release = updater.available {
            pill("Download \(release.version)", prominent: true) { updater.install(release) }
        } else {
            pill("Check Now") { Task { await updater.check(userInitiated: true) } }
        }
    }

    private func install() async {
        installing = true
        defer { installing = false }
        do {
            try await Transcription.install(.speech(localeIdentifier))
            installed = true
        } catch {
            failure = error.localizedDescription
        }
    }
}

enum Privacy {
    static func open(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}
