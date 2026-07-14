import SwiftUI

struct WindowItem: Identifiable, Equatable {
  let id: CGWindowID
  let ownerPID: Int32
  let ownerName: String
  let windowName: String
  let bounds: CGRect
  let appIcon: NSImage?

  static func == (lhs: WindowItem, rhs: WindowItem) -> Bool {
    lhs.id == rhs.id
  }
}

@available(macOS 26.0, *)
struct WindowSwitcherHUDView: View {
  @ObservedObject var service: WindowSwitcherService

  var body: some View {
    let windows = service.windows
    let selectedIndex = service.selectedIndex

    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        Image(systemName: "square.on.square.badge.person.crop")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.primary)

        Text("Window Switcher")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(.primary)

        Spacer()

        Text("Release Option to Select")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 16)

      Divider()
        .opacity(0.1)

      // Window List
      ScrollViewReader { proxy in
        ScrollView(.vertical, showsIndicators: false) {
          VStack(spacing: 8) {
            ForEach(0..<windows.count, id: \.self) { index in
              let item = windows[index]
              let isSelected = index == selectedIndex

              HStack(spacing: 12) {
                if let icon = item.appIcon {
                  Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                } else {
                  Image(systemName: "window.template")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                  Text(item.ownerName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? .white : .primary)

                  Text(item.windowName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : .secondary)
                    .lineLimit(1)
                }

                Spacer()
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .background {
                if isSelected {
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.85))
                    .shadow(color: Color.blue.opacity(0.3), radius: 6, y: 2)
                } else {
                  RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.clear)
                }
              }
              .id(index)
            }
          }
          .padding(12)
        }
        .onChange(of: selectedIndex) { _, newIndex in
          withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(newIndex, anchor: .center)
          }
        }
      }
    }
    .frame(width: 550, height: 380)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
    }
  }
}
