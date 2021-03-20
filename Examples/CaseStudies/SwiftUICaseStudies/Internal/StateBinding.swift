
/// A struct that describe a directional binding between instances of `Source` and `Destination`. It's main
/// use is to describe a connection between a property of `Source` and a property of `Destination` when
/// using `BoundState`, `OptionalBoundState`, `ComputedState` or `ComputedOptionalState`
public struct PropertyBinding<Source, Destination> {
  let get: (Source, inout Destination) -> Void
  let set: (inout Source, Destination) -> Void
  /// Initialize a binding between a `Source` instance and a`Destination` instance.
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

  /// Initialized a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get and set `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  ///   - removeDuplicates: Used when the `Value` is set on `Source`. If this function is implemented
  ///     and returns `true`, no assignation will occur and `Source` will be kept untouched.
  public init<Value>(
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

  /// Initialized a `PropertyBinding` using a couble of `KeyPath` describing a similar property in
  /// `Source` and `Destination`. This binding is unidirectional (readonly on Source )and the
  /// `KeyPath<Source, Value` doesn't need to be writable.
  /// - Parameters:
  ///   - sourceValue: A `KeyPath` to get `Value` in `Source`
  ///   - destinationValue: A `KeyPath` to get and set `Value` in `Destination`
  public init<Value>(
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

#if swift(>=5.4)
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
///   var internalValue: Int = 0
/// }
/// ```
/// We can the use `StateBinding` to generate a `Destination` instance whose `value` will be synchronized
/// with the `title` value of `Source`:
/// ```
/// struct Source {
///   var title: String = "Hello! world"
///
///   private var _storage = Feature()
///   private static let _binding = StateBinding(\Self._storage) {
///     (\.title, \.value)
///   }
///
///   var feature: Feature {
///     get { Self._binding.get(self) }
///     set { Self._binding.set(&self, newValue) }
///   }
/// }
///
public struct StateBinding<Source, Destination> {
  /// Retrieve the storage in `source`, update it and returns the result.
  public let get: (_ source: Source) -> Destination
  /// Set the storage in `source` and update `source`.
  public let set: (_ source: inout Source, _ newValue: Destination) -> Void

  /// Initialize an binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for a `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties`
  /// are synchronized with `Source`.
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an instance of `Destination`, used to store
  ///   `Destination`'s internal properties.
  ///   - removeDuplicateStorage: A function used to compare private storage and avoid setting it in `Source` if unnecessary
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  public init(
    _ storage: WritableKeyPath<Source, Destination>,
    removeDuplicateStorage: ((Destination, Destination) -> Bool)? = nil,
    @PropertyBindingsBuilder <Source, Destination> properties: () -> [PropertyBinding<Source, Destination>]
  ) {
    let properties = properties()
    get = { source in
      var stored = source[keyPath: storage]
      properties.forEach { $0.get(source, &stored) }
      return stored
    }
    set = { source, newValue in
      if removeDuplicateStorage?(source[keyPath: storage], newValue) != true {
        source[keyPath: storage] = newValue
      }
      properties.forEach { $0.set(&source, newValue) }
    }
  }
  
  /// Initialize an binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for a `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties`
  /// are synchronized with `Source`.
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an instance of `Destination`, used to store
  ///   `Destination`'s internal properties.
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  /// Remark: this function is defined to maintain trailing closure syntax between Swift 5.3 and earlier versions.
  public init(
    _ storage: WritableKeyPath<Source, Destination>,
    @PropertyBindingsBuilder <Source, Destination> properties: () -> [PropertyBinding<Source, Destination>]
  ) {
    self = .init(storage, removeDuplicateStorage: nil, properties: properties)
  }

  /// Initialize a  computed binding between a parent state `Source` and a child state `Destination`. These derived states
  /// are used when all the properties of `Destination` can be individually stored in `Source`.
  /// - Parameters:
  ///   - source: The `Source`'s or parent state type
  ///   - destination: A function that returns an default instance of `Destination` (the child state)
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  public init(
    _ source: Source.Type,
    with destination: @escaping () -> Destination,
    @PropertyBindingsBuilder <Source, Destination> properties: () -> [PropertyBinding<Source, Destination>]
  ) {
    let properties = properties()
    get = { source in
      var destination = destination()
      properties.forEach { $0.get(source, &destination) }
      return destination
    }
    set = { source, newValue in
      properties.forEach { $0.set(&source, newValue) }
    }
  }

  /// Initialize an binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for an optional `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties` are synchronized
  /// with `Source`. If the child is set to nil, source properties other than the storage property are kept untouched
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an instance of `Destination?`, used to store
  ///   `Destination`'s internal properties. If this instance is nil, the computed property will be also nil.
  ///   - removeDuplicateStorage: A function used to compare private storage and avoid setting it in `Source` if unnecessary
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  public init<UnwrappedDestination>(
    _ storage: WritableKeyPath<Source, Destination>,
    removeDuplicateStorage: ((Destination, Destination) -> Bool)? = nil,
    @PropertyBindingsBuilder <Source, UnwrappedDestination> properties: () -> [PropertyBinding<Source, UnwrappedDestination>]
  ) where Destination == UnwrappedDestination? {
    let properties = properties()
    get = { source in
      guard var stored = source[keyPath: storage] else { return nil }
      properties.forEach { $0.get(source, &stored) }
      return stored
    }
    set = { source, newValue in
      if removeDuplicateStorage?(source[keyPath: storage], newValue) != true {
        source[keyPath: storage] = newValue
      }
      guard let newValue = newValue else { return }
      properties.forEach { $0.set(&source, newValue) }
    }
  }

  /// Initialize a  computed binding between a parent state `Source` and an optional child state `Destination`
  /// These derived states are used when all the properties of `Destination` can be individually stored in `Source`.
  /// If the child is set to nil, the source properties are kept untouched
  /// - Parameters:
  ///   - destination: A function that returns an default instance of `Destination`(the child state) or nil.
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  public init<UnwrappedDestination>(
    with destination: @escaping (Source) -> Destination,
    @PropertyBindingsBuilder <Source, UnwrappedDestination> properties: () -> [PropertyBinding<Source, UnwrappedDestination>] = { [] }
  ) where Destination == UnwrappedDestination? {
    let properties = properties()
    get = { source in
      guard var destination = destination(source) else { return nil }
      properties.forEach { $0.get(source, &destination) }
      return destination
    }
    set = { source, newValue in
      guard let newValue = newValue else { return }
      properties.forEach { $0.set(&source, newValue) }
    }
  }
}

@resultBuilder public enum PropertyBindingsBuilder<Source, Destination> {
  /// Initialize a `PropertyBinding<Source, Destination>` from a couple of `WritableKeyPath`
  public static func buildExpression<Value>(_ expression: (WritableKeyPath<Source, Value>, WritableKeyPath<Destination, Value>)
  ) -> [PropertyBinding<Source, Destination>] {
    [PropertyBinding(expression.0, expression.1)]
  }

  /// Initialize a readonly `PropertyBinding<Source, Destination>` from a couple`(KeyPath,WritableKeyPath)`.
  public static func buildExpression<Value>(readonly expression: (KeyPath<Source, Value>, WritableKeyPath<Destination, Value>)
  ) -> [PropertyBinding<Source, Destination>] {
    [PropertyBinding(readonly: expression.0, expression.1)]
  }

  /// Initialize a  deduplicating`PropertyBinding<Source, Destination>` from a couple of `WritableKeyPath<_, Value>`
  /// and a function `(Value, Value) -> Bool` which returns `true` when both argurments are duplicates.
  public static func buildExpression<Value>(_ expression: (WritableKeyPath<Source, Value>, WritableKeyPath<Destination, Value>, (Value, Value) -> Bool)
  ) -> [PropertyBinding<Source, Destination>] {
    [PropertyBinding(expression.0, expression.1, removeDuplicates: expression.2)]
  }

  public static func buildExpression(_ expression: PropertyBinding<Source, Destination>) -> [PropertyBinding<Source, Destination>] {
    [expression]
  }
  
  public static func buildExpression(_ expression: [PropertyBinding<Source, Destination>]) -> [PropertyBinding<Source, Destination>] {
    expression
  }

  public static func buildBlock(_ components: [PropertyBinding<Source, Destination>]...) -> [PropertyBinding<Source, Destination>] {
    components.flatMap { $0 }
  }

  public static func buildArray(_ components: [[PropertyBinding<Source, Destination>]]) -> [PropertyBinding<Source, Destination>] {
    components.flatMap { $0 }
  }

  public static func buildEither(first component: [PropertyBinding<Source, Destination>]) -> [PropertyBinding<Source, Destination>] {
    component
  }

  public static func buildEither(second component: [PropertyBinding<Source, Destination>]) -> [PropertyBinding<Source, Destination>] {
    component
  }

  public static func buildOptional(_ component: [PropertyBinding<Source, Destination>]?) -> [PropertyBinding<Source, Destination>] {
    component ?? []
  }
}
#else

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
///   var internalValue: Int = 0
/// }
/// ```
/// We can the use `StateBinding` to generate a `Destination` instance whose `value` will be synchronized
/// with the `title` value of `Source`:
/// ```
/// struct Source {
///   var title: String = "Hello! world"
///
///   private var _storage = Feature()
///   private static let _binding = StateBinding(\Self._storage) {
///     (\.title, \.value)
///   }
///
///   var feature: Feature {
///     get { Self._binding.get(self) }
///     set { Self._binding.set(&self, newValue) }
///   }
/// }
///
public struct StateBinding<Source, Destination> {
  /// Retrieve the storage in `source`, update it and returns the result.
  public let get: (_ source: Source) -> Destination
  /// Set the storage in `source` and update `source`.
  public let set: (_ source: inout Source, _ newValue: Destination) -> Void

  /// Initialize an binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for a `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties`
  /// are synchronized with `Source`.
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an instance of `Destination`, used to store
  ///   `Destination`'s internal properties.
  ///   - removeDuplicateStorage: A function used to compare private storage and avoid setting it in `Source` if unnecessary
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  public init(
    _ storage: WritableKeyPath<Source, Destination>,
    removeDuplicateStorage: ((Destination, Destination) -> Bool)? = nil,
    properties: () -> [PropertyBinding<Source, Destination>]
  ) {
    let properties = properties()
    get = { source in
      var stored = source[keyPath: storage]
      properties.forEach { $0.get(source, &stored) }
      return stored
    }
    set = { source, newValue in
      if removeDuplicateStorage?(source[keyPath: storage], newValue) != true {
        source[keyPath: storage] = newValue
      }
      properties.forEach { $0.set(&source, newValue) }
    }
  }

  /// Initialize a  computed binding between a parent state `Source` and a child state `Destination`. These derived states
  /// are used when all the properties of `Destination` can be individually stored in `Source`.
  /// - Parameters:
  ///   - source: The `Source`'s or parent state type
  ///   - destination: A function that returns an default instance of `Destination` (the child state)
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  public init(
    _ source: Source.Type,
    with destination: @escaping () -> Destination,
    properties: () -> [PropertyBinding<Source, Destination>]
  ) {
    let properties = properties()
    get = { source in
      var destination = destination()
      properties.forEach { $0.get(source, &destination) }
      return destination
    }
    set = { source, newValue in
      properties.forEach { $0.set(&source, newValue) }
    }
  }

  /// Initialize an binding between a parent state `Source` and a child state `Destination`.
  /// A private storage for an optional `Source` is provided so unaffected properties are preserved between accesses.
  /// In other words, `Destination` can have private fields and only properties specified in `properties` are synchronized
  /// with `Source`. If the child is set to nil, source properties other than the storage property are kept untouched
  /// - Parameters:
  ///   - storage: A writable (private) keyPath to an instance of `Destination?`, used to store
  ///   `Destination`'s internal properties. If this instance is nil, the computed property will be also nil.
  ///   - removeDuplicateStorage: A function used to compare private storage and avoid setting it in `Source` if unnecessary
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  public init<UnwrappedDestination>(
    _ storage: WritableKeyPath<Source, Destination>,
    removeDuplicateStorage: ((Destination, Destination) -> Bool)? = nil,
    properties: () -> [PropertyBinding<Source, UnwrappedDestination>]
  ) where Destination == UnwrappedDestination? {
    let properties = properties()
    get = { source in
      guard var stored = source[keyPath: storage] else { return nil }
      properties.forEach { $0.get(source, &stored) }
      return stored
    }
    set = { source, newValue in
      if removeDuplicateStorage?(source[keyPath: storage], newValue) != true {
        source[keyPath: storage] = newValue
      }
      guard let newValue = newValue else { return }
      properties.forEach { $0.set(&source, newValue) }
    }
  }

  /// Initialize a  computed binding between a parent state `Source` and an optional child state `Destination`
  /// These derived states are used when all the properties of `Destination` can be individually stored in `Source`.
  /// If the child is set to nil, the source properties are kept untouched
  /// - Parameters:
  ///   - destination: A function that returns an default instance of `Destination`(the child state) or nil.
  ///   - properties: A function that returns an array of `PropertyBinding<Source, Destination>`
  public init<UnwrappedDestination>(
    with destination: @escaping (Source) -> Destination,
    properties: () -> [PropertyBinding<Source, UnwrappedDestination>] = { [] }
  ) where Destination == UnwrappedDestination? {
    let properties = properties()
    get = { source in
      guard var destination = destination(source) else { return nil }
      properties.forEach { $0.get(source, &destination) }
      return destination
    }
    set = { source, newValue in
      guard let newValue = newValue else { return }
      properties.forEach { $0.set(&source, newValue) }
    }
  }
}

#endif
