import UIKit

protocol MainPresenterProtocol: AnyObject {
    var view: MainViewProtocol? { get set }
    var interactor: MainInteractorProtocol? { get set }
    var router: MainRouterProtocol? { get set }
    func viewDidLoad()
    func storeSelected(storeName: String)
    func presentMainScreen()
    func presentStores()
    func presentShopScreen(storeName: String)
}

class MainPresenter: MainPresenterProtocol {
    weak var view: MainViewProtocol?
    var interactor: MainInteractorProtocol?
    var router: MainRouterProtocol?
    
    init(view: MainViewProtocol, interactor: MainInteractorProtocol, router: MainRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
    }
    
    func storeSelected(storeName: String) {
        interactor?.storeSelected(storeName: storeName)
    }
    
    func presentMainScreen() {
        view?.displayMainScreen()
    }
    
    func presentStores() {
        let stores = [
            StoreViewModel(imageName: "ashan", storeName: "Ашан"),
            StoreViewModel(imageName: "perek", storeName: "Перекресток"),
            StoreViewModel(imageName: "lenta", storeName: "Лента"),
            StoreViewModel(imageName: "pyaterochka", storeName: "Пятерочка"),
            StoreViewModel(imageName: "magnit", storeName: "Магнит")
        ]
        view?.displayStores(stores)
    }
    
    func presentShopScreen(storeName: String) {
        router?.navigateToShop(shopName: storeName)
    }
}

