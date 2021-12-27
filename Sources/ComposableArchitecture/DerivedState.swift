
public protocol DerivedState {
    init(by valueForKeyPath: [PartialKeyPath<Self> : Any])
}

@propertyWrapper
public struct StateToDerivedStatePropertyMapping
<State, DerivedSubState: DerivedState, Value1, Value2, Value3, Value4, Value5, Value6, Value7, Value8, Value9, Value10, Value11, Value12, Value13, Value14, Value15, Value16>: Hashable {
    
    public static func == (
        lhs: StateToDerivedStatePropertyMapping<State, DerivedSubState, Value1, Value2, Value3, Value4, Value5, Value6, Value7, Value8, Value9, Value10, Value11, Value12, Value13, Value14, Value15, Value16>,
        rhs: StateToDerivedStatePropertyMapping<State, DerivedSubState, Value1, Value2, Value3, Value4, Value5, Value6, Value7, Value8, Value9, Value10, Value11, Value12, Value13, Value14, Value15, Value16>
    )-> Bool {
        if lhs.mapping1.0 != rhs.mapping1.0 || lhs.mapping1.1 != rhs.mapping1.1 { return false }
        guard let lhsMapping2 = lhs.mapping2, let rhsMapping2 = rhs.mapping2 else { return false }
        if lhsMapping2.0 != rhsMapping2.0 || lhsMapping2.1 != rhsMapping2.1 { return false }
        guard let lhsMapping3 = lhs.mapping3, let rhsMapping3 = rhs.mapping3 else { return false }
        if lhsMapping3.0 != rhsMapping3.0 || lhsMapping3.1 != rhsMapping3.1 { return false }
        guard let lhsMapping4 = lhs.mapping4, let rhsMapping4 = rhs.mapping4 else { return false }
        if lhsMapping4.0 != rhsMapping4.0 || lhsMapping4.1 != rhsMapping4.1 { return false }
        guard let lhsMapping5 = lhs.mapping5, let rhsMapping5 = rhs.mapping5 else { return false }
        if lhsMapping5.0 != rhsMapping5.0 || lhsMapping5.1 != rhsMapping5.1 { return false }
        guard let lhsMapping6 = lhs.mapping6, let rhsMapping6 = rhs.mapping6 else { return false }
        if lhsMapping6.0 != rhsMapping6.0 || lhsMapping6.1 != rhsMapping6.1 { return false }
        guard let lhsMapping7 = lhs.mapping7, let rhsMapping7 = rhs.mapping7 else { return false }
        if lhsMapping7.0 != rhsMapping7.0 || lhsMapping7.1 != rhsMapping7.1 { return false }
        guard let lhsMapping8 = lhs.mapping8, let rhsMapping8 = rhs.mapping8 else { return false }
        if lhsMapping8.0 != rhsMapping8.0 || lhsMapping8.1 != rhsMapping8.1 { return false }
        guard let lhsMapping9 = lhs.mapping9, let rhsMapping9 = rhs.mapping9 else { return false }
        if lhsMapping9.0 != rhsMapping9.0 || lhsMapping9.1 != rhsMapping9.1 { return false }
        guard let lhsMapping10 = lhs.mapping10, let rhsMapping10 = rhs.mapping10 else { return false }
        if lhsMapping10.0 != rhsMapping10.0 || lhsMapping10.1 != rhsMapping10.1 { return false }
        guard let lhsMapping11 = lhs.mapping11, let rhsMapping11 = rhs.mapping11 else { return false }
        if lhsMapping11.0 != rhsMapping11.0 || lhsMapping11.1 != rhsMapping11.1 { return false }
        guard let lhsMapping12 = lhs.mapping12, let rhsMapping12 = rhs.mapping12 else { return false }
        if lhsMapping12.0 != rhsMapping12.0 || lhsMapping12.1 != rhsMapping12.1 { return false }
        guard let lhsMapping13 = lhs.mapping13, let rhsMapping13 = rhs.mapping13 else { return false }
        if lhsMapping13.0 != rhsMapping13.0 || lhsMapping13.1 != rhsMapping13.1 { return false }
        guard let lhsMapping14 = lhs.mapping14, let rhsMapping14 = rhs.mapping14 else { return false }
        if lhsMapping14.0 != rhsMapping14.0 || lhsMapping14.1 != rhsMapping14.1 { return false }
        guard let lhsMapping15 = lhs.mapping15, let rhsMapping15 = rhs.mapping15 else { return false }
        if lhsMapping15.0 != rhsMapping15.0 || lhsMapping15.1 != rhsMapping15.1 { return false }
        guard let lhsMapping16 = lhs.mapping16, let rhsMapping16 = rhs.mapping16 else { return false }
        if lhsMapping16.0 != rhsMapping16.0 || lhsMapping16.1 != rhsMapping16.1 { return false }
        return true
    }
    
    private var mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>)
    private var mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?
    private var mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?
    private var mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?
    private var mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?
    private var mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?
    private var mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?
    private var mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?
    private var mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?
    private var mapping10: (WritableKeyPath<State, Value10>, KeyPath<DerivedSubState, Value10>)?
    private var mapping11: (WritableKeyPath<State, Value11>, KeyPath<DerivedSubState, Value11>)?
    private var mapping12: (WritableKeyPath<State, Value12>, KeyPath<DerivedSubState, Value12>)?
    private var mapping13: (WritableKeyPath<State, Value13>, KeyPath<DerivedSubState, Value13>)?
    private var mapping14: (WritableKeyPath<State, Value14>, KeyPath<DerivedSubState, Value14>)?
    private var mapping15: (WritableKeyPath<State, Value15>, KeyPath<DerivedSubState, Value15>)?
    private var mapping16: (WritableKeyPath<State, Value16>, KeyPath<DerivedSubState, Value16>)?
    
    public var wrappedValue: (derivedState: (State) -> DerivedSubState, mutate: (inout State, DerivedSubState) -> Void) {
        return (derivedState: derivedState, mutate: mutate)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>)
    ) where Value2 == Void, Value3 == Void, Value4 == Void, Value5 == Void, Value6 == Void, Value7 == Void, Value8 == Void, Value9 == Void, Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)
    ) where Value3 == Void, Value4 == Void, Value5 == Void, Value6 == Void, Value7 == Void, Value8 == Void, Value9 == Void, Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }

    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?
    ) where Value4 == Void, Value5 == Void, Value6 == Void, Value7 == Void, Value8 == Void, Value9 == Void, Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?
    ) where Value5 == Void, Value6 == Void, Value7 == Void, Value8 == Void, Value9 == Void, Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?
    ) where Value6 == Void, Value7 == Void, Value8 == Void, Value9 == Void, Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?
    ) where Value7 == Void, Value8 == Void, Value9 == Void, Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?
    ) where Value8 == Void, Value9 == Void, Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, nil, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?
    ) where Value9 == Void, Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, nil, nil, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?,
        _ mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?
    ) where Value10 == Void, Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, mapping9, nil, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?,
        _ mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?,
        _ mapping10: (WritableKeyPath<State, Value10>, KeyPath<DerivedSubState, Value10>)?
    ) where Value11 == Void, Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, mapping9, mapping10, nil, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?,
        _ mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?,
        _ mapping10: (WritableKeyPath<State, Value10>, KeyPath<DerivedSubState, Value10>)?,
        _ mapping11: (WritableKeyPath<State, Value11>, KeyPath<DerivedSubState, Value11>)?
    ) where Value12 == Void, Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, mapping9, mapping10, mapping11, nil, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?,
        _ mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?,
        _ mapping10: (WritableKeyPath<State, Value10>, KeyPath<DerivedSubState, Value10>)?,
        _ mapping11: (WritableKeyPath<State, Value11>, KeyPath<DerivedSubState, Value11>)?,
        _ mapping12: (WritableKeyPath<State, Value12>, KeyPath<DerivedSubState, Value12>)?
    ) where Value13 == Void, Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, mapping9, mapping10, mapping11, mapping12, nil, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?,
        _ mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?,
        _ mapping10: (WritableKeyPath<State, Value10>, KeyPath<DerivedSubState, Value10>)?,
        _ mapping11: (WritableKeyPath<State, Value11>, KeyPath<DerivedSubState, Value11>)?,
        _ mapping12: (WritableKeyPath<State, Value12>, KeyPath<DerivedSubState, Value12>)?,
        _ mapping13: (WritableKeyPath<State, Value13>, KeyPath<DerivedSubState, Value13>)?
    ) where Value14 == Void, Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, mapping9, mapping10, mapping11, mapping12, mapping13, nil, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?,
        _ mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?,
        _ mapping10: (WritableKeyPath<State, Value10>, KeyPath<DerivedSubState, Value10>)?,
        _ mapping11: (WritableKeyPath<State, Value11>, KeyPath<DerivedSubState, Value11>)?,
        _ mapping12: (WritableKeyPath<State, Value12>, KeyPath<DerivedSubState, Value12>)?,
        _ mapping13: (WritableKeyPath<State, Value13>, KeyPath<DerivedSubState, Value13>)?,
        _ mapping14: (WritableKeyPath<State, Value14>, KeyPath<DerivedSubState, Value14>)?
    ) where Value15 == Void, Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, mapping9, mapping10, mapping11, mapping12, mapping13, mapping14, nil, nil)
    }
    
    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?,
        _ mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?,
        _ mapping10: (WritableKeyPath<State, Value10>, KeyPath<DerivedSubState, Value10>)?,
        _ mapping11: (WritableKeyPath<State, Value11>, KeyPath<DerivedSubState, Value11>)?,
        _ mapping12: (WritableKeyPath<State, Value12>, KeyPath<DerivedSubState, Value12>)?,
        _ mapping13: (WritableKeyPath<State, Value13>, KeyPath<DerivedSubState, Value13>)?,
        _ mapping14: (WritableKeyPath<State, Value14>, KeyPath<DerivedSubState, Value14>)?,
        _ mapping15: (WritableKeyPath<State, Value15>, KeyPath<DerivedSubState, Value15>)?
    ) where Value16 == Void {
        self.init(mapping1, mapping2, mapping3, mapping4, mapping5, mapping6, mapping7, mapping8, mapping9, mapping10, mapping11, mapping12, mapping13, mapping14, mapping15, nil)
    }

    public init(
        _ mapping1: (WritableKeyPath<State, Value1>, KeyPath<DerivedSubState, Value1>),
        _ mapping2: (WritableKeyPath<State, Value2>, KeyPath<DerivedSubState, Value2>)?,
        _ mapping3: (WritableKeyPath<State, Value3>, KeyPath<DerivedSubState, Value3>)?,
        _ mapping4: (WritableKeyPath<State, Value4>, KeyPath<DerivedSubState, Value4>)?,
        _ mapping5: (WritableKeyPath<State, Value5>, KeyPath<DerivedSubState, Value5>)?,
        _ mapping6: (WritableKeyPath<State, Value6>, KeyPath<DerivedSubState, Value6>)?,
        _ mapping7: (WritableKeyPath<State, Value7>, KeyPath<DerivedSubState, Value7>)?,
        _ mapping8: (WritableKeyPath<State, Value8>, KeyPath<DerivedSubState, Value8>)?,
        _ mapping9: (WritableKeyPath<State, Value9>, KeyPath<DerivedSubState, Value9>)?,
        _ mapping10: (WritableKeyPath<State, Value10>, KeyPath<DerivedSubState, Value10>)?,
        _ mapping11: (WritableKeyPath<State, Value11>, KeyPath<DerivedSubState, Value11>)?,
        _ mapping12: (WritableKeyPath<State, Value12>, KeyPath<DerivedSubState, Value12>)?,
        _ mapping13: (WritableKeyPath<State, Value13>, KeyPath<DerivedSubState, Value13>)?,
        _ mapping14: (WritableKeyPath<State, Value14>, KeyPath<DerivedSubState, Value14>)?,
        _ mapping15: (WritableKeyPath<State, Value15>, KeyPath<DerivedSubState, Value15>)?,
        _ mapping16: (WritableKeyPath<State, Value16>, KeyPath<DerivedSubState, Value16>)?
    ) {
        self.mapping1 = mapping1
        self.mapping2 = mapping2
        self.mapping3 = mapping3
        self.mapping4 = mapping4
        self.mapping5 = mapping5
        self.mapping6 = mapping6
        self.mapping7 = mapping7
        self.mapping8 = mapping8
        self.mapping9 = mapping9
        self.mapping10 = mapping10
        self.mapping11 = mapping11
        self.mapping12 = mapping12
        self.mapping13 = mapping13
        self.mapping14 = mapping14
        self.mapping15 = mapping15
        self.mapping16 = mapping16
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(mapping1.0); hasher.combine(mapping1.1)
        guard let mapping2 = mapping2 else { return }
        hasher.combine(mapping2.0); hasher.combine(mapping2.1)
        guard let mapping3 = mapping3 else { return }
        hasher.combine(mapping3.0); hasher.combine(mapping3.1)
        guard let mapping4 = mapping4 else { return }
        hasher.combine(mapping4.0); hasher.combine(mapping4.1)
        guard let mapping5 = mapping5 else { return }
        hasher.combine(mapping5.0); hasher.combine(mapping5.1)
        guard let mapping6 = mapping6 else { return }
        hasher.combine(mapping6.0); hasher.combine(mapping6.1)
        guard let mapping7 = mapping7 else { return }
        hasher.combine(mapping7.0); hasher.combine(mapping7.1)
        guard let mapping8 = mapping8 else { return }
        hasher.combine(mapping8.0); hasher.combine(mapping8.1)
        guard let mapping9 = mapping9 else { return }
        hasher.combine(mapping9.0); hasher.combine(mapping9.1)
        guard let mapping10 = mapping10 else { return }
        hasher.combine(mapping10.0); hasher.combine(mapping10.1)
        guard let mapping11 = mapping11 else { return }
        hasher.combine(mapping11.0); hasher.combine(mapping11.1)
        guard let mapping12 = mapping12 else { return }
        hasher.combine(mapping12.0); hasher.combine(mapping12.1)
        guard let mapping13 = mapping13 else { return }
        hasher.combine(mapping13.0); hasher.combine(mapping13.1)
        guard let mapping14 = mapping14 else { return }
        hasher.combine(mapping14.0); hasher.combine(mapping14.1)
        guard let mapping15 = mapping15 else { return }
        hasher.combine(mapping15.0); hasher.combine(mapping15.1)
        guard let mapping16 = mapping16 else { return }
        hasher.combine(mapping16.0); hasher.combine(mapping16.1)
    }
    
    private func derivedState(from state: State) -> DerivedSubState {
        var valuesByKeyPath: [PartialKeyPath<DerivedSubState> : Any] = [mapping1.1 : state[keyPath: mapping1.0]]
        guard let mapping2 = mapping2 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping2.1] = state[keyPath: mapping2.0]
        guard let mapping3 = mapping3 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping3.1] = state[keyPath: mapping3.0]
        guard let mapping4 = mapping4 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping4.1] = state[keyPath: mapping4.0]
        guard let mapping5 = mapping5 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping5.1] = state[keyPath: mapping5.0]
        guard let mapping6 = mapping6 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping6.1] = state[keyPath: mapping6.0]
        guard let mapping7 = mapping7 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping7.1] = state[keyPath: mapping7.0]
        guard let mapping8 = mapping8 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping8.1] = state[keyPath: mapping8.0]
        guard let mapping9 = mapping9 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping9.1] = state[keyPath: mapping9.0]
        guard let mapping10 = mapping10 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping10.1] = state[keyPath: mapping10.0]
        guard let mapping11 = mapping11 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping11.1] = state[keyPath: mapping11.0]
        guard let mapping12 = mapping12 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping12.1] = state[keyPath: mapping12.0]
        guard let mapping13 = mapping13 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping13.1] = state[keyPath: mapping13.0]
        guard let mapping14 = mapping14 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping14.1] = state[keyPath: mapping14.0]
        guard let mapping15 = mapping15 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping15.1] = state[keyPath: mapping15.0]
        guard let mapping16 = mapping16 else { return DerivedSubState(by: valuesByKeyPath) }
        valuesByKeyPath[mapping16.1] = state[keyPath: mapping16.0]
        return DerivedSubState(by: valuesByKeyPath)
    }
    
    private func mutate(state: inout State, derivedState: DerivedSubState) -> Void {
        state[keyPath: mapping1.0] = derivedState[keyPath: mapping1.1]
        guard let mapping2 = mapping2 else { return }
        state[keyPath: mapping2.0] = derivedState[keyPath: mapping2.1]
        guard let mapping3 = mapping3 else { return }
        state[keyPath: mapping3.0] = derivedState[keyPath: mapping3.1]
        guard let mapping4 = mapping4 else { return }
        state[keyPath: mapping4.0] = derivedState[keyPath: mapping4.1]
        guard let mapping5 = mapping5 else { return }
        state[keyPath: mapping5.0] = derivedState[keyPath: mapping5.1]
        guard let mapping6 = mapping6 else { return }
        state[keyPath: mapping6.0] = derivedState[keyPath: mapping6.1]
        guard let mapping7 = mapping7 else { return }
        state[keyPath: mapping7.0] = derivedState[keyPath: mapping7.1]
        guard let mapping8 = mapping8 else { return }
        state[keyPath: mapping8.0] = derivedState[keyPath: mapping8.1]
        guard let mapping9 = mapping9 else { return }
        state[keyPath: mapping9.0] = derivedState[keyPath: mapping9.1]
        guard let mapping10 = mapping10 else { return }
        state[keyPath: mapping10.0] = derivedState[keyPath: mapping10.1]
        guard let mapping11 = mapping11 else { return }
        state[keyPath: mapping11.0] = derivedState[keyPath: mapping11.1]
        guard let mapping12 = mapping12 else { return }
        state[keyPath: mapping12.0] = derivedState[keyPath: mapping12.1]
        guard let mapping13 = mapping13 else { return }
        state[keyPath: mapping13.0] = derivedState[keyPath: mapping13.1]
        guard let mapping14 = mapping14 else { return }
        state[keyPath: mapping14.0] = derivedState[keyPath: mapping14.1]
        guard let mapping15 = mapping15 else { return }
        state[keyPath: mapping15.0] = derivedState[keyPath: mapping15.1]
        guard let mapping16 = mapping16 else { return }
        state[keyPath: mapping16.0] = derivedState[keyPath: mapping16.1]
    }
}
