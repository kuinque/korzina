import UIKit

class ShopBuilder {
    static func build(shopName: String) -> UIViewController {
        let view = ShopView()
        let interactor = ShopInteractor()
        let router = ShopRouter(viewController: view)
        let presenter = ShopPresenter(view: view, interactor: interactor, router: router, shopName: shopName)
        
        // Устанавливаем связи между компонентами
        view.presenter = presenter
        interactor.presenter = presenter
        
        return view
    }
}

