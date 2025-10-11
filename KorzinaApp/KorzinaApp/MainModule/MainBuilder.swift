import UIKit

class MainBuilder {
    static func build() -> UIViewController {
        let view = MainView()
        let interactor = MainInteractor()
        let router = MainRouter(viewController: view)
        let presenter = MainPresenter(view: view, interactor: interactor, router: router)
        
        // Устанавливаем связи между компонентами
        view.presenter = presenter
        interactor.presenter = presenter
        
        return view
    }
}

