import ComposableArchitecture

// MARK: - State Bindings

/// Describes a binding between a parent state `Source` and a child state `Destination`. Several initializers are
/// provided to handle the following cases:
/// - Synchronization of a subset of `Destination` properties with `Source`
/// - Synchronization of all the properties of `Destination` with `Source`
///
/// This binding can then be used to define public accessors to a `Destination` value in `Source`, calling
/// the `get` and `set` function with the `Source` value and `Destination`'s `newValue`.
///
/// Let the child state `Destination` be:
/// ```
/// struct Destination {
///   var value: String = ""
///   var count: Int = 0
///   var internalValue: Int = 0
/// }
/// ```
/// We can the use `StateBinding` to generate a `Destination` value whose `value` will be synchronized
/// with the `title` value of `Source`:
/// ```
/// struct Source {
///   var title: String = "Hello! world"
///   var count: Int = 0
///
///   private var _storage = Feature()
///   private static let featureBinding = StateBinding(\Self._storage)
///     .rw(\.title, \.value)
///     .rw(\.count, \.count)
///
///   var feature: Feature {
///     get { Self.featureBinding.get(self) }
///     set { Self.featureBinding.set(&self, newValue) }
///   }
/// }
/// ```
/// One can also omit the `feature` accessor implementation and work directly with the state bindind
/// when scoping a store:
/// ```
/// store.scope(Source.featureBinding.get)
/// ```
/// or pulling back a reducer:
/// ```
/// featureReducer.pullback(binding: Source.featureBinding, action: ...
/// ```
/// If one implements `feature` accessors, one can use its keyPath like a classical state property in TCA.
public struct StateBinding<Source, Destination> {
  /// Retrieve the storage in `source`, update it and returns the result.
  public let get: (_ source: Source) -> Destination
  /// Set the storage in `source` and update `source`.
  public let set: (_ source: inout Source, _ newValue: Destination) -> Void

  public func callAsFunction(_ source: Source) -> Destination {
    get(source)
  }
}

public extension StateBinding {
  /// Initializes a binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for a `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties`
  /// are synchronized with `Source`.
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an value of `Destination`, used to store
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
  /// If the child is set to nil, the source properties are kept untouched. This kind of binding is convenient when `Destination`'s
  /// existence is conditioned with a boolean flag like `isEditing` on `Source`'s side.
  /// - Parameters:
  ///   - destination: A function that returns an default value of `Destination`(the child state) or nil. `Source` can
  ///   be used to decide if `Destination` is nil or not.
  init(with destination: @escaping (Source) -> Destination) {
    get = destination
    set = { _, _ in () }
  }

  /// Initializes a computed binding between a parent state `Source` and a child state `Destination`. These derived states
  /// are used when all the properties of `Destination` can be individually stored in `Source`. Please note that this version
  /// needs explicit generics on call site as the initializer lacks information to resolve `Source` by itself. This kind of binding is
  /// useful when `Destination` has an `init()` initializer without arguments.
  /// - Parameters:
  ///   - destination: A function that returns an default value of `Destination` (the child state).
  init(with destination: @escaping () -> Destination) {
    self.init(with: { _ in destination() })
  }
}

public extension StateBinding {
  /// Returns a modified `StateBinding`using a `PropertyBinding` to bind similar
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
  ///   value can be updated at this point.
  ///   - set: A function applied when `Destination` is set in `Source`. The `Source` value can be
  ///   updated at this point.
  func with(get: @escaping (Source, inout Destination) -> Void,
            set: @escaping (inout Source, Destination) -> Void = { _, _ in () }) -> Self
  {
    with(PropertyBinding<Source, Destination>(get: get, set: set))
  }
}

// Shorthands
public extension StateBinding {
  /// Returns a modified `StateBinding`using a couble of `KeyPath` to link in a read-write fashion a similar
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

  /// Returns a modified `StateBinding`using a couble of `KeyPath` to link in a read-only fashion a similar
  /// property in `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  func ro<Value>(_ sourceValue: KeyPath<Source, Value>,
                 _ destinationValue: WritableKeyPath<Destination, Value>) -> Self
  {
    with(.init(readonly: sourceValue, destinationValue))
  }
}

