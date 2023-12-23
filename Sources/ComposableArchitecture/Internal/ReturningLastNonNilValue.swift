// Creates a memoized cache that always returns the last non-`nil` value.
//
// Useful for preserving a presented UI during the programmatic dismissal of sheets and other forms
// of navigation, where setting state to `nil` drives dismissal.
func returningLastNonNilValue<A, B>(_ f: @escaping (A) -> B?) -> (A) -> B? {
  var lastWrapped: B?
  return { wrapped in
    lastWrapped = f(wrapped) ?? lastWrapped
    return lastWrapped
  }
}

// Creates a memoized cache that always returns the last non-`nil` value.
//
// Useful for preserving a presented UI during the programmatic dismissal of sheets and other forms
// of navigation, where setting state to `nil` drives dismissal.
func coalesceToLastValue<A, B>(
  _ f: @escaping (A) -> B?,
  initialValue: B
) -> (A) -> B {
  var lastValue = initialValue
  return { wrapped in
    lastValue = f(wrapped) ?? lastValue
    return lastValue
  }
}
