import Foundation

@MainActor
protocol TerminalResourceReleasing: AnyObject {
  func releaseTerminalResources()
}

@MainActor
final class SynchronousTerminalBoundary {
  private(set) var isTerminated = false
  private(set) var generation = EngineGeneration.zero
  private var resources: [any TerminalResourceReleasing] = []
  private var registeredResourceIDs: Set<ObjectIdentifier> = []
  private var releasedResourceIDs: Set<ObjectIdentifier> = []

  @discardableResult
  func beginGeneration() -> EngineGeneration {
    guard !isTerminated else { return generation }
    generation = generation.next()
    return generation
  }

  func register(_ resource: any TerminalResourceReleasing) {
    let id = ObjectIdentifier(resource)
    guard !releasedResourceIDs.contains(id) else { return }
    guard registeredResourceIDs.insert(id).inserted else { return }

    if isTerminated {
      releasedResourceIDs.insert(id)
      resource.releaseTerminalResources()
      return
    }
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
      let id = ObjectIdentifier(resource)
      guard releasedResourceIDs.insert(id).inserted else { continue }
      resource.releaseTerminalResources()
    }
    resources.removeAll(keepingCapacity: false)
    registeredResourceIDs.removeAll(keepingCapacity: false)
  }
}