// Mappings of `StateBinding` so they can work in containers elements directly.
public extension StateBinding {
  /// Maps a `PropertyBinding<Source, Wrapped>` to a `PropertyBinding<Source, Wrapped?>` and installs
  /// it into a `StateBinding<Source, Wrapped?>`.
  /// - Parameters:
  ///   - binding: A `PropertyBinding<Source, Wrapped>` to be mapped.
  ///   - reduce: A `(Source, Wrapped?) -> Wrapped?` function to decide how to reinject the `Wrapped?` value  into `Source`.
  ///   If this function returns nil, the binding will be readonly. By default, we directly returns the destination's value, as it is the expected behavior
  ///   for `WritableKeyPath<Source, Wrapped?>`.
  /// - Returns: A `StateBinding<Source, Wrapped?>` state binding.
  func map<Wrapped>(_ binding: PropertyBinding<Source, Wrapped>,
                    reduce: @escaping (Source, Destination) -> Wrapped? = { $1 }) -> Self
    where Destination == Wrapped?
  {
    with(binding.map(reduce: reduce))
  }

  /// Maps a `PropertyBinding<Source, Element>` to a `PropertyBinding<Source, [Element]>` and installs
  /// it into a `StateBinding<Source, [Element]>`.
  /// - Parameters:
  ///   - binding: A `PropertyBinding<Source, Element>` to be mapped.
  ///   - reduce: A `(Source, [Element]) -> Element?` function to decide how to "unmap" `[Element]`'s values
  ///    into `Source`'s properties.  In other words, we need to extract from `[Element]` a candidate `Element` value to send
  ///    upward the original `StateBinding<Source, Element>`'s setter and set some values in `Source`.
  ///    If this function returns nil, the binding will be readonly for its mapped properties.
  /// - Returns: A `StateBinding<Source, [Element]>` state binding.
  func map<Element>(_ binding: PropertyBinding<Source, Element>,
                    reduce: @escaping (Source, Destination) -> Element? = { _, _ in nil }) -> Self
    where Destination == [Element]
  {
    with(binding.map(reduce: reduce))
  }

  /// Maps a `PropertyBinding<Source, Value>` to a `PropertyBinding<Source, [Key: Value]>` and installs
  /// it into a `StateBinding<Source, [Key: Value]>`.
  /// - Parameters:
  ///   - binding: A `PropertyBinding<Source, Value>` to be mapped.
  ///   - reduce: A `(Source, [Key: Value]) -> Value?` function to decide how to "unmap" `[Key: Value]`'s values
  ///    into `Source`'s properties.  In other words, we need to extract from `[Key: Value]` a candidate `Value` value to send
  ///    upward the original `StateBinding<Source, Value>`'s setter and set some values in `Source`.
  ///   If this function returns nil, the binding will be readonly for  its mapped properties.
  /// - Returns: A `StateBinding<Source, [Key: Value]>` state binding.
  func map<Key, Value>(_ binding: PropertyBinding<Source, Value>,
                       reduce: @escaping (Source, Destination) -> Value? = { _, _ in nil }) -> Self
    where Destination == [Key: Value]
  {
    with(binding.map(reduce: reduce))
  }

  /// Maps a `PropertyBinding<Source, Element>` to a `PropertyBinding<Source, IdentifiedArray<ID, Element>>`
  /// and installs it into a `StateBinding<Source, IdentifiedArray<ID, Element>>`.
  /// - Parameters:
  ///   - binding: A `PropertyBinding<Source, Element>` to be mapped.
  ///   - reduce: A `(Source, IdentifiedArray<ID, Element>) -> Element?`function to decide how to "unmap"
  ///   `IdentifiedArray<ID, Element>`'s values into `Source`'s properties.  In other words, we need to extract from
  ///   `IdentifiedArray<ID, Element>` a candidate `Element` value to send upward the original `StateBinding<Source, Element>`'s
  ///   setter and set some values in `Source`. If this function returns nil, the binding will be readonly for its mapped properties.
  /// - Returns: A `StateBinding<Source, IdentifiedArray<ID, Element>>` state binding.
  func map<ID, Element>(_ binding: PropertyBinding<Source, Element>,
                        reduce: @escaping (Source, Destination) -> Element? = { _, _ in nil }) -> Self
    where Destination == IdentifiedArray<ID, Element>
  {
    with(binding.map(reduce: reduce))
  }
}

