import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "icon-ac" asset catalog image resource.
    static let iconAc = DeveloperToolsSupport.ImageResource(name: "icon-ac", bundle: resourceBundle)

    /// The "icon-back" asset catalog image resource.
    static let iconBack = DeveloperToolsSupport.ImageResource(name: "icon-back", bundle: resourceBundle)

    /// The "icon-calculator" asset catalog image resource.
    static let iconCalculator = DeveloperToolsSupport.ImageResource(name: "icon-calculator", bundle: resourceBundle)

    /// The "icon-divide" asset catalog image resource.
    static let iconDivide = DeveloperToolsSupport.ImageResource(name: "icon-divide", bundle: resourceBundle)

    /// The "icon-equal" asset catalog image resource.
    static let iconEqual = DeveloperToolsSupport.ImageResource(name: "icon-equal", bundle: resourceBundle)

    /// The "icon-menu" asset catalog image resource.
    static let iconMenu = DeveloperToolsSupport.ImageResource(name: "icon-menu", bundle: resourceBundle)

    /// The "icon-minus" asset catalog image resource.
    static let iconMinus = DeveloperToolsSupport.ImageResource(name: "icon-minus", bundle: resourceBundle)

    /// The "icon-multiply" asset catalog image resource.
    static let iconMultiply = DeveloperToolsSupport.ImageResource(name: "icon-multiply", bundle: resourceBundle)

    /// The "icon-percent" asset catalog image resource.
    static let iconPercent = DeveloperToolsSupport.ImageResource(name: "icon-percent", bundle: resourceBundle)

    /// The "icon-plus" asset catalog image resource.
    static let iconPlus = DeveloperToolsSupport.ImageResource(name: "icon-plus", bundle: resourceBundle)

    /// The "icon-plusminus" asset catalog image resource.
    static let iconPlusminus = DeveloperToolsSupport.ImageResource(name: "icon-plusminus", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "icon-ac" asset catalog image.
    static var iconAc: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconAc)
#else
        .init()
#endif
    }

    /// The "icon-back" asset catalog image.
    static var iconBack: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconBack)
#else
        .init()
#endif
    }

    /// The "icon-calculator" asset catalog image.
    static var iconCalculator: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconCalculator)
#else
        .init()
#endif
    }

    /// The "icon-divide" asset catalog image.
    static var iconDivide: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconDivide)
#else
        .init()
#endif
    }

    /// The "icon-equal" asset catalog image.
    static var iconEqual: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconEqual)
#else
        .init()
#endif
    }

    /// The "icon-menu" asset catalog image.
    static var iconMenu: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconMenu)
#else
        .init()
#endif
    }

    /// The "icon-minus" asset catalog image.
    static var iconMinus: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconMinus)
#else
        .init()
#endif
    }

    /// The "icon-multiply" asset catalog image.
    static var iconMultiply: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconMultiply)
#else
        .init()
#endif
    }

    /// The "icon-percent" asset catalog image.
    static var iconPercent: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconPercent)
#else
        .init()
#endif
    }

    /// The "icon-plus" asset catalog image.
    static var iconPlus: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconPlus)
#else
        .init()
#endif
    }

    /// The "icon-plusminus" asset catalog image.
    static var iconPlusminus: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .iconPlusminus)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "icon-ac" asset catalog image.
    static var iconAc: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconAc)
#else
        .init()
#endif
    }

    /// The "icon-back" asset catalog image.
    static var iconBack: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconBack)
#else
        .init()
#endif
    }

    /// The "icon-calculator" asset catalog image.
    static var iconCalculator: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconCalculator)
#else
        .init()
#endif
    }

    /// The "icon-divide" asset catalog image.
    static var iconDivide: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconDivide)
#else
        .init()
#endif
    }

    /// The "icon-equal" asset catalog image.
    static var iconEqual: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconEqual)
#else
        .init()
#endif
    }

    /// The "icon-menu" asset catalog image.
    static var iconMenu: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconMenu)
#else
        .init()
#endif
    }

    /// The "icon-minus" asset catalog image.
    static var iconMinus: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconMinus)
#else
        .init()
#endif
    }

    /// The "icon-multiply" asset catalog image.
    static var iconMultiply: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconMultiply)
#else
        .init()
#endif
    }

    /// The "icon-percent" asset catalog image.
    static var iconPercent: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconPercent)
#else
        .init()
#endif
    }

    /// The "icon-plus" asset catalog image.
    static var iconPlus: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconPlus)
#else
        .init()
#endif
    }

    /// The "icon-plusminus" asset catalog image.
    static var iconPlusminus: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .iconPlusminus)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

