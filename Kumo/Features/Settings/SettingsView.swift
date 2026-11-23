import SwiftUI

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
        Form {
            Section {
                Picker("Language", selection: $localeIdentifier) {
                    Text("System (\(Locale.preferredSpeech.localizedName))").tag("")
                    ForEach(locales, id: \.identifier) { locale in
                        Text(locale.localizedName).tag(locale.identifier)
                    }
                }
                LabeledContent("Speech model") {
                    if installing {
                        ProgressView().controlSize(.small)
                    } else if installed == true {
                        Text("Downloaded")
                            .foregroundStyle(.secondary)
                    } else if installed == false {
                        Button("Download") { Task { await install() } }
                    }
                }
                if let failure {
                    Text(failure).font(.footnote).foregroundStyle(.secondary)
                }
                Toggle("Write notes after each recording", isOn: $writesNotes)
                Text("Kumo listens again with a more accurate model, fixes hard-to-hear words and writes notes with Apple Intelligence. It takes a little battery once, right after you stop.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Transcription")
            }

            Section {
                Picker("Use Kumo as", selection: $persona) {
                    ForEach(Persona.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                Picker("Appearance", selection: $appearance) {
                    ForEach(Appearance.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .onChange(of: appearance) { _, value in value.apply() }
            } header: {
                Text("General")
            }

            Section {
                LabeledContent("Kumo \(Updater.currentVersion)") {
                    updateControl
                }
                Toggle("Check automatically", isOn: $checksAutomatically)
                    .onChange(of: checksAutomatically) { _, value in updater.checksAutomatically = value }
                Toggle("Install small fixes automatically", isOn: $installsFixes)
                    .onChange(of: installsFixes) { _, value in updater.installsFixesAutomatically = value }
                LabeledContent("Backups") {
                    Button("Show in Finder") {
                        try? FileManager.default.createDirectory(at: Backup.directory, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(Backup.directory)
                    }
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("An update replaces only the app. Your recordings and notes stay where they are. © 2026 Salise Studio. Free for personal use.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 560)
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

    @ViewBuilder
    private var updateControl: some View {
        if updater.isQuiet {
            Text("Up to date").foregroundStyle(.secondary)
        } else if case .downloading(let fraction) = updater.state {
            ProgressView(value: fraction).frame(width: 120)
        } else if case .ready(let url) = updater.state {
            Button(url.pathExtension == "app" ? "Restart and Update" : "Install and Quit") { updater.openInstaller(url) }
        } else if let release = updater.available {
            Button("Download \(release.version)") { updater.install(release) }
        } else {
            Button("Check Now") { Task { await updater.check(userInitiated: true) } }
                .disabled(updater.state == .checking)
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