// Because a trivial reduction `(Source, Destination?) -> Destination?` exists, and because
// mapping successively `Optional` values has no sensible performance impact (unlike Arrays for
// example, we can implement dedicated overloads when the destination state is optional.
// This allows to directly chain `rw(...`, `ro(...`, etc. without having to call `.map(...` first.
public extension StateBinding {
  /// Returns a modified `StateBinding`using a couble of `KeyPath` to link in a read-write fashion a similar
  /// property in `Source` and `Destination.Wrapped`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function
  ///     returns `true`, no assignation will occur and `Source` will be kept untouched.
  func rw<Value, Wrapped>(_ sourceValue: WritableKeyPath<Source, Value>,
                          _ destinationValue: WritableKeyPath<Wrapped, Value>,
                          reduce: (Source, Destination) -> Wrapped? = { $1 },
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

  /// Returns a modified `StateBinding`using a `PropertyBinding` to bind similar properties in `Source` and
  /// `Destination.Wrapped`.
  func with<Wrapped>(_ propertyBinding: PropertyBinding<Source, Wrapped>,
                     reduce: @escaping (Source, Destination) -> Wrapped? = { $1 }) -> Self
    where Destination == Wrapped?
  {
    self.map(propertyBinding, reduce: reduce)
  }

  /// Returns a modified `StateBinding` binding similar properties between `Source` and `Destination.Wrapped`.
  /// - Parameters:
  ///   - get: A function applied when `Destination.Wrapped` is requested from `Source`. The `Destination.Wrapped`
  ///   value can be updated at this point.
  ///   - set: A function applied when `Destination.Wrapped` is set in `Source`. The `Source` value can be
  ///   updated at this point.
  func with<Wrapped>(get: @escaping (Source, inout Wrapped) -> Void,
                     set: @escaping (inout Source, Wrapped) -> Void = { _, _ in () },
                     reduce: @escaping (Source, Destination) -> Wrapped? = { $1 }) -> Self
    where Destination == Wrapped?
  {
    with(PropertyBinding<Source, Wrapped>(get: get, set: set), reduce: reduce)
  }
}

// MARK: - Property Bindings

/// A  type that describes a directional binding between values of `Source` and `Destination`. We usually link only
/// one property per `PropertyBinding` value, and compose them using `.with`, `rw` or `ro.` We can also map
/// a `PropertyBinding<Source, Destination>` to `PropertyBinding<Source, T<Destination>>`, allowing
/// to work on `T<Destination>` with `Destination`'s transformations.
public struct PropertyBinding<Source, Destination> {
  let get: (Source, inout Destination) -> Void
  let set: (inout Source, Destination) -> Void
  /// Initializes a binding between a `Source` value and a`Destination` value.
  /// - Parameters:
  ///   - get: A function applied when `Destination` is requested from `Source`. The `Destination`
  ///   value can be updated at this point.
  ///   - set: A function applied when `Destination` is set in `Source`. The `Source` value can be
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
  /// - Parameter reduce: A `(Source, Destination?) -> Destination?` function to decide how to "unmap"
  ///   `Destination?` into `Source`. In other words, we need to extract from `Destination?` a candidate
  ///   `Destination` value to send upward the original `PropertyBinding<Source, Destination>`'s setter and set some
  ///   values in `Source`. If this function returns nil, the binding will be readonly. By default, we return the wrapped value itself,
  ///   as it is the expected behavior for `WritableKeyPath<Source, Destination?>`.
  /// - Returns: A  `PropertyBinding<Source, Destination?>`
  func map(reduce: @escaping (Source, Destination?) -> Destination? = { $1 })
    -> PropertyBinding<Source, Destination?>
  {
    PropertyBinding<Source, Destination?>(get: { src, container in
      container = container.map {
        var value = $0
        self.get(src, &value)
        return value
      }
    }, set: { src, container in
      guard let reduced = reduce(src, container) else { return }
      self.set(&src, reduced)
    })
  }

