extension TestScheduler {
  @MainActor
  public func advance(by stride: SchedulerTimeType.Stride = .zero) async {
    _ = { self.advance(by: stride) }()
    await Task.yield()
    _ = { self.advance() }()
  }

  @MainActor
  public func run() async {
    _ = { self.run() }()
    await Task.yield()
    _ = { self.advance() }()
  }
}
