import Combine

// NB: Deprecated after 0.1.3:

extension Effect {
  @available(*, deprecated, renamed: "run")
  public static func async(
    _ work: @escaping (Effect.Subscriber<Output, Failure>) -> Cancellable
  ) -> Self {
    self.run(work)
  }
}

extension Effect where Failure == Swift.Error {
  @available(*, deprecated, renamed: "catching")
  public static func sync(_ work: @escaping () throws -> Output) -> Self {
    self.catching(work)
  }
}
