import ComposableArchitecture
import MapKit

public struct LocalSearchClient {
  public var search: (MKLocalSearch.Request) -> Effect<LocalSearchResponse, LocalSearchError>
}
