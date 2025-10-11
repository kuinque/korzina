import UIKit

class BasketBuilder {
    static func build() -> UIViewController {
        let view = BasketView()
        let interactor = BasketInteractor()
        let router = BasketRouter(viewController: view)
        let presenter = BasketPresenter(view: view, interactor: interactor, router: router)
        
        // Устанавливаем связи между компонентами
        view.presenter = presenter
        interactor.presenter = presenter
        
        return view
    }
}

