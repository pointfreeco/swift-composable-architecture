import ComposableArchitecture

/// Describes a binding between a parent state `Source` and a child state `Destination`. Several initializers are
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
  /// Initializes a binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for a `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties`
  /// are synchronized with `Source`.
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an instance of `Destination`, used to store
  ///   `Destination`'s internal properties.
  ///   - removeDuplicateStorage: A function used to compare private storage and avoid setting it in `Source` if unnecessary
  init(_ storage: WritableKeyPath<Source, Destination>,
       removeDuplicateStorage: @escaping (Destination, Destination) -> Bool = { _, _ in false })
  {
    get = { $0[keyPath: storage] }
    set = { source, newValue in
      if !removeDuplicateStorage(source[keyPath: storage], newValue) {
        source[keyPath: storage] = newValue
      }
    }
  }

  /// Initializes a computed binding between a parent state `Source` and an optional child state `Destination`
  /// These derived states are used when all the properties of `Destination` can be individually stored in `Source`.
  /// If the child is set to nil, the source properties are kept untouched
  /// - Parameters:
  ///   - destination: A function that returns an default instance of `Destination`(the child state) or nil. `Source` can
  ///   be used to decide if `Destination` is nil or not.
  init(with destination: @escaping (Source) -> Destination) {
    get = destination
    set = { _, _ in () }
  }

  /// Initializes a computed binding between a parent state `Source` and a child state `Destination`. These derived states
  /// are used when all the properties of `Destination` can be individually stored in `Source`. Please note that this version
  /// needs explicit generics on call site as the initializer lacks information to resolve `Source` by itself.
  /// - Parameters:
  ///   - destination: A function that returns an default instance of `Destination` (the child state).
  ///     This initializer signature is convenient when `Destination` has a `.init()` initializer without arguments.
  init(with destination: @escaping () -> Destination) {
    self.init(with: { _ in destination() })
  }
}

public extension StateBinding {
  /// Returns a modified `StateBinding`using a couble of `PropertyBinding` to bind similar
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

  /// Returns a modified `StateBinding` binding similar properties between `Source` and `Destination`.
  /// - Parameters:
  ///   - get: A function applied when `Destination` is requested from `Source`. The `Destination`
  ///   instance can be updated at this point.
  ///   - set: A function applied when `Destination` is set in `Source`. The `Source` instance can be
  ///   updated at this point.
  func with(get: @escaping (Source, inout Destination) -> Void,
            set: @escaping (inout Source, Destination) -> Void = { _, _ in () }) -> Self
  {
    with(PropertyBinding<Source, Destination>(get: get, set: set))
  }
}

public extension StateBinding {
  /// Returns a modified `StateBinding`using a couble of `KeyPath`  to link in a read-write fashion a similar
  /// property in `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function returns `true`,
  ///   no assignation will occur and `Source` will be kept untouched.
  func rw<Value>(_ sourceValue: WritableKeyPath<Source, Value>,
                 _ destinationValue: WritableKeyPath<Destination, Value>,
                 removeDuplicates: @escaping (Value, Value) -> Bool = { _, _ in false }) -> Self
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
}

// Mappings of `StateBinding` so they can work in some containers content directly.
public extension StateBinding {
  /// Maps a `PropertyBinding<Source, Wrapped>` to a `PropertyBinding<Source, Wrapped?>` and installs
  /// it into a `StateBinding<Source, Wrapped?>`.
  /// - Parameters:
  ///   - binding: A `PropertyBinding<Source, Wrapped>` to be mapped.
  ///   - getBack: A `(Source, Wrapped?) -> Wrapped?` function to decide how to reinject the
  ///   `Wrapped` instance's properties into `Source`. If this function returns nil, the binding will be readonly. The returned type
  ///   should rigorously be  `Wrapped??`, but since both `nil` values would have the same semantic in the setter,
  ///   we can use only `Wrapped?`.
  /// - Returns: A `StateBinding<Source, Wrapped?>` state binding.
  func map<Wrapped>(_ binding: PropertyBinding<Source, Wrapped>,
                    getBack: @escaping (Source, Destination) -> Wrapped? = { $1 }) -> Self
    where Destination == Wrapped?
  {
    with(binding.map(getBack: getBack))
  }

