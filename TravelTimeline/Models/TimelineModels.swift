import CoreLocation
import Foundation

struct TimelineVisit: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var note: String
    var latitude: Double
    var longitude: Double
    var arrivalDate: Date
    var departureDate: Date?
    var address: String?
    var photoFilenames: [String]

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        latitude: Double,
        longitude: Double,
        arrivalDate: Date = Date(),
        departureDate: Date? = nil,
        address: String? = nil,
        photoFilenames: [String] = []
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.arrivalDate = arrivalDate
        self.departureDate = departureDate
        self.address = address
        self.photoFilenames = photoFilenames
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    var durationText: String {
        guard let departureDate else {
            return "In progress"
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: arrivalDate, to: departureDate) ?? "Short visit"
    }
}

struct TimelineArchive: Codable {
    var visits: [TimelineVisit]
    var activeVisitID: UUID?
}
