extension AnyKeyPath: CustomDebugOutputConvertible {
  public var debugOutput: String {
    guard let name = keyPathToName[self] else {
      func reflectName() -> String {
        var namedKeyPaths = Reflection.allNamedKeyPaths(forUnderlyingTypeOf: Self.rootType)
        while !namedKeyPaths.isEmpty {
          let (name, keyPath) = namedKeyPaths.removeFirst()
          if keyPath == self { return "\\\(Self.rootType).\(name)" }
          let valueType = type(of: keyPath).valueType
          let valueNamedKeyPaths = Reflection.allNamedKeyPaths(forUnderlyingTypeOf: valueType)
          for (valueName, valueKeyPath) in valueNamedKeyPaths {
            if let appendedKeyPath = keyPath.appending(path: valueKeyPath) {
              namedKeyPaths.append(("\(name).\(valueName)", appendedKeyPath))
            }
          }
        }
        return String(describing: type(of: self))
      }
      let name = reflectName()
      keyPathToName[self] = name
      return name
    }
    return name
  }
}

private var keyPathToName: [AnyKeyPath: String] = [:]

//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

private protocol RelativePointer {
  associatedtype Pointee

  var offset: Int32 { get }

  func address(from ptr: UnsafeRawPointer) -> UnsafePointer<Pointee>
  func pointee(from ptr: UnsafeRawPointer) -> Pointee?
}

private extension RelativePointer {
  func address(from ptr: UnsafeRawPointer) -> UnsafePointer<Pointee> {
    let newPtr = UnsafeRawPointer(
      bitPattern: UInt(bitPattern: ptr) &+ UInt(bitPattern: Int(offset)))!
    return newPtr.assumingMemoryBound(to: Pointee.self)
  }
}

private struct RelativeDirectPointer<Pointee>: RelativePointer {
  let offset: Int32

  func pointee(from ptr: UnsafeRawPointer) -> Pointee? {
    guard offset != 0 else {
      return nil
    }

    return address(from: ptr).pointee
  }
}

private extension UnsafeRawPointer {
  func relativeDirect<T>(as type: T.Type) -> UnsafePointer<T> {
    let relativePointer = RelativeDirectPointer<T>(
      offset: load(as: Int32.self)
    )
    return relativePointer.address(from: self)
  }
}

private struct RelativeIndirectPointer<T>: RelativePointer {
  typealias Pointee = UnsafePointer<T>

  let offset: Int32

  func pointee(from ptr: UnsafeRawPointer) -> Pointee? {
    guard offset != 0 else {
      return nil
    }

    return address(from: ptr).pointee
  }
}

private struct RelativeIndirectablePointer<Pointee>: RelativePointer {
  let offset: Int32

  func address(from ptr: UnsafeRawPointer) -> UnsafePointer<Pointee> {
    UnsafePointer<Pointee>((ptr + Int(offset & ~1))._rawValue)
  }

  func pointee(from ptr: UnsafeRawPointer) -> Pointee? {
    guard offset != 0 else {
      return nil
    }

    if offset & 1 == 1 {
      let pointer = UnsafeRawPointer(address(from: ptr))
                      .load(as: UnsafePointer<Pointee>.self)
      return pointer.pointee
    } else {
      return address(from: ptr).pointee
    }
  }
}

//===----------------------------------------------------------------------===//
// Metadata Structures
//===----------------------------------------------------------------------===//

// MetadataKind is the discriminator value found at the start of all metadata
// records to determine what kind is a metadata.
private enum MetadataKind: Int {
  case `class` = 0
  case `struct` = 512
}

// Metadata refers to the runtime representation of a type in Swift. This
// protocol is the generic version handed out by various methods to retrieve
// metadata from types.
private protocol Metadata {
  // The required backing pointer which points at the metadata record.
  var pointer: UnsafeRawPointer { get }

  // The discriminator which determines what kind of metadata this is.
  var kind: MetadataKind { get }
}

private extension Metadata {
  // The type representation of the metadata.
  var type: Any.Type {
    unsafeBitCast(pointer, to: Any.Type.self)
  }
}

