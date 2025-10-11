import UIKit

class ProfileBuilder {
    static func build() -> UIViewController {
        let view = ProfileView()
        let interactor = ProfileInteractor()
        let router = ProfileRouter(viewController: view)
        let presenter = ProfilePresenter(view: view, interactor: interactor, router: router)
        
        // Устанавливаем связи между компонентами
        view.presenter = presenter
        interactor.presenter = presenter
        
        return view
    }
}

