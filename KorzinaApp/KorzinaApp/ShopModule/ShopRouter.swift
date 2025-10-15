import UIKit

protocol ShopRouterProtocol: AnyObject {
    var view: ShopViewProtocol? { get set }
}

class ShopRouter: ShopRouterProtocol {
    weak var view: ShopViewProtocol?
    private weak var viewController: UIViewController?
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        self.view = viewController as? ShopViewProtocol
    }
}

