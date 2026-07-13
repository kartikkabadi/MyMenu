import SwiftUI

/// Brightness panel — `PopoverView` + `DimmingView` parity with One Menu Liquid Glass.
struct BrightnessPopoverView: View {
  @Bindable var router: DisplayRouter
  var animationToken: PopoverAnimationToken

  @State private var hasAccessibility = PermissionManager.shared.hasAccessibilityAccess
  @State private var hasScreenRecording = PermissionManager.shared.hasScreenRecordingAccess

  private var windowSnappingBinding: Binding<Bool> {
    Binding(
      get: { AppPreferences.isWindowSnappingEnabled },
      set: { newValue in
        AppPreferences.isWindowSnappingEnabled = newValue
        AppDelegate.shared?.updateWindowSnappingState()
        if newValue && !PermissionManager.shared.hasAccessibilityAccess {
          PermissionManager.shared.requestAccessibilityAccess()
        }
      }
    )
  }

  private var windowSwitcherBinding: Binding<Bool> {
    Binding(
      get: { AppPreferences.isWindowSwitcherEnabled },
      set: { newValue in
        AppPreferences.isWindowSwitcherEnabled = newValue
        AppDelegate.shared?.updateWindowSwitcherState()
        if newValue {
          if !PermissionManager.shared.hasAccessibilityAccess {
            PermissionManager.shared.requestAccessibilityAccess()
          }
          if !PermissionManager.shared.hasScreenRecordingAccess {
            PermissionManager.shared.requestScreenRecordingAccess()
          }
        }
      }
    )
  }

  private var screenRecordingPreviewBinding: Binding<Bool> {
    Binding(
      get: { router.isScreenRecordingPreviewEnabled },
      set: { router.setScreenRecordingPreviewEnabled($0) }
    )
  }

  var body: some View {
    Group {
      if #available(macOS 26.0, *) {
        tahoePanel
      } else {
        legacyPanel
      }
    }
    .onAppear {
      refreshPermissions()
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      refreshPermissions()
    }
  }

  private func refreshPermissions() {
    hasAccessibility = PermissionManager.shared.hasAccessibilityAccess
    hasScreenRecording = PermissionManager.shared.hasScreenRecordingAccess
  }

  @available(macOS 26.0, *)
  private var tahoePanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Glass Block 1: Display Brightness
      header
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        }

      // Glass Block 2: Window Management Controls
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Toggle(isOn: windowSnappingBinding) {
            HStack(spacing: 8) {
              Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
              Text("Window Snapping")
                .font(.system(size: 12, weight: .medium))
            }
          }
          .toggleStyle(.switch)

          if windowSnappingBinding.wrappedValue && !hasAccessibility {
            Button {
              PermissionManager.shared.requestAccessibilityAccess()
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Accessibility permission required. Click to Fix.")
                  .underline()
              }
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
          }
        }

        Divider()
          .opacity(0.1)

        VStack(alignment: .leading, spacing: 6) {
          Toggle(isOn: windowSwitcherBinding) {
            HStack(spacing: 8) {
              Image(systemName: "square.on.square.badge.person.crop")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
              Text("Alt-Tab Switcher")
                .font(.system(size: 12, weight: .medium))
            }
          }
          .toggleStyle(.switch)

          if windowSwitcherBinding.wrappedValue && !hasScreenRecording {
            Button {
              PermissionManager.shared.requestScreenRecordingAccess()
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Screen Recording permission required. Click to Fix.")
                  .underline()
              }
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
          }

          if windowSwitcherBinding.wrappedValue && !hasAccessibility {
            Button {
              PermissionManager.shared.requestAccessibilityAccess()
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Accessibility permission required. Click to Fix.")
                  .underline()
              }
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
          }
        }

        Divider()
          .opacity(0.1)

        VStack(alignment: .leading, spacing: 6) {
          Toggle(isOn: screenRecordingPreviewBinding) {
            HStack(spacing: 8) {
              Image(systemName: "record.circle")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
              Text("Show Dimming in Recordings")
                .font(.system(size: 12, weight: .medium))
            }
          }
          .toggleStyle(.switch)

          if router.isScreenRecordingPreviewEnabled {
            Text("Adds a capture-visible overlay for demo videos; the monitor may look slightly darker. This mode lasts until MyMenu quits.")
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
              .padding(.leading, 24)
          }
        }
      }
      .padding(.vertical, 12)
      .padding(.horizontal, 14)
      .background(.ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
      }

      Spacer(minLength: 4)

      // Quit Button
      Button {
        AppDelegate.shared?.quitApp()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "power")
            .font(.system(size: 11, weight: .bold))
          Text("Quit MyMenu")
            .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.red)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background {
          Capsule()
            .fill(.regularMaterial)
            .overlay {
              Capsule()
                .fill(Color.red.opacity(0.12))
            }
            .overlay {
              Capsule()
                .stroke(Color.red.opacity(0.42), lineWidth: 1)
            }
        }
      }
      .buttonStyle(.plain)
    }
    .padding(12)
    .frame(width: BrightnessDesign.panelWidth)
  }

  @available(macOS 26.0, *)
  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Image(systemName: "sun.max.fill")
          .font(.system(size: 15, weight: .semibold))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(.primary)
          .frame(width: 20, height: 20)

        VStack(alignment: .leading, spacing: 1) {
          Text("External Monitor")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.primary)

          Text("Brightness")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 0)
      }

      if router.presentationDisplays.isEmpty {
        Text("Connect an external display.")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      } else if let display = router.presentationDisplays.first {
        GlassBrightnessControl(displayID: display.id, router: router)
          .padding(.top, 2)

        Text(display.tierLabel)
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.tertiary)
          .padding(.leading, 34)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var legacyPanel: some View {
    VStack(spacing: BrightnessDesign.sectionSpacing) {
      Text("External Monitor Brightness")
        .font(.system(size: 13, weight: .semibold))

      if let display = router.presentationDisplays.first {
        ExternalBrightnessSlider(displayID: display.id, router: router)
        Text(display.tierLabel)
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }

      Toggle("Show Dimming in Recordings", isOn: screenRecordingPreviewBinding)
        .toggleStyle(.checkbox)

      Button("Quit") {
        AppDelegate.shared?.quitApp()
      }
      .buttonStyle(.borderedProminent)
      .tint(BrightnessDesign.quitTint)
    }
    .padding(BrightnessDesign.panelPadding)
    .frame(width: BrightnessDesign.panelWidth)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: BrightnessDesign.panelCornerRadius))
  }
}
