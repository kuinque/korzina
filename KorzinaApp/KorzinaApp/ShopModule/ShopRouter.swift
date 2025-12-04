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
        guard let tabBarController = viewController?.tabBarController else { 
            return 
        }
        tabBarController.selectedIndex = 1 // Basket tab index
        
        // Передаем информацию о магазине через NotificationCenter
        NotificationCenter.default.post(name: NSNotification.Name("NavigateToBasket"), object: nil, userInfo: ["shopName": shopName])
    }
}