  /// Transform a binding from `Source` to `Destination` into a binding from `Source` to `[Destination]`.
  /// - Parameter reduce: A `(Source, [Destination]) -> Destination?` function to decide how to "unmap" the
  ///   `[Destination]` values into `Source`'s properties. In other words, we need to extract from `[Destination]`
  ///   a candidate `Destination` value to send upward the original `PropertyBinding<Source, Destination>`'s setter and set
  ///   some values in `Source`. If this function returns nil, the binding will be readonly.
  /// - Returns: A  `PropertyBinding<Source, [Destination]>`
  func map(reduce: @escaping (Source, [Destination]) -> Destination? = { _, _ in nil })
    -> PropertyBinding<Source, [Destination]>
  {
    PropertyBinding<Source, [Destination]>(get: { src, container in
      container = container.map {
        var value = $0
        self.get(src, &value)
        return value
      }
    }, set: { src, container in
      guard let reduced = reduce(src, container) else { return }
      self.set(&src, reduced)
    })
  }

  /// Transform a binding from `Source` to `Destination` into a binding from `Source` to `[Key: Destination]`.
  /// - Parameter reduce: A `(Source, [Key: Destination]) -> Destination?` function to decide how to reinject the
  ///   `[Key: Destination]` values into `Source`'s properties. In other words, we need to extract from `[Key: Destination]`
  ///   a candidate `Destination` value to send upward the original `PropertyBinding<Source, Destination>`'s setter and set
  ///   some values in `Source`.  If this function returns nil, the binding will be readonly.
  /// - Returns: A  `PropertyBinding<Source, [Key: Destination]>`
  func map<Key>(reduce: @escaping (Source, [Key: Destination]) -> Destination? = { _, _ in nil })
    -> PropertyBinding<Source, [Key: Destination]>
  {
    PropertyBinding<Source, [Key: Destination]>(get: { src, container in
      container = container.mapValues {
        var value = $0
        self.get(src, &value)
        return value
      }
    }, set: { src, container in
      guard let reduced = reduce(src, container) else { return }
      self.set(&src, reduced)
    })
  }

  /// Transform a binding from `Source` to `Destination` into a binding from `Source` to `IdentifiedArray<ID, Destination>`.
  /// - Parameter reduce: A `(Source, IdentifiedArray<ID, Destination>) -> Destination?` function to decide how
  ///   to reinject the `IdentifiedArray<ID, Destination>` values into `Source`. In other words, we need to extract
  ///   from `IdentifiedArray<ID, Destination>` a candidate `Destination` value to send upward the original
  ///   `PropertyBinding<Source, Destination>` setter and set some values in `Source`.
  ///   If this function returns nil, the binding will be readonly.
  /// - Returns: A  `PropertyBinding<Source, IdentifiedArray<ID, Destination>>`
  func map<ID>(reduce: @escaping (Source, IdentifiedArray<ID, Destination>) -> Destination? = { _, _ in nil })
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
                                                                guard let reduced = reduce(src, container)
                                                                else { return }
                                                                self.set(&src, reduced)
                                                              })
  }
}


// MARK: Reducer Specializations to use StateBinding directly -
/// Use this marker protocol on a parent state `Source` to allow reducer pullbacks using `StateBinding<Source, _>`
/// directly, without having to generate accessors.
public protocol StateContainer {}

extension StateContainer {
  // This subscript is used instead of `WritableKeyPath<Self, T>` in `StateBinding` reducer's specializations
  subscript<T>(binding binding: StateBinding<Self, T>) -> T {
    get { binding.get(self) }
    set { binding.set(&self, newValue) }
  }
}

