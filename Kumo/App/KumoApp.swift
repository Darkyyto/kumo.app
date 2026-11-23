import SwiftUI

@main
struct KumoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var library: Library
    @State private var recorder: VoiceRecorder
    @State private var enhancer: NoteEnhancer
    @State private var updater: Updater

    init() {
        SandboxMigration.importDefaults()
        let library = Library()
        let recorder = VoiceRecorder(library: library)
        let enhancer = NoteEnhancer(library: library)
        let updater = Updater()
        _library = State(initialValue: library)
        _recorder = State(initialValue: recorder)
        _enhancer = State(initialValue: enhancer)
        _updater = State(initialValue: updater)
        updater.canRestart = { !recorder.isActive }
        AppDelegate.isRecording = { recorder.isActive }
        AppDelegate.quitNow = { updater.installBeforeQuitting() }
        AppDelegate.beforeTerminate = {
            if recorder.isActive, await recorder.stop() != nil {
                library.flush()
            }
            updater.installBeforeQuitting()
        }
        DispatchQueue.main.async {
            Backup.onLaunch()
            updater.checkOnLaunch()
            enhancer.resumePending(for: Persona(rawValue: UserDefaults.standard.string(forKey: Preference.persona) ?? "") ?? .student)
        }
    }

    var body: some Scene {
        Window("Kumo", id: "main") {
            HomeView()
                .environment(library)
                .environment(recorder)
                .environment(enhancer)
                .environment(updater)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    library.flush()
                }
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 760, height: 820)
        .restorationBehavior(.disabled)

        Settings {
            SettingsView()
                .environment(library)
                .environment(updater)
        }
        .windowResizability(.contentSize)
    }
}

enum Preference {
    static let persona = "persona"
    static let transcriptionLocale = "transcriptionLocale"
    static let writesNotes = "writesNotes"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var isRecording: (@MainActor () -> Bool)?
    @MainActor static var beforeTerminate: (@MainActor () async -> Void)?
    @MainActor static var quitNow: (@MainActor () -> Void)?

    func applicationWillFinishLaunching(_ notification: Notification) {
        Appearance.current.apply()
    }

    /// Closing the window ends the app, unless a recording is still running.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        MainActor.assumeIsolated { Self.isRecording?() != true }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if Self.isRecording?() != true {
            Self.quitNow?()
            return .terminateNow
        }
        guard let beforeTerminate = Self.beforeTerminate else { return .terminateNow }
        Task { @MainActor in
            await beforeTerminate()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
