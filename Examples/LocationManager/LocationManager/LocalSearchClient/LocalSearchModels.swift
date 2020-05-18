import MapKit

struct LocalSearchResponse: Equatable {
  var boundingRegion: MKCoordinateRegion
  var mapItems: [MapItem]

  init(
    response: MKLocalSearch.Response
  ) {
    self.boundingRegion = response.boundingRegion
    self.mapItems = response.mapItems.map(MapItem.init(rawValue:))
  }

  init(
    boundingRegion: MKCoordinateRegion,
    mapItems: [MapItem]
  ) {
    self.boundingRegion = boundingRegion
    self.mapItems = mapItems
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.boundingRegion.center.latitude == rhs.boundingRegion.center.latitude
      && lhs.boundingRegion.center.longitude == rhs.boundingRegion.center.longitude
      && lhs.boundingRegion.span.latitudeDelta == rhs.boundingRegion.span.latitudeDelta
      && lhs.boundingRegion.span.longitudeDelta == rhs.boundingRegion.span.longitudeDelta
      && lhs.mapItems == rhs.mapItems
  }
}

struct MapItem: Equatable {
  var isCurrentLocation: Bool
  var name: String?
  var phoneNumber: String?
  var placemark: Placemark
  var pointOfInterestCategory: MKPointOfInterestCategory?
  var timeZone: TimeZone?
  var url: URL?

  init(rawValue: MKMapItem) {
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
    self.isCurrentLocation = isCurrentLocation
    self.name = name
    self.phoneNumber = phoneNumber
    self.placemark = placemark
    self.pointOfInterestCategory = pointOfInterestCategory
    self.timeZone = timeZone
    self.url = url
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
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
        == lhs.placemark.subAdministrativeArea
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

struct Placemark: Equatable {
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
    lhs.administrativeArea == lhs.administrativeArea
      && lhs.areasOfInterest == lhs.areasOfInterest
      && lhs.coordinate.latitude == rhs.coordinate.latitude
      && lhs.coordinate.longitude == rhs.coordinate.longitude
      && lhs.country == lhs.country
      && lhs.countryCode == rhs.countryCode
      && lhs.inlandWater == lhs.inlandWater
      && lhs.isoCountryCode == lhs.isoCountryCode
      && lhs.locality == lhs.locality
      && lhs.name == rhs.name
      && lhs.ocean == lhs.ocean
      && lhs.postalCode == lhs.postalCode
      && lhs.region == rhs.region
      && lhs.subAdministrativeArea == lhs.subAdministrativeArea
      && lhs.subLocality == lhs.subLocality
      && lhs.subThoroughfare == lhs.subThoroughfare
      && lhs.subtitle == rhs.subtitle
      && lhs.thoroughfare == lhs.thoroughfare
      && lhs.title == rhs.title
  }
}
