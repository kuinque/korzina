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
    func addToCart(product: ProductViewModel)
    func removeFromCart(product: ProductViewModel)
    func updateCartQuantity(product: ProductViewModel, quantity: Int)
    func getCartQuantity(for product: ProductViewModel) -> Int
    func navigateToBasket()
}

class ShopPresenter: ShopPresenterProtocol {
    weak var view: ShopViewProtocol?
    var interactor: ShopInteractorProtocol?
    weak var router: ShopRouterProtocol?
    private let shopName: String
    private var allProducts: [ProductViewModel] = []
    private var currentCategory: String = "Все"
    
    init(view: ShopViewProtocol, interactor: ShopInteractorProtocol, router: ShopRouterProtocol, shopName: String) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.shopName = shopName
    }
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
        interactor?.fetchProducts(shopName: shopName, query: nil, category: nil)
        view?.setShopHeader(for: shopName)
    }
    
    func categorySelected(_ category: String) {
        currentCategory = category
        view?.displaySelectedCategory(category)
        applyFilter()
    }
    
    func presentShopScreen() {
        view?.displayShopScreen()
    }
    
    // Маппинг коротких названий на реальные категории из API
    private let categoryMapping: [String: String] = [
        "Все": "Все",
        "Фрукты": "Овощи, фрукты, орехи",
        "Овощи": "Овощи, фрукты, орехи",
        "Мясо": "Мясо, птица, колбасы",
        "Молочка": "Молочная продукция",
        "Хлеб": "Хлеб и выпечка",
        "Напитки": "Вода и напитки",
        "Сладости": "Сладости"
    ]
    
    func presentCategories() {
        let categories = ["Все", "Фрукты", "Овощи", "Мясо", "Молочка", "Хлеб", "Напитки", "Сладости"]
        view?.displayCategories(categories)
    }
    
    func presentSelectedCategory(_ category: String) {
        view?.displaySelectedCategory(category)
    }
    
    func didLoadProducts(_ products: [[String: Any]]) {
        print("🛍️ ShopPresenter: Received \(products.count) products")
        
        let vms: [ProductViewModel] = products.compactMap { dict in
            guard let name = dict["name"] as? String else { 
                print("❌ Missing name in product: \(dict)")
                return nil 
            }
            var price: Double = 0
            if let priceNum = dict["price"] as? NSNumber {
                price = priceNum.doubleValue
            } else if let priceDouble = dict["price"] as? Double {
                price = priceDouble
            } else if let priceString = dict["price"] as? String, let parsedPrice = Double(priceString) {
                price = parsedPrice
            }
            let description = dict["description"] as? String
            let category = dict["category"] as? String
            let images = dict["images"] as? [String]
            let imageURL = images?.first
            let offerId = dict["id"] as? Int
            print("✅ Product: \(name) - \(price) ₽ - Category: \(category ?? "none") - ID: \(offerId ?? -1)")
            return ProductViewModel(
                name: name, 
                price: price, 
                imageURL: imageURL,
                description: description,
                category: category,
                offerId: offerId
            )
        }
        
        print("🛍️ ShopPresenter: Created \(vms.count) ProductViewModels")
        
        // Сохраняем все продукты и применяем фильтр
        allProducts = vms
        applyFilter()
    }
    
    private func applyFilter() {
        let filtered: [ProductViewModel]
        if currentCategory == "Все" {
            filtered = allProducts
        } else {
            let apiCategory = categoryMapping[currentCategory] ?? currentCategory
            filtered = allProducts.filter { $0.category == apiCategory }
        }
        print("🛍️ ShopPresenter: Filtered to \(filtered.count) products for category '\(currentCategory)'")
        view?.displayProducts(filtered)
    }
    
    func searchTextChanged(_ text: String) {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        interactor?.fetchProducts(shopName: shopName, query: query.isEmpty ? nil : query, category: nil)
    }
    
    func addToCart(product: ProductViewModel) {
        // Устанавливаем текущий магазин при добавлении товара
        CartManager.shared.setCurrentShop(shopName)
        
        // Если это новый товар (не было в корзине) - инвалидируем кэш
        let wasInCart = CartManager.shared.getCartQuantity(for: product) > 0
        CartManager.shared.addToCart(product: product)
        
        if !wasInCart {
            // Новый товар добавлен - нужно пересчитать корзины других магазинов
            CartManager.shared.invalidateCache()
            print("🔄 New product added, cache invalidated")
        }
        
        updateCartDisplay()
    }
    
    func removeFromCart(product: ProductViewModel) {
        // Устанавливаем текущий магазин при удалении товара
        CartManager.shared.setCurrentShop(shopName)
        
        let quantityBefore = CartManager.shared.getCartQuantity(for: product)
        CartManager.shared.removeFromCart(product: product)
        let quantityAfter = CartManager.shared.getCartQuantity(for: product)
        
        // Если товар полностью удален - инвалидируем кэш
        if quantityBefore > 0 && quantityAfter == 0 {
            CartManager.shared.invalidateCache()
            print("🔄 Product removed completely, cache invalidated")
        }
        
        updateCartDisplay()
    }
    
    func updateCartQuantity(product: ProductViewModel, quantity: Int) {
        // Устанавливаем текущий магазин при изменении количества
        CartManager.shared.setCurrentShop(shopName)
        CartManager.shared.updateCartQuantity(product: product, quantity: quantity)
        updateCartDisplay()
    }
    
    private func updateCartDisplay() {
        let total = CartManager.shared.getCartTotal()
        view?.updateCartTotal(total)
        view?.refreshProductCells()
    }
    
    func getCartQuantity(for product: ProductViewModel) -> Int {
        return CartManager.shared.getCartQuantity(for: product)
    }
    
    func navigateToBasket() {
        router?.navigateToBasket()
    }
}

