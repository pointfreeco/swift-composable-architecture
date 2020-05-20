import MapKit

public struct LocalSearchResponse: Equatable {
  public var boundingRegion: MKCoordinateRegion
  public var mapItems: [MapItem]

  public init(
    response: MKLocalSearch.Response
  ) {
    self.boundingRegion = response.boundingRegion
    self.mapItems = response.mapItems.map(MapItem.init(rawValue:))
  }

  public init(
    boundingRegion: MKCoordinateRegion,
    mapItems: [MapItem]
  ) {
    self.boundingRegion = boundingRegion
    self.mapItems = mapItems
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.boundingRegion.center.latitude == rhs.boundingRegion.center.latitude
      && lhs.boundingRegion.center.longitude == rhs.boundingRegion.center.longitude
      && lhs.boundingRegion.span.latitudeDelta == rhs.boundingRegion.span.latitudeDelta
      && lhs.boundingRegion.span.longitudeDelta == rhs.boundingRegion.span.longitudeDelta
      && lhs.mapItems == rhs.mapItems
  }
}

public struct MapItem: Equatable {
  public var isCurrentLocation: Bool
  public var name: String?
  public var phoneNumber: String?
  public var placemark: Placemark
  public var pointOfInterestCategory: MKPointOfInterestCategory?
  public var timeZone: TimeZone?
  public var url: URL?

  public init(rawValue: MKMapItem) {
    self.isCurrentLocation = rawValue.isCurrentLocation
    self.name = rawValue.name
    self.placemark = Placemark(rawValue: rawValue.placemark)
    self.phoneNumber = rawValue.phoneNumber
    self.pointOfInterestCategory = rawValue.pointOfInterestCategory
    self.timeZone = rawValue.timeZone
    self.url = rawValue.url
  }

  public init(
    isCurrentLocation: Bool = false,
    name: String? = nil,
    phoneNumber: String? = nil,
    placemark: Placemark,
    pointOfInterestCategory: MKPointOfInterestCategory? = nil,
    timeZone: TimeZone? = nil,
    url: URL? = nil
  ) {
    self.isCurrentLocation = isCurrentLocation
    self.name = name
    self.phoneNumber = phoneNumber
    self.placemark = placemark
    self.pointOfInterestCategory = pointOfInterestCategory
    self.timeZone = timeZone
    self.url = url
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.isCurrentLocation == rhs.isCurrentLocation
      && lhs.name == rhs.name
      && lhs.phoneNumber == rhs.phoneNumber
      && lhs.placemark.coordinate.latitude == rhs.placemark.coordinate.latitude
      && lhs.placemark.coordinate.longitude
        == rhs.placemark.coordinate.longitude
      && lhs.placemark.countryCode == rhs.placemark.countryCode
      && lhs.placemark.region == rhs.placemark.region
      && lhs.placemark.subtitle == rhs.placemark.subtitle
      && lhs.placemark.title == rhs.placemark.title
      && lhs.placemark.name == rhs.placemark.name
      && lhs.placemark.thoroughfare == rhs.placemark.thoroughfare
      && lhs.placemark.subThoroughfare == rhs.placemark.subThoroughfare
      && lhs.placemark.locality == rhs.placemark.locality
      && lhs.placemark.subLocality == rhs.placemark.subLocality
      && lhs.placemark.administrativeArea == rhs.placemark.administrativeArea
      && lhs.placemark.subAdministrativeArea
        == rhs.placemark.subAdministrativeArea
      && lhs.placemark.postalCode == rhs.placemark.postalCode
      && lhs.placemark.isoCountryCode == rhs.placemark.isoCountryCode
      && lhs.placemark.country == rhs.placemark.country
      && lhs.placemark.inlandWater == rhs.placemark.inlandWater
      && lhs.placemark.ocean == rhs.placemark.ocean
      && lhs.placemark.areasOfInterest == rhs.placemark.areasOfInterest
      && lhs.pointOfInterestCategory == rhs.pointOfInterestCategory
      && lhs.timeZone == rhs.timeZone
      && lhs.url == rhs.url
  }
}

public struct Placemark: Equatable {
  public var administrativeArea: String?
  public var areasOfInterest: [String]?
  public var coordinate: CLLocationCoordinate2D
  public var country: String?
  public var countryCode: String?
  public var inlandWater: String?
  public var isoCountryCode: String?
  public var locality: String?
  public var name: String?
  public var ocean: String?
  public var postalCode: String?
  public var region: CLRegion?
  public var subAdministrativeArea: String?
  public var subLocality: String?
  public var subThoroughfare: String?
  public var subtitle: String?
  public var thoroughfare: String?
  public var title: String?

