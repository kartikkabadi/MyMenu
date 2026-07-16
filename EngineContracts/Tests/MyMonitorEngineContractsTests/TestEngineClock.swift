import Foundation
@testable import MyMonitorEngineContracts

actor TestEngineClock: EngineClock {
  private struct Waiter {
    let deadline: EngineInstant
    let continuation: CheckedContinuation<Void, Error>
  }

  private var instant: EngineInstant
  private var waiters: [UUID: Waiter] = [:]

  init(now: EngineInstant = .zero) {
    instant = now
  }

  func now() async -> EngineInstant {
    instant
  }

  func sleep(until deadline: EngineInstant) async throws {
    try Task.checkCancellation()
    guard deadline > instant else { return }

    let id = UUID()
    try await withTaskCancellationHandler(
      operation: {
        try await withCheckedThrowingContinuation { continuation in
          waiters[id] = Waiter(deadline: deadline, continuation: continuation)
        }
      },
      onCancel: {
        Task { await self.cancelWaiter(id) }
      }
    )
  }

  func advance(by duration: Duration) {
    advance(to: instant.advanced(by: duration))
  }

  func advance(to newInstant: EngineInstant) {
    precondition(newInstant >= instant, "Test clocks cannot move backwards")
    instant = newInstant

    let ready = waiters.filter { $0.value.deadline <= instant }
    for (id, waiter) in ready {
      waiters.removeValue(forKey: id)
      waiter.continuation.resume()
    }
  }

  func pendingSleepCount() -> Int {
    waiters.count
  }

  private func cancelWaiter(_ id: UUID) {
    guard let waiter = waiters.removeValue(forKey: id) else { return }
    waiter.continuation.resume(throwing: CancellationError())
  }
}
