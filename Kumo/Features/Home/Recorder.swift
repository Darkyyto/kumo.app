import SwiftUI

/// After Stop: the recording is already safe. Give it a name if it needs one.
struct SavedCard: View {
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

/// The running words. Every finished piece is its own line and only the last, still changing one is redrawn. It follows the end by itself, and you can scroll up to read what came before.
struct TranscriptText: View {
    @Environment(VoiceRecorder.self) private var recorder

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if recorder.segments.isEmpty, recorder.volatileText.isEmpty {
                    Text("Listening…")
                        .foregroundStyle(Palette.inkTertiary)
                }
                ForEach(Array(recorder.segments.enumerated()), id: \.offset) { _, segment in
                    Text(segment)
                        .foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !recorder.volatileText.isEmpty {
                    Text(recorder.volatileText)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.system(size: 20))
            .lineSpacing(6)
        }
        .defaultScrollAnchor(.bottom)
        .scrollIndicators(.automatic)
    }
}

/// One thin bar for the microphone level. Redrawn a few times a second, and only while the window is in front.
struct LevelMeter: View {
    var tint: Color = Palette.ink
    @Environment(VoiceRecorder.self) private var recorder

    var body: some View {
        let level = CGFloat(recorder.levels.last ?? 0)
        Capsule()
            .fill(tint.opacity(0.12))
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint.opacity(0.85))
                        .frame(width: max(4, proxy.size.width * level))
                }
            }
    }
}
