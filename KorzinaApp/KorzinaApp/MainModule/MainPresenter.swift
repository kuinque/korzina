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
            StoreViewModel(imageName: "pyaterochka", storeName: "Пятёрочка"),
            StoreViewModel(imageName: "perek", storeName: "Перекрёсток"),
            StoreViewModel(imageName: "lenta", storeName: "Лента"),
            StoreViewModel(imageName: "magnit", storeName: "Магнит"),
            StoreViewModel(imageName: "ashan", storeName: "Ашан"),
            StoreViewModel(imageName: "dixi", storeName: "Дикси"),
            StoreViewModel(imageName: "azbuka", storeName: "Азбука Вкуса"),
            StoreViewModel(imageName: "metro", storeName: "Метро")
        ]
        view?.displayStores(stores)
    }
    
    func presentShopScreen(storeName: String) {
        router?.navigateToShop(shopName: storeName)
    }
}

