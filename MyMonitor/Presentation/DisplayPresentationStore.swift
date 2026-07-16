import Foundation
import Observation

/// Hardware-independent state owner for every frontend surface.
///
/// The store reconciles controller snapshots with direct manipulation so a stale backend
/// update cannot move a slider away from the user's pointer.
@MainActor
@Observable
final class DisplayPresentationStore {
  private(set) var state: DisplayPresentationState

  @ObservationIgnored
  private let controller: any MonitorControlling

  @ObservationIgnored
  private var activeAdjustments: Set<MonitorID> = []

  @ObservationIgnored
  private var optimisticBrightness: [MonitorID: Double] = [:]

  init(controller: any MonitorControlling) {
    self.controller = controller
    state = .detecting(cached: [])

    controller.setSnapshotHandler { [weak self] snapshot in
      self?.apply(snapshot)
    }
    apply(controller.currentSnapshot)
  }

  var monitors: [MonitorPresentation] {
    state.monitors
  }

  func monitor(withID monitorID: MonitorID) -> MonitorPresentation? {
    monitors.first { $0.id == monitorID }
  }

  func refresh() {
    state = .detecting(cached: monitors)
    controller.refresh()
  }

  func retryControl(for monitorID: MonitorID) {
    updateVisibleControl(.checking, for: monitorID)
    controller.retryControl(for: monitorID)
  }

  func beginBrightnessAdjustment(for monitorID: MonitorID) {
    guard monitor(withID: monitorID)?.brightness != nil else { return }
    activeAdjustments.insert(monitorID)
  }

  func updateBrightness(_ value: Double, for monitorID: MonitorID) {
    guard let monitor = monitor(withID: monitorID), monitor.brightness != nil else { return }

    let clamped = min(max(value, monitor.allowedRange.lowerBound), monitor.allowedRange.upperBound)
    optimisticBrightness[monitorID] = clamped
    updateVisibleBrightness(clamped, for: monitorID)

    controller.setBrightness(
      clamped,
      for: monitorID,
      animated: false,
      persist: false
    )
  }

  func endBrightnessAdjustment(for monitorID: MonitorID) {
    activeAdjustments.remove(monitorID)

    guard let value = optimisticBrightness[monitorID]
      ?? monitor(withID: monitorID)?.brightness
    else {
      return
    }

    controller.setBrightness(
      value,
      for: monitorID,
      animated: true,
      persist: true
    )
  }

  func teardown() {
    controller.teardown()
  }

  // MARK: - Snapshot reconciliation

  private func apply(_ snapshot: DisplayControllerSnapshot) {
    switch snapshot {
    case .detecting(let cached):
      state = .detecting(cached: reconcile(cached, acknowledgeWrites: false))

    case .ready(let snapshots):
      let presentations = reconcile(snapshots, acknowledgeWrites: true)
      state = presentations.isEmpty ? .empty : .ready(presentations)

    case .failed(let message, let canRetry):
      state = .failed(
        DisplayPresentationFailure(message: message, canRetry: canRetry)
      )
    }
  }

  private func reconcile(
    _ snapshots: [MonitorSnapshot],
    acknowledgeWrites: Bool
  ) -> [MonitorPresentation] {
    let incomingIDs = Set(snapshots.map(\.id))
    optimisticBrightness = optimisticBrightness.filter { incomingIDs.contains($0.key) }
    activeAdjustments = activeAdjustments.filter { incomingIDs.contains($0) }

    var presentations: [MonitorPresentation] = []
    presentations.reserveCapacity(snapshots.count)

    for snapshot in snapshots {
      let override = optimisticBrightness[snapshot.id]
      let isActive = activeAdjustments.contains(snapshot.id)
      let isAcknowledged = acknowledgeWrites
        && valuesMatch(snapshot.brightness, override)

      if isAcknowledged, !isActive {
        optimisticBrightness.removeValue(forKey: snapshot.id)
      }

      let shouldKeepOverride = override != nil && (isActive || !isAcknowledged)
      presentations.append(
        MonitorPresentation(
          snapshot: snapshot,
          brightnessOverride: shouldKeepOverride ? override : nil
        )
      )
    }

    return presentations
  }

  private func valuesMatch(_ snapshot: Double?, _ optimistic: Double?) -> Bool {
    guard let snapshot, let optimistic else { return false }
    return abs(snapshot - optimistic) < 0.005
  }

  private func updateVisibleBrightness(_ value: Double, for monitorID: MonitorID) {
    switch state {
    case .detecting(var cached):
      updateBrightness(value, for: monitorID, in: &cached)
      state = .detecting(cached: cached)

    case .ready(var monitors):
      updateBrightness(value, for: monitorID, in: &monitors)
      state = .ready(monitors)

    case .empty, .failed:
      break
    }
  }

  private func updateVisibleControl(
    _ control: MonitorControlState,
    for monitorID: MonitorID
  ) {
    switch state {
    case .detecting(var cached):
      updateControl(control, for: monitorID, in: &cached)
      state = .detecting(cached: cached)

    case .ready(var monitors):
      updateControl(control, for: monitorID, in: &monitors)
      state = .ready(monitors)

    case .empty, .failed:
      break
    }
  }

  private func updateBrightness(
    _ value: Double,
    for monitorID: MonitorID,
    in monitors: inout [MonitorPresentation]
  ) {
    guard let index = monitors.firstIndex(where: { $0.id == monitorID }) else { return }
    monitors[index].brightness = value
  }

  private func updateControl(
    _ control: MonitorControlState,
    for monitorID: MonitorID,
    in monitors: inout [MonitorPresentation]
  ) {
    guard let index = monitors.firstIndex(where: { $0.id == monitorID }) else { return }
    monitors[index].control = control
  }
}
