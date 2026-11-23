import SwiftUI

/// The whole app in one landscape window. On the left: record. On the right: the words as they come, or everything recorded before.
struct HomeView: View {
    @Environment(Library.self) private var library
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(NoteEnhancer.self) private var enhancer
    @Environment(Updater.self) private var updater
    @AppStorage(Preference.persona) private var persona = Persona.student
    @AppStorage(Preference.transcriptionLocale) private var localeIdentifier = ""
    @AppStorage(Preference.writesNotes) private var writesNotes = true
    @State private var modal: Modal?
    @State private var name = ""
    @State private var saved: Recording?

    var body: some View {
        @Bindable var updater = updater
        HStack(spacing: 0) {
            RecordRail(name: $name, begin: begin, stop: stop, copy: copy)
                .frame(width: 304)
            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 1)
            content
        }
        .background(Palette.canvas)
        .frame(minWidth: 860, minHeight: 560)
        .card(item: $modal) { modal in
            switch modal {
            case .recording(let recording):
                RecordingDetail(recording: recording)
                    .frame(width: 720, height: 600)
            }
        }
        .card(item: $updater.presented) { release in
            UpdateCard(release: release)
        }
        .environment(\.present, PresentAction { [binding = $modal] in binding.wrappedValue = $0 })
    }

    @ViewBuilder
    private var content: some View {
        if recorder.isActive {
            VStack(spacing: 14) {
                if let message = recorder.errorMessage {
                    ErrorBanner(message: message) { recorder.dismissError() }
                }
                switch recorder.state {
                case .recording:
                    Tile(padding: 32) { TranscriptText() }
                case .preparing:
                    waiting("Getting ready…")
                case .downloadingModel:
                    waiting("Downloading the speech model. This happens once.")
                default:
                    waiting("Saving…")
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 44)
            .padding(.bottom, 28)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    if let message = recorder.errorMessage {
                        ErrorBanner(message: message) { recorder.dismissError() }
                    }
                    if let saved {
                        SavedCard(recording: saved) { self.saved = nil }
                    }
                    PastRecordings()
                }
                .padding(.horizontal, 28)
                .padding(.top, 44)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.never)
        }
    }

    private func waiting(_ text: String) -> some View {
        Tile(padding: 32) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func begin() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let vocabulary = library.activeGoals.map(\.title)
        let locale = Locale.speech(localeIdentifier)
        let noun = persona.recordingNoun
        Task {
            await recorder.start(locale: locale, goalID: nil, vocabulary: vocabulary, noun: noun, name: title)
        }
        name = ""
        saved = nil
    }

    private func stop() {
        recorder.finishStandalone(enhancer: enhancer, persona: persona, refine: writesNotes) { saved = $0 }
    }

    private func copy() {
        let text = Transcription.joined([recorder.finalizedText, recorder.volatileText])
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// The control column: Kumo's name, one big button, and what is going on while it listens.
struct RecordRail: View {
    @Binding var name: String
    let begin: () -> Void
    let stop: () -> Void
    let copy: () -> Void
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(Updater.self) private var updater
    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Preference.transcriptionLocale) private var localeIdentifier = ""
    @AppStorage(Preference.writesNotes) private var writesNotes = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image("Logo")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 30, height: 30)
                Text("Kumo")
                    .font(.system(size: 18, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Settings (⌘,)")
            }

            Tile(dark: true, padding: 24) { control }
                .fixedSize(horizontal: false, vertical: true)

            if case .idle = recorder.state {
                TextField("Name it now, or after", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Palette.surface, in: .rect(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 6) {
                if updater.available != nil {
                    Button("Update available") { updater.presented = updater.pending }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.ink)
                }
                Button {
                    openSettings()
                } label: {
                    Text("\(Locale.speech(localeIdentifier).localizedName) · notes \(writesNotes ? "on" : "off")")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkTertiary)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                Text("Audio and text stay on this Mac.")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkTertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 44)
        .padding(.bottom, 24)
        .onChange(of: scenePhase) { _, phase in recorder.setMetering(phase == .active && recorder.isActive) }
    }

    @ViewBuilder
    private var control: some View {
        switch recorder.state {
        case .idle:
            VStack(alignment: .leading, spacing: 18) {
                TileTitle(title: "Transcribe", subtitle: "Words appear as people speak.", dark: true)
                Button(action: begin) {
                    HStack(spacing: 9) {
                        Circle().fill(Palette.record).frame(width: 10, height: 10)
                        Text("Record")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x111111))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(.white, in: .capsule)
                    .contentShape(.capsule)
                }
                .buttonStyle(PressableStyle(scale: 0.98))
                .keyboardShortcut(.return, modifiers: .command)
                .help("Start transcribing (⌘↩)")
            }
        case .preparing, .downloadingModel:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small).tint(.white)
                Text(recorder.state == .preparing ? "Getting ready…" : "Downloading…")
                    .font(.system(size: 14))
                    .foregroundStyle(Site.onDarkDim)
            }
        case .recording(let since):
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Circle().fill(Palette.record).frame(width: 8, height: 8)
                    Text("Recording")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Site.onDark)
                }
                Text(since, style: .timer)
                    .font(.system(size: 40, weight: .semibold).monospacedDigit())
                    .tracking(-1)
                    .foregroundStyle(Site.onDark)
                LevelMeter(tint: .white)
                    .frame(height: 4)
                HStack(spacing: 8) {
                    Button(action: stop) {
                        Text("Stop")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x111111))
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(.white, in: .capsule)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                    .keyboardShortcut(.return, modifiers: .command)
                    Button(action: copy) {
                        Text("Copy")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Site.onDark)
                            .padding(.horizontal, 18)
                            .frame(height: 42)
                            .overlay { Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 1) }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onAppear { recorder.setMetering(true) }
            .onDisappear { recorder.setMetering(false) }
        case .finishing:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small).tint(.white)
                Text("Saving…")
                    .font(.system(size: 14))
                    .foregroundStyle(Site.onDarkDim)
            }
        }
    }
}
