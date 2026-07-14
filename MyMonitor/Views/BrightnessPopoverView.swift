import SwiftUI

/// Main menu-bar surface. Optional window tools stay visually secondary to the
/// one job people open MyMonitor for: changing an external display's brightness.
struct BrightnessPopoverView: View {
  @Bindable var router: DisplayRouter
  var animationToken: PopoverAnimationToken

  @State private var hasAccessibility = PermissionManager.shared.hasAccessibilityAccess
  @State private var hasScreenRecording = PermissionManager.shared.hasScreenRecordingAccess
  @State private var showOnboarding = !AppPreferences.hasCompletedOnboarding
  @AppStorage(AppPreferences.isWindowSnappingEnabledKey) private var windowSnappingEnabled = false
  @AppStorage(AppPreferences.isWindowSwitcherEnabledKey) private var windowSwitcherEnabled = false

  var onOnboardingComplete: (() -> Void)?

  private var windowSnappingBinding: Binding<Bool> {
    Binding(
      get: { windowSnappingEnabled },
      set: { enabled in
        windowSnappingEnabled = enabled
        AppDelegate.shared?.updateWindowSnappingState()
        if enabled && !PermissionManager.shared.hasAccessibilityAccess {
          PermissionManager.shared.requestAccessibilityAccess()
        }
        refreshPermissions()
      }
    )
  }

  private var windowSwitcherBinding: Binding<Bool> {
    Binding(
      get: { windowSwitcherEnabled },
      set: { enabled in
        windowSwitcherEnabled = enabled
        AppDelegate.shared?.updateWindowSwitcherState()
        if enabled {
          if !PermissionManager.shared.hasAccessibilityAccess {
            PermissionManager.shared.requestAccessibilityAccess()
          }
          if !PermissionManager.shared.hasScreenRecordingAccess {
            PermissionManager.shared.requestScreenRecordingAccess()
          }
        }
        refreshPermissions()
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
      if showOnboarding {
        OnboardingView {
          AppPreferences.hasCompletedOnboarding = true
          withAnimation(BrightnessDesign.appearSpring) {
            showOnboarding = false
          }
          onOnboardingComplete?()
        }
      } else {
        mainPanel
      }
    }
    .onAppear(perform: refreshPermissions)
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
      refreshPermissions()
    }
  }

  private var mainPanel: some View {
    VStack(alignment: .leading, spacing: 10) {
      displayCard
      toolsCard
      recordingCard

      Button {
        AppDelegate.shared?.quitApp()
      } label: {
        Label("Quit MyMonitor", systemImage: "power")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.primary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 9)
          .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
              .fill(Color.white.opacity(0.07))
          )
      }
      .buttonStyle(.plain)
      .keyboardShortcut("q", modifiers: [.command])
    }
    .padding(12)
    .frame(width: BrightnessDesign.panelWidth)
    .background(BrightnessDesign.panelBackground)
  }

  private var displayCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image(systemName: "sun.max.fill")
          .font(.system(size: 15, weight: .semibold))
          .symbolRenderingMode(.hierarchical)
          .foregroundStyle(BrightnessDesign.accent)
          .frame(width: 22, height: 22)

        VStack(alignment: .leading, spacing: 1) {
          Text("External display")
            .font(.system(size: 13, weight: .semibold))
          Text("MyMonitor")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
        }

        Spacer()
        Circle()
          .fill(router.presentationDisplays.isEmpty ? Color.secondary : BrightnessDesign.accent)
          .frame(width: 7, height: 7)
      }

      if router.presentationDisplays.isEmpty {
        Text("Connect an external display to control its brightness.")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      } else if let display = router.presentationDisplays.first {
        GlassBrightnessControl(displayID: display.id, router: router)
          .padding(.horizontal, -4)

        Text(display.tierLabel)
          .font(.system(size: 9, weight: .medium))
          .foregroundStyle(.tertiary)
          .padding(.leading, 30)
      }
    }
    .padding(14)
    .glassCard()
  }

  private var toolsCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Window tools")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)

      Toggle(isOn: windowSnappingBinding) {
        Label("Window snapping", systemImage: "macwindow.badge.plus")
          .font(.system(size: 12, weight: .medium))
      }
      .toggleStyle(.switch)

      if windowSnappingBinding.wrappedValue && !hasAccessibility {
        permissionRow("Accessibility is needed to move windows") {
          PermissionManager.shared.requestAccessibilityAccess()
        }
      }

      Divider().opacity(0.12)

      Toggle(isOn: windowSwitcherBinding) {
        Label("Option–Tab switcher", systemImage: "square.on.square")
          .font(.system(size: 12, weight: .medium))
      }
      .toggleStyle(.switch)

      if windowSwitcherBinding.wrappedValue && (!hasAccessibility || !hasScreenRecording) {
        if !hasAccessibility {
          permissionRow("Accessibility is needed to focus windows") {
            PermissionManager.shared.requestAccessibilityAccess()
          }
        }
        if !hasScreenRecording {
          permissionRow("Screen Recording is needed to list windows") {
            PermissionManager.shared.requestScreenRecordingAccess()
          }
        }
      }
    }
    .padding(14)
    .glassCard()
  }

  private var recordingCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle(isOn: screenRecordingPreviewBinding) {
        Label("Show dimming in recordings", systemImage: "record.circle")
          .font(.system(size: 12, weight: .medium))
      }
      .toggleStyle(.switch)

      if router.isScreenRecordingPreviewEnabled {
        Text("Adds a capture-visible overlay for demo videos until MyMonitor quits.")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(14)
    .glassCard()
  }

  private func permissionRow(_ message: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: "lock.open")
        Text(message)
          .multilineTextAlignment(.leading)
        Spacer(minLength: 4)
        Image(systemName: "arrow.up.right")
      }
      .font(.system(size: 10, weight: .medium))
      .foregroundStyle(BrightnessDesign.accent)
    }
    .buttonStyle(.plain)
    .padding(.leading, 26)
  }

  private func refreshPermissions() {
    hasAccessibility = PermissionManager.shared.hasAccessibilityAccess
    hasScreenRecording = PermissionManager.shared.hasScreenRecordingAccess
  }
}

private extension View {
  func glassCard() -> some View {
    background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
      }
  }
}
