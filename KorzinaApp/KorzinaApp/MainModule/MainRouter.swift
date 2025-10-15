import UIKit

protocol MainRouterProtocol: AnyObject {
    var view: MainViewProtocol? { get set }
    func navigateToShop(shopName: String)
}

class MainRouter: MainRouterProtocol {
    weak var view: MainViewProtocol?
    private weak var viewController: UIViewController?
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        self.view = viewController as? MainViewProtocol
    }
    
    func navigateToShop(shopName: String) {
        guard let viewController = viewController else { return }
        
        let shopView = ShopBuilder.build(shopName: shopName)
        
        if let navigationController = viewController.navigationController {
            navigationController.pushViewController(shopView, animated: true)
        } else {
            shopView.modalPresentationStyle = .fullScreen
            viewController.present(shopView, animated: true)
        }
    }
}