// Given an arbitrary type of anything, produce the metadata that represents
// said type.
// FIXME: Right now this only supports structs and class types, but in the
// future if we ever want to produce keypaths for tuples, enums, etc. handle
// that here.
private func getMetadata(for type: Any.Type) -> Metadata? {
  let pointer = unsafeBitCast(type, to: UnsafeRawPointer.self)
  let int = pointer.load(as: Int.self)

  guard let kind = MetadataKind(rawValue: int) else {
    // If the metadata kind is greater than 2047, then it's an ISA pointer
    // meaning we have some class metadata.
    guard int > 2047 else {
      return nil
    }

    return ClassMetadata(pointer: pointer)
  }

  switch kind {
  case .class:
    return ClassMetadata(pointer: pointer)
  case .struct:
    return StructMetadata(pointer: pointer)
  }
}

// Type Metadata

// Type Metadata is a more specialized metadata in that only struct, class, and
// enum types conform to. There's more detail about the type and its properties
// in the context descriptors, the generic types that make up said type, etc.
private protocol TypeMetadata: Metadata {}

private extension TypeMetadata {
  // The context descriptors describes more in detail about the type. Some of
  // this information includes number of properties, the property names, the
  // name of this type, generic requirements, etc.
  var contextDescriptor: TypeContextDescriptor {
    switch self {
    case let structMetadata as StructMetadata:
      return structMetadata.descriptor
    case let classMetadata as ClassMetadata:
      return classMetadata.descriptor
    default:
      fatalError("TypeMetadata conformance we don't know about?")
    }
  }

  // An array of integers that represent the offset to a certain field. This
  // corresponds to the index of fields in the field descriptor.
  var fieldOffsets: [Int] {
    switch self {
    case let structMetadata as StructMetadata:
      return structMetadata.fieldOffsets
    case let classMetadata as ClassMetadata:
      return classMetadata.fieldOffsets
    default:
      fatalError("TypeMetadata conformance we don't know about?")
    }
  }

  // The pointer to the beginning of this type's generic arguments.
  var genericArgumentPointer: UnsafeRawPointer {
    switch self {
    case is StructMetadata:
      return pointer + MemoryLayout<_StructMetadata>.size
    case let classMetadata as ClassMetadata:
      let descriptor = classMetadata.descriptor

      guard !descriptor.typeFlags.classHasResilientSuperclass else {
        let memberOffset = descriptor.resilientBounds._immediateMembersOffset
        return pointer + memberOffset
      }

      let negativeSize = descriptor.negativeSize
      let positiveSize = descriptor.positiveSize
      let numImmediateMembers = descriptor.numImmediateMembers

      if descriptor.typeFlags.classAreImmediateMembersNegative {
        return pointer + MemoryLayout<Int>.size * -negativeSize
      } else {
        return pointer + MemoryLayout<Int>.size *
          (positiveSize - numImmediateMembers)
      }
    default:
      fatalError("TypeMetadata conformance we don't know about?")
    }
  }

  // Given a mangled name (preferrably one of the property type name's), return
  // the type as represented by the mangled name within this type's context.
  func type(of mangledName: UnsafePointer<CChar>) -> Any.Type? {
    let type = _getTypeByMangledNameInContext(
      UnsafePointer<UInt8>(mangledName._rawValue),
      UInt(getSymbolicMangledNameLength(UnsafeRawPointer(mangledName))),
      genericContext: contextDescriptor.pointer,
      genericArguments: genericArgumentPointer
    )

    return type
  }
}

// Struct Metadata

// Struct Metadata refers to types whom are implemented via a struct. Consider
// the standard library type 'Int', it's implemented using a struct, so getting
// the type metadata for that type will return an instance of struct metadata.
private struct StructMetadata: TypeMetadata, LayoutWrapper {
  typealias Layout = _StructMetadata

  // The backing metadata pointer.
  let pointer: UnsafeRawPointer

  // The metadata discriminator.
  var kind: MetadataKind {
    .struct
  }

  // The context descriptor of this struct.
  var descriptor: StructDescriptor {
    layout.descriptor
  }

  // An array of integers with the offsets for each stored field in this struct.
  var fieldOffsets: [Int] {
    let fieldOffsetVectorOffset = descriptor.fieldOffsetVectorOffset
    let start = pointer + MemoryLayout<Int>.size * fieldOffsetVectorOffset
    let buffer = UnsafeBufferPointer<UInt32>(
      start: UnsafePointer<UInt32>(start._rawValue),
      count: descriptor.numFields
    )
    return Array(buffer).map { Int($0) }
  }
}

