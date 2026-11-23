import SwiftUI

/// Everything recorded before, newest first, with search. A click opens the transcript and the notes.
struct PastRecordings: View {
    @Environment(Library.self) private var library
    @Environment(NoteEnhancer.self) private var enhancer
    @Environment(VoiceRecorder.self) private var recorder
    @Environment(\.present) private var present
    @AppStorage(Preference.persona) private var persona = Persona.student
    @State private var query = ""
    @State private var renaming: Recording?
    @State private var newTitle = ""
    @State private var deleting: Recording?
    @State private var merging: [Recording] = []
    @State private var mergeError: String?

    private var visible: [Recording] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        return library.recordings
            .filter { $0.stage != .recording }
            .filter { recording in
                needle.isEmpty
                    || recording.title.localizedStandardContains(needle)
                    || recording.transcript.localizedStandardContains(needle)
                    || (recording.notes?.text.localizedStandardContains(needle) ?? false)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var hasAny: Bool {
        library.recordings.contains { $0.stage != .recording }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Past \(persona.recordingsTitle.lowercased())")
                    .font(.system(size: 20, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(Palette.ink)
                Spacer()
            }

            if hasAny {
                search
                if visible.isEmpty {
                    Text("Nothing matches “\(query)”.")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                }
                VStack(spacing: 8) {
                    ForEach(visible) { recording in
                        row(recording)
                    }
                }
            } else {
                Text(persona.recordingsEmptyMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            }
        }
        .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $newTitle)
            Button("Cancel", role: .cancel) { renaming = nil }
            Button("Rename") {
                let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if var recording = renaming, !title.isEmpty {
                    recording.title = title
                    recording.isNamed = true
                    library.save(recording)
                }
                renaming = nil
            }
        }
        .confirmationDialog(
            "Merge these recordings?",
            isPresented: Binding(get: { !merging.isEmpty }, set: { if !$0 { merging = [] } })
        ) {
            Button("Merge") {
                merge(merging)
                merging = []
            }
        } message: {
            Text("“\(merging.sorted { $0.createdAt < $1.createdAt }.map(\.title).joined(separator: "” and “"))” become one recording, in the order they were recorded. Audio, transcripts, notes and flashcards are joined.")
        }
        .alert("Could not merge", isPresented: Binding(get: { mergeError != nil }, set: { if !$0 { mergeError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mergeError ?? "")
        }
        .confirmationDialog(
            "Delete “\(deleting?.title ?? "")”?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
        ) {
            Button("Delete", role: .destructive) {
                if let deleting { library.delete(deleting) }
                deleting = nil
            }
        } message: {
            Text("The audio, the transcript and the notes will be removed from this Mac. This cannot be undone.")
        }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkSecondary)
            TextField("Search titles, transcripts and notes", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Palette.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Palette.surface, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    private func row(_ recording: Recording) -> some View {
        Button {
            present(.recording(recording))
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(recording.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                    Text(metadata(recording))
                        .font(.system(size: 12.5).monospacedDigit())
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                status(recording)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Palette.surface, in: .rect(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .contextMenu { actions(for: recording) }
    }

    private func metadata(_ recording: Recording) -> String {
        let length = recording.duration < 60 ? "\(Int(recording.duration.rounded())) s" : recording.duration.compactDuration
        return [recording.createdAt.formatted(date: .abbreviated, time: .shortened), length].joined(separator: " · ")
    }

    @ViewBuilder
    private func status(_ recording: Recording) -> some View {
        switch enhancer.phase(of: recording) {
        case .transcribing:
            Text("Transcribing").font(.system(size: 12)).foregroundStyle(Palette.inkSecondary)
        case .writing:
            Text(enhancer.progress(of: recording).map { "Writing notes · \($0)%" } ?? "Writing notes")
                .font(.system(size: 12).monospacedDigit()).foregroundStyle(Palette.inkSecondary)
        case nil:
            if recording.wasInterrupted == true {
                Text("Recovered").font(.system(size: 12)).foregroundStyle(Palette.inkSecondary)
            } else if recording.notes != nil {
                Text("Notes ready").font(.system(size: 12)).foregroundStyle(Palette.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private func actions(for recording: Recording) -> some View {
        Button("Open", systemImage: "arrow.up.forward.app") { present(.recording(recording)) }
        Button("Rename…", systemImage: "pencil") {
            newTitle = recording.title
            renaming = recording
        }
        Menu("Merge with", systemImage: "arrow.triangle.merge") {
            ForEach(mergeCandidates(for: recording)) { other in
                Button("\(other.title) · \(other.createdAt.formatted(date: .abbreviated, time: .shortened))") {
                    merging = [recording, other]
                }
            }
        }
        .disabled(mergeCandidates(for: recording).isEmpty || enhancer.isWorking(on: recording))
        Divider()
        Button("Export as PDF…", systemImage: "arrow.down.doc") {
            NotesPDF.export(recording, goal: library.goal(recording.goalID), original: false)
        }
        Button("Copy Transcript", systemImage: "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(recording.notes?.text ?? recording.transcript, forType: .string)
        }
        Button("Write Notes Again", systemImage: "arrow.clockwise") { transcribeAgain(recording) }
            .disabled(enhancer.isWorking(on: recording) || recorder.isActive)
        Button("Show Audio in Finder", systemImage: "folder.badge.gearshape") {
            NSWorkspace.shared.activateFileViewerSelecting([library.audioURL(for: recording)])
        }
        Divider()
        Button("Delete…", systemImage: "trash", role: .destructive) { deleting = recording }
    }

    private func mergeCandidates(for recording: Recording) -> [Recording] {
        library.recordings
            .filter { $0.id != recording.id && $0.stage != .recording && !enhancer.isWorking(on: $0) }
            .filter { abs($0.createdAt.timeIntervalSince(recording.createdAt)) < 3 * 86_400 }
            .sorted { abs($0.createdAt.timeIntervalSince(recording.createdAt)) < abs($1.createdAt.timeIntervalSince(recording.createdAt)) }
            .prefix(8)
            .map { $0 }
    }

    private func merge(_ recordings: [Recording]) {
        Task {
            do {
                let merged = try await RecordingMerger.merge(recordings, in: library)
                if merged.notes == nil {
                    enhancer.enhance(merged, for: persona)
                }
            } catch {
                mergeError = error.localizedDescription
            }
        }
    }

    private func transcribeAgain(_ recording: Recording) {
        var refreshed = recording
        refreshed.stage = .refining
        library.save(refreshed)
        enhancer.enhance(refreshed, for: persona)
    }
}