  /// Maps a `PropertyBinding<Source, Element>` to a `PropertyBinding<Source, [Element]>` and installs
  /// it into a `StateBinding<Source, [Element]>`.
  /// - Parameters:
  ///   - binding: A `PropertyBinding<Source, Element>` to be mapped.
  ///   - getBack: A `(Source, [Element]) -> Element?` function to decide how to reinject the
  ///   `[Element]` instance's properties into `Source`. If this function returns nil, the binding will be readonly.
  /// - Returns: A `StateBinding<Source, [Element]>` state binding.
  func map<Element>(_ binding: PropertyBinding<Source, Element>,
                    getBack: @escaping (Source, Destination) -> Element? = { _, _ in nil }) -> Self
    where Destination == [Element]
  {
    with(binding.map(getBack: getBack))
  }

  /// Maps a `PropertyBinding<Source, Value>` to a `PropertyBinding<Source, [Key: Value]>` and installs
  /// it into a `StateBinding<Source, [Key: Value]>`.
  /// - Parameters:
  ///   - binding: A `PropertyBinding<Source, Value>` to be mapped.
  ///   - getBack: A `(Source, [Key: Value]) -> Value?` function to decide how to reinject the
  ///   `[Key: Value]` instance's properties into `Source`. If this function returns nil, the binding will be readonly.
  /// - Returns: A `StateBinding<Source, [Key: Value]>` state binding.
  func map<Key, Value>(_ binding: PropertyBinding<Source, Value>,
                       getBack: @escaping (Source, Destination) -> Value? = { _, _ in nil }) -> Self
    where Destination == [Key: Value]
  {
    with(binding.map(getBack: getBack))
  }

  /// Maps a `PropertyBinding<Source, Element>` to a `PropertyBinding<Source, IdentifiedArray<ID, Element>>`
  /// and installs it into a `StateBinding<Source, IdentifiedArray<ID, Element>>`.
  /// - Parameters:
  ///   - binding: A `PropertyBinding<Source, Element>` to be mapped.
  ///   - getBack: A `(Source, IdentifiedArray<ID, Element>) -> Element?` function to decide how to reinject the
  ///   `IdentifiedArray<ID, Element>` instance's properties into `Source`. If this function returns nil, the binding will be readonly.
  /// - Returns: A `StateBinding<Source, IdentifiedArray<ID, Element>>` state binding.
  func map<ID, Element>(_ binding: PropertyBinding<Source, Element>,
                        getBack: @escaping (Source, Destination) -> Element? = { _, _ in nil }) -> Self
    where Destination == IdentifiedArray<ID, Element>
  {
    with(binding.map(getBack: getBack))
  }
}

// Because a trivial reduction `(Source, Destination?) -> Destination?` exists, and because
// mapping successively `Optional` has no sensible performance impact, we can implement
// dedicated overloads when the destination state is optional. This allows the user to
// directly chain `rw(...`, `ro(...`, etc. without having to call `.map(...` first.
public extension StateBinding {
  /// Returns a modified `StateBinding`using a couble of `KeyPath`  to link in a read-write fashion a similar
  /// property in `Source` and `Destination.Wrapped`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function
  ///     returns `true`, no assignation will occur and `Source` will be kept untouched.
  func rw<Value, Wrapped>(_ sourceValue: WritableKeyPath<Source, Value>,
                          _ destinationValue: WritableKeyPath<Wrapped, Value>,
                          getBack: (Source, Destination) -> Wrapped? = { $1 },
                          removeDuplicates: @escaping (Value, Value) -> Bool = { _, _ in false }) -> Self
    where Destination == Wrapped?
  {
    with(.rw(sourceValue, destinationValue, removeDuplicates: removeDuplicates))
  }

  /// Returns a modified `StateBinding`using a couble of `KeyPath`  to link in a read-only fashion a similar
  /// property in `Source` and `Destination.Wrapped`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  func ro<Value, Wrapped>(_ sourceValue: KeyPath<Source, Value>,
                          _ destinationValue: WritableKeyPath<Wrapped, Value>) -> Self
    where Destination == Wrapped?
  {
    with(.ro(sourceValue, destinationValue))
  }

  /// Returns a modified `StateBinding`using a couble of `PropertyBinding` to bind similar
  /// properties in `Source` and `Destination.Wrapped`.
  func with<Wrapped>(_ propertyBinding: PropertyBinding<Source, Wrapped>,
                     getBack: @escaping (Source, Destination) -> Wrapped? = { $1 }) -> Self
    where Destination == Wrapped?
  {
    self.map(propertyBinding, getBack: getBack)
  }

  /// Returns a modified `StateBinding` binding similar properties between `Source` and `Destination.Wrapped`.
  /// - Parameters:
  ///   - get: A function applied when `Destination.Wrapped` is requested from `Source`. The `Destination.Wrapped`
  ///   instance can be updated at this point.
  ///   - set: A function applied when `Destination.Wrapped` is set in `Source`. The `Source` instance can be
  ///   updated at this point.
  func with<Wrapped>(get: @escaping (Source, inout Wrapped) -> Void,
                     set: @escaping (inout Source, Wrapped) -> Void = { _, _ in () },
                     getBack: @escaping (Source, Destination) -> Wrapped? = { $1 }) -> Self
    where Destination == Wrapped?
  {
    with(PropertyBinding<Source, Wrapped>(get: get, set: set), getBack: getBack)
  }
}