private struct _StructMetadata {
  let kind: Int
  let descriptor: StructDescriptor
}

// Class Metadata

// Class Metadata refers to types whom are implemented via a class. Consider
// the standard library type 'KeyPath', it's implemented using a class, so
// getting the type metadata for that type will return an instance of class
// metadata.
private struct ClassMetadata: TypeMetadata, LayoutWrapper {
  typealias Layout = _ClassMetadata

  // The backing metadata pointer.
  let pointer: UnsafeRawPointer

  // The metadata discriminator.
  var kind: MetadataKind {
    .class
  }

  // The context descriptor of this class.
  var descriptor: ClassDescriptor {
    layout._descriptor
  }

  // An array of integers with the offsets for each stored field in this class.
  var fieldOffsets: [Int] {
    let fieldOffsetVectorOffset = descriptor.fieldOffsetVectorOffset
    let start = pointer + MemoryLayout<Int>.size * fieldOffsetVectorOffset
    let buffer = UnsafeBufferPointer<Int>(
      start: UnsafePointer<Int>(start._rawValue),
      count: descriptor.numFields
    )
    return Array(buffer)
  }

  // The required size of instances of this type.
  var instanceSize: Int {
    Int(layout._instanceSize)
  }

  // The alignment mask of the address point for instances of this type.
  var instanceAlignMask: Int {
    Int(layout._instanceAlignMask)
  }
}

private struct _ClassMetadata {
  let _kind: Int
  let _superclass: Any.Type?
  let _reserved: (Int, Int)
  let _rodata: Int
  let _flags: UInt32
  let _instanceAddressPoint: UInt32
  let _instanceSize: UInt32
  let _instanceAlignMask: UInt16
  let _runtimeReserved: UInt16
  let _classSize: UInt32
  let _classAddressPoint: UInt32
  let _descriptor: ClassDescriptor
}

//===----------------------------------------------------------------------===//
// Context Descriptor Structures
//===----------------------------------------------------------------------===//

// A context descriptor describes in entity in Swift who declares some context
// which other declarations can be declared within.
private protocol ContextDescriptor {
  // The backing context descriptor pointer.
  var pointer: UnsafeRawPointer { get }
}

private extension ContextDescriptor {
  // The base structural representation of a context descriptor.
  var _contextDescriptor: _ContextDescriptor {
    pointer.load(as: _ContextDescriptor.self)
  }

  // Flags that describe this context which include what kind it is, whether
  // or not it's a generic context, whether or not it's unique, etc.
  var flags: ContextDescriptorFlags {
    _contextDescriptor._flags
  }
}

private struct _ContextDescriptor {
  let _flags: ContextDescriptorFlags
  let _parent: RelativeIndirectablePointer<_ContextDescriptor>
}

// Flags that describe this context which include what kind it is, whether
// or not it's a generic context, whether or not it's unique, etc.
private struct ContextDescriptorFlags {
  // The backing integer representation of these flags.
  let bits: UInt32

  // The reserved bits for other flags that are interpretted differently by
  // conforming context descriptor types.
  var kindSpecificFlags: UInt16 {
    UInt16((bits >> 0x10) & 0xFFFF)
  }
}

// Type Context Descriptor

// A type context descriptor is a refined context descriptor who describes a
// type in Swift. This includes structs, classes, and enums. Protocols also
// define a new type in Swift, but aren't considered type contexts.
private protocol TypeContextDescriptor: ContextDescriptor {
  // The field descriptor that describes the stored representation of this type.
  var fields: FieldDescriptor { get }
}

private extension TypeContextDescriptor {
  // The base structural representation of a type context descriptor.
  var _typeDescriptor: _TypeContextDescriptor {
    pointer.load(as: _TypeContextDescriptor.self)
  }

  // The field descriptor that describes the stored representation of this type.
  var fields: FieldDescriptor {
    let offset = pointer.advanced(by: MemoryLayout<Int32>.size * 4)
    let address = UnsafeRawPointer(_typeDescriptor._fields.address(from: offset))
    return FieldDescriptor(signedPointer: address)
  }

  // Certain flags specific to types in Swift, such as whether or not a class
  // has a resilient superclass.
  var typeFlags: TypeContextDescriptorFlags {
    TypeContextDescriptorFlags(bits: flags.kindSpecificFlags)
  }
}

