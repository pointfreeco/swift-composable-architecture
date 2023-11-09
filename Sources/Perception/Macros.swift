#if canImport(Observation)
import Observation

@available(iOS, deprecated: 17, message: "TODO")
@attached(member, names: named(_$id), named(_$perceptionRegistrar), named(access), named(withMutation))
@attached(memberAttribute)
@attached(extension, conformances: Observable, Perceptible)
public macro Perceptible() =
#externalMacro(module: "PerceptionMacros", type: "PerceptibleMacro")

@available(iOS, deprecated: 17, message: "TODO")
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(_))
public macro PerceptionTracked() =
#externalMacro(module: "PerceptionMacros", type: "PerceptionTrackedMacro")

@available(iOS, deprecated: 17, message: "TODO")
@attached(accessor, names: named(willSet))
public macro PerceptionIgnored() =
#externalMacro(module: "PerceptionMacros", type: "PerceptionIgnoredMacro")
#endif
