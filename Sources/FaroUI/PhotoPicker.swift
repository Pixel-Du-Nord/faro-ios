#if canImport(UIKit) && os(iOS)
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/**
 "Add photos": the system photo picker, which runs out of process and needs no
 photo-library permission (the person only shares what they pick).
 `PhotosPicker` on iOS 16+, `PHPickerViewController` on iOS 15.
 */
struct PhotoPickerButton: View {
    let limit: Int
    let label: String
    let onPick: ([Data]) -> Void

    var body: some View {
        if #available(iOS 16.0, *) {
            ModernPicker(limit: limit, label: label, onPick: onPick)
        } else {
            LegacyPicker(limit: limit, label: label, onPick: onPick)
        }
    }
}

/// The tile both pickers show.
private struct AddTile: View {
    let label: String

    @Environment(\.faroStyle) private var style

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title3)
            Text(label)
                .font(style.font(.caption2, .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(style.accentInk)
        .padding(6)
        .frame(width: 78, height: 78)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .foregroundStyle(style.accent.opacity(0.6))
        )
        .contentShape(Rectangle())
    }
}

@available(iOS 16.0, *)
private struct ModernPicker: View {
    let limit: Int
    let label: String
    let onPick: ([Data]) -> Void

    @State private var items: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(selection: $items, maxSelectionCount: limit, matching: .images) {
            AddTile(label: label)
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier("faro.photos.add")
        .onChange(of: items) { picked in
            guard !picked.isEmpty else { return }
            items = []
            Task {
                var data: [Data] = []
                for item in picked {
                    if let bytes = try? await item.loadTransferable(type: Data.self) { data.append(bytes) }
                }
                onPick(data)
            }
        }
    }
}

private struct LegacyPicker: View {
    let limit: Int
    let label: String
    let onPick: ([Data]) -> Void

    @State private var showing = false

    var body: some View {
        Button { showing = true } label: { AddTile(label: label) }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(label)
            .accessibilityIdentifier("faro.photos.add")
            .sheet(isPresented: $showing) {
                SystemPhotoPicker(limit: limit) { data in
                    showing = false
                    onPick(data)
                }
                .ignoresSafeArea()
            }
    }
}

private struct SystemPhotoPicker: UIViewControllerRepresentable {
    let limit: Int
    let onDone: ([Data]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = limit
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onDone: ([Data]) -> Void

        init(onDone: @escaping ([Data]) -> Void) { self.onDone = onDone }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let providers = results.map(\.itemProvider)
            let onDone = self.onDone
            Task { @MainActor in
                var data: [Data] = []
                for provider in providers {
                    if let bytes = await Self.load(provider) { data.append(bytes) }
                }
                onDone(data)
            }
        }

        private static func load(_ provider: NSItemProvider) async -> Data? {
            await withCheckedContinuation { continuation in
                guard provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) else {
                    continuation.resume(returning: nil)
                    return
                }
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
#endif
