import AppKit
import SwiftUI

/// Design tokens. Every color, size and radius in the app comes from here.
/// See docs/design-system.md for the rules behind them.
enum Theme {
    enum Palette {
        static let canvas = dynamic(light: 0xFAFAFA, dark: 0x0D0E10)
        static let surface = dynamic(light: 0xFFFFFF, dark: 0x131416)
        /// Hover and selection fill.
        static let raised = dynamic(light: 0xF1F1F2, dark: 0x1B1C1F)
        static let hairline = dynamic(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.08, darkAlpha: 0.07)

        static let text = dynamic(light: 0x18181B, dark: 0xEDEDEF)
        static let textSecondary = dynamic(light: 0x6B6D74, dark: 0x8B8D94)
        static let textTertiary = dynamic(light: 0xA0A2A8, dark: 0x5B5D63)

        /// Used and alive. Soft mint, never loud.
        static let accent = dynamic(light: 0x059669, dark: 0x6EE7B7)
        static let accentSoft = dynamic(light: 0x059669, dark: 0x6EE7B7, lightAlpha: 0.10, darkAlpha: 0.12)
        /// Installed but never used.
        static let idle = dynamic(light: 0xB7791F, dark: 0xE3B341)
        static let danger = dynamic(light: 0xDC2626, dark: 0xF87171)

        private static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
            Color(nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return NSColor(hex: isDark ? dark : light, alpha: isDark ? darkAlpha : lightAlpha)
            })
        }
    }

    enum Space {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 6
        static let row: CGFloat = 6
        static let panel: CGFloat = 10
    }

    enum Size {
        static let row: CGFloat = 34
        static let header: CGFloat = 52
        static let agentColumn: CGFloat = 34
    }

    enum Font {
        static let title = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 13)
        static let bodyMedium = SwiftUI.Font.system(size: 13, weight: .medium)
        static let secondary = SwiftUI.Font.system(size: 12)
        static let number = SwiftUI.Font.system(size: 12, weight: .medium).monospacedDigit()
        static let caption = SwiftUI.Font.system(size: 11)
        static let section = SwiftUI.Font.system(size: 11, weight: .semibold)
        static let mono = SwiftUI.Font.system(size: 11, design: .monospaced)
    }

    enum Motion {
        static let quick = Animation.easeOut(duration: 0.12)
        static let smooth = Animation.spring(duration: 0.28, bounce: 0.1)
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
