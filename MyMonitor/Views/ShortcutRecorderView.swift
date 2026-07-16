import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
  let shortcut: RecordedShortcut?
  let onChange: (RecordedShortcut?) -> Void

  func makeNSView(context: Context) -> ShortcutRecorderButton {
    let button = ShortcutRecorderButton()
    button.recordedShortcut = shortcut
    button.onChange = onChange
    return button
  }

  func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
    nsView.recordedShortcut = shortcut
    nsView.onChange = onChange
  }
}

final class ShortcutRecorderButton: NSButton {
  var recordedShortcut: RecordedShortcut? {
    didSet {
      guard !isRecording else { return }
      updateTitle()
    }
  }

  var onChange: ((RecordedShortcut?) -> Void)?
  private var isRecording = false

  override var acceptsFirstResponder: Bool { true }

  init() {
    super.init(frame: .zero)
    bezelStyle = .rounded
    setButtonType(.momentaryPushIn)
    controlSize = .regular
    font = .monospacedSystemFont(
      ofSize: NSFont.systemFontSize,
      weight: .regular
    )
    target = self
    action = #selector(beginRecording)
    focusRingType = .default
    toolTip = "Click, then type a keyboard shortcut. Press Delete to clear it."
    setAccessibilityLabel("Keyboard shortcut")
    updateTitle()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  override var intrinsicContentSize: NSSize {
    let base = super.intrinsicContentSize
    return NSSize(width: max(base.width, 150), height: base.height)
  }

  @objc private func beginRecording() {
    isRecording = true
    title = "Type Shortcut…"
    setAccessibilityValue("Recording")
    window?.makeFirstResponder(self)
  }

  override func keyDown(with event: NSEvent) {
    guard isRecording else {
      super.keyDown(with: event)
      return
    }

    if event.keyCode == UInt16(kVK_Escape) {
      finishRecording()
      return
    }

    if event.keyCode == UInt16(kVK_Delete)
      || event.keyCode == UInt16(kVK_ForwardDelete)
    {
      recordedShortcut = nil
      onChange?(nil)
      finishRecording()
      return
    }

    let modifiers = ShortcutModifiers(event.modifierFlags)
    guard !modifiers.isEmpty else {
      NSSound.beep()
      title = "Add a Modifier"
      return
    }

    let keyDisplay = Self.keyDisplay(for: event)
    guard !keyDisplay.isEmpty else {
      NSSound.beep()
      return
    }

    let shortcut = RecordedShortcut(
      keyCode: UInt32(event.keyCode),
      modifiers: modifiers,
      keyDisplay: keyDisplay
    )
    recordedShortcut = shortcut
    onChange?(shortcut)
    finishRecording()
  }

  override func resignFirstResponder() -> Bool {
    let result = super.resignFirstResponder()
    if result, isRecording {
      finishRecording()
    }
    return result
  }

  private func finishRecording() {
    isRecording = false
    updateTitle()
  }

  private func updateTitle() {
    title = recordedShortcut?.displayText ?? "Record Shortcut"
    setAccessibilityValue(recordedShortcut?.displayText ?? "Not set")
  }

  private static func keyDisplay(for event: NSEvent) -> String {
    switch Int(event.keyCode) {
    case kVK_Return: "↩"
    case kVK_Tab: "⇥"
    case kVK_Space: "Space"
    case kVK_LeftArrow: "←"
    case kVK_RightArrow: "→"
    case kVK_UpArrow: "↑"
    case kVK_DownArrow: "↓"
    case kVK_Home: "Home"
    case kVK_End: "End"
    case kVK_PageUp: "Page Up"
    case kVK_PageDown: "Page Down"
    case kVK_ANSI_KeypadEnter: "⌤"
    case kVK_F1: "F1"
    case kVK_F2: "F2"
    case kVK_F3: "F3"
    case kVK_F4: "F4"
    case kVK_F5: "F5"
    case kVK_F6: "F6"
    case kVK_F7: "F7"
    case kVK_F8: "F8"
    case kVK_F9: "F9"
    case kVK_F10: "F10"
    case kVK_F11: "F11"
    case kVK_F12: "F12"
    case kVK_F13: "F13"
    case kVK_F14: "F14"
    case kVK_F15: "F15"
    case kVK_F16: "F16"
    case kVK_F17: "F17"
    case kVK_F18: "F18"
    case kVK_F19: "F19"
    case kVK_F20: "F20"
    default:
      event.charactersIgnoringModifiers?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .uppercased() ?? ""
    }
  }
}

private extension ShortcutModifiers {
  init(_ flags: NSEvent.ModifierFlags) {
    var result: ShortcutModifiers = []
    let independent = flags.intersection(.deviceIndependentFlagsMask)
    if independent.contains(.control) { result.insert(.control) }
    if independent.contains(.option) { result.insert(.option) }
    if independent.contains(.shift) { result.insert(.shift) }
    if independent.contains(.command) { result.insert(.command) }
    self = result
  }
}
