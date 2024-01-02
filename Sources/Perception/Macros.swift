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

#if canImport(Observation)
  import Observation

  @available(iOS, deprecated: 17, message: "TODO")
  @available(macOS, deprecated: 14, message: "TODO")
  @available(tvOS, deprecated: 17, message: "TODO")
  @available(watchOS, deprecated: 10, message: "TODO")
  @attached(
    member, names: named(_$id), named(_$perceptionRegistrar), named(access), named(withMutation))
  @attached(memberAttribute)
  @attached(extension, conformances: Observable, Perceptible)
  public macro Perceptible() =
    #externalMacro(module: "PerceptionMacros", type: "PerceptibleMacro")

  @available(iOS, deprecated: 17, message: "TODO")
  @available(macOS, deprecated: 14, message: "TODO")
  @available(tvOS, deprecated: 17, message: "TODO")
  @available(watchOS, deprecated: 10, message: "TODO")
  @attached(accessor, names: named(init), named(get), named(set))
  @attached(peer, names: prefixed(_))
  public macro PerceptionTracked() =
    #externalMacro(module: "PerceptionMacros", type: "PerceptionTrackedMacro")

  @available(iOS, deprecated: 17, message: "TODO")
  @available(macOS, deprecated: 14, message: "TODO")
  @available(tvOS, deprecated: 17, message: "TODO")
  @available(watchOS, deprecated: 10, message: "TODO")
  @attached(accessor, names: named(willSet))
  public macro PerceptionIgnored() =
    #externalMacro(module: "PerceptionMacros", type: "PerceptionIgnoredMacro")
#endif
