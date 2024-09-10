#if canImport(Combine)
  import Combine
#endif

/// A property wrapper type that shares a value with multiple parts of an application.
///
/// See the <doc:SharingState> article for more detailed information on how to use this property
/// wrapper, in particular <doc:SharingState#Read-only-shared-state>.
@dynamicMemberLookup
@propertyWrapper
public struct SharedReader<Value: Sendable> {
  fileprivate let reference: any Reference
  fileprivate let keyPath: AnyKeyPath

  init(reference: any Reference, keyPath: AnyKeyPath) {
    self.reference = reference
    self.keyPath = keyPath
  }

  init(reference: some Reference<Value>) {
    self.init(reference: reference, keyPath: \Value.self)
  }

  /// Creates a read-only shared reference from another read-only shared reference.
  ///
  /// You don't call this initializer directly. Instead, Swift calls it for you when you use a
  /// property-wrapper attribute on a binding closure parameter.
  ///
  /// - Parameter projectedValue: A read-only shared reference.
  public init(projectedValue: SharedReader) {
    self = projectedValue
  }

  /// Unwraps a read-only shared reference to an optional value.
  ///
  /// ```swift
  /// @SharedReader(.currentUser) var currentUser: User?
  ///
  /// if let sharedCurrentUser = SharedReader($currentUser) {
  ///   sharedCurrentUser  // SharedReader<User>
  /// }
  /// ```
  ///
  /// - Parameter base: A read-only shared reference to an optional value.
  public init?(_ base: SharedReader<Value?>) {
    guard let initialValue = base.wrappedValue
    else { return nil }
    self.init(
      reference: base.reference,
      keyPath: base.keyPath.appending(path: \Value?.[default:DefaultSubscript(initialValue)])!
    )
  }

  /// Creates a read-only shared reference from a shared reference.
  ///
  /// - Parameter base: A shared reference.
  public init(_ base: Shared<Value>) {
    self = base.reader
  }

  /// Constructs a read-only shared value that remains constant.
  ///
  /// This can be useful for providing ``SharedReader`` values to features in previews and tests:
  ///
  /// ```swift
  /// #Preview {
  ///   FeatureView(
  ///     store: Store(
  ///       initialState: Feature.State(count: .constant(42))
  ///     ) {
  ///       Feature()
  ///     }
  ///   )
  /// )
  /// ```
  public static func constant(_ value: Value) -> Self {
    Shared(value).reader
  }

  /// The underlying value referenced by the shared variable.
  ///
  /// This property provides primary access to the value's data. However, you don't access
  /// `wrappedValue` directly. Instead, you use the property variable created with the
  /// ``SharedReader`` attribute. In the following example, the shared variable `topics` returns the
  /// value of `wrappedValue`:
  ///
  /// ```swift
  /// struct State {
  ///   @SharedReader var subscriptions: [Subscription]
  ///
  ///   var isSubscribed: Bool {
  ///     !subscriptions.isEmpty
  ///   }
  /// }
  /// ```
  public var wrappedValue: Value {
    func open<Root>(_ reference: some Reference<Root>) -> Value {
      reference.value[
        keyPath: unsafeDowncast(self.keyPath, to: KeyPath<Root, Value>.self)
      ]
    }
    return open(self.reference)
  }

  /// A projection of the read-only shared value that returns a shared reference.
  public var projectedValue: Self {
    get {
      reference.access()
      return self
    }
    set {
      reference.withMutation {
        self = newValue
      }
    }
  }

  /// Returns a shared reference to the resulting value of a given key path.
  public subscript<Member>(
    dynamicMember keyPath: KeyPath<Value, Member>
  ) -> SharedReader<Member> {
    SharedReader<Member>(reference: self.reference, keyPath: self.keyPath.appending(path: keyPath)!)
  }

  @_disfavoredOverload
  @available(
    *, deprecated, message: "Use 'SharedReader($value.optional)' to unwrap optional shared values"
  )
  public subscript<Member>(
    dynamicMember keyPath: KeyPath<Value, Member?>
  ) -> SharedReader<Member>? {
    SharedReader<Member>(self[dynamicMember: keyPath])
  }

  #if canImport(Combine)
    /// Returns a publisher that emits events when the underlying value changes.
    public var publisher: AnyPublisher<Value, Never> {
      func open<R: Reference>(_ reference: R) -> AnyPublisher<Value, Never> {
        return reference.publisher
          .compactMap { $0[keyPath: self.keyPath] as? Value }
          .eraseToAnyPublisher()
      }
      return open(self.reference)
    }
  #endif
}

extension SharedReader: @unchecked Sendable where Value: Sendable {}

extension SharedReader: Equatable where Value: Equatable {
  public static func == (lhs: SharedReader, rhs: SharedReader) -> Bool {
    lhs.wrappedValue == rhs.wrappedValue
  }
}

extension SharedReader: Hashable where Value: Hashable {
  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.wrappedValue)
  }
}

extension SharedReader: Identifiable where Value: Identifiable {
  public var id: Value.ID {
    self.wrappedValue.id
  }
}

extension SharedReader: Encodable where Value: Encodable {
  public func encode(to encoder: any Encoder) throws {
    do {
      var container = encoder.singleValueContainer()
      try container.encode(self.wrappedValue)
    } catch {
      try self.wrappedValue.encode(to: encoder)
    }
  }
}

extension SharedReader: CustomDumpRepresentable {
  public var customDumpValue: Any {
    self.wrappedValue
  }
}

extension SharedReader
where
  Value: RandomAccessCollection & MutableCollection,
  Value.Index: Hashable & Sendable,
  Value.Element: Sendable
{
  /// Derives a collection of read-only shared elements from a read-only shared collection of
  /// elements.
  ///
  /// See the documentation for [`@Shared`](<doc:Shared>)'s ``Shared/elements`` for more
  /// information.
  public var elements: some RandomAccessCollection<SharedReader<Value.Element>> {
    zip(self.wrappedValue.indices, self.wrappedValue).lazy.map { index, element in
      self[index, default: DefaultSubscript(element)]
    }
  }
}
