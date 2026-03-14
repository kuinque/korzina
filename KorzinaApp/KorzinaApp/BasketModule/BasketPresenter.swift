import UIKit

protocol BasketPresenterProtocol: AnyObject {
    var view: BasketViewProtocol? { get set }
    var interactor: BasketInteractorProtocol? { get set }
    var router: BasketRouterProtocol? { get set }
    func viewDidLoad()
    func viewWillAppear()
    func presentBasketScreen()
    func updateItemQuantity(item: CartItem, quantity: Int)
    func removeItem(item: CartItem)
    func comparePrices()
    func didReceivePriceComparisons(_ comparisons: [PriceComparison])
    func setCurrentShop(_ shopName: String)
}

class BasketPresenter: BasketPresenterProtocol {
    weak var view: BasketViewProtocol?
    var interactor: BasketInteractorProtocol?
    var router: BasketRouterProtocol?
    private var currentShopName: String = "Пятёрочка" // По умолчанию
    
    init(view: BasketViewProtocol, interactor: BasketInteractorProtocol, router: BasketRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
    }
    
    func viewDidLoad() {
        interactor?.viewDidLoad()
        view?.setShopHeader(for: currentShopName)
    }
    
    func viewWillAppear() {
        loadCartItems()
        
        // Получаем текущий магазин из CartManager (если был установлен при добавлении товаров)
        if let shopFromCart = CartManager.shared.getCurrentShop() {
            currentShopName = shopFromCart
            print("🏪 BasketPresenter: Got current shop from CartManager: '\(shopFromCart)'")
        }
        
        let currentItems = CartManager.shared.getAllCartItems()
        
        // Если корзина пустая - очищаем всё
        if currentItems.isEmpty {
            CartManager.shared.invalidateCache()
            view?.displayPriceComparisons([])
            return
        }
        
        // Запрос к API только если кэш не готов (первый переход на экран корзины)
        if !CartManager.shared.isCacheReady() {
            print("🔄 Cache not ready, doing full price comparison via API")
            comparePrices()
        } else {
            print("✅ Using cached price comparisons (no API call)")
            loadFromCache()
        }
    }
    
    func presentBasketScreen() {
        view?.displayBasketScreen()
    }
    
    func updateItemQuantity(item: CartItem, quantity: Int) {
        CartManager.shared.updateCartQuantity(product: item.product, quantity: quantity)
        loadCartItems()
        
        // Обновляем количество во всех кэшированных корзинах (без запросов к API)
        if CartManager.shared.isCacheReady() {
            updateQuantityInCachedCarts(productName: item.product.name, quantity: quantity)
            loadFromCache()
        }
    }
    
    private func updateQuantityInCachedCarts(productName: String, quantity: Int) {
        let cachedCarts = CartManager.shared.getCachedShopCarts()
        for var cart in cachedCarts {
            // Находим похожий товар используя метод matchesProduct
            if let index = cart.items.firstIndex(where: { $0.matchesProduct(named: productName) }) {
                if quantity > 0 {
                    var updatedItem = cart.items[index]
                    updatedItem.quantity = quantity
                    cart.items[index] = updatedItem
                } else {
                    cart.items.remove(at: index)
                }
                cart.totalPrice = cart.items.reduce(0) { $0 + $1.totalPrice }
                cart.productsFound = cart.items.count
                CartManager.shared.updateCachedCart(shopName: cart.shopName, cart: cart)
                print("🔄 Updated quantity for '\(productName)' to \(quantity) in \(cart.shopName) cache, new total: \(cart.totalPrice)")
            }
        }
    }
    
    func removeItem(item: CartItem) {
        CartManager.shared.updateCartQuantity(product: item.product, quantity: 0)
        loadCartItems()
        
        // Удаляем товар из всех кэшированных корзин (без запросов к API)
        if CartManager.shared.isCacheReady() {
            updateQuantityInCachedCarts(productName: item.product.name, quantity: 0)
            loadFromCache()
        }
    }
    
    private func loadCartItems() {
        let items = CartManager.shared.getAllCartItems()
        let total = CartManager.shared.getCartTotal()
        view?.displayCartItems(items)
        view?.updateCartTotal(total)
    }
    
