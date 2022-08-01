import Foundation

#if swift(>=5.7)
  // MARK: swift(>=5.7)
  // MARK: Decodable

  func _decode(_ type: Any.Type, from data: Data) throws -> Any? {
    try (type as? any Decodable.Type)?.init(from: data)
  }

  private extension Decodable {
    init(from data: Data) throws {
      self = try decoder.decode(Self.self, from: data)
    }
  }

  // MARK: Encodable

  func _encode(_ value: Any) throws -> Data? {
    try (value as? any Encodable)?.encode()
  }

  private extension Encodable {
    func encode() throws -> Data {
      try encoder.encode(self)
    }
  }

  // MARK: Equatable

  func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
    (lhs as? any Equatable)?.isEqual(other: rhs)
  }

  private extension Equatable {
    func isEqual(other: Any) -> Bool {
      self == other as? Self
    }
  }
#else
  // MARK: -
  // MARK: swift(<5.7)

  private enum Witness<T> {}

  // MARK: Decodable

  func _decode(_ type: Any.Type, from data: Data) throws -> Any? {
    func open<T>(_: T.Type) throws -> Any? {
      try (Witness<T>.self as? AnyDecodable.Type)?.decode(from: data)
    }
    return try _openExistential(type, do: open)
  }

  private protocol AnyDecodable {
    static func decode(from data: Data) throws -> Any
  }

  extension Witness: AnyDecodable where T: Decodable {
    static func decode(from data: Data) throws -> Any {
      try decoder.decode(T.self, from: data)
    }
  }

  // MARK: Encodable

  func _encode(_ value: Any) throws -> Data? {
    func open<T>(_: T.Type) throws -> Data? {
      try (Witness<T>.self as? AnyEncodable.Type)?.encode(value)
    }
    return try _openExistential(type(of: value), do: open)
  }

  private protocol AnyEncodable {
    static func encode(_ value: Any) throws -> Data?
  }

  extension Witness: AnyEncodable where T: Encodable {
    static func encode(_ value: Any) throws -> Data? {
      try (value as? T).map(encoder.encode)
    }
  }

  // MARK: Equatable

  func _isEqual(_ lhs: Any, _ rhs: Any) -> Bool? {
    func open<T>(_: T.Type) -> Bool? {
      (Witness<T>.self as? AnyEquatable.Type)?.isEqual(lhs, rhs)
    }
    return _openExistential(type(of: lhs), do: open)
  }

  private protocol AnyEquatable {
    static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
  }

  extension Witness: AnyEquatable where T: Equatable {
    fileprivate static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
      guard
        let lhs = lhs as? T,
        let rhs = rhs as? T
      else { return false }
      return lhs == rhs
    }
  }
#endif

private let decoder = JSONDecoder()
private let encoder = JSONEncoder()
