import AppKit
import CoreGraphics

/// Per-display gamma dimming (Tier 2) via `CGSetDisplayTransferByFormula`.
@MainActor
final class GammaBrightnessBackend: BrightnessBackend {
    static let tier: BrightnessTier = .gamma

    /// Slightly off-identity curve used only during `probe`.
    private static let probeGamma: CGGammaValue = 0.92
    private static let probeGammaTolerance: CGGammaValue = 0.03

    private let displayID: CGDirectDisplayID
    private var currentBrightness: Double = 0

    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
        guard Self.isExternal(displayID) else { return }
        _ = DisplayGamma.applyGamma(1.0, to: displayID)
    }

    static func probe(displayID: CGDirectDisplayID) -> Bool {
        guard isExternal(displayID) else { return false }

        guard DisplayGamma.applyGamma(probeGamma, to: displayID) == .success else { return false }
        defer { _ = DisplayGamma.applyGamma(1.0, to: displayID) }

        return verifyGamma(probeGamma, on: displayID)
    }

    func setBrightness(_ value: Double, animated: Bool) {
        let clamped = min(max(value, 0), 1)
        guard Self.isExternal(displayID) else { return }
        guard clamped != currentBrightness else { return }
        _ = animated
        currentBrightness = clamped
        _ = DisplayGamma.applyBrightnessHold(clamped, displayID: displayID)
    }

    func teardown() {
        guard Self.isExternal(displayID) else { return }
        DisplayGamma.releaseHold(displayID: displayID)
        CGDisplayRestoreColorSyncSettings()
    }

    // MARK: - CoreGraphics

    private static func isExternal(_ displayID: CGDirectDisplayID) -> Bool {
        CGDisplayIsBuiltin(displayID) == 0
    }

    private static func verifyGamma(_ expected: CGGammaValue, on displayID: CGDirectDisplayID) -> Bool {
        var redMin: CGGammaValue = 0
        var redMax: CGGammaValue = 0
        var redGamma: CGGammaValue = 0
        var greenMin: CGGammaValue = 0
        var greenMax: CGGammaValue = 0
        var greenGamma: CGGammaValue = 0
        var blueMin: CGGammaValue = 0
        var blueMax: CGGammaValue = 0
        var blueGamma: CGGammaValue = 0

        guard CGGetDisplayTransferByFormula(
            displayID,
            &redMin, &redMax, &redGamma,
            &greenMin, &greenMax, &greenGamma,
            &blueMin, &blueMax, &blueGamma
        ) == .success else {
            return false
        }

        return abs(redGamma - expected) <= probeGammaTolerance
            && abs(greenGamma - expected) <= probeGammaTolerance
            && abs(blueGamma - expected) <= probeGammaTolerance
    }
}
