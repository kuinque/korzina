import UIKit

protocol BasketPresenterProtocol: AnyObject {
    var view: BasketViewProtocol? { get set }
    var interactor: BasketInteractorProtocol? { get set }
    var router: BasketRouterProtocol? { get set }
    func viewDidLoad()
    func presentBasketScreen()
}

class BasketPresenter: BasketPresenterProtocol {
    weak var view: BasketViewProtocol?
    var interactor: BasketInteractorProtocol?
    var router: BasketRouterProtocol?
    
    init(view: BasketViewProtocol, interactor: BasketInteractorProtocol, router: BasketRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
    }
    
    func presentBasketScreen() {
        view?.displayBasketScreen()
    }
}

