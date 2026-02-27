#if DEBUG
import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

enum FontDebug {
    private static var hasLogged = false

    static func logSatoshiAvailability() {
        guard !hasLogged else { return }
        hasLogged = true

        #if canImport(UIKit)
        let families = UIFont.familyNames.sorted()
        let satoshiFamilies = families.filter { $0.localizedCaseInsensitiveContains("satoshi") }
        print("[FontDebug] UIFont families containing 'Satoshi': \(satoshiFamilies)")
        for family in satoshiFamilies {
            let names = UIFont.fontNames(forFamilyName: family).sorted()
            print("[FontDebug] \(family): \(names)")
        }
        #elseif canImport(AppKit)
        let families = NSFontManager.shared.availableFontFamilies.sorted()
        let satoshiFamilies = families.filter { $0.localizedCaseInsensitiveContains("satoshi") }
        print("[FontDebug] NSFont families containing 'Satoshi': \(satoshiFamilies)")
        #endif

        for weight in Theme.AppFontWeight.allCases {
            let resolvedName = Theme.resolvedAppFontPostScript(for: weight) ?? "none"
            print("[FontDebug] \(weight.rawValue) -> \(resolvedName)")
        }
    }
}
#endif