/// `inout` arguments in subscripts are not currently allowed in Swift.
/// If this changes one day (*), the StateContainer protocol can be dropped in favor of a `StateBinding` subscript:
///
/// ```
/// extension StateBinding {
///  subscript (source source: inout Source) -> Destination {
///    get { get(source) }
///    set { set(&source, newValue) }
///  }
/// }
/// ```
/// The reducer specializations can then call `toLocalState[source: &globalState]` instead
/// of  `&globalState[binding: toLocalState]`
///
/// (*) see: https://forums.swift.org/t/inout-subscript-parameters/31429
public extension Reducer {
  /// Transforms a reducer that works on local state, action, and environment into one that works on
  /// global state, action and environment. It accomplishes this by providing 3 transformations to
  /// the method:
  ///
  ///   * A state binding that can get/set a piece of local state from the global state.
  ///   * A case path that can extract/embed a local action into a global action.
  ///   * A function that can transform the global environment into a local environment.
  ///
  /// This operation is important for breaking down large reducers into small ones. When used with
  /// the `combine` operator you can define many reducers that work on small pieces of domain, and
  /// then _pull them back_ and _combine_ them into one big reducer that works on a large domain.
  ///
  ///     // Global domain that holds a local domain:
  ///     struct AppState { static var settings: StateBinding<AppState,SettingsState>, /* rest of state */ }
  ///     enum AppAction { case settings(SettingsAction), /* other actions */ }
  ///     struct AppEnvironment { var settings: SettingsEnvironment, /* rest of dependencies */ }
  ///
  ///     // A reducer that works on the local domain:
  ///     let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment> { ... }
  ///
  ///     // Pullback the settings reducer so that it works on all of the app domain:
  ///     let appReducer: Reducer<AppState, AppAction, AppEnvironment> = .combine(
  ///       settingsReducer.pullback(
  ///         binding: AppState.settings,
  ///         action: /AppAction.settings,
  ///         environment: { $0.settings }
  ///       ),
  ///
  ///       /* other reducers */
  ///     )
  ///
  /// - Parameters:
  ///   - toLocalState: A state binding can get/set `State` inside `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `Action` from `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  func pullback<GlobalState, GlobalAction, GlobalEnvironment>(
    binding toLocalState: StateBinding<GlobalState, State>,
    action toLocalAction: CasePath<GlobalAction, Action>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
  where GlobalState: StateContainer {
    .init { globalState, globalAction, globalEnvironment in
      guard let localAction = toLocalAction.extract(from: globalAction) else { return .none }
      return self.run(
        &globalState[binding: toLocalState],
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map(toLocalAction.embed)
    }
  }


  /// A version of `pullback` that transforms a reducer that works on an element into one that works
  /// on a collection of elements.
  ///
  ///     // Global domain that holds a collection of local domains bindings:
  ///     struct AppState { static var todos: StateBinding<AppState, [Todo]> }
  ///     enum AppAction { case todo(index: Int, action: TodoAction) }
  ///     struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
  ///
  ///     // A reducer that works on a local domain:
  ///     let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { ... }
  ///
  ///     // Pullback the local todo reducer so that it works on all of the app domain:
  ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  ///       todoReducer.forEach(
  ///         binding: AppState.todos,
  ///         action: /AppAction.todo(index:action:),
  ///         environment: { _ in TodoEnvironment() }
  ///       ),
  ///       Reducer { state, action, environment in
  ///         ...
  ///       }
  ///     )
  ///
  /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
  /// combine `forEach` reducers _before_ parent reducers that can modify the collection.
  ///
  /// - Parameters:
  ///   - toLocalState: A state binding that can get/set an array of `State` elements inside.
  ///     `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `(Int, Action)` from `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  ///   - breakpointOnNil: Raises `SIGTRAP` signal when an action is sent to the reducer but the
  ///     index is out of bounds. This is generally considered a logic error, as a child reducer
  ///     cannot process a child action for unavailable child state.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  func forEach<GlobalState, GlobalAction, GlobalEnvironment>(
    binding toLocalState: StateBinding<GlobalState, [State]>,
    action toLocalAction: CasePath<GlobalAction, (Int, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool = true,
    _ file: StaticString = #file,
    _ line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
  where GlobalState: StateContainer {
    .init { globalState, globalAction, globalEnvironment in
      guard let (index, localAction) = toLocalAction.extract(from: globalAction) else {
        return .none
      }
      if index >= globalState[binding: toLocalState].endIndex {
        #if DEBUG
          if breakpointOnNil {
            fputs(
              """
              ---
              Warning: Reducer.forEach@\(file):\(line)

              "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at index \
              \(index) when its state contained no element at this index. This is generally \
              considered an application logic error, and can happen for a few reasons:

              * This "forEach" reducer was combined with or run from another reducer that removed \
              the element at this index when it handled this action. To fix this make sure that \
              this "forEach" reducer is run before any other reducers that can move or remove \
              elements from state. This ensures that "forEach" reducers can handle their actions \
              for the element at the intended index.

              * An in-flight effect emitted this action while state contained no element at this \
              index. While it may be perfectly reasonable to ignore this action, you may want to \
              cancel the associated effect when moving or removing an element. If your "forEach" \
              reducer returns any long-living effects, you should use the identifier-based \
              "forEach" instead.

              * This action was sent to the store while its state contained no element at this \
              index. To fix this make sure that actions for this reducer can only be sent to a \
              view store when its state contains an element at this index. In SwiftUI \
              applications, use "ForEachStore".
              ---

              """,
              stderr
            )
            raise(SIGTRAP)
          }
        #endif
        return .none
      }
      return self.run(
        &globalState[binding: toLocalState][index],
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map { toLocalAction.embed((index, $0)) }
    }
  }

  /// A version of `pullback` that transforms a reducer that works on an element into one that works
  /// on an identified array of elements.
  ///
  ///     // Global domain that holds a collection of local domains:
  ///     struct AppState { static var todos: StateBinding<AppState: IdentifiedArrayOf<Todo>> }
  ///     enum AppAction { case todo(id: Todo.ID, action: TodoAction) }
  ///     struct AppEnvironment { var mainQueue: AnySchedulerOf<DispatchQueue> }
  ///
  ///     // A reducer that works on a local domain:
  ///     let todoReducer = Reducer<Todo, TodoAction, TodoEnvironment> { ... }
  ///
  ///     // Pullback the local todo reducer so that it works on all of the app domain:
  ///     let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
  ///       todoReducer.forEach(
  ///         binding: AppState.todos,
  ///         action: /AppAction.todo(id:action:),
  ///         environment: { _ in TodoEnvironment() }
  ///       ),
  ///       Reducer { state, action, environment in
  ///         ...
  ///       }
  ///     )
  ///
  /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
  /// combine `forEach` reducers _before_ parent reducers that can modify the collection.
  ///
  /// - Parameters:
  ///   - toLocalState: A state binding that can get/set a collection of `State` elements inside
  ///     `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `(Collection.Index, Action)` from
  ///     `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  ///   - breakpointOnNil: Raises `SIGTRAP` signal when an action is sent to the reducer but the
  ///     identified array does not contain an element with the action's identifier. This is
  ///     generally considered a logic error, as a child reducer cannot process a child action
  ///     for unavailable child state.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  func forEach<GlobalState, GlobalAction, GlobalEnvironment, ID>(
    binding toLocalState: StateBinding<GlobalState, IdentifiedArray<ID, State>>,
    action toLocalAction: CasePath<GlobalAction, (ID, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool = true,
    _ file: StaticString = #file,
    _ line: UInt = #line

  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
  where GlobalState: StateContainer {
    .init { globalState, globalAction, globalEnvironment in
      guard let (id, localAction) = toLocalAction.extract(from: globalAction) else { return .none }
      if globalState[binding: toLocalState][id: id] == nil {
        #if DEBUG
          if breakpointOnNil {
            fputs(
              """
              ---
              Warning: Reducer.forEach@\(file):\(line)

              "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at id \(id) \
              when its state contained no element at this id. This is generally considered an \
              application logic error, and can happen for a few reasons:

              * This "forEach" reducer was combined with or run from another reducer that removed \
              the element at this id when it handled this action. To fix this make sure that this \
              "forEach" reducer is run before any other reducers that can move or remove elements \
              from state. This ensures that "forEach" reducers can handle their actions for the \
              element at the intended id.

              * An in-flight effect emitted this action while state contained no element at this \
              id. It may be perfectly reasonable to ignore this action, but you also may want to \
              cancel the effect it originated from when removing an element from the identified \
              array, especially if it is a long-living effect.

              * This action was sent to the store while its state contained no element at this id. \
              To fix this make sure that actions for this reducer can only be sent to a view store \
              when its state contains an element at this id. In SwiftUI applications, use \
              "ForEachStore".
              ---

              """,
              stderr
            )
            raise(SIGTRAP)
          }
        #endif
        return .none
      }
      return
        self
        .run(
          &globalState[binding: toLocalState][id: id]!,
          localAction,
          toLocalEnvironment(globalEnvironment)
        )
        .map { toLocalAction.embed((id, $0)) }
    }
  }

  /// A version of `pullback` that transforms a reducer that works on an element into one that works
  /// on a dictionary of element values.
  ///
  /// Take care when combining `forEach` reducers into parent domains, as order matters. Always
  /// combine `forEach` reducers _before_ parent reducers that can modify the dictionary.
  ///
  /// - Parameters:
  ///   - toLocalState: A state binding that can get/set a dictionary of `State` values inside
  ///     `GlobalState`.
  ///   - toLocalAction: A case path that can extract/embed `(Key, Action)` from `GlobalAction`.
  ///   - toLocalEnvironment: A function that transforms `GlobalEnvironment` into `Environment`.
  ///   - breakpointOnNil: Raises `SIGTRAP` signal when an action is sent to the reducer but the
  ///     identified array does not contain an element with the action's identifier. This is
  ///     generally considered a logic error, as a child reducer cannot process a child action
  ///     for unavailable child state.
  /// - Returns: A reducer that works on `GlobalState`, `GlobalAction`, `GlobalEnvironment`.
  func forEach<GlobalState, GlobalAction, GlobalEnvironment, Key>(
    binding toLocalState: StateBinding<GlobalState, [Key: State]>,
    action toLocalAction: CasePath<GlobalAction, (Key, Action)>,
    environment toLocalEnvironment: @escaping (GlobalEnvironment) -> Environment,
    breakpointOnNil: Bool = true,
    _ file: StaticString = #file,
    _ line: UInt = #line
  ) -> Reducer<GlobalState, GlobalAction, GlobalEnvironment>
  where GlobalState: StateContainer {
    .init { globalState, globalAction, globalEnvironment in
      guard let (key, localAction) = toLocalAction.extract(from: globalAction) else { return .none }

      if globalState[binding: toLocalState][key] == nil {
        #if DEBUG
          if breakpointOnNil {
            fputs(
              """
              ---
              Warning: Reducer.forEach@\(file):\(line)

              "\(debugCaseOutput(localAction))" was received by a "forEach" reducer at key \(key) \
              when its state contained no element at this key. This is generally considered an \
              application logic error, and can happen for a few reasons:

              * This "forEach" reducer was combined with or run from another reducer that removed \
              the element at this key when it handled this action. To fix this make sure that this \
              "forEach" reducer is run before any other reducers that can move or remove elements \
              from state. This ensures that "forEach" reducers can handle their actions for the \
              element at the intended key.

              * An in-flight effect emitted this action while state contained no element at this \
              key. It may be perfectly reasonable to ignore this action, but you also may want to \
              cancel the effect it originated from when removing a value from the dictionary, \
              especially if it is a long-living effect.

              * This action was sent to the store while its state contained no element at this \
              key. To fix this make sure that actions for this reducer can only be sent to a view \
              store when its state contains an element at this key.
              ---

              """,
              stderr
            )
            raise(SIGTRAP)
          }
        #endif
        return .none
      }
      return self.run(
        &globalState[binding: toLocalState][key]!,
        localAction,
        toLocalEnvironment(globalEnvironment)
      )
      .map { toLocalAction.embed((key, $0)) }
    }
  }
}

// MARK: - Copy/Paste debugCaseOutput which is internal to TCA.
// Should be discared if `StateBinding` moves into TCA.
fileprivate func debugCaseOutput(_ value: Any) -> String {
  func debugCaseOutputHelp(_ value: Any) -> String {
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .enum:
      guard let child = mirror.children.first else {
        let childOutput = "\(value)"
        return childOutput == "\(type(of: value))" ? "" : ".\(childOutput)"
      }
      let childOutput = debugCaseOutputHelp(child.value)
      return ".\(child.label ?? "")\(childOutput.isEmpty ? "" : "(\(childOutput))")"
    case .tuple:
      return mirror.children.map { label, value in
        let childOutput = debugCaseOutputHelp(value)
        return
          "\(label.map { isUnlabeledArgument($0) ? "_:" : "\($0):" } ?? "")\(childOutput.isEmpty ? "" : " \(childOutput)")"
      }
      .joined(separator: ", ")
    default:
      return ""
    }
  }

  return "\(type(of: value))\(debugCaseOutputHelp(value))"
}

private func isUnlabeledArgument(_ label: String) -> Bool {
  label.firstIndex(where: { $0 != "." && !$0.isNumber }) == nil
}
