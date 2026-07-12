import MapKit
import PhotosUI
import SwiftUI

struct PlaceDetailView: View {
    @ObservedObject var store: TimelineStore
    let visitID: UUID
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    private var visit: TimelineVisit? {
        store.sortedVisits.first { $0.id == visitID }
    }

    var body: some View {
        Group {
            if let visit {
                Form {
                    Section {
                        Map {
                            Marker(visit.title, coordinate: visit.coordinate)
                        }
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Section("Place") {
                        TextField("Name", text: titleBinding)
                        if let address = visit.address, !address.isEmpty {
                            Text(address)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent("Arrived") {
                            Text(visit.arrivalDate, format: .dateTime.weekday().month().day().hour().minute())
                        }
                        if let departureDate = visit.departureDate {
                            LabeledContent("Last Seen") {
                                Text(departureDate, format: .dateTime.weekday().month().day().hour().minute())
                            }
                        }
                    }

                    Section("Notes") {
                        TextEditor(text: noteBinding)
                            .frame(minHeight: 130)
                    }

                    Section("Photos") {
                        if visit.photoFilenames.isEmpty {
                            ContentUnavailableView("No Photos", systemImage: "photo", description: Text("Attach up to four photos for this place."))
                                .frame(maxWidth: .infinity)
                        } else {
                            PhotoGrid(store: store, filenames: visit.photoFilenames)
                        }

                        PhotosPicker(
                            selection: $selectedPhotoItems,
                            maxSelectionCount: max(0, 4 - visit.photoFilenames.count),
                            matching: .images
                        ) {
                            Label("Add Photos", systemImage: "photo.badge.plus")
                        }
                        .disabled(visit.photoFilenames.count >= 4)
                    }
                }
                .navigationTitle(visit.title)
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: selectedPhotoItems) { _, newItems in
                    Task {
                        await attachPhotos(newItems)
                    }
                }
            } else {
                ContentUnavailableView("Visit Not Found", systemImage: "mappin.slash")
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding {
            visit?.title ?? ""
        } set: { newValue in
            store.updateTitle(newValue, for: visitID)
        }
    }

    private var noteBinding: Binding<String> {
        Binding {
            visit?.note ?? ""
        } set: { newValue in
            store.updateNote(newValue, for: visitID)
        }
    }

    private func attachPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                continue
            }
            await MainActor.run {
                store.attachPhotoData(data, to: visitID)
            }
        }
        await MainActor.run {
            selectedPhotoItems = []
        }
    }
}

private struct PhotoGrid: View {
    @ObservedObject var store: TimelineStore
    let filenames: [String]

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(filenames, id: \.self) { filename in
                if let image = store.image(named: filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .clipped()
                }
            }
        }
    }
}
