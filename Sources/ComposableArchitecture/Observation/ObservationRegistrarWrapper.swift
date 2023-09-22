// NB: A wrapper around `Observation.ObservationRegistrar` for availability.
struct ObservationRegistrarWrapper: Sendable {
  private let _rawValue: AnySendable

  init() {
    if #available(iOS 17, tvOS 17, watchOS 10, macOS 14, *) {
      self._rawValue = AnySendable(ObservationRegistrar())
    } else {
      self._rawValue = AnySendable(())
    }
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  init(rawValue: ObservationRegistrar) {
    self._rawValue = AnySendable(rawValue)
  }

  @available(iOS, introduced: 17)
  @available(macOS, introduced: 14)
  @available(tvOS, introduced: 17)
  @available(watchOS, introduced: 10)
  var rawValue: ObservationRegistrar {
    self._rawValue.base as! ObservationRegistrar
  }
}
