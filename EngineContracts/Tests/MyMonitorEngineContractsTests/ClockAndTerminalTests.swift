import XCTest
@testable import MyMonitorEngineContracts

final class ClockAndTerminalTests: XCTestCase {
  func testFakeClockResumesOnlyAtDeadline() async throws {
    let clock = TestEngineClock()
    let task = Task {
      try await clock.sleep(until: EngineInstant(rawValue: 100))
      return await clock.now()
    }

    var pendingAtStart = 0
    for _ in 0..<100 {
      pendingAtStart = await clock.pendingSleepCount()
      if pendingAtStart == 1 { break }
      await Task.yield()
    }
    XCTAssertEqual(pendingAtStart, 1)

    await clock.advance(to: EngineInstant(rawValue: 99))
    await Task.yield()
    let pendingBeforeDeadline = await clock.pendingSleepCount()
    XCTAssertEqual(pendingBeforeDeadline, 1)

    await clock.advance(to: EngineInstant(rawValue: 100))
    let resumedAt = try await task.value
    let pendingAtEnd = await clock.pendingSleepCount()
    XCTAssertEqual(resumedAt, EngineInstant(rawValue: 100))
    XCTAssertEqual(pendingAtEnd, 0)
  }

  func testFakeClockCancellationRemovesWaiter() async {
    let clock = TestEngineClock()
    let task = Task {
      try await clock.sleep(until: EngineInstant(rawValue: 100))
    }

    await Task.yield()
    task.cancel()

    do {
      try await task.value
      XCTFail("Expected cancellation")
    } catch is CancellationError {
      // Expected.
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    let pendingAtEnd = await clock.pendingSleepCount()
    XCTAssertEqual(pendingAtEnd, 0)
  }

  @MainActor
  func testTerminalBoundaryIsSynchronousIdempotentAndRejectsLatePublication() {
    let events = ReleaseEvents()
    let first = ReleaseResource(name: "first", events: events)
    let second = ReleaseResource(name: "second", events: events)
    let boundary = SynchronousTerminalBoundary()

    let generation = boundary.beginGeneration()
    XCTAssertTrue(boundary.permitsPublication(from: generation))

    boundary.register(first)
    boundary.register(first)
    boundary.register(second)
    boundary.terminateSynchronously()
    boundary.terminateSynchronously()

    XCTAssertTrue(boundary.isTerminated)
    XCTAssertFalse(boundary.permitsPublication(from: generation))
    XCTAssertEqual(events.values, ["second", "first"])

    var late: ReleaseResource? = ReleaseResource(name: "late", events: events)
    weak var releasedLate = late
    boundary.register(late!)
    boundary.register(late!)
    XCTAssertEqual(events.values, ["second", "first", "late"])

    late = nil
    XCTAssertNil(releasedLate, "The terminal boundary must not retain released resources")

    let later = ReleaseResource(name: "later", events: events)
    boundary.register(later)
    XCTAssertEqual(events.values, ["second", "first", "late", "later"])
  }
}

@MainActor
private final class ReleaseEvents {
  var values: [String] = []
}

@MainActor
private final class ReleaseResource: TerminalResourceReleasing {
  let name: String
  let events: ReleaseEvents

  init(name: String, events: ReleaseEvents) {
    self.name = name
    self.events = events
  }

  func releaseTerminalResources() {
    events.values.append(name)
  }
}
