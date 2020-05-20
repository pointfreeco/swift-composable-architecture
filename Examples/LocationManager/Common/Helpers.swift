import MapKit

public struct AppAlert: Identifiable {
  public var title: String

  public init(title: String) {
    self.title = title
  }

  public var id: String { self.title }
}

extension MKPointOfInterestCategory {
  public var displayName: String {
    switch self {
    case .cafe:
      return "Cafe"
    case .museum:
      return "Museum"
    case .nightlife:
      return "Nightlife"
    case .park:
      return "Park"
    case .restaurant:
      return "Restaurant"
    default:
      return "N/A"
    }
  }
}
