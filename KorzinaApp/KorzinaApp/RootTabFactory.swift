import UIKit

enum RootTabFactory {
    static func makeRootTabController() -> UITabBarController {
        let homeVC = MainBuilder.build()
      
        let basketVC = BasketBuilder.build()
        
        let profileVC = ProfileBuilder.build()
    

        let navHome = UINavigationController(rootViewController: homeVC)
        let navBasket = UINavigationController(rootViewController: basketVC)
        let navProfile = UINavigationController(rootViewController: profileVC)

        // Use provided asset images (template mode so tint applies), resized bigger
        let targetIconSize = CGSize(width: 20, height: 28)
        let homeImage = resizeTemplateImage(named: "home", to: targetIconSize)
        let homeSelected = resizeTemplateImage(named: "home_s", to: targetIconSize)
        let basketImage = resizeTemplateImage(named: "basket", to: targetIconSize)
        let basketSelected = resizeTemplateImage(named: "basket_s", to: targetIconSize)
        let profileImage = resizeTemplateImage(named: "profilex", to: targetIconSize)
        let profileSelected = resizeTemplateImage(named: "profilex_s", to: targetIconSize)

        navHome.tabBarItem = UITabBarItem(title: "Магазины", image: homeImage, selectedImage: homeSelected)
        navBasket.tabBarItem = UITabBarItem(title: "Моя корзина", image: basketImage, selectedImage: basketSelected)
        navProfile.tabBarItem = UITabBarItem(title: "Профиль", image: profileImage, selectedImage: profileSelected)

        let tabBar = UITabBarController()
        // Replace default tabBar with taller custom tab bar
        let customTabBar = TallerTabBar()
        customTabBar.extraHeight = 12 // raise top edge by 12pt (adjust as needed)
        tabBar.setValue(customTabBar, forKey: "tabBar")
        tabBar.viewControllers = [navHome, navBasket, navProfile]

        // Colors for selected/unselected states
        tabBar.tabBar.tintColor = UIColor.primaryColor
        tabBar.tabBar.unselectedItemTintColor = .unselect

        // Background color and bigger labels with Inter-Regular if available
        if #available(iOS 13.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.barColor

            let normalFont = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
            let selectedFont = UIFont(name: "Inter-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14, weight: .medium)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .font: normalFont,
                .foregroundColor: UIColor.unselect ?? .black
            ]
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .font: selectedFont,
                .foregroundColor: UIColor.primaryColor ?? .label
            ]
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.unselect ?? .black
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.primaryColor ?? .label

            // Remove top hairline
            appearance.shadowColor = .clear

            appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
            appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance

            tabBar.tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                tabBar.tabBar.scrollEdgeAppearance = appearance
            }
        }

        // Fallback for older iOS: remove hairline
        tabBar.tabBar.backgroundImage = UIImage()
        tabBar.tabBar.shadowImage = UIImage()

        // Slight insets to emphasize icon size
        navHome.tabBarItem.imageInsets = UIEdgeInsets(top: -1, left: 0, bottom: 1, right: 0)
        navBasket.tabBarItem.imageInsets = UIEdgeInsets(top: -1, left: 0, bottom: 1, right: 0)
        navProfile.tabBarItem.imageInsets = UIEdgeInsets(top: -1, left: 0, bottom: 1, right: 0)

        return tabBar
    }

    // MARK: - Helpers
    private static func resizeTemplateImage(named: String, to size: CGSize) -> UIImage? {
        guard let image = UIImage(named: named) else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.withRenderingMode(.alwaysTemplate)
    }
}

// Taller tab bar to raise the top edge higher
final class TallerTabBar: UITabBar {
    var extraHeight: CGFloat = 0

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var newSize = super.sizeThatFits(size)
        newSize.height += extraHeight
        return newSize
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep tab bar buttons at original vertical position (relative to bottom)
        // while only raising the top edge by extraHeight.
        let offset = extraHeight / 2
        for view in subviews {
            if let cls = NSClassFromString("UITabBarButton"), view.isKind(of: cls) {
                var frame = view.frame
                frame.origin.y += offset
                view.frame = frame
            }
        }
    }
}


