import Foundation

// MARK: - Shop Cart Cache
struct ShopCart {
    let shopName: String
    var items: [CartItem]
    var totalPrice: Double
    var productsFound: Int
    var productsTotal: Int
    var matchPercentage: Double
    
    // Добавляем методы для удобства работы с items
    mutating func updateItem(productName: String, quantity: Int) {
        if let index = items.firstIndex(where: { $0.product.name == productName }) {
            items[index].quantity = quantity
            recalculateTotal()
        }
    }
    
    mutating func removeItem(productName: String) {
        items.removeAll { $0.product.name == productName }
        recalculateTotal()
    }
    
    private mutating func recalculateTotal() {
        totalPrice = items.reduce(0) { $0 + $1.totalPrice }
        productsFound = items.count
    }
}

class CartManager {
    static let shared = CartManager()
    
    private var cartItems: [String: CartItem] = [:]
    private var cartTotal: Double = 0.0
    
    // Кэш корзин других магазинов
    private var cachedShopCarts: [String: ShopCart] = [:]
    private var isCacheInitialized = false
    
    // Текущий магазин, из которого добавлены товары
    private var currentShopName: String? = nil
    
    private init() {}
    
    // MARK: - Notification Names
    static let cartDidChangeNotification = Notification.Name("CartDidChange")
    static let cartDidUpdateNotification = Notification.Name("CartDidUpdate")
    static let cartItemAddedNotification = Notification.Name("CartItemAdded")
    static let cartItemRemovedNotification = Notification.Name("CartItemRemoved")
    
    // MARK: - Cart Operations
    func addToCart(product: ProductViewModel) {
        if let existingItem = cartItems[product.name] {
            cartItems[product.name] = CartItem(product: product, quantity: existingItem.quantity + 1)
        } else {
            cartItems[product.name] = CartItem(product: product, quantity: 1)
        }
        updateCartTotal()
        NotificationCenter.default.post(name: CartManager.cartDidChangeNotification, object: nil)
    }
    
    func removeFromCart(product: ProductViewModel) {
        if let existingItem = cartItems[product.name] {
            if existingItem.quantity > 1 {
                cartItems[product.name] = CartItem(product: product, quantity: existingItem.quantity - 1)
            } else {
                cartItems.removeValue(forKey: product.name)
            }
        }
        updateCartTotal()
        NotificationCenter.default.post(name: CartManager.cartDidChangeNotification, object: nil)
    }
    
    func updateCartQuantity(product: ProductViewModel, quantity: Int) {
        if quantity > 0 {
            cartItems[product.name] = CartItem(product: product, quantity: quantity)
        } else {
            cartItems.removeValue(forKey: product.name)
        }
        updateCartTotal()
        NotificationCenter.default.post(name: CartManager.cartDidChangeNotification, object: nil)
    }
    
    func getCartQuantity(for product: ProductViewModel) -> Int {
        return cartItems[product.name]?.quantity ?? 0
    }
    
    func getAllCartItems() -> [CartItem] {
        return Array(cartItems.values)
    }
    
    func getCartTotal() -> Double {
        return cartTotal
    }
    
    func clearCart() {
        cartItems.removeAll()
        cartTotal = 0.0
        cachedShopCarts.removeAll()
        isCacheInitialized = false
        NotificationCenter.default.post(name: CartManager.cartDidChangeNotification, object: nil)
    }
    
    private func updateCartTotal() {
        cartTotal = cartItems.values.reduce(0) { $0 + $1.totalPrice }
    }
    
    // MARK: - Shop Cart Cache Management
    func getCachedShopCarts() -> [ShopCart] {
        return Array(cachedShopCarts.values)
    }
    
    func setCachedShopCarts(_ carts: [ShopCart]) {
        cachedShopCarts.removeAll()
        for cart in carts {
            cachedShopCarts[cart.shopName] = cart
        }
        isCacheInitialized = true
    }
    
    func updateCachedCart(shopName: String, cart: ShopCart) {
        cachedShopCarts[shopName] = cart
        
        // Если добавляем первые данные, помечаем кэш как инициализированный
        if !isCacheInitialized && !cachedShopCarts.isEmpty {
            isCacheInitialized = true
        }
    }
    
    func addItemToCachedCart(shopName: String, item: CartItem) {
        guard var cart = cachedShopCarts[shopName] else { return }
        
        // Ищем существующий товар по имени
        if let index = cart.items.firstIndex(where: { $0.product.name == item.product.name }) {
            // Обновляем данные товара (включая изображение) и увеличиваем количество
            cart.items[index] = CartItem(product: item.product, quantity: cart.items[index].quantity + item.quantity)
            print("🔄 Updated existing item in \(shopName): \(item.product.name), new quantity: \(cart.items[index].quantity)")
        } else {
            cart.items.append(item)
            print("➕ Added new item to \(shopName): \(item.product.name)")
        }
        
        // Пересчитываем итоги
        cart.totalPrice = cart.items.reduce(0) { $0 + $1.totalPrice }
        cart.productsFound = cart.items.count
        cart.productsTotal = cartItems.count
        cart.matchPercentage = Double(cart.productsFound) / Double(cart.productsTotal) * 100.0
        
        cachedShopCarts[shopName] = cart
    }
    
    func removeItemFromCachedCart(shopName: String, productName: String) {
        guard var cart = cachedShopCarts[shopName] else { return }
        
        // Удаляем товар по имени
        cart.items.removeAll { $0.product.name == productName }
        
        // Пересчитываем итоги
        cart.totalPrice = cart.items.reduce(0) { $0 + $1.totalPrice }
        cart.productsFound = cart.items.count
        cart.productsTotal = cartItems.count
        cart.matchPercentage = cart.productsTotal > 0 ? Double(cart.productsFound) / Double(cart.productsTotal) * 100.0 : 0.0
        
        cachedShopCarts[shopName] = cart
    }
    
    func isCacheReady() -> Bool {
        return isCacheInitialized
    }
    
    func invalidateCache() {
        cachedShopCarts.removeAll()
        isCacheInitialized = false
    }
    
    // MARK: - Current Shop Management
    func setCurrentShop(_ shopName: String) {
        currentShopName = shopName
        print("🏪 CartManager: Set current shop to '\(shopName)'")
    }
    
    func getCurrentShop() -> String? {
        return currentShopName
    }
}

// MARK: - Data Models
struct ProductViewModel {
    let name: String
    let price: Double
    let imageURL: String?
    let description: String?
    let category: String?
    let offerId: Int? // ID оффера из API для сравнения цен
}

struct CartItem {
    let product: ProductViewModel
    var quantity: Int
    var originalProductName: String? = nil // Название оригинального товара (для замен в других магазинах)
    
    var totalPrice: Double {
        return product.price * Double(quantity)
    }
    
    // Проверяет, соответствует ли этот товар указанному названию (учитывая замены)
    func matchesProduct(named name: String) -> Bool {
        let nameLower = name.lowercased()
        let productNameLower = product.name.lowercased()
        let originalLower = originalProductName?.lowercased()
        
        // Проверяем прямое совпадение
        if productNameLower == nameLower {
            return true
        }
        
        // Проверяем совпадение с оригинальным названием
        if let original = originalLower, original == nameLower {
            return true
        }
        
        // Проверяем частичное совпадение
        if productNameLower.contains(nameLower) || nameLower.contains(productNameLower) {
            return true
        }
        
        if let original = originalLower {
            if original.contains(nameLower) || nameLower.contains(original) {
                return true
            }
        }
        
        return false
    }
}
