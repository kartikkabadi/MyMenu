import Foundation

@MainActor
protocol TerminalResourceReleasing: AnyObject {
  func releaseTerminalResources()
}

@MainActor
final class SynchronousTerminalBoundary {
  private final class WeakReleasedResource {
    weak var value: (any TerminalResourceReleasing)?

    init(_ value: any TerminalResourceReleasing) {
      self.value = value
    }
  }

  private(set) var isTerminated = false
  private(set) var generation = EngineGeneration.zero
  private var resources: [any TerminalResourceReleasing] = []
  private var registeredResourceIDs: Set<ObjectIdentifier> = []
  private var releasedResources: [WeakReleasedResource] = []

  @discardableResult
  func beginGeneration() -> EngineGeneration {
    guard !isTerminated else { return generation }
    generation = generation.next()
    return generation
  }

  func register(_ resource: any TerminalResourceReleasing) {
    if isTerminated {
      releaseOnce(resource)
      return
    }

    let id = ObjectIdentifier(resource)
    guard registeredResourceIDs.insert(id).inserted else { return }
    resources.append(resource)
  }

  func permitsPublication(from candidate: EngineGeneration) -> Bool {
    !isTerminated && candidate == generation
  }

  func terminateSynchronously() {
    guard !isTerminated else { return }
    isTerminated = true
    generation = generation.next()

    for resource in resources.reversed() {
      releaseOnce(resource)
    }
    resources.removeAll(keepingCapacity: false)
    registeredResourceIDs.removeAll(keepingCapacity: false)
  }

  private func releaseOnce(_ resource: any TerminalResourceReleasing) {
    releasedResources.removeAll { $0.value == nil }
    guard !releasedResources.contains(where: { $0.value === resource }) else { return }

    releasedResources.append(WeakReleasedResource(resource))
    resource.releaseTerminalResources()
  }
}
