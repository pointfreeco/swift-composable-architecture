/// Describe a binding between a parent state `Source` and a child state `Destination`. Several initializer are
/// provided to handle the following cases:
/// - Synchronization of a subset of `Destination` properties with `Source`
/// - Synchronization of a subset of an optional `Destination` state with `Source`
/// - Synchronization of all the properties of `Destination` with `Source`
/// - Synchronization of all the properties of an optional `Destination` with `Source`.
///
/// This binding can then be used to define public accessors to a `Destination` instance in `Source`, calling
/// the `get` and `set` function with the `Source` instance and `Destination`'s `newValue`.
///
/// Let the child state `Destination` be:
/// ```
/// struct Destination {
///   var value: String = ""
///   var count: Int = 0
///   var internalValue: Int = 0
/// }
/// ```
/// We can the use `StateBinding` to generate a `Destination` instance whose `value` will be synchronized
/// with the `title` value of `Source`:
/// ```
/// struct Source {
///   var title: String = "Hello! world"
///   var count: Int = 0
///
///   private var _storage = Feature()
///   private static let _binding = StateBinding(\Self._storage)
///     .rw(\.title, \.value)
///     .rw(\.count, \.count)
///
///   var feature: Feature {
///     get { Self._binding.get(self) }
///     set { Self._binding.set(&self, newValue) }
///   }
/// }
/// ```
///
public struct StateBinding<Source, Destination> {
  /// Retrieve the storage in `source`, update it and returns the result.
  public let get: (_ source: Source) -> Destination
  /// Set the storage in `source` and update `source`.
  public let set: (_ source: inout Source, _ newValue: Destination) -> Void
}

public extension StateBinding {
  /// Initialize a binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for a `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties`
  /// are synchronized with `Source`.
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an instance of `Destination`, used to store
  ///   `Destination`'s internal properties.
  ///   - removeDuplicateStorage: A function used to compare private storage and avoid setting it in `Source` if unnecessary
  init(_ storage: WritableKeyPath<Source, Destination>,
       removeDuplicateStorage: ((Destination, Destination) -> Bool)? = nil)
  {
    get = { $0[keyPath: storage] }
    set = { source, newValue in
      if removeDuplicateStorage?(source[keyPath: storage], newValue) != true {
        source[keyPath: storage] = newValue
      }
    }
  }

  /// Initialize a binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for an optional `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties` are synchronized
  /// with `Source`. If the child is set to nil, source properties other than the storage property are kept untouched
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an instance of `Destination?`, used to store
  ///   `Destination`'s internal properties. If this instance is nil, the computed property will be also nil.
  ///   - removeDuplicateStorage: A function used to compare private storage and avoid setting it in `Source` if unnecessary
  init<UnwrappedDestination>(
    _ storage: WritableKeyPath<Source, Destination>,
    removeDuplicateStorage: ((Destination, Destination) -> Bool)? = nil
  ) where Destination == UnwrappedDestination? {
    get = { $0[keyPath: storage] }
    set = { source, newValue in
      if removeDuplicateStorage?(source[keyPath: storage], newValue) != true {
        source[keyPath: storage] = newValue
      }
    }
  }
  
  /// Initialize a computed binding between a parent state `Source` and a child state `Destination`. These derived states
  /// are used when all the properties of `Destination` can be individually stored in `Source`. Please note that this version
  /// needs explicit generics on call site as the initializer lacks information to resolve `Source` by itself.
  /// - Parameters:
  ///   - destination: A function that returns an default instance of `Destination` (the child state)
  init(
    with destination: @escaping () -> Destination
  ) {
    get = { _ in destination() }
    set = { _, _ in () }
  }

  /// Initialize a computed binding between a parent state `Source` and an optional child state `Destination`
  /// These derived states are used when all the properties of `Destination` can be individually stored in `Source`.
  /// If the child is set to nil, the source properties are kept untouched
  /// - Parameters:
  ///   - destination: A function that returns an default instance of `Destination`(the child state) or nil. `Source` can
  ///   be used to decide if `Destination` is nil or not.
  init(
    with destination: @escaping (Source) -> Destination
  ) {
    get = destination
    set = { _, _ in () }
  }
}

fileprivate extension StateBinding {
  /// Returns a modified `StateBinding`using a couble of `PropertyBinding`  to bind similar
  /// properties in `Source` and `Destination`.
  func with(_ propertyBinding: PropertyBinding<Source, Destination>) -> Self {
    let get: (Source) -> Destination = { source in
      var destination = self.get(source)
      propertyBinding.get(source, &destination)
      return destination
    }
    let set: (inout Source, Destination) -> Void = { source, destination in
      self.set(&source, destination)
      propertyBinding.set(&source, destination)
    }
    return .init(get: get, set: set)
  }

  /// Returns a modified `StateBinding`using a couble of `PropertyBinding` to bind similar
  /// properties in `Source` and `Destination.Wrapped`.
  func with<UnwrappedDestination>(_ propertyBinding: PropertyBinding<Source, UnwrappedDestination>) -> Self
    where Destination == UnwrappedDestination?
  {
    let get: (Source) -> Destination = { source in
      guard var destination = self.get(source) else { return nil }
      propertyBinding.get(source, &destination)
      return destination
    }
    let set: (inout Source, Destination) -> Void = { source, destination in
      self.set(&source, destination)
      guard let destination = destination else { return }
      propertyBinding.set(&source, destination)
    }
    return .init(get: get, set: set)
  }
}

