import SwiftUI

struct SettingsRootView: View {
  @Bindable var store: DisplayPresentationStore
  @Bindable var configurationStore: DisplayConfigurationStore
  @Bindable var launchAtLoginController: LaunchAtLoginController
  @Bindable var keyboardShortcutController: KeyboardShortcutController
  @Bindable var navigationModel: SettingsNavigationModel
  @Bindable var diagnosticsController: DiagnosticsController

  var body: some View {
    NavigationSplitView {
      List(SettingsDestination.allCases, selection: $navigationModel.selection) { destination in
        Label(destination.title, systemImage: destination.symbol)
          .tag(destination)
          .accessibilityIdentifier("settings.destination.\(destination.rawValue)")
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
      .accessibilityIdentifier("settings.sidebar")
    } detail: {
      detail
        .navigationTitle(navigationModel.selection.title)
        .accessibilityIdentifier("settings.detail.\(navigationModel.selection.rawValue)")
    }
    .frame(minWidth: 620, minHeight: 420)
  }

  @ViewBuilder
  private var detail: some View {
    switch navigationModel.selection {
    case .general:
      GeneralSettingsView(
        launchAtLoginController: launchAtLoginController
      )
    case .displays:
      DisplaysSettingsView(
        store: store,
        configurationStore: configurationStore
      )
    case .keyboard:
      KeyboardSettingsView(
        configurationStore: configurationStore,
        keyboardShortcutController: keyboardShortcutController
      )
    case .advanced:
      AdvancedSettingsView(
        store: store,
        diagnosticsController: diagnosticsController
      )
    case .about:
      AboutSettingsView()
    }
  }
}
