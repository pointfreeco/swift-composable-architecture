extension Task where Failure == Error {
  var cancellableValue: Success {
    try await withTaskCancellationHandler {
      self.cancel()
    } operation: {
      try await self.value
    }
  }
}

extension Task where Failure == Never {
  var cancellableValue: Success {
    await withTaskCancellationHandler {
      self.cancel()
    } operation: {
      await self.value
    }
  }
}
