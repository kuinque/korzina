import UIKit

protocol ShopPresenterProtocol: AnyObject {
    var view: ShopViewProtocol? { get set }
    var interactor: ShopInteractorProtocol? { get set }
    var router: ShopRouterProtocol? { get set }
    func viewDidLoad()
    func categorySelected(_ category: String)
    func presentShopScreen()
    func presentCategories()
    func presentSelectedCategory(_ category: String)
    func didLoadProducts(_ products: [[String: Any]])
    func searchTextChanged(_ text: String)
}

class ShopPresenter: ShopPresenterProtocol {
    weak var view: ShopViewProtocol?
    var interactor: ShopInteractorProtocol?
    weak var router: ShopRouterProtocol?
    private let shopName: String
    
    struct ProductViewModel {
        let name: String
        let price: Double
    }
    
    init(view: ShopViewProtocol, interactor: ShopInteractorProtocol, router: ShopRouterProtocol, shopName: String) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.shopName = shopName
    }
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
        interactor?.fetchProducts(shopName: shopName, query: nil)
    }
    
    func categorySelected(_ category: String) {
        interactor?.categorySelected(category)
    }
    
    func presentShopScreen() {
        view?.displayShopScreen()
    }
    
    func presentCategories() {
        let categories = ["Все", "Фрукты", "Овощи", "Мясо", "Молочка", "Хлеб", "Напитки", "Сладости"]
        view?.displayCategories(categories)
    }
    
    func presentSelectedCategory(_ category: String) {
        view?.displaySelectedCategory(category)
    }
    
    func didLoadProducts(_ products: [[String: Any]]) {
        let vms: [ProductViewModel] = products.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            let price = (dict["price"] as? NSNumber)?.doubleValue ?? (dict["price"] as? Double) ?? 0
            return ProductViewModel(name: name, price: price)
        }
        view?.displayProducts(vms)
    }
    
    func searchTextChanged(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        interactor?.fetchProducts(shopName: shopName, query: query.isEmpty ? nil : query)
    }
}