/// A utility struct that describe a directional binding between instances of `Source` and `Destination`.
public struct PropertyBinding<Source, Destination> {
  let get: (Source, inout Destination) -> Void
  let set: (inout Source, Destination) -> Void
  /// Initializes a binding between a `Source` instance and a`Destination` instance.
  /// - Parameters:
  ///   - get: A function applied when `Destination` is requested from `Source`. The `Destination`
  ///   instance can be updated at this point.
  ///   - set: A function applied when `Destination` is set in `Source`. The `Source` instance can be
  ///   updated at this point.
  public init(
    get: @escaping (Source, inout Destination) -> Void = { _, _ in },
    set: @escaping (inout Source, Destination) -> Void = { _, _ in }
  ) {
    self.get = get
    self.set = set
  }

  /// Initializes a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function
  ///    returns `true`, no assignation will occur and `Source` will be kept untouched.
  public init<Value>(
    _ sourceValue: WritableKeyPath<Source, Value>,
    _ destinationValue: WritableKeyPath<Destination, Value>,
    removeDuplicates: @escaping (Value, Value) -> Bool = { _, _ in false }
  ) {
    self.get = { source, destination in
      destination[keyPath: destinationValue] = source[keyPath: sourceValue]
    }

    self.set = { source, destination in
      if !removeDuplicates(source[keyPath: sourceValue],
                           destination[keyPath: destinationValue])
      {
        source[keyPath: sourceValue] = destination[keyPath: destinationValue]
      }
    }
  }

  /// Initializes a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
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

// Convenience initializers
public extension PropertyBinding {
  /// Initializes a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function returns `true`,
  ///   no assignation will occur and `Source` will be kept untouched.
  static func rw<Value>(_ sourceValue: WritableKeyPath<Source, Value>,
                        _ destinationValue: WritableKeyPath<Destination, Value>,
                        removeDuplicates: @escaping (Value, Value) -> Bool = { _, _ in false })
    -> Self { .init(sourceValue, destinationValue, removeDuplicates: removeDuplicates) }

  /// Initializes a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function returns `true`,
  ///   no assignation will occur and `Source` will be kept untouched.
  func rw<Value>(_ sourceValue: WritableKeyPath<Source, Value>,
                 _ destinationValue: WritableKeyPath<Destination, Value>,
                 removeDuplicates: @escaping (Value, Value) -> Bool = { _, _ in false })
    -> Self { self.with(Self.rw(sourceValue, destinationValue, removeDuplicates: removeDuplicates)) }

  /// Initializes a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`. This binding is unidirectional (readonly on Source ) and the
  /// `KeyPath<Source, Value` doesn't need to be writable.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  static func ro<Value>(_ sourceValue: KeyPath<Source, Value>,
                        _ destinationValue: WritableKeyPath<Destination, Value>)
    -> Self { .init(readonly: sourceValue, destinationValue) }

  /// Initializes a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`. This binding is unidirectional (readonly on Source ) and the
  /// `KeyPath<Source, Value` doesn't need to be writable.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  func ro<Value>(_ sourceValue: KeyPath<Source, Value>,
                 _ destinationValue: WritableKeyPath<Destination, Value>)
    -> Self { self.with(Self.ro(sourceValue, destinationValue)) }

  /// Combines the current property binding with another one. The appended binding transormations will occur after the
  /// current binding's transormations.
  func with(_ propertyBinding: PropertyBinding<Source, Destination>) -> Self {
    let get: (Source, inout Destination) -> Void = { source, destination in
      self.get(source, &destination)
      propertyBinding.get(source, &destination)
    }
    let set: (inout Source, Destination) -> Void = { source, destination in
      self.set(&source, destination)
      propertyBinding.set(&source, destination)
    }
    return .init(get: get, set: set)
  }

  /// Combines the current property binding with another one. The appended binding transormations will occur after the
  /// current binding's transormations.
  func with(get: @escaping (Source, inout Destination) -> Void,
            set: @escaping (inout Source, Destination) -> Void = { _, _ in () }) -> Self
  {
    PropertyBinding<Source, Destination>(get: get, set: set)
  }
}

