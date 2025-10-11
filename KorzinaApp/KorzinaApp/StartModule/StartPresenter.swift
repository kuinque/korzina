import UIKit

protocol StartPresenterProtocol: AnyObject {
    var view: StartViewProtocol? { get set }
    var interactor: StartInteractorProtocol? { get set }
    var router: StartRouterProtocol? { get set }
    func viewDidLoad()
    func viewDidAppear()
    func presentStartScreen()
    func presentAnimations()
    func presentTabBar()
    func startButtonTapped()
}

class StartPresenter: StartPresenterProtocol {
    weak var view: StartViewProtocol?
    var interactor: StartInteractorProtocol?
    var router: StartRouterProtocol?
    
    init(view: StartViewProtocol, interactor: StartInteractorProtocol, router: StartRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
    }
    
    func viewDidAppear() {
        interactor?.viewDidAppear()
    }
    
    func presentStartScreen() {
        view?.displayStartScreen()
    }
    
    func presentAnimations() {
        // Добавляем небольшую задержку для корректного отображения анимаций
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.view?.animateLogo()
            self.view?.animateLogoName()
            self.view?.animateStartButton()
        }
    }
    
    func startButtonTapped() {
        interactor?.startButtonTapped()
    }
    
    func presentTabBar() {
        router?.navigateToTabBar()
    }
}