    func comparePrices() {
        let cartItems = CartManager.shared.getAllCartItems()
        
        // Если корзина пустая, очищаем сравнение цен
        if cartItems.isEmpty {
            view?.displayPriceComparisons([])
            return
        }
        
        // Создаем список товаров для сравнения (с учетом количества)
        var products: [String] = []
        for item in cartItems {
            // Добавляем товар столько раз, сколько его количество в корзине
            for _ in 0..<item.quantity {
                products.append(item.product.name)
            }
        }
        
        // Вызываем API для сравнения цен
        interactor?.comparePrices(products: products, currentShopPrice: getCurrentShopPrice(), currentShopName: currentShopName)
    }
    
    private func getCurrentShopPrice() -> Double? {
        // Получаем цену в текущем магазине из корзины
        let cartItems = CartManager.shared.getAllCartItems()
        let totalPrice = cartItems.reduce(0.0) { $0 + $1.totalPrice }
        return totalPrice > 0 ? totalPrice : nil
    }
    
    func didReceivePriceComparisons(_ comparisons: [PriceComparison]) {
        // Товары уже сохранены в кэш в BasketInteractor
        // Сортируем: текущий магазин первый, остальные по выгоде (от меньшей цены к большей)
        let sortedComparisons = comparisons.sorted { c1, c2 in
            // Текущий магазин всегда первый
            if c1.isCurrentShop && !c2.isCurrentShop {
                return true
            }
            if !c1.isCurrentShop && c2.isCurrentShop {
                return false
            }
            // Если оба текущие или оба не текущие, сортируем по цене
            let price1 = c1.totalPrice ?? Double.infinity
            let price2 = c2.totalPrice ?? Double.infinity
            return price1 < price2
        }
        view?.displayPriceComparisons(sortedComparisons)
    }
    
    private func loadFromCache() {
        let cachedCarts = CartManager.shared.getCachedShopCarts()
        let currentPrice = getCurrentShopPrice()
        
        print("🏪 loadFromCache: currentShopName = '\(currentShopName)'")
        print("🏪 loadFromCache: cachedCarts = \(cachedCarts.map { $0.shopName })")
        
        let comparisons = cachedCarts.map { cart -> PriceComparison in
            // Магазин считается текущим по названию
            let isCurrentShop = currentShopName == cart.shopName
            
            if isCurrentShop {
                print("🏪 Found current shop in cache: \(cart.shopName)")
            }
            
            return PriceComparison(
                shopName: cart.shopName,
                totalPrice: cart.totalPrice > 0 ? cart.totalPrice : nil,
                productsFound: cart.productsFound,
                productsTotal: cart.productsTotal,
                matchPercentage: cart.matchPercentage,
                isAvailable: cart.totalPrice > 0,
                currentShopPrice: currentPrice,
                isCurrentShop: isCurrentShop
            )
        }
        
        // Добавляем текущий магазин, если его нет в кэше
        var allComparisons = comparisons
        if !cachedCarts.contains(where: { $0.shopName == currentShopName }) {
            let currentCartItems = CartManager.shared.getAllCartItems()
            let currentCartTotal = currentCartItems.reduce(0) { $0 + $1.quantity }
            
            let currentShopComparison = PriceComparison(
                shopName: currentShopName,
                totalPrice: currentPrice,
                productsFound: currentCartTotal,
                productsTotal: currentCartTotal,
                matchPercentage: 100.0,
                isAvailable: currentPrice != nil && currentPrice! > 0,
                currentShopPrice: currentPrice,
                isCurrentShop: true
            )
            allComparisons.append(currentShopComparison)
        }
        
        // Сортируем: текущий магазин первый, остальные по выгоде (от меньшей цены к большей)
        let sortedComparisons = allComparisons.sorted { c1, c2 in
            // Текущий магазин всегда первый
            if c1.isCurrentShop && !c2.isCurrentShop {
                return true
            }
            if !c1.isCurrentShop && c2.isCurrentShop {
                return false
            }
            // Если оба текущие или оба не текущие, сортируем по цене
            let price1 = c1.totalPrice ?? Double.infinity
            let price2 = c2.totalPrice ?? Double.infinity
            return price1 < price2
        }
        view?.displayPriceComparisons(sortedComparisons)
    }
    
    func setCurrentShop(_ shopName: String) {
        currentShopName = shopName
        // Сохраняем текущий магазин в CartManager
        CartManager.shared.setCurrentShop(shopName)
        view?.setShopHeader(for: shopName)
        print("🏪 BasketPresenter: Set current shop to '\(shopName)'")
    }
}