// PropertyBinding Mappings
public extension PropertyBinding {
  /// Transform a binding from `Source` to `Destination` into a binding from `Source` to `Destination?`.
  /// - Parameter getBack: A `(Source, Destination?) -> Destination?` function to decide how to reinject the
  ///   `Destination` instance's properties into `Source`. If this function returns nil, the binding will be readonly.
  ///   The returned type should rigorously be  `Destination??`, but since both `nil` values would have the same
  ///   semantic in the setter, we can use only `Wrapped?`.
  /// - Returns: A  `PropertyBinding<Source, Destination?>`
  func map(getBack: @escaping (Source, Destination?) -> Destination? = { $1 })
    -> PropertyBinding<Source, Destination?>
  {
    PropertyBinding<Source, Destination?>(get: { src, container in
      container = container.map {
        var value = $0
        self.get(src, &value)
        return value
      }
    }, set: { src, container in
      guard let reduced = getBack(src, container) else { return }
      self.set(&src, reduced)
    })
  }

  /// Transform a binding from `Source` to `Destination` into a binding from `Source` to `[Destination]`.
  /// - Parameter getBack: A `(Source, [Destination]) -> Destination?` function to decide how to reinject the
  ///   `Destination` instance's properties into `Source`. If this function returns nil, the binding will be readonly.
  /// - Returns: A  `PropertyBinding<Source, [Destination]>`
  func map(getBack: @escaping (Source, [Destination]) -> Destination? = { _, _ in nil })
    -> PropertyBinding<Source, [Destination]>
  {
    PropertyBinding<Source, [Destination]>(get: { src, container in
      container = container.map {
        var value = $0
        self.get(src, &value)
        return value
      }
    }, set: { src, container in
      guard let reduced = getBack(src, container) else { return }
      self.set(&src, reduced)
    })
  }

  /// Transform a binding from `Source` to `Destination` into a binding from `Source` to `[Key: Destination]`.
  /// - Parameter getBack: A `(Source, [Key: Destination]) -> Destination?` function to decide how to reinject the
  ///   `Destination` instance's properties into `Source`. If this function returns nil, the binding will be readonly.
  /// - Returns: A  `PropertyBinding<Source, [Key: Destination]>`
  func map<Key>(getBack: @escaping (Source, [Key: Destination]) -> Destination? = { _, _ in nil })
    -> PropertyBinding<Source, [Key: Destination]>
  {
    PropertyBinding<Source, [Key: Destination]>(get: { src, container in
      container = container.mapValues {
        var value = $0
        self.get(src, &value)
        return value
      }
    }, set: { src, container in
      guard let reduced = getBack(src, container) else { return }
      self.set(&src, reduced)
    })
  }

  /// Transform a binding from `Source` to `Destination` into a binding from `Source` to `IdentifiedArray<ID, Destination>`.
  /// - Parameter getBack: A `(Source, IdentifiedArray<ID, Destination>) -> Destination?` function to decide how
  ///   to reinject the `Destination` instance's properties into `Source`. If this function returns nil, the binding will be readonly.
  /// - Returns: A  `PropertyBinding<Source, IdentifiedArray<ID, Destination>>`
  func map<ID>(getBack: @escaping (Source, IdentifiedArray<ID, Destination>) -> Destination? = { _, _ in nil })
    -> PropertyBinding<Source, IdentifiedArray<ID, Destination>> where ID: Hashable
  {
    PropertyBinding<Source, IdentifiedArray<ID, Destination>>(get: { src, container in
                                                                container = IdentifiedArray(
                                                                  container.elements
                                                                    .map { value -> Destination in
                                                                      var value = value
                                                                      self.get(src, &value)
                                                                      return value
                                                                    },
                                                                  id: container.id
                                                                )
                                                              },
                                                              set: { src, container in
                                                                guard let reduced = getBack(src, container)
                                                                else { return }
                                                                self.set(&src, reduced)
                                                              })
  }
}