private struct _TypeContextDescriptor {
  let _base: _ContextDescriptor
  let _name: RelativeDirectPointer<CChar>
  let _accessor: RelativeDirectPointer<UnsafeRawPointer>
  let _fields: RelativeDirectPointer<_FieldDescriptor>
}

// Certain flags specific to types in Swift, such as whether or not a class
// has a resilient superclass.
private struct TypeContextDescriptorFlags {
  // The backing integer representation of these flags.
  let bits: UInt16

  // Whether or not the class's members are negative.
  var classAreImmediateMembersNegative: Bool {
    bits & 0x1000 != 0
  }

  // Whether or not the class has a resilient superclass.
  var classHasResilientSuperclass: Bool {
    bits & 0x2000 != 0
  }
}

// Struct Descriptor

// A struct descriptor that describes some structure context.
private struct StructDescriptor: TypeContextDescriptor, PointerAuthenticatedLayoutWrapper {
  typealias Layout = _StructDescriptor

  // The backing context descriptor pointer.
  let signedPointer: UnsafeRawPointer

  // The offset to the field offset vector found in the metadata.
  var fieldOffsetVectorOffset: Int {
    Int(layout._fieldOffsetVectorOffset)
  }

  // The number of stored properties this struct has.
  var numFields: Int {
    Int(layout._numFields)
  }
}

private struct _StructDescriptor {
  let _base: _TypeContextDescriptor
  let _numFields: UInt32
  let _fieldOffsetVectorOffset: UInt32
}

// Class Descriptor

// A class descriptor that descibes some class context.
private struct ClassDescriptor: TypeContextDescriptor, PointerAuthenticatedLayoutWrapper {
  typealias Layout = _ClassDescriptor

  // The backing context descriptor pointer.
  let signedPointer: UnsafeRawPointer

  // The offset to the field offset vector found in the metadata.
  var fieldOffsetVectorOffset: Int {
    Int(layout._fieldOffsetVectorOffset)
  }

  // The negative size of the metadata objects in this class.
  var negativeSize: Int {
    assert(!typeFlags.classHasResilientSuperclass)
    return Int(layout._negativeSizeOrResilientBounds)
  }

  // The number of stored properties this class defines.
  var numFields: Int {
    Int(layout._numFields)
  }

  // The total number of members this class defines (not including it's
  // superclass, if it has one).
  var numImmediateMembers: Int {
    Int(layout._numImmediateMembers)
  }

  // The positive size of the metadata objects in this class.
  var positiveSize: Int {
    assert(!typeFlags.classHasResilientSuperclass)
    return Int(layout._positiveSizeOrExtraFlags)
  }

  // The resilient bounds for this class.
  var resilientBounds: _StoredClassMetadataBounds {
    let addr = address(for: \._negativeSizeOrResilientBounds)
    let pointer = UnsafeRawPointer(addr)
    return pointer.relativeDirect(as: _StoredClassMetadataBounds.self).pointee
  }
}

private struct _ClassDescriptor {
  let _base: _TypeContextDescriptor
  let _superclassMangledName: RelativeDirectPointer<CChar>
  let _negativeSizeOrResilientBounds: Int32
  let _positiveSizeOrExtraFlags: Int32
  let _numImmediateMembers: UInt32
  let _numFields: UInt32
  let _fieldOffsetVectorOffset: UInt32
}

private struct _StoredClassMetadataBounds {
  let _immediateMembersOffset: Int
}

// Field Descriptor

// A special descriptor that describes a type's fields.
private struct FieldDescriptor: PointerAuthenticatedLayoutWrapper {
  typealias Layout = _FieldDescriptor

  // The backing field descriptor pointer.
  let signedPointer: UnsafeRawPointer

  // The number of fields this type has. This could mean different things
  // depending on what kind of type this is found under. For example, this is
  // the number of stored properties found within a struct, but for enums this
  // is the number of cases.
  var numFields: Int {
    Int(layout._numFields)
  }

  // An array of the field record information. Field record information contains
  // things like it's mangled type, whether or not its a var, indirect, etc.
  var records: [FieldRecord] {
    var result = [FieldRecord]()
    result.reserveCapacity(numFields)

    for i in 0 ..< numFields {
      let address = trailing + MemoryLayout<_FieldRecord>.size * i
      result.append(FieldRecord(signedPointer: address))
    }

    return result
  }
}

