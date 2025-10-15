import UIKit

protocol ProfileRouterProtocol: AnyObject {
    var view: ProfileViewProtocol? { get set }
}

class ProfileRouter: ProfileRouterProtocol {
    weak var view: ProfileViewProtocol?
    private weak var viewController: UIViewController?
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        self.view = viewController as? ProfileViewProtocol
    }
}

