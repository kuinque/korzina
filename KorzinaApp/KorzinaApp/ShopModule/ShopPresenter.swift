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
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
        interactor?.fetchProducts(shopName: shopName, query: nil, category: nil)
        view?.setShopHeader(for: shopName)
    }
    
    func categorySelected(_ category: String) {
        currentCategory = category
        view?.displaySelectedCategory(category)
        
        // Очищаем текущие товары перед загрузкой новой категории
        allProducts = []
        view?.displayProducts([], append: false)
        
        // Получаем название категории из маппинга для API
        // Если категория "Все", отправляем nil, иначе используем точное название из маппинга
        let categoryToFetch: String?
        if category == "Все" {
            categoryToFetch = nil
        } else {
            categoryToFetch = categoryMapping[category] ?? category
        }
        
        // Загружаем продукты с сервера для выбранной категории
        interactor?.fetchProducts(shopName: shopName, query: nil, category: categoryToFetch)
    }
    
    func presentShopScreen() {
        view?.displayShopScreen()
    }
    
    // Маппинг коротких названий на реальные категории из БД
    // Названия категорий в БД: "Овощи, фрукты", "Молочная продукция", "Хлеб и выпечка", "Мясо и птица", "Сладости", "Вода и напитки"
    private let categoryMapping: [String: String] = [
        "Все": "Все",
        "Фрукты": "Овощи, фрукты",
        "Овощи": "Овощи, фрукты",
        "Мясо": "Мясо и птица",
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
                    guard let name = dict["name"] as? String else { return nil }
                    
                    var price: Double = 0
                    if let priceNum = dict["price"] as? NSNumber {
                        price = priceNum.doubleValue
                    } else if let priceDouble = dict["price"] as? Double {
                        price = priceDouble
                    } else if let priceString = dict["price"] as? String, let parsedPrice = Double(priceString) {
                        price = parsedPrice
                    }
                    
                    let category = dict["category"] as? String
                    let images = dict["images"] as? [String]
                    let imageURL = images?.first
                    let offerId = dict["id"] as? Int
                    
                    return ProductViewModel(
                        name: name,
                        price: price,
                        imageURL: imageURL,
                        description: dict["description"] as? String,
                        category: category,
                        offerId: offerId
                    )
                }
                
                // Еще раз проверяем актуальность категории
                guard self.currentCategory == expectedCategory else {
                    print("⚠️ Category changed after parsing, ignoring products")
                    DispatchQueue.main.async {
                        self.view?.hideLoadingIndicator()
                    }
                    return
                }
                
                // Сохраняем товары
                self.allProducts = vms
                
                // Фильтруем по категории
                let filteredProducts: [ProductViewModel]
                if self.currentCategory == "Все" {
                    filteredProducts = vms
                } else {
                    let apiCategory = self.categoryMapping[self.currentCategory] ?? self.currentCategory
                    print("🔍 Filtering products for category '\(self.currentCategory)' (API category: '\(apiCategory)')")
                    print("📦 Total products before filter: \(vms.count)")
                    
                    // Логируем категории всех товаров для отладки
                    let categoryCounts = Dictionary(grouping: vms, by: { $0.category ?? "nil" })
                    print("📊 Products by category:")
                    for (cat, products) in categoryCounts {
                        print("   \(cat ?? "nil"): \(products.count) products")
                    }
                    
                    filteredProducts = vms.filter { product in
                        let matches = product.category == apiCategory
                        if !matches && product.category != nil {
                            print("   ❌ Product '\(product.name)' has category '\(product.category ?? "nil")', expected '\(apiCategory)'")
                        }
                        return matches
                    }
                    print("✅ Filtered to \(filteredProducts.count) products")
                }
                
                // Финальная проверка перед отображением
                guard self.currentCategory == expectedCategory else {
                    print("⚠️ Category changed before display, ignoring products")
                    DispatchQueue.main.async {
                        self.view?.hideLoadingIndicator()
                    }
                    return
                }
                
                // Показываем на главном потоке
                DispatchQueue.main.async {
                    // Последняя проверка перед отображением
                    guard self.currentCategory == expectedCategory else {
                        self.view?.hideLoadingIndicator()
                        return
                    }
                    self.view?.displayProducts(filteredProducts, append: false)
                    // Скрываем индикатор загрузки после отображения товаров
                    self.view?.hideLoadingIndicator()
                }
            }
        } else {
            // Для последующих страниц парсим синхронно (уже на фоне)
            let vms: [ProductViewModel] = products.compactMap { dict in
                guard let name = dict["name"] as? String else { return nil }
                
                var price: Double = 0
                if let priceNum = dict["price"] as? NSNumber {
                    price = priceNum.doubleValue
                } else if let priceDouble = dict["price"] as? Double {
                    price = priceDouble
                } else if let priceString = dict["price"] as? String, let parsedPrice = Double(priceString) {
                    price = parsedPrice
                }
                
                let category = dict["category"] as? String
                let images = dict["images"] as? [String]
                let imageURL = images?.first
                let offerId = dict["id"] as? Int
                
                return ProductViewModel(
                    name: name,
                    price: price,
                    imageURL: imageURL,
                    description: dict["description"] as? String,
                    category: category,
                    offerId: offerId
                )
            }
            
            allProducts.append(contentsOf: vms)
            
            // Для append не фильтруем - товары уже должны быть отфильтрованы API
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
    
    private func applyFilter() {
        let filtered: [ProductViewModel]
        if currentCategory == "Все" {
            filtered = allProducts
        } else {
            let apiCategory = categoryMapping[currentCategory] ?? currentCategory
            filtered = allProducts.filter { $0.category == apiCategory }
        }
        print("🛍️ ShopPresenter: Filtered to \(filtered.count) products for category '\(currentCategory)'")
        view?.displayProducts(filtered, append: false)
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

