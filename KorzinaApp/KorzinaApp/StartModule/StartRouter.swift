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
        
        // Временно убрали tab bar - показываем только MainView
        let mainView = MainBuilder.build()
        let navController = UINavigationController(rootViewController: mainView)
        navController.modalPresentationStyle = .fullScreen
        navController.modalTransitionStyle = .crossDissolve
        viewController.present(navController, animated: true, completion: nil)
        
        /*
        // Оригинальный код с tab bar (закомментирован)
        let tabBar = RootTabFactory.makeRootTabController()
        tabBar.modalPresentationStyle = .fullScreen
        tabBar.modalTransitionStyle = .crossDissolve // Плавный переход
        viewController.present(tabBar, animated: true, completion: nil)
        */
    }
}
