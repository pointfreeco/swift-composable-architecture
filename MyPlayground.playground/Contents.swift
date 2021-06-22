@testable import ComposableArchitecture

extension Int: Identifiable { public var id: Self { self } }

var a: ComposableArchitecture._IdentifiedArray<Int> = []
a.append(1)
a.append(2)
a.append(3)

a.remove(at: 0)

a._ids
a._elements
