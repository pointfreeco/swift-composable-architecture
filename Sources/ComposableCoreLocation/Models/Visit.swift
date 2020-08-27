import CoreLocation

/// A value type wrapper for `CLVisit`. This type is necessary so that we can do equality checks
/// and write tests against its values.
@available(iOS 8, macCatalyst 13, *)
@available(macOS, unavailable)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
public struct Visit: Hashable {
  public let rawValue: CLVisit?

  public var arrivalDate: Date
  public var coordinate: CLLocationCoordinate2D
  public var departureDate: Date
  public var horizontalAccuracy: CLLocationAccuracy

  init(visit: CLVisit) {
    self.rawValue = nil

    self.arrivalDate = visit.arrivalDate
    self.coordinate = visit.coordinate
    self.departureDate = visit.departureDate
    self.horizontalAccuracy = visit.horizontalAccuracy
  }

  public init(
    arrivalDate: Date,
    coordinate: CLLocationCoordinate2D,
    departureDate: Date,
    horizontalAccuracy: CLLocationAccuracy
  ) {
    self.rawValue = nil

    self.arrivalDate = arrivalDate
    self.coordinate = coordinate
    self.departureDate = departureDate
    self.horizontalAccuracy = horizontalAccuracy
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.arrivalDate == rhs.arrivalDate
      && lhs.coordinate.latitude == rhs.coordinate.latitude
      && lhs.coordinate.longitude == rhs.coordinate.longitude
      && lhs.departureDate == rhs.departureDate
      && lhs.horizontalAccuracy == rhs.horizontalAccuracy
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.arrivalDate)
    hasher.combine(self.coordinate.latitude)
    hasher.combine(self.coordinate.longitude)
    hasher.combine(self.departureDate)
    hasher.combine(self.horizontalAccuracy)
  }
}
