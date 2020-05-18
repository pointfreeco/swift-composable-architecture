import MapKit

struct LocalSearchResponse: Equatable {
  var mapItems: [MapItem]
  var boundingRegion: MKCoordinateRegion

  init(
    mapItems: [MapItem],
    boundingRegion: MKCoordinateRegion
  ) {
    self.mapItems = mapItems
    self.boundingRegion = boundingRegion
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.mapItems == rhs.mapItems
      && lhs.boundingRegion.center.latitude == rhs.boundingRegion.center.latitude
      && lhs.boundingRegion.center.longitude == rhs.boundingRegion.center.longitude
      && lhs.boundingRegion.span.latitudeDelta == rhs.boundingRegion.span.latitudeDelta
      && lhs.boundingRegion.span.longitudeDelta == rhs.boundingRegion.span.longitudeDelta
  }
}

struct Placemark: Equatable {
  let rawValue: MKPlacemark?

  var administrativeArea: String?
  var areasOfInterest: [String]?
  var coordinate: CLLocationCoordinate2D
  var country: String?
  var countryCode: String?
  var inlandWater: String?
  var isoCountryCode: String?
  var locality: String?
  var name: String?
  var ocean: String?
  var postalCode: String?
  var region: CLRegion?
  var subAdministrativeArea: String?
  var subLocality: String?
  var subThoroughfare: String?
  var subtitle: String?
  var thoroughfare: String?
  var title: String?

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
    self.subtitle =
      rawValue.responds(to: #selector(getter:MKPlacemark.subtitle)) ? rawValue.subtitle : nil
    self.thoroughfare = rawValue.thoroughfare
    self.title = rawValue.responds(to: #selector(getter:MKPlacemark.title)) ? rawValue.title : nil
  }

  init(
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

  static func == (lhs: Self, rhs: Self) -> Bool {
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

struct MapItem: Equatable {
  let rawValue: MKMapItem?

  var isCurrentLocation: Bool
  var name: String?
  var phoneNumber: String?
  var placemark: Placemark
  var pointOfInterestCategory: MKPointOfInterestCategory?
  var timeZone: TimeZone?
  var url: URL?

  init(rawValue: MKMapItem) {
    self.rawValue = rawValue

    self.isCurrentLocation = rawValue.isCurrentLocation
    self.name = rawValue.name
    self.placemark = Placemark(rawValue: rawValue.placemark)
    self.phoneNumber = rawValue.phoneNumber
    self.pointOfInterestCategory = rawValue.pointOfInterestCategory
    self.timeZone = rawValue.timeZone
    self.url = rawValue.url
  }

  init(
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

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue?.isCurrentLocation == rhs.rawValue?.isCurrentLocation
      && lhs.rawValue?.name == rhs.rawValue?.name
      && lhs.rawValue?.phoneNumber == rhs.rawValue?.phoneNumber
      && lhs.rawValue?.placemark.coordinate.latitude == rhs.rawValue?.placemark.coordinate.latitude
      && lhs.rawValue?.placemark.coordinate.longitude
        == rhs.rawValue?.placemark.coordinate.longitude
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
      && lhs.rawValue?.placemark.subAdministrativeArea
        == lhs.rawValue?.placemark.subAdministrativeArea
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
