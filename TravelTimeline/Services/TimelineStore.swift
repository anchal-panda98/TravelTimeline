import CoreLocation
import Foundation
import UIKit

@MainActor
final class TimelineStore: ObservableObject {
    @Published private(set) var visits: [TimelineVisit] = []
    @Published private(set) var activeVisitID: UUID?
    @Published var lastErrorMessage: String?

    private let visitRadiusMeters: CLLocationDistance = 150
    private let maxHorizontalAccuracyMeters: CLLocationAccuracy = 250
    private let maxPhotosPerVisit = 4
    private let geocoder = CLGeocoder()

    private var archiveURL: URL {
        documentsDirectory.appendingPathComponent("timeline.json")
    }

    private var photosDirectory: URL {
        documentsDirectory.appendingPathComponent("TimelinePhotos", isDirectory: true)
    }

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() {
        load()
    }

    var sortedVisits: [TimelineVisit] {
        visits.sorted { $0.arrivalDate > $1.arrivalDate }
    }

    func record(location: CLLocation) async {
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= maxHorizontalAccuracyMeters else {
            return
        }

        let timestamp = location.timestamp
        if let activeIndex = activeVisitIndex(),
           visits[activeIndex].location.distance(from: location) <= visitRadiusMeters {
            visits[activeIndex].departureDate = timestamp
            persist()
            return
        }

        if let latest = visits.max(by: { $0.arrivalDate < $1.arrivalDate }),
           latest.location.distance(from: location) <= visitRadiusMeters,
           let latestIndex = visits.firstIndex(where: { $0.id == latest.id }) {
            activeVisitID = latest.id
            visits[latestIndex].departureDate = timestamp
            persist()
            return
        }

        let address = await reverseGeocode(location)
        let title = address?.firstLine.isEmpty == false ? address?.firstLine ?? "Visited Place" : "Visited Place"
        let visit = TimelineVisit(
            title: title,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            arrivalDate: timestamp,
            address: address?.fullAddress
        )
        activeVisitID = visit.id
        visits.append(visit)
        persist()
    }

    func updateTitle(_ title: String, for id: UUID) {
        mutateVisit(id) { visit in
            visit.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Visited Place" : title
        }
    }

    func updateNote(_ note: String, for id: UUID) {
        mutateVisit(id) { visit in
            visit.note = note
        }
    }

    func attachPhotoData(_ data: Data, to id: UUID) {
        guard let index = visits.firstIndex(where: { $0.id == id }) else {
            return
        }

        guard visits[index].photoFilenames.count < maxPhotosPerVisit else {
            lastErrorMessage = "Each place can keep up to four photos."
            return
        }

        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
            let filename = "\(id.uuidString)-\(UUID().uuidString).image"
            let photoURL = photosDirectory.appendingPathComponent(filename)
            try data.write(to: photoURL, options: [.atomic])
            visits[index].photoFilenames.append(filename)
            persist()
        } catch {
            lastErrorMessage = "Could not save the photo: \(error.localizedDescription)"
        }
    }

    func image(named filename: String) -> UIImage? {
        let url = photosDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return UIImage(data: data)
    }

    func deleteVisit(_ visit: TimelineVisit) {
        visits.removeAll { $0.id == visit.id }
        if activeVisitID == visit.id {
            activeVisitID = nil
        }
        for filename in visit.photoFilenames {
            try? FileManager.default.removeItem(at: photosDirectory.appendingPathComponent(filename))
        }
        persist()
    }

    func load() {
        guard FileManager.default.fileExists(atPath: archiveURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: archiveURL)
            let archive = try JSONDecoder.timeline.decode(TimelineArchive.self, from: data)
            visits = archive.visits
            activeVisitID = archive.activeVisitID
        } catch {
            lastErrorMessage = "Could not load saved timeline: \(error.localizedDescription)"
        }
    }

    private func persist() {
        do {
            let archive = TimelineArchive(visits: visits, activeVisitID: activeVisitID)
            let data = try JSONEncoder.timeline.encode(archive)
            try data.write(to: archiveURL, options: [.atomic])
        } catch {
            lastErrorMessage = "Could not save timeline: \(error.localizedDescription)"
        }
    }

    private func activeVisitIndex() -> Int? {
        guard let activeVisitID else {
            return nil
        }
        return visits.firstIndex { $0.id == activeVisitID }
    }

    private func mutateVisit(_ id: UUID, change: (inout TimelineVisit) -> Void) {
        guard let index = visits.firstIndex(where: { $0.id == id }) else {
            return
        }
        change(&visits[index])
        persist()
    }

    private func reverseGeocode(_ location: CLLocation) async -> VisitAddress? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else {
                return nil
            }
            return VisitAddress(placemark: placemark)
        } catch {
            return nil
        }
    }
}

private extension JSONEncoder {
    static var timeline: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var timeline: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct VisitAddress {
    let firstLine: String
    let fullAddress: String

    init(placemark: CLPlacemark) {
        let name = placemark.name
        let locality = placemark.locality
        let area = placemark.administrativeArea
        let country = placemark.country

        firstLine = [name, locality]
            .compactMap { $0 }
            .removingDuplicates()
            .joined(separator: ", ")

        fullAddress = [
            name,
            placemark.thoroughfare,
            locality,
            area,
            placemark.postalCode,
            country
        ]
        .compactMap { $0 }
        .removingDuplicates()
        .joined(separator: ", ")
    }
}

private extension Array where Element == String {
    func removingDuplicates() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0).inserted }
    }
}