// A record that describes a single stored property or an enum case.
private struct FieldRecord: PointerAuthenticatedLayoutWrapper {
  typealias Layout = _FieldRecord

  // The backing field record pointer.
  let signedPointer: UnsafeRawPointer

  // The flags that describe this field record.
  var flags: FieldRecordFlags {
    layout._flags
  }

  // The mangled type name that demangles to the field's type.
  var mangledTypeName: UnsafePointer<CChar> {
    address(for: \._mangledTypeName)
  }

  // The name of the stored property/enum case.
  var name: String {
    String(cString: address(for: \._fieldName))
  }
}

private struct _FieldDescriptor {
  let _mangledTypeName: RelativeDirectPointer<CChar>
  let _superclassMangledTypeName: RelativeDirectPointer<CChar>
  let _kind: UInt16
  let _recordSize: UInt16
  let _numFields: UInt32
}

private struct _FieldRecord {
  let _flags: FieldRecordFlags
  let _mangledTypeName: RelativeDirectPointer<CChar>
  let _fieldName: RelativeDirectPointer<CChar>
}

// The flags which describe a field record.
private struct FieldRecordFlags {
  // The backing integer representation of these flags.
  let bits: UInt32

  // Whether or not this stored property is a var.
  var isVar: Bool {
    bits & 0x2 != 0
  }
}

//===----------------------------------------------------------------------===//
// Misc. Utilities
//===----------------------------------------------------------------------===//

private protocol LayoutWrapper {
  associatedtype Layout
  var pointer: UnsafeRawPointer { get }
}

private protocol PointerAuthenticatedLayoutWrapper: LayoutWrapper {
  var signedPointer: UnsafeRawPointer { get }
}

private extension PointerAuthenticatedLayoutWrapper {
  var pointer: UnsafeRawPointer {
    signedPointer
  }
}

private extension LayoutWrapper {
  var layout: Layout {
    pointer.load(as: Layout.self)
  }

  var trailing: UnsafeRawPointer {
    pointer + MemoryLayout<Layout>.size
  }

  func address<T>(for field: KeyPath<Layout, T>) -> UnsafePointer<T> {
    let offset = MemoryLayout<Layout>.offset(of: field)!
    return UnsafePointer<T>((pointer + offset)._rawValue)
  }

  func address<T: RelativePointer, U>(
    for field: KeyPath<Layout, T>
  ) -> UnsafePointer<U> where T.Pointee == U {
    let offset = MemoryLayout<Layout>.offset(of: field)!
    return layout[keyPath: field].address(from: pointer + offset)
  }
}

// This is a utility within KeyPath.swift in the standard library. If this
// gets moved into there, then this goes away, but will have to rethink if this
// goes into a different module.
private func getSymbolicMangledNameLength(_ base: UnsafeRawPointer) -> Int {
  var end = base
  while let current = Optional(end.load(as: UInt8.self)), current != 0 {
    // Skip the current character
    end = end + 1

    // Skip over a symbolic reference
    if current >= 0x1 && current <= 0x17 {
      end += 4
    } else if current >= 0x18 && current <= 0x1F {
      end += MemoryLayout<Int>.size
    }
  }

  return end - base
}

@_silgen_name("swift_allocObject")
internal func _allocObject(_: UnsafeMutableRawPointer, _: Int, _: Int) -> AnyObject?

// This is a utility within KeyPath.swift in the standard library. If this
// gets moved into there, then this goes away, but will have to rethink if this
// goes into a different module.
private extension AnyKeyPath {
  static func _create(
    capacityInBytes bytes: Int,
    initializedBy body: (UnsafeMutableRawBufferPointer) -> ()
  ) -> Self {
    assert(bytes > 0 && bytes % 4 == 0,
           "capacity must be multiple of 4 bytes")
    let metadata = getMetadata(for: self) as! ClassMetadata
    var size = metadata.instanceSize

    let tailStride = MemoryLayout<Int32>.stride
    let tailAlignMask = MemoryLayout<Int32>.alignment - 1

    size += tailAlignMask
    size &= ~tailAlignMask
    size += tailStride * (bytes / 4)

    let alignment = metadata.instanceAlignMask | tailAlignMask

    let object = _allocObject(
      UnsafeMutableRawPointer(mutating: metadata.pointer),
      size,
      alignment
    )

    guard object != nil else {
      fatalError("Allocating \(self) instance failed for keypath reflection")
    }

    // This memory layout of Int by 2 is the size of a heap object which object
    // points to. Tail members appear immediately afterwards.
    let base = unsafeBitCast(object, to: UnsafeMutableRawPointer.self) + MemoryLayout<Int>.size * 2

    // The first word is the kvc string pointer. Set it to 0 (nil).
    base.storeBytes(of: 0, as: Int.self)

    // Return an offseted base after the kvc string pointer.
    let newBase = base + MemoryLayout<Int>.size
    let newBytes = bytes - MemoryLayout<Int>.size

    body(UnsafeMutableRawBufferPointer(start: newBase, count: newBytes))

    return unsafeBitCast(object, to: self)
  }
}

