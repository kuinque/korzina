import UIKit

protocol BasketInteractorProtocol: AnyObject {
    var presenter: BasketPresenterProtocol? { get set }
    func viewDidLoad()
    func comparePrices(products: [String], currentShopPrice: Double?, currentShopName: String?)
    func findProductInAllShops(productName: String, quantity: Int, currentShopName: String?)
}

class BasketInteractor: BasketInteractorProtocol {
    weak var presenter: BasketPresenterProtocol?
    private let baseURLString = Config.apiBaseURL
    
    func viewDidLoad() {
        presenter?.presentBasketScreen()
    }
    
    func comparePrices(products: [String], currentShopPrice: Double?, currentShopName: String?) {
        // Получаем offer_ids из корзины
        let cartItems = CartManager.shared.getAllCartItems()
        let offerIds = cartItems.compactMap { $0.product.offerId }
        
        print("🔍 Comparing prices for \(offerIds.count) offer IDs: \(offerIds)")
        
        // Если нет offer_ids, показываем только текущий магазин
        if offerIds.isEmpty {
            print("⚠️ No offer IDs available, showing current shop only")
            var priceComparisons: [PriceComparison] = []
            
            if let shopName = currentShopName {
                priceComparisons.append(PriceComparison(
                    shopName: shopName,
                    totalPrice: currentShopPrice,
                    productsFound: cartItems.count,
                    productsTotal: cartItems.count,
                    matchPercentage: 1.0,
                    isAvailable: true,
                    currentShopPrice: currentShopPrice,
                    isCurrentShop: true
                ))
            }
            
            presenter?.didReceivePriceComparisons(priceComparisons)
            return
        }
        
        guard let url = URL(string: baseURLString + "/api/all_alternatives") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = ["offer_ids": offerIds]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("Error creating request body: \(error)")
            return
        }
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error comparing prices: \(error)")
                    return
                }
                
                guard let data = data else { return }
                
                // Убрано избыточное логирование ответа
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let shops = json["shops"] as? [String: [[String: Any]]] {
                        
                        var priceComparisons: [PriceComparison] = []
                        let currentCartItems = CartManager.shared.getAllCartItems()
                        
                        for (shopName, matches) in shops {
                            print("🏪 Shop: \(shopName), matches: \(matches.count)")
                            
                            // Считаем общую цену для этого магазина
                            var totalPrice: Double = 0
                            var productsFound = 0
                            var cartItems: [CartItem] = []
                            
                            for (index, match) in matches.enumerated() {
                                print("  [\(index)] Processing match for shop \(shopName)")
                                guard let matchedOffer = match["matched_offer"] as? [String: Any],
                                      matchedOffer["offer_id"] != nil else {
                                    continue
                                }
                                
                                // Логируем все поля match
                                print("    📋 Match fields:")
                                for (key, value) in match {
                                    if key != "matched_offer" {
                                        print("      \(key): \(value)")
                                    }
                                }
                                
                                // Логируем все поля matched_offer
                                print("    📦 Matched offer fields:")
                                for (key, value) in matchedOffer {
                                    if key != "images" {
                                        print("      \(key): \(value)")
                                    } else {
                                        print("      \(key): [\(value)] (images array)")
                                    }
                                }
                                
                                let productName = matchedOffer["title"] as? String ?? ""
                                let targetTitle = match["target_title"] as? String ?? ""
                                
                                // Парсим цену (может быть строкой или числом)
                                var price: Double = 0
                                if let priceNum = matchedOffer["price"] as? NSNumber {
                                    price = priceNum.doubleValue
                                } else if let priceDouble = matchedOffer["price"] as? Double {
                                    price = priceDouble
                                } else if let priceString = matchedOffer["price"] as? String, let parsedPrice = Double(priceString) {
                                    price = parsedPrice
                                }
                                
                                // Находим количество из текущей корзины
                                var quantity = 1
                                if let matchingItem = currentCartItems.first(where: { 
                                    $0.product.name.lowercased() == targetTitle.lowercased() ||
                                    $0.product.name.lowercased().contains(targetTitle.lowercased()) || 
                                    targetTitle.lowercased().contains($0.product.name.lowercased()) 
                                }) {
                                    quantity = matchingItem.quantity
                                }
                                
                                totalPrice += price * Double(quantity)
                                productsFound += 1
                                
                                // Получаем изображение
                                var imageURL: String? = nil
                                if let images = matchedOffer["images"] as? [String], !images.isEmpty {
                                    imageURL = images.first
                                }
                                
                                let product = ProductViewModel(
                                    name: productName,
                                    price: price,
                                    imageURL: imageURL,
                                    description: matchedOffer["description"] as? String,
                                    category: matchedOffer["category_name"] as? String,
                                    offerId: matchedOffer["offer_id"] as? Int
                                )
                                
                                // Получаем is_identical из ответа API /api/all_alternatives
                                // Сначала проверяем прямое поле is_identical в match
                                var isIdentical = false
                                
                                let matchType = match["match_type"] as? String ?? ""
                                let similarity = match["similarity"] as? Double ?? 0.0
                                let matchedOfferId = matchedOffer["offer_id"] as? Int
                                let targetOfferId = match["target_offer_id"] as? Int
                                
                                if let isIdenticalValue = match["is_identical"] as? Bool {
                                    isIdentical = isIdenticalValue
                                    print("   ✅ is_identical from API: \(isIdentical)")
                                } else if let isIdenticalValue = match["isIdentical"] as? Bool {
                                    isIdentical = isIdenticalValue
                                    print("   ✅ isIdentical from API: \(isIdentical)")
                                } else {
                                    // Fallback: определяем на основе match_type и similarity
                                    if let matchedId = matchedOfferId, let targetId = targetOfferId, matchedId == targetId {
                                        // Если offer_id совпадает, это точно тот же товар
                                        isIdentical = true
                                    } else if matchType.contains("full") && similarity >= 1.0 {
                                        // Если match_type содержит "full" и similarity = 1, товар идентичен
                                        isIdentical = true
                                    }
                                    print("   ⚠️ is_identical not in API response, calculated: \(isIdentical)")
                                }
                                
                                // Логируем информацию о товаре и флаге is_identical для корзины другого магазина
                                print("🛒 BasketInteractor: Adding offer to alternative shop cart (\(shopName)):")
                                print("   📦 Product name: \(productName)")
                                print("   🎯 Original product (target): \(targetTitle)")
                                print("   💰 Price: \(price) ₽")
                                print("   🆔 offer_id: \(matchedOfferId ?? -1)")
                                print("   🆔 target_offer_id: \(targetOfferId ?? -1)")
                                print("   🔍 match_type: '\(matchType)'")
                                print("   📊 similarity: \(similarity)")
                                print("   ✅ is_identical: \(isIdentical)")
                                
                                // Сохраняем связь с оригинальным товаром (targetTitle) и флаг is_identical
                                cartItems.append(CartItem(
                                    product: product,
                                    quantity: quantity,
                                    originalProductName: targetTitle,
                                    isIdentical: isIdentical
                                ))
                            }
                            
                            let isCurrentShop = shopName == currentShopName
                            
                            let priceComp = PriceComparison(
                                shopName: shopName,
                                totalPrice: productsFound > 0 ? totalPrice : nil,
                                productsFound: productsFound,
                                productsTotal: offerIds.count,
                                matchPercentage: Double(productsFound) / Double(offerIds.count),
                                isAvailable: productsFound > 0,
                                currentShopPrice: currentShopPrice,
                                isCurrentShop: isCurrentShop
                            )
                            
                            priceComparisons.append(priceComp)
                            
                            // Кэшируем товары для других магазинов
                            if !isCurrentShop && !cartItems.isEmpty {
                                let shopCart = ShopCart(
                                    shopName: shopName,
                                    items: cartItems,
                                    totalPrice: totalPrice,
                                    productsFound: productsFound,
                                    productsTotal: offerIds.count,
                                    matchPercentage: Double(productsFound) / Double(offerIds.count)
                                )
                                
                                CartManager.shared.updateCachedCart(shopName: shopName, cart: shopCart)
                                print("✅ Cached \(cartItems.count) items for \(shopName), total: \(totalPrice) ₽")
                            }
                        }
                        
                        // Сортируем: текущий магазин первый, остальные по выгоде (от меньшей цены к большей)
                        priceComparisons.sort { c1, c2 in
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
                        
                        print("📊 Sorted price comparisons:")
                        for comp in priceComparisons {
                            print("   \(comp.shopName): \(comp.totalPrice ?? 0) ₽")
                        }
                        
                        self?.presenter?.didReceivePriceComparisons(priceComparisons)
                    }
                } catch {
                    print("Error parsing price comparisons: \(error)")
                }
            }
        }.resume()
    }
    
    func findProductInAllShops(productName: String, quantity: Int, currentShopName: String? = nil) {
        // Получаем все кэшированные магазины
        let cachedCarts = CartManager.shared.getCachedShopCarts()
        
        // Для каждого магазина (кроме текущего) ищем похожий товар
        for cart in cachedCarts {
            // Пропускаем текущий магазин - для него показываем реальную корзину
            if let currentShop = currentShopName, cart.shopName == currentShop {
                print("⏭️ Skipping search in current shop: \(cart.shopName)")
                continue
            }
            findProductInShop(productName: productName, shopName: cart.shopName, quantity: quantity)
        }
    }
    
    private func findProductInShop(productName: String, shopName: String, quantity: Int) {
        // Кодируем параметры для URL
        let encodedProductName = productName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? productName
        let encodedShopName = shopName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shopName
        
        let urlString = baseURLString + "/api/search-product-in-shop?product_name=\(encodedProductName)&shop_name=\(encodedShopName)"
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL: \(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        print("🔍 Searching for '\(productName)' in '\(shopName)'...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error finding product: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("❌ No data received")
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("📦 Response: \(json)")
                        
                        if let found = json["found"] as? Bool, found,
                           let productData = json["product"] as? [String: Any] {
                            
                            // Создаем CartItem из найденного товара
                            let product = ProductViewModel(
                                name: productData["name"] as? String ?? productName,
                                price: productData["price"] as? Double ?? 0,
                                imageURL: productData["image"] as? String,
                                description: productData["description"] as? String,
                                category: productData["category"] as? String,
                                offerId: nil
                            )
                            
                            let cartItem = CartItem(product: product, quantity: quantity)
                            
                            print("✅ Found product: \(product.name) at \(product.price) ₽")
                            
                            // Добавляем товар в кэш для этого магазина
                            CartManager.shared.addItemToCachedCart(shopName: shopName, item: cartItem)
                            
                            // Обновляем UI (загружаем из кэша)
                            if let presenter = self.presenter {
                                presenter.viewWillAppear()
                            }
                        } else {
                            print("⚠️ Product not found in \(shopName)")
                        }
                    }
                } catch {
                    print("❌ Error parsing product search: \(error)")
                }
            }
        }.resume()
    }
}



