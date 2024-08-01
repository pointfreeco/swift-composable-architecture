#if canImport(SwiftUI)
  import SwiftUI
#endif

// NB: Deprecated with 1.13.0:

#if canImport(SwiftUI)
  extension Binding {
    @available(
      *, deprecated,
      message: "Use 'Binding.init(_:)' to project an optional binding to a Boolean, instead."
    )
    public func isPresent<Wrapped>() -> Binding<Bool>
    where Value == Wrapped? {
      Binding<Bool>(self)
    }
  }
#endif

// NB: Deprecated with 1.10.0:

@available(*, deprecated, message: "Use '.fileSystem' ('FileStorage.fileSystem') instead")
public func LiveFileStorage() -> FileStorage { .fileSystem }

@available(*, deprecated, message: "Use '.inMemory' ('FileStorage.inMemory') instead")
public func InMemoryFileStorage() -> FileStorage { .inMemory }

// NB: Deprecated with 1.0.0:

@available(*, unavailable, renamed: "Effect")
public typealias EffectTask = Effect

@available(*, unavailable, renamed: "Reducer")
public typealias ReducerProtocol = Reducer

@available(*, unavailable, renamed: "ReducerOf")
public typealias ReducerProtocolOf<R: Reducer> = Reducer<R.State, R.Action>
