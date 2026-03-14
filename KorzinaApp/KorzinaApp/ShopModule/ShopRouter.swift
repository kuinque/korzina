import UIKit

protocol ShopRouterProtocol: AnyObject {
    var view: ShopViewProtocol? { get set }
    func navigateToBasket()
}

class ShopRouter: ShopRouterProtocol {
    weak var view: ShopViewProtocol?
    private weak var viewController: UIViewController?
    private var shopName: String
    
    init(viewController: UIViewController, shopName: String) {
        self.viewController = viewController
        self.view = viewController as? ShopViewProtocol
        self.shopName = shopName
    }
    
    func navigateToBasket() {
        guard let viewController = viewController else { 
            print("❌ ShopRouter: viewController is nil")
            return 
        }
        
        print("🛒 ShopRouter: navigateToBasket called, shopName: \(shopName)")
        
        // Создаем BasketView и пушим через navigation controller
        let basketView = BasketBuilder.build()
        
        // Передаем информацию о магазине через NotificationCenter перед навигацией
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToBasket"), object: nil, userInfo: ["shopName": shopName])
        
        // Навигация через navigation controller
        if let navigationController = viewController.navigationController {
            print("✅ ShopRouter: Found navigation controller, pushing BasketView")
            navigationController.pushViewController(basketView, animated: true)
        } else {
            print("⚠️ ShopRouter: No navigation controller, presenting modally")
            // Если нет navigation controller, создаем новый
            let navController = UINavigationController(rootViewController: basketView)
            navController.modalPresentationStyle = .fullScreen
            viewController.present(navController, animated: true)
        }
    }
}

