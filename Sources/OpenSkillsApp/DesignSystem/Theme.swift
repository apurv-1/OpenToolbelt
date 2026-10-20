import AppKit
import SwiftUI

/// Design tokens. Every color, size and radius in the app comes from here.
/// See docs/design-system.md for the rules behind them.
enum Theme {
    enum Palette {
        static let canvas = dynamic(light: 0xF4F5F4, dark: 0x0E1113)
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x171B1E)
        static let sunken = dynamic(light: 0xEEF0EF, dark: 0x121518)
        static let hairline = dynamic(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.08)

        static let text = dynamic(light: 0x111414, dark: 0xF2F4F3)
        static let textSecondary = dynamic(light: 0x5E6866, dark: 0x9AA4A1)
        static let textTertiary = dynamic(light: 0x9AA3A0, dark: 0x5F6967)

        /// Phosphor mint. The text-safe shade on light, the glowing shade on dark.
        static let accent = dynamic(light: 0x0FA673, dark: 0x7CF8C8)
        static let accentSoft = dynamic(light: 0x12B981, dark: 0x7CF8C8, lightAlpha: 0.12, darkAlpha: 0.14)
        /// Amber marks dead weight: installed, never used.
        static let idle = dynamic(light: 0xB86E00, dark: 0xF5B544)
        static let idleSoft = dynamic(light: 0xF59E0B, dark: 0xF5B544, lightAlpha: 0.14, darkAlpha: 0.14)

        private static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
            })
        }
    }

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let pill: CGFloat = 6
        static let control: CGFloat = 8
        static let card: CGFloat = 14
        static let hero: CGFloat = 18
    }

    enum Font {
        static let display = SwiftUI.Font.system(size: 30, weight: .semibold).monospacedDigit()
        static let title = SwiftUI.Font.system(size: 20, weight: .semibold)
        static let headline = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 13)
        static let number = SwiftUI.Font.system(size: 13, weight: .medium).monospacedDigit()
        static let caption = SwiftUI.Font.system(size: 11, weight: .medium)
        /// Small uppercase labels above sections and stats.
        static let eyebrow = SwiftUI.Font.system(size: 10, weight: .semibold)
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
