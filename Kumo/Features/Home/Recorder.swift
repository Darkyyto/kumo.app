import SwiftUI

/// Start, read along, save. No scenes and no animation: the only things that change are the words and the clock.
struct Recorder: View {
    @Environment(Library.self) private var library
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(NoteEnhancer.self) private var enhancer
    @AppStorage(Preference.persona) private var persona = Persona.student
    @AppStorage(Preference.transcriptionLocale) private var localeIdentifier = ""
    @AppStorage(Preference.writesNotes) private var writesNotes = true
    @State private var name = ""
    @State private var saved: Recording?

    var body: some View {
        VStack(spacing: 12) {
            switch recorder.state {
            case .idle:
                if let saved {
                    SavedCard(recording: saved) { self.saved = nil }
                }
                start
            case .preparing:
                status("Getting ready…")
            case .downloadingModel:
                status("Downloading the speech model. This happens once.")
            case .recording(let since):
                LiveTranscript(since: since, language: recorder.transcriptionLocale?.localizedName, copy: copy, stop: stop)
            case .finishing:
                status("Saving…")
            }

            if let message = recorder.errorMessage {
                ErrorBanner(message: message) { recorder.dismissError() }
            }
        }
    }

    private var start: some View {
        Tile(padding: 28) {
            VStack(spacing: 18) {
                SitePill(title: "Start transcribing", style: .ink, action: begin)
                    .keyboardShortcut(.return, modifiers: .command)
                TextField("Name it now, or after (optional)", text: $name)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: 360, minHeight: 40)
                    .background(Site.row, in: .rect(cornerRadius: 14, style: .continuous))
                Text("Words appear as people speak. Audio and text stay on this Mac.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Palette.inkTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func status(_ text: String) -> some View {
        Tile(padding: 28) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
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

/// After Stop: the recording is already safe. Give it a name if it needs one.
private struct SavedCard: View {
    let recording: Recording
    let dismiss: () -> Void
    @Environment(Library.self) private var library
    @Environment(NoteEnhancer.self) private var enhancer
    @Environment(\.present) private var present
    @State private var title: String

    init(recording: Recording, dismiss: @escaping () -> Void) {
        self.recording = recording
        self.dismiss = dismiss
        _title = State(initialValue: recording.title)
    }

    private var words: Int {
        (library.recordings.first { $0.id == recording.id }?.transcript ?? recording.transcript)
            .split(whereSeparator: \.isWhitespace).count
    }

    var body: some View {
        Tile(dark: true, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                    Text("Saved")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Site.onDarkDim)
                            .frame(width: 24, height: 24)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(Site.onDark)

                TextField("Name", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(Site.onDark)
                    .onSubmit(rename)

                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(Site.onDarkDim)

                HStack(spacing: 10) {
                    SitePill(title: "Save name", style: .white, action: rename)
                    Button {
                        rename()
                        if let current = library.recordings.first(where: { $0.id == recording.id }) {
                            present(.recording(current))
                        }
                    } label: {
                        Text("Open")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Site.onDark)
                            .padding(.horizontal, 20)
                            .frame(height: 40)
                            .overlay { Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1) }
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var detail: String {
        var parts = [recording.duration.clock, "\(words) words"]
        switch enhancer.phase(of: recording) {
        case .transcribing: parts.append("Listening again for accuracy…")
        case .writing: parts.append(enhancer.progress(of: recording).map { "Writing notes · \($0)%" } ?? "Writing notes…")
        case nil: break
        }
        return parts.joined(separator: " · ")
    }

    private func rename() {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, var current = library.recordings.first(where: { $0.id == recording.id }), current.title != clean else { return }
        current.title = clean
        current.isNamed = true
        library.save(current)
    }
}

/// The running transcript. It reads the recorder itself, so only this view redraws as words arrive.
private struct LiveTranscript: View {
    let since: Date
    let language: String?
    let copy: () -> Void
    let stop: () -> Void
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(\.scenePhase) private var scenePhase

    /// The screen only ever needs the last few lines. The whole text is kept and saved by the recorder.
    private var finalized: String {
        String(recorder.finalizedText.suffix(1_400))
    }

    var body: some View {
        VStack(spacing: 12) {
            Tile(padding: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Palette.record)
                            .frame(width: 8, height: 8)
                        Text("Recording")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                        if let language {
                            Text(language)
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.inkTertiary)
                        }
                        Spacer(minLength: 12)
                        Text(since, style: .timer)
                            .font(.numeric(14, weight: .medium))
                            .foregroundStyle(Palette.inkSecondary)
                            .monospacedDigit()
                    }
                    LevelMeter()
                        .frame(height: 4)
                    transcript
                        .font(.system(size: 18))
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .bottomLeading)
                        .frame(height: 300, alignment: .bottomLeading)
                        .clipped()
                        .mask {
                            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12)], startPoint: .top, endPoint: .bottom)
                        }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                SitePill(title: "Stop", style: .ink, action: stop)
                    .keyboardShortcut(.return, modifiers: .command)
                SitePill(title: "Copy", style: .soft, action: copy)
                Spacer()
            }
        }
        .onAppear { recorder.setMetering(scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in recorder.setMetering(phase == .active) }
        .onDisappear { recorder.setMetering(false) }
    }

    @ViewBuilder
    private var transcript: some View {
        if finalized.isEmpty, recorder.volatileText.isEmpty {
            Text("Listening…")
                .foregroundStyle(Palette.inkTertiary)
        } else {
            Text(finalized).foregroundStyle(Palette.ink)
                + Text(finalized.isEmpty || recorder.volatileText.isEmpty ? "" : " ")
                + Text(recorder.volatileText).foregroundStyle(Palette.inkSecondary)
        }
    }
}

/// One thin bar for the microphone level. Redrawn a few times a second, and only while the window is in front.
private struct LevelMeter: View {
    @Environment(VoiceRecorder.self) private var recorder

    var body: some View {
        let level = CGFloat(recorder.levels.last ?? 0)
        Capsule()
            .fill(Palette.ink.opacity(0.08))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Palette.ink.opacity(0.7))
                        .frame(width: max(4, proxy.size.width * level))
                }
            }
    }
}