// Helper struct to represent the keypath buffer header. This structure is also
// found within KeyPath.swift, so if this gets moved there this goes away.
private struct KeyPathBufferHeader {
  let bits: UInt32

  init(hasReferencePrefix: Bool, isTrivial: Bool, size: UInt32) {
    var bits = size

    if hasReferencePrefix {
      bits |= 0x40000000
    }

    if isTrivial {
      bits |= 0x80000000
    }

    self.bits = bits
  }
}

// This initializes the raw keypath buffer with the field offset information.
private func instantiateKeyPathBuffer(
  _ metadata: TypeMetadata,
  _ leafIndex: Int,
  _ data: UnsafeMutableRawBufferPointer
) {
  let header = KeyPathBufferHeader(
    hasReferencePrefix: false,
    isTrivial: true,
    size: UInt32(MemoryLayout<UInt32>.size)
  )

  data.storeBytes(of: header, as: KeyPathBufferHeader.self)

  var componentBits = UInt32(metadata.fieldOffsets[leafIndex])
  componentBits |= metadata.kind == .struct ? 1 << 24 : 3 << 24

  data.storeBytes(
    of: componentBits,
    toByteOffset: MemoryLayout<Int>.size,
    as: UInt32.self
  )
}

// Returns a concrete type for which this keypath is going to be given a root
// and leaf type.
private func getKeyPathType(
  from root: TypeMetadata,
  for leaf: FieldRecord
) -> AnyKeyPath.Type {
  let leafType = root.type(of: leaf.mangledTypeName)!

  func openRoot<Root>(_: Root.Type) -> AnyKeyPath.Type {
    func openLeaf<Value>(_: Value.Type) -> AnyKeyPath.Type {
      if leaf.flags.isVar {
        return root.kind == .class
          ? ReferenceWritableKeyPath<Root, Value>.self
          : WritableKeyPath<Root, Value>.self
      }
      return KeyPath<Root, Value>.self
    }
    return _openExistential(leafType, do: openLeaf)
  }
  return _openExistential(root.type, do: openRoot)
}

// Given a root type and a leaf index, create a concrete keypath object at
// runtime.
private func createKeyPath(root: TypeMetadata, leaf: Int) -> AnyKeyPath {
  let field = root.contextDescriptor.fields.records[leaf]

  let keyPathTy = getKeyPathType(from: root, for: field)
  let size = MemoryLayout<Int>.size * 3
  let instance = keyPathTy._create(capacityInBytes: size) {
    instantiateKeyPathBuffer(root, leaf, $0)
  }

  let heapObj = UnsafeRawPointer(Unmanaged.passUnretained(instance).toOpaque())
  let keyPath = unsafeBitCast(heapObj, to: AnyKeyPath.self)
  return keyPath
}

fileprivate enum Reflection {
  /// Returns the collection of all named key paths of this type.
  ///
  /// - Parameter value: A value of any type to return the stored key paths of.
  /// - Returns: An array of tuples with both the name and partial key path
  ///            for this value.
  static func allNamedKeyPaths(
    forUnderlyingTypeOf type: Any.Type
  ) -> [(name: String, keyPath: AnyKeyPath)] {
    guard let metadata = getMetadata(for: type) as? TypeMetadata else {
      return []
    }

    var result = [(name: String, keyPath: AnyKeyPath)]()
    result.reserveCapacity(metadata.contextDescriptor.fields.numFields)

    for i in 0 ..< metadata.contextDescriptor.fields.numFields {
      let name = metadata.contextDescriptor.fields.records[i].name
      let keyPath = createKeyPath(root: metadata, leaf: i)
      result.append((name: name, keyPath: keyPath))
    }

    return result
  }
}
