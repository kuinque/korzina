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
    func didLoadProducts(_ products: [[String: Any]], append: Bool)
    func willStartLoading()
    func didFinishLoading()
    func didFailLoading(error: String)
    func loadMoreProducts()
    func searchTextChanged(_ text: String)
    func addToCart(product: ProductViewModel)
    func removeFromCart(product: ProductViewModel)
    func updateCartQuantity(product: ProductViewModel, quantity: Int)
    func getCartQuantity(for product: ProductViewModel) -> Int
    func navigateToBasket()
    func cancelCurrentRequest()
}

class ShopPresenter: ShopPresenterProtocol {
    weak var view: ShopViewProtocol?
    var interactor: ShopInteractorProtocol?
    var router: ShopRouterProtocol? // Убрали weak, чтобы router не освобождался
    private let shopName: String
    private var allProducts: [ProductViewModel] = []
    private var currentCategory: String = "Все"
    
    init(view: ShopViewProtocol, interactor: ShopInteractorProtocol, router: ShopRouterProtocol, shopName: String) {
        self.view = view
        self.interactor = interactor
        self.router = router
        self.shopName = shopName
    }
    
    private static let dairyCategoryName = "Молочная продукция"
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
        interactor?.fetchCategoryProducts(category: ShopPresenter.dairyCategoryName)
        view?.setShopHeader(for: shopName)
    }
    
    func categorySelected(_ category: String) {
        currentCategory = category
        view?.displaySelectedCategory(category)
        
        allProducts = []
        view?.displayProducts([], append: false)
        
        if category == "Все" {
            interactor?.fetchCategoryProducts(category: ShopPresenter.dairyCategoryName)
        } else {
            interactor?.fetchSubcategoryProducts(shopName: shopName, subcategory: category)
        }
    }
    
    func presentShopScreen() {
        view?.displayShopScreen()
    }
    
    // Порядок отображения подкатегорий в scrollView
    // Эти значения приходят с бэка в поле subcategory
    private let subcategoriesOrder: [String] = [
        "Молоко",
        "Растительные напитки",
        "Кисломолочные напитки",
        "Молочные коктейли и напитки",
        "Йогурты",
        "Творог и творожные продукты",
        "Молочные десерты",
        "Сметана",
        "Сливки",
        "Масло",
        "Сыры",
        "Сгущёнка и молочные консервы",
        "Детская молочная продукция",
        "Мороженое",
        "Закваски"
    ]
    
    func presentCategories() {
        // В scrollView теперь отображаем подкатегории (subcategory), плюс пункт "Все"
        let categories = ["Все"] + subcategoriesOrder
        view?.displayCategories(categories)
    }
    
    func presentSelectedCategory(_ category: String) {
        view?.displaySelectedCategory(category)
    }
    
    func didLoadProducts(_ products: [[String: Any]], append: Bool) {
        // Сохраняем текущую категорию для проверки актуальности
        let expectedCategory = currentCategory
        
        // Оптимизированный парсинг - делаем на фоновом потоке для первой страницы
        if !append {
            // Для первой страницы парсим быстро и показываем сразу
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                
                // Проверяем, что категория не изменилась во время парсинга
                guard self.currentCategory == expectedCategory else {
                    print("⚠️ Category changed during parsing, ignoring products")
                    DispatchQueue.main.async {
                        self.view?.hideLoadingIndicator()
                    }
                    return
                }
                
                let vms: [ProductViewModel] = products.compactMap { dict in
                    // Поддерживаем оба формата: name/title, id/offer_id
                    let name = dict["name"] as? String ?? dict["title"] as? String
                    guard let productName = name else { return nil }
                    
                    var price: Double = 0
                    if let priceNum = dict["price"] as? NSNumber {
                        price = priceNum.doubleValue
                    } else if let priceDouble = dict["price"] as? Double {
                        price = priceDouble
                    } else if let priceString = dict["price"] as? String, let parsedPrice = Double(priceString) {
                        price = parsedPrice
                    }
                    
                    let category = dict["category"] as? String ?? dict["category_name"] as? String
                    let subcategory = dict["subcategory"] as? String
                    let images = dict["images"] as? [String]
                    let imageURL = images?.first
                    let offerId = dict["id"] as? Int ?? dict["offer_id"] as? Int
                    
                    return ProductViewModel(
                        name: productName,
                        price: price,
                        imageURL: imageURL,
                        description: dict["description"] as? String,
                        category: category,
                        subcategory: subcategory,
                        offerId: offerId
                    )
                }
                
                guard self.currentCategory == expectedCategory else {
                    DispatchQueue.main.async { self.view?.hideLoadingIndicator() }
                    return
                }
                
                self.allProducts = vms
                print("📦 Loaded \(vms.count) products for '\(self.currentCategory)'")
                
                DispatchQueue.main.async {
                    guard self.currentCategory == expectedCategory else {
                        self.view?.hideLoadingIndicator()
                        return
                    }
                    self.view?.displayProducts(vms, append: false)
                    self.view?.hideLoadingIndicator()
                }
            }
        } else {
            // Для последующих страниц парсим синхронно (уже на фоне)
            let vms: [ProductViewModel] = products.compactMap { dict in
                let name = dict["name"] as? String ?? dict["title"] as? String
                guard let productName = name else { return nil }
                
                var price: Double = 0
                if let priceNum = dict["price"] as? NSNumber {
                    price = priceNum.doubleValue
                } else if let priceDouble = dict["price"] as? Double {
                    price = priceDouble
                } else if let priceString = dict["price"] as? String, let parsedPrice = Double(priceString) {
                    price = parsedPrice
                }
                
                let category = dict["category"] as? String ?? dict["category_name"] as? String
                let subcategory = dict["subcategory"] as? String
                let images = dict["images"] as? [String]
                let imageURL = images?.first
                let offerId = dict["id"] as? Int ?? dict["offer_id"] as? Int
                
                return ProductViewModel(
                    name: productName,
                    price: price,
                    imageURL: imageURL,
                    description: dict["description"] as? String,
                    category: category,
                    subcategory: subcategory,
                    offerId: offerId
                )
            }
            
            allProducts.append(contentsOf: vms)
            view?.displayProducts(vms, append: true)
        }
    }
    
    
    func loadMoreProducts() {
        interactor?.loadMoreProducts()
    }
    
    func willStartLoading() {
        view?.showLoadingIndicator()
    }
    
    func didFinishLoading() {
        view?.hideLoadingIndicator()
    }
    
    func didFailLoading(error: String) {
        view?.hideLoadingIndicator()
        // Можно показать ошибку пользователю, если нужно
        print("❌ Failed to load products: \(error)")
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
        print("🛒 ShopPresenter: navigateToBasket called")
        guard let router = router else {
            print("❌ ShopPresenter: router is nil")
            return
        }
        router.navigateToBasket()
    }
    
    func cancelCurrentRequest() {
        interactor?.cancelCurrentRequest()
    }
}

