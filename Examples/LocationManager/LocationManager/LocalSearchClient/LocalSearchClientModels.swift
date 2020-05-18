import MapKit

public struct LocalSearchResponse: Equatable {
  public var mapItems: [MapItem]
  public var boundingRegion: MKCoordinateRegion

  public init(
    mapItems: [MapItem],
    boundingRegion: MKCoordinateRegion
  ) {
    self.mapItems = mapItems
    self.boundingRegion = boundingRegion
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.mapItems == rhs.mapItems
      && lhs.boundingRegion.center.latitude == rhs.boundingRegion.center.latitude
      && lhs.boundingRegion.center.longitude == rhs.boundingRegion.center.longitude
      && lhs.boundingRegion.span.latitudeDelta == rhs.boundingRegion.span.latitudeDelta
      && lhs.boundingRegion.span.longitudeDelta == rhs.boundingRegion.span.longitudeDelta
  }
}

public struct Placemark: Equatable {
  public let rawValue: MKPlacemark?

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

  init(rawValue: MKPlacemark) {
    self.rawValue = rawValue

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
    self.subtitle = rawValue.responds(to: #selector(getter: MKPlacemark.subtitle)) ? rawValue.subtitle : nil
    self.thoroughfare = rawValue.thoroughfare
    self.title = rawValue.responds(to: #selector(getter: MKPlacemark.title)) ? rawValue.title : nil
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
    self.rawValue = nil

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

  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.coordinate.latitude == rhs.coordinate.latitude
      && lhs.coordinate.longitude == rhs.coordinate.longitude
      && lhs.countryCode == rhs.countryCode
      && lhs.region == rhs.region
      && lhs.subtitle == rhs.subtitle
      && lhs.title == rhs.title
      && lhs.name == rhs.name
      && lhs.thoroughfare == lhs.thoroughfare
      && lhs.subThoroughfare == lhs.subThoroughfare
      && lhs.locality == lhs.locality
      && lhs.subLocality == lhs.subLocality
      && lhs.administrativeArea == lhs.administrativeArea
      && lhs.subAdministrativeArea == lhs.subAdministrativeArea
      && lhs.postalCode == lhs.postalCode
      && lhs.isoCountryCode == lhs.isoCountryCode
      && lhs.country == lhs.country
      && lhs.inlandWater == lhs.inlandWater
      && lhs.ocean == lhs.ocean
      && lhs.areasOfInterest == lhs.areasOfInterest
  }
}

public struct MapItem: Equatable {
  public let rawValue: MKMapItem?

  public var isCurrentLocation: Bool
  public var name: String?
  public var phoneNumber: String?
  public var placemark: Placemark
  public var pointOfInterestCategory: MKPointOfInterestCategory?
  public var timeZone: TimeZone?
  public var url: URL?

  public init(rawValue: MKMapItem) {
    self.rawValue = rawValue

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
    self.rawValue = nil

    self.isCurrentLocation = isCurrentLocation
    self.name = name
    self.phoneNumber = phoneNumber
    self.placemark = placemark
    self.pointOfInterestCategory = pointOfInterestCategory
    self.timeZone = timeZone
    self.url = url
  }

  public static func ==(lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue?.isCurrentLocation == rhs.rawValue?.isCurrentLocation
      && lhs.rawValue?.name == rhs.rawValue?.name
      && lhs.rawValue?.phoneNumber == rhs.rawValue?.phoneNumber
      && lhs.rawValue?.placemark.coordinate.latitude == rhs.rawValue?.placemark.coordinate.latitude
      && lhs.rawValue?.placemark.coordinate.longitude == rhs.rawValue?.placemark.coordinate.longitude
      && lhs.rawValue?.placemark.countryCode == rhs.rawValue?.placemark.countryCode
      && lhs.rawValue?.placemark.region == rhs.rawValue?.placemark.region
      && lhs.placemark.subtitle == rhs.placemark.subtitle
      && lhs.rawValue?.placemark.title == rhs.rawValue?.placemark.title
      && lhs.rawValue?.placemark.name == rhs.rawValue?.placemark.name
      && lhs.rawValue?.placemark.thoroughfare == lhs.rawValue?.placemark.thoroughfare
      && lhs.rawValue?.placemark.subThoroughfare == lhs.rawValue?.placemark.subThoroughfare
      && lhs.rawValue?.placemark.locality == lhs.rawValue?.placemark.locality
      && lhs.rawValue?.placemark.subLocality == lhs.rawValue?.placemark.subLocality
      && lhs.rawValue?.placemark.administrativeArea == lhs.rawValue?.placemark.administrativeArea
      && lhs.rawValue?.placemark.subAdministrativeArea == lhs.rawValue?.placemark.subAdministrativeArea
      && lhs.rawValue?.placemark.postalCode == lhs.rawValue?.placemark.postalCode
      && lhs.rawValue?.placemark.isoCountryCode == lhs.rawValue?.placemark.isoCountryCode
      && lhs.rawValue?.placemark.country == lhs.rawValue?.placemark.country
      && lhs.rawValue?.placemark.inlandWater == lhs.rawValue?.placemark.inlandWater
      && lhs.rawValue?.placemark.ocean == lhs.rawValue?.placemark.ocean
      && lhs.rawValue?.placemark.areasOfInterest == lhs.rawValue?.placemark.areasOfInterest
      && lhs.rawValue?.pointOfInterestCategory == rhs.rawValue?.pointOfInterestCategory
      && lhs.rawValue?.timeZone == rhs.rawValue?.timeZone
      && lhs.rawValue?.url == rhs.rawValue?.url
  }
}

public struct LocalSearchError: Error, Equatable {
  public init() {}
}
