import UIKit

protocol ProfilePresenterProtocol: AnyObject {
    var view: ProfileViewProtocol? { get set }
    var interactor: ProfileInteractorProtocol? { get set }
    var router: ProfileRouterProtocol? { get set }
    func viewDidLoad()
    func presentProfileScreen()
}

class ProfilePresenter: ProfilePresenterProtocol {
    weak var view: ProfileViewProtocol?
    var interactor: ProfileInteractorProtocol?
    var router: ProfileRouterProtocol?
    
    init(view: ProfileViewProtocol, interactor: ProfileInteractorProtocol, router: ProfileRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
    }
    
    func presentProfileScreen() {
        view?.displayProfileScreen()
    }
}

