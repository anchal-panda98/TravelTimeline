import MapKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store: TimelineStore
    @StateObject private var tracker: LocationTracker
    @State private var mapPosition: MapCameraPosition = .automatic

    init() {
        let store = TimelineStore()
        _store = StateObject(wrappedValue: store)
        _tracker = StateObject(wrappedValue: LocationTracker(store: store))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                timelineMap
                    .frame(height: 280)
                    .overlay(alignment: .bottomTrailing) {
                        if tracker.isTracking {
                            Label("Tracking", systemImage: "location.fill")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                                .padding()
                        }
                    }

                trackingControls

                if store.sortedVisits.isEmpty {
                    ContentUnavailableView(
                        "No Visits Yet",
                        systemImage: "map",
                        description: Text("Start tracking and your timeline will appear here.")
                    )
                } else {
                    List {
                        Section("Places") {
                            ForEach(store.sortedVisits) { visit in
                                NavigationLink(value: visit.id) {
                                    VisitRow(visit: visit)
                                }
                            }
                            .onDelete(perform: deleteVisits)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Travel Timeline")
            .navigationDestination(for: UUID.self) { visitID in
                PlaceDetailView(store: store, visitID: visitID)
            }
            .alert("Timeline Notice", isPresented: errorIsPresented) {
                Button("OK", role: .cancel) {
                    store.lastErrorMessage = nil
                    tracker.lastErrorMessage = nil
                }
            } message: {
                Text(store.lastErrorMessage ?? tracker.lastErrorMessage ?? "")
            }
        }
    }

    private var timelineMap: some View {
        Map(position: $mapPosition) {
            ForEach(store.sortedVisits) { visit in
                Marker(visit.title, coordinate: visit.coordinate)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
    }

    private var trackingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tracker.authorizationSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    tracker.requestWhenInUsePermission()
                } label: {
                    Label("Allow", systemImage: "location")
                }
                .buttonStyle(.bordered)

                Button {
                    tracker.requestAlwaysPermission()
                } label: {
                    Label("Always", systemImage: "location.fill")
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                Button {
                    tracker.isTracking ? tracker.stopTracking() : tracker.startTracking()
                } label: {
                    Label(tracker.isTracking ? "Stop" : "Start", systemImage: tracker.isTracking ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var errorIsPresented: Binding<Bool> {
        Binding {
            store.lastErrorMessage != nil || tracker.lastErrorMessage != nil
        } set: { newValue in
            if !newValue {
                store.lastErrorMessage = nil
                tracker.lastErrorMessage = nil
            }
        }
    }

    private func deleteVisits(at offsets: IndexSet) {
        let visitsToDelete = offsets.map { store.sortedVisits[$0] }
        visitsToDelete.forEach(store.deleteVisit)
    }
}

private struct VisitRow: View {
    let visit: TimelineVisit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(visit.title)
                    .font(.headline)
                Spacer()
                Text(visit.arrivalDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let address = visit.address, !address.isEmpty {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label(visit.durationText, systemImage: "clock")
                Label("\(visit.photoFilenames.count)/4", systemImage: "photo")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
#Preview {
    ContentView()
}
