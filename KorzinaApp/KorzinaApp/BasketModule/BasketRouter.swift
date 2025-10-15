import UIKit

protocol BasketRouterProtocol: AnyObject {
    var view: BasketViewProtocol? { get set }
}

class BasketRouter: BasketRouterProtocol {
    weak var view: BasketViewProtocol?
    private weak var viewController: UIViewController?
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        self.view = viewController as? BasketViewProtocol
    }
}