  public init(rawValue: MKPlacemark) {
    self.administrativeArea = rawValue.administrativeArea
    self.areasOfInterest = rawValue.areasOfInterest
    self.coordinate = rawValue.coordinate
    self.country = rawValue.country
    self.countryCode = rawValue.countryCode
    self.inlandWater = rawValue.inlandWater
    self.isoCountryCode = rawValue.isoCountryCode
    self.locality = rawValue.locality
    self.name = rawValue.name
    self.ocean = rawValue.ocean
    self.postalCode = rawValue.postalCode
    self.region = rawValue.region
    self.subAdministrativeArea = rawValue.subAdministrativeArea
    self.subLocality = rawValue.subLocality
    self.subThoroughfare = rawValue.subThoroughfare
    self.subtitle =
      rawValue.responds(to: #selector(getter:MKPlacemark.subtitle)) ? rawValue.subtitle : nil
    self.thoroughfare = rawValue.thoroughfare
    self.title = rawValue.responds(to: #selector(getter:MKPlacemark.title)) ? rawValue.title : nil
  }

  public init(
    administrativeArea: String? = nil,
    areasOfInterest: [String]? = nil,
    coordinate: CLLocationCoordinate2D = .init(),
    country: String? = nil,
    countryCode: String? = nil,
    inlandWater: String? = nil,
    isoCountryCode: String? = nil,
    locality: String? = nil,
    name: String? = nil,
    ocean: String? = nil,
    postalCode: String? = nil,
    region: CLRegion? = nil,
    subAdministrativeArea: String? = nil,
    subLocality: String? = nil,
    subThoroughfare: String? = nil,
    subtitle: String? = nil,
    thoroughfare: String? = nil,
    title: String? = nil
  ) {
    self.administrativeArea = administrativeArea
    self.areasOfInterest = areasOfInterest
    self.coordinate = coordinate
    self.country = country
    self.countryCode = countryCode
    self.inlandWater = inlandWater
    self.isoCountryCode = isoCountryCode
    self.locality = locality
    self.name = name
    self.ocean = ocean
    self.postalCode = postalCode
    self.region = region
    self.subAdministrativeArea = subAdministrativeArea
    self.subLocality = subLocality
    self.subThoroughfare = subThoroughfare
    self.subtitle = subtitle
    self.thoroughfare = thoroughfare
    self.title = title
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.administrativeArea == rhs.administrativeArea
      && lhs.areasOfInterest == rhs.areasOfInterest
      && lhs.coordinate.latitude == rhs.coordinate.latitude
      && lhs.coordinate.longitude == rhs.coordinate.longitude
      && lhs.country == rhs.country
      && lhs.countryCode == rhs.countryCode
      && lhs.inlandWater == rhs.inlandWater
      && lhs.isoCountryCode == rhs.isoCountryCode
      && lhs.locality == rhs.locality
      && lhs.name == rhs.name
      && lhs.ocean == rhs.ocean
      && lhs.postalCode == rhs.postalCode
      && lhs.region == rhs.region
      && lhs.subAdministrativeArea == rhs.subAdministrativeArea
      && lhs.subLocality == rhs.subLocality
      && lhs.subThoroughfare == rhs.subThoroughfare
      && lhs.subtitle == rhs.subtitle
      && lhs.thoroughfare == rhs.thoroughfare
      && lhs.title == rhs.title
  }
}

public struct CoordinateRegion: Equatable {
  public var center: CLLocationCoordinate2D
  public var span: MKCoordinateSpan

  public init(
    center: CLLocationCoordinate2D,
    span: MKCoordinateSpan
  ) {
    self.center = center
    self.span = span
  }

  public init(coordinateRegion: MKCoordinateRegion) {
    self.center = coordinateRegion.center
    self.span = coordinateRegion.span
  }

  public var asMKCoordinateRegion: MKCoordinateRegion {
    .init(center: self.center, span: self.span)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.center.latitude == rhs.center.latitude
      && lhs.center.longitude == rhs.center.longitude
      && lhs.span.latitudeDelta == rhs.span.latitudeDelta
      && lhs.span.longitudeDelta == rhs.span.longitudeDelta
  }
}
