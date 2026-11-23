import SwiftUI

/// The whole app on one page: record at the top, everything you recorded before underneath.
struct HomeView: View {
    @Environment(Library.self) private var library
    @Environment(Updater.self) private var updater
    @Environment(\.openSettings) private var openSettings
    @State private var modal: Modal?

    var body: some View {
        @Bindable var updater = updater
        ScrollView {
            VStack(spacing: 32) {
                header
                Recorder()
                PastRecordings()
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 56)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.never)
        .background(Palette.canvas)
        .frame(minWidth: 560, minHeight: 600)
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
        .overlay(alignment: .topTrailing) {
            if updater.available != nil {
                Button("Update") { updater.presented = updater.pending }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.inkSecondary)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image("Logo")
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
            Text("Kumo")
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(Palette.ink)
        }
    }
}
