#if swift(>=5.9)
  import Observation

  @attached(member, names: named(send))
  public macro WithViewStore<R: Reducer>(for: R.Type) = #externalMacro(
    module: "ComposableArchitectureMacros", type: "WithViewStoreMacro"
  ) where R.Action: ViewAction

  public protocol ViewAction<ViewAction> {
    associatedtype ViewAction
    static func view(_ action: ViewAction) -> Self
  }

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

  @attached(member, names: named(_$id), named(_$observationRegistrar), named(access), named(withMutation))
  @attached(memberAttribute)
  @attached(extension, conformances: Observable, ObservableState)
  public macro ObservableState() =
  #externalMacro(module: "ComposableArchitectureMacros", type: "ObservableStateMacro")

  @attached(accessor, names: named(init), named(get), named(set))
  @attached(peer, names: prefixed(_))
  public macro ObservationStateTracked() =
  #externalMacro(module: "ComposableArchitectureMacros", type: "ObservationStateTrackedMacro")

  @attached(accessor, names: named(willSet))
  public macro ObservationStateIgnored() =
  #externalMacro(module: "ComposableArchitectureMacros", type: "ObservationStateIgnoredMacro")

#endif
