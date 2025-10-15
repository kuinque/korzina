import UIKit

class StartBuilder {
    static func build() -> UIViewController {
        let view = StartView()
        let interactor = StartInteractor()
        let router = StartRouter(viewController: view)
        
        // Создаем presenter с уже установленными связями
        let presenter = StartPresenter(view: view, interactor: interactor, router: router)
        
        // Устанавливаем обратную связь
        view.presenter = presenter
        interactor.presenter = presenter
        
        
        return view
    }
}
