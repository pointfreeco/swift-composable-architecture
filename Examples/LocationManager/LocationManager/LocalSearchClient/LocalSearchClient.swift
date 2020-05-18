import ComposableArchitecture
import MapKit

struct LocalSearchClient {
  var search: (MKLocalSearch.Request) -> Effect<LocalSearchResponse, LocalSearchError>
}