public extension StateBinding {
  /// Returns a modified `StateBinding` binding similar properties between `Source` and `Destination`.
  /// - Parameters:
  ///   - get: A function applied when `Destination` is requested from `Source`. The `Destination`
  ///   instance can be updated at this point.
  ///   - set: A function applied when `Destination` is set in `Source`. The `Source` instance can be
  ///   updated at this point.
  func with(get: @escaping (Source, inout Destination) -> Void,
            set: @escaping (inout Source, Destination) -> Void = { _, _ in () }
  ) -> Self {
    with(PropertyBinding<Source, Destination>(get: get, set: set))
  }

  /// Returns a modified `StateBinding` binding similar properties between `Source` and `Destination.Wrapped`.
  /// - Parameters:
  ///   - get: A function applied when `Destination.Wrapped` is requested from `Source`. The `Destination.Wrapped`
  ///   instance can be updated at this point.
  ///   - set: A function applied when `Destination.Wrapped` is set in `Source`. The `Source` instance can be
  ///   updated at this point.
  func with<UnwrappedDestination>(get: @escaping (Source, inout UnwrappedDestination) -> Void,
                                  set: @escaping (inout Source, UnwrappedDestination) -> Void = { _, _ in () }
                        ) -> Self
    where Destination == UnwrappedDestination?
  {
    with(PropertyBinding<Source, UnwrappedDestination>(get: get, set: set))
  }

  /// Returns a modified `StateBinding`using a couble of `KeyPath`  to link in a read-write fashion a similar
  /// property in `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function is implemented
  ///     and returns `true`, no assignation will occur and `Source` will be kept untouched.
  func rw<Value>(_ sourceValue: WritableKeyPath<Source, Value>,
                 _ destinationValue: WritableKeyPath<Destination, Value>,
                 removeDuplicates: ((Value, Value) -> Bool)? = nil) -> Self
  {
    with(.init(sourceValue, destinationValue, removeDuplicates: removeDuplicates))
  }

  /// Returns a modified `StateBinding`using a couble of `KeyPath`  to link in a read-write fashion a similar
  /// property in `Source` and `Destination.Wrapped`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function is implemented
  ///     and returns `true`, no assignation will occur and `Source` will be kept untouched.
  func rw<Value, UnwrappedDestination>(_ sourceValue: WritableKeyPath<Source, Value>,
                                       _ destinationValue: WritableKeyPath<UnwrappedDestination, Value>,
                                       removeDuplicates: ((Value, Value) -> Bool)? = nil) -> Self
    where Destination == UnwrappedDestination?
  {
    with(.init(sourceValue, destinationValue, removeDuplicates: removeDuplicates))
  }

  /// Returns a modified `StateBinding`using a couble of `KeyPath`  to link in a read-only fashion a similar
  /// property in `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  func ro<Value>(_ sourceValue: KeyPath<Source, Value>,
                 _ destinationValue: WritableKeyPath<Destination, Value>) -> Self
  {
    with(.init(readonly: sourceValue, destinationValue))
  }

  /// Returns a modified `StateBinding`using a couble of `KeyPath`  to link in a read-only fashion a similar
  /// property in `Source` and `Destination.Wrapped`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  func ro<Value, UnwrappedDestination>(_ sourceValue: KeyPath<Source, Value>,
                                       _ destinationValue: WritableKeyPath<UnwrappedDestination, Value>) -> Self
    where Destination == UnwrappedDestination?
  {
    with(.init(readonly: sourceValue, destinationValue))
  }
}

/// A utility struct that describe a directional binding between instances of `Source` and `Destination`.
fileprivate struct PropertyBinding<Source, Destination> {
  let get: (Source, inout Destination) -> Void
  let set: (inout Source, Destination) -> Void
  /// Initialize a binding between a `Source` instance and a`Destination` instance.
  /// - Parameters:
  ///   - get: A function applied when `Destination` is requested from `Source`. The `Destination`
  ///   instance can be updated at this point.
  ///   - set: A function applied when `Destination` is set in `Source`. The `Source` instance can be
  ///   updated at this point.
  init(
    get: @escaping (Source, inout Destination) -> Void = { _, _ in },
    set: @escaping (inout Source, Destination) -> Void = { _, _ in }
  ) {
    self.get = get
    self.set = set
  }

  /// Initialize a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function is implemented
  ///     and returns `true`, no assignation will occur and `Source` will be kept untouched.
  init<Value>(
    _ sourceValue: WritableKeyPath<Source, Value>,
    _ destinationValue: WritableKeyPath<Destination, Value>,
    removeDuplicates: ((Value, Value) -> Bool)? = nil
  ) {
    self.get = { source, destination in
      destination[keyPath: destinationValue] = source[keyPath: sourceValue]
    }

    self.set = { source, destination in
      guard removeDuplicates?(source[keyPath: sourceValue], destination[keyPath: destinationValue]) != true
      else { return }
      source[keyPath: sourceValue] = destination[keyPath: destinationValue]
    }
  }

  /// Initialize a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`. This binding is unidirectional (readonly on Source ) and the
  /// `KeyPath<Source, Value` doesn't need to be writable.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  init<Value>(
    readonly sourceValue: KeyPath<Source, Value>,
    _ destinationValue: WritableKeyPath<Destination, Value>
  ) {
    self.get = { source, destination in
      destination[keyPath: destinationValue] = source[keyPath: sourceValue]
    }
    self.set = { _, _ in
    }
  }
}
