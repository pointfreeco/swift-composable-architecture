extension TestScheduler {
  @MainActor
  public func advance(by stride: SchedulerTimeType.Stride = .zero) async {
    await Task(priority: .background) { await Task.yield() }.value
    _ = { self.advance(by: stride) }()
    for _ in 1...10 {
      await Task(priority: .background) { await Task.yield() }.value
      _ = { self.advance() }()
    }
    await Task(priority: .background) { await Task.yield() }.value
  }

  @MainActor
  public func run() async {
    await Task(priority: .background) { await Task.yield() }.value
    _ = { self.run() }()
    for _ in 1...10 {
      await Task(priority: .background) { await Task.yield() }.value
      _ = { self.run() }()
    }
    await Task(priority: .background) { await Task.yield() }.value
  }
}
