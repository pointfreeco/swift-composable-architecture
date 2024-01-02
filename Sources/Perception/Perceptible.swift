//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

/// A type that emits notifications to observers when underlying data changes.
///
/// Conforming to this protocol signals to other APIs that the type supports
/// observation. However, applying the `Perceptible` protocol by itself to a
/// type doesn't add observation functionality to the type. Instead, always use
/// the ``Perception/Perceptible()`` macro when adding observation
/// support to a type.
@available(iOS, deprecated: 17, message: "TODO")
@available(macOS, deprecated: 14, message: "TODO")
@available(tvOS, deprecated: 17, message: "TODO")
@available(watchOS, deprecated: 10, message: "TODO")
public protocol Perceptible {}

// TODO: Rename to Perceptive?
