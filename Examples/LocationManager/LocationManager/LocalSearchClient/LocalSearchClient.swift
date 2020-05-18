import ComposableArchitecture
import MapKit

struct LocalSearchClient {
  var search: (MKLocalSearch.Request) -> Effect<LocalSearchResponse, Error>

  struct Error: Swift.Error, Equatable {
    init() {}
  }
}
