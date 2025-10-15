import UIKit

protocol StartRouterProtocol: AnyObject {
    var view: StartViewProtocol? { get set }
    func navigateToTabBar()
}

class StartRouter: StartRouterProtocol {
    weak var view: StartViewProtocol?
    private weak var viewController: UIViewController?
    
    init(viewController: UIViewController) {
        self.viewController = viewController
        self.view = viewController as? StartViewProtocol
    }
    
    func navigateToTabBar() {
        guard let viewController = viewController else { return }
        let tabBar = RootTabFactory.makeRootTabController()
        tabBar.modalPresentationStyle = .fullScreen
        viewController.present(tabBar, animated: true)
    }
}
