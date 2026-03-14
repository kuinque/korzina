import UIKit

protocol ShopInteractorProtocol: AnyObject {
    var presenter: ShopPresenterProtocol? { get set }
    func viewDidLoad()
    func categorySelected(_ category: String)
    func fetchProducts(shopName: String, query: String?, category: String?)
    func fetchCategoryProducts(category: String)
    func fetchSubcategoryProducts(shopName: String, subcategory: String)
    func loadMoreProducts()
    func cancelCurrentRequest()
    var hasMoreProducts: Bool { get }
    var isLoading: Bool { get }
}

class ShopInteractor: ShopInteractorProtocol {
    weak var presenter: ShopPresenterProtocol?
    
    // Оптимизированная сессия с кэшированием
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }()
    
    private let baseURLString = Config.apiBaseURL
    private var currentShopName: String = ""
    private var currentTask: URLSessionDataTask? // Храним ссылку на текущую задачу
    private var currentCategory: String? // Храним текущую категорию для проверки актуальности
    private var currentQuery: String? // Храним текущий поисковый запрос
    
    // Пагинация
    private var currentPage: Int = 1
    private let firstPageSize: Int = 6
    private let pageSize: Int = 20
    private var hasMore: Bool = true
    var isLoading: Bool = false
    
    // Пагинация для новых эндпоинтов (offset-based)
    private var currentOffset: Int = 0
    private let offsetPageSize: Int = 50
    private enum FetchMode { case legacy, category, subcategory }
    private var currentFetchMode: FetchMode = .legacy
    
    // Очередь для парсинга данных
    private let parsingQueue = DispatchQueue(label: "com.korzina.parsing", qos: .userInitiated)
    
    func viewDidLoad() {
        presenter?.presentShopScreen()
        presenter?.presentCategories()
    }
    
    func categorySelected(_ category: String) {
        presenter?.presentSelectedCategory(category)
        // Фильтруем продукты по выбранной категории
        // НО: этот метод не должен использоваться, так как ShopPresenter вызывает fetchProducts напрямую
        // Оставляем для совместимости, но лучше использовать fetchProducts напрямую
        let categoryToFilter = category == "Все" ? nil : category
        print("⚠️ ShopInteractor.categorySelected called directly (should use fetchProducts instead)")
        fetchProducts(shopName: currentShopName, query: nil, category: categoryToFilter)
    }
    
    var hasMoreProducts: Bool {
        return hasMore && !isLoading
    }
    
    func fetchProducts(shopName: String, query: String?, category: String?) {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        
        currentFetchMode = .legacy
        
        let isNewSearch = currentShopName != shopName || currentCategory != category || currentQuery != query
        if isNewSearch {
            currentPage = 1
            hasMore = true
        }
        
        currentShopName = shopName
        currentCategory = category
        currentQuery = query
        
        fetchProductsPage(page: 1, shopName: shopName, query: query, category: category, append: false, isFirstPage: true)
    }
    
    func loadMoreProducts() {
        guard hasMore && !isLoading else { return }
        
        switch currentFetchMode {
        case .legacy:
            currentPage += 1
            fetchProductsPage(page: currentPage, shopName: currentShopName, query: currentQuery, category: currentCategory, append: true, isFirstPage: false)
        case .category:
            currentOffset += offsetPageSize
            fetchOffsetPage(pathPrefix: "/api/category/", name: currentCategory ?? "", offset: currentOffset, append: true)
        case .subcategory:
            currentOffset += offsetPageSize
            fetchOffsetPage(pathPrefix: "/api/subcategory/", name: currentCategory ?? "", offset: currentOffset, append: true)
        }
    }
    
    private func fetchProductsPage(page: Int, shopName: String, query: String?, category: String?, append: Bool, isFirstPage: Bool) {
        guard !isLoading else { 
            // Если уже загружается, скрываем индикатор для предыдущего запроса
            if !append {
                DispatchQueue.main.async {
                    self.presenter?.didFinishLoading()
                }
            }
            return 
        }
        
        isLoading = true
        
        // Уведомляем о начале загрузки (только для первой страницы)
        if !append {
            DispatchQueue.main.async {
                self.presenter?.willStartLoading()
            }
        }
        
        // Используем меньше товаров для первой страницы
        let limit = isFirstPage ? firstPageSize : pageSize
        
        guard var components = URLComponents(string: baseURLString + "/api/products") else { 
            print("❌ Failed to create URL components for baseURL: \(baseURLString)")
            isLoading = false
            DispatchQueue.main.async {
                if !append {
                    self.presenter?.didFailLoading(error: "Invalid URL")
                }
            }
            return 
        }
        var items: [URLQueryItem] = [
            URLQueryItem(name: "shop", value: shopName),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        if let cat = category, !cat.isEmpty {
            items.append(URLQueryItem(name: "category", value: cat))
            print("🔍 ShopInteractor: Fetching products with category filter: '\(cat)'")
        } else {
            print("🔍 ShopInteractor: Fetching products without category filter")
        }
        components.queryItems = items
        guard let url = components.url else { 
            print("❌ Failed to create URL from components")
            isLoading = false
            DispatchQueue.main.async {
                if !append {
                    self.presenter?.didFailLoading(error: "Invalid URL")
                }
            }
            return 
        }
        
        // НЕ используем кэш при фильтрации по категории - всегда загружаем свежие данные
        // Кэш может содержать товары из другой категории
        
        // При фильтрации по категории не используем кэш - всегда загружаем свежие данные
        let cachePolicy: URLRequest.CachePolicy = category != nil ? .reloadIgnoringLocalCacheData : .returnCacheDataElseLoad
        // Увеличиваем таймаут для запросов с категорией (может быть медленнее)
        let timeout: TimeInterval = category != nil ? 30 : 15
        let request = URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: timeout)
        // Сохраняем параметры для проверки в замыкании
        let expectedCategory = category
        let expectedPage = page
        let expectedIsFirstPage = isFirstPage
        let expectedShopName = shopName
        let expectedQuery = query
        
        // Создаем task и сохраняем его в currentTask перед использованием в замыкании
        var task: URLSessionDataTask!
        task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            defer {
                self.isLoading = false
            }
            
            // Проверяем, не был ли запрос отменен
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                // При отмене запроса скрываем индикатор загрузки
                DispatchQueue.main.async {
                    if !append {
                        self.presenter?.didFinishLoading()
                    }
                }
                return
            }
            
            // Проверяем, что это все еще актуальный запрос
            if self.currentTask !== task {
                // Запрос больше не актуален, скрываем индикатор
                DispatchQueue.main.async {
                    if !append {
                        self.presenter?.didFinishLoading()
                    }
                }
                return
            }
            
            // Проверяем, что параметры не изменились
            // Важно: проверяем все параметры, так как при быстром переключении
            // может прийти ответ от предыдущего запроса
            if self.currentShopName != expectedShopName || 
               self.currentCategory != expectedCategory || 
               self.currentPage != expectedPage ||
               self.currentQuery != expectedQuery {
                // Параметры изменились, скрываем индикатор и игнорируем ответ
                DispatchQueue.main.async {
                    if !append {
                        self.presenter?.didFinishLoading()
                    }
                }
                return
            }
            
            if let error = error {
                let nsError = error as NSError
                // Проверяем, является ли это таймаутом
                if nsError.code == NSURLErrorTimedOut {
                    print("⏱️ ShopInteractor: Request timed out for category: \(expectedCategory ?? "none")")
                    print("   URL: \(url.absoluteString)")
                } else {
                    print("❌ ShopInteractor: Network error: \(error)")
                }
                DispatchQueue.main.async {
                    if !append {
                        let errorMessage = nsError.code == NSURLErrorTimedOut ? 
                            "Запрос превысил время ожидания. Попробуйте еще раз." : 
                            "Ошибка сети: \(error.localizedDescription)"
                        self.presenter?.didFailLoading(error: errorMessage)
                    }
                }
                return
            }
            
            guard let data = data else {
                print("❌ ShopInteractor: No data received")
                DispatchQueue.main.async {
                    if !append {
                        self.presenter?.didFailLoading(error: "No data received")
                    }
                }
                return
            }
            
            // Парсим JSON на фоновом потоке для оптимизации
            self.parsingQueue.async {
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ ShopInteractor: Failed to parse JSON")
                    DispatchQueue.main.async {
                        if !append {
                            self.presenter?.didFailLoading(error: "Failed to parse response")
                        }
                    }
                    return
                }
                
                guard let status = json["status"] as? String, status == "success" else {
                    print("❌ ShopInteractor: API returned error status: \(json["status"] ?? "unknown")")
                    DispatchQueue.main.async {
                        if !append {
                            self.presenter?.didFailLoading(error: "API error: \(json["status"] ?? "unknown")")
                        }
                    }
                    return
                }
                
                guard let products = json["products"] as? [[String: Any]] else {
                    print("❌ ShopInteractor: No products in response")
                    DispatchQueue.main.async {
                        if !append {
                            self.presenter?.didFailLoading(error: "No products in response")
                        }
                    }
                    return
                }
                
                // Логируем категории товаров из ответа API
                if let expectedCat = expectedCategory {
                    print("🔍 ShopInteractor: Expected category: '\(expectedCat)', received \(products.count) products")
                    let categoriesInResponse = Set(products.compactMap { dict -> String? in
                        dict["category"] as? String ?? dict["category_name"] as? String
                    })
                    print("📊 Categories in API response: \(Array(categoriesInResponse))")
                }
                
                // Проверяем, есть ли еще товары (используем limit для текущей страницы)
                let expectedCount = expectedIsFirstPage ? self.firstPageSize : self.pageSize
                self.hasMore = products.count >= expectedCount
                
                // Кэшируем результаты (только для первой страницы)
                if !append && products.count > 0 {
                    // Парсим в ProductViewModel для кэша
                    let cachedProducts = products.compactMap { dict -> ProductViewModel? in
                        guard let name = dict["name"] as? String else { return nil }
                        var price: Double = 0
                        if let priceNum = dict["price"] as? NSNumber {
                            price = priceNum.doubleValue
                        } else if let priceDouble = dict["price"] as? Double {
                            price = priceDouble
                        }
                        let category = dict["category"] as? String ?? dict["category_name"] as? String
                        let subcategory = dict["subcategory"] as? String
                        let images = dict["images"] as? [String]
                        let imageURL = images?.first
                        
                        // Логируем категорию для отладки
                        if let cat = category {
                            print("   📦 Product '\(dict["name"] ?? "unknown")' has category: '\(cat)'")
                        }
                        return ProductViewModel(
                            name: name,
                            price: price,
                            imageURL: imageURL,
                            description: dict["description"] as? String,
                            category: category,
                            subcategory: subcategory,
                            offerId: dict["id"] as? Int
                        )
                    }
                    ProductCache.shared.cacheProducts(cachedProducts, for: url.absoluteString)
                }
                
                DispatchQueue.main.async {
                    // Проверяем еще раз, что запрос все еще актуален
                    if self.currentTask === task {
                        self.presenter?.didLoadProducts(products, append: append)
                    } else {
                        // Запрос больше не актуален, скрываем индикатор
                        if !append {
                            self.presenter?.didFinishLoading()
                        }
                    }
                }
            }
        }
        currentTask = task
        task.resume()
    }
    
    /// Загружает товары по категории через /api/category/{category_name}/offers
    func fetchCategoryProducts(category: String) {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        
        currentOffset = 0
        hasMore = true
        currentFetchMode = .category
        currentCategory = category
        currentQuery = nil
        
        fetchOffsetPage(pathPrefix: "/api/category/", name: category, offset: 0, append: false)
    }
    
    /// Загружает товары по подкатегории через /api/subcategory/{category_name}/offers
    func fetchSubcategoryProducts(shopName: String, subcategory: String) {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        
        currentOffset = 0
        hasMore = true
        currentFetchMode = .subcategory
        currentShopName = shopName
        currentCategory = subcategory
        currentQuery = nil
        
        fetchOffsetPage(pathPrefix: "/api/subcategory/", name: subcategory, offset: 0, append: false)
    }
    
    /// Универсальный метод для offset-based эндпоинтов (/api/category/ и /api/subcategory/)
    private func fetchOffsetPage(pathPrefix: String, name: String, offset: Int, append: Bool) {
        guard !isLoading else { return }
        isLoading = true
        
        if !append {
            DispatchQueue.main.async { self.presenter?.willStartLoading() }
        }
        
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let path = "\(pathPrefix)\(encodedName)/offers"
        
        guard var components = URLComponents(string: baseURLString + path) else {
            isLoading = false
            DispatchQueue.main.async { self.presenter?.didFailLoading(error: "Invalid URL") }
            return
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: String(offsetPageSize)),
            URLQueryItem(name: "offset", value: String(offset))
        ]
        
        guard let url = components.url else {
            isLoading = false
            DispatchQueue.main.async { self.presenter?.didFailLoading(error: "Invalid URL") }
            return
        }
        
        print("🔍 Fetching \(pathPrefix) '\(name)' offset=\(offset): \(url.absoluteString)")
        
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        let expectedCategory = self.currentCategory
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            defer { self.isLoading = false }
            
            if let error = error as NSError?, error.code == NSURLErrorCancelled { return }
            
            guard self.currentCategory == expectedCategory else {
                DispatchQueue.main.async { self.presenter?.didFinishLoading() }
                return
            }
            
            if let error = error {
                print("❌ Fetch error: \(error)")
                DispatchQueue.main.async { self.presenter?.didFailLoading(error: error.localizedDescription) }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async { self.presenter?.didFailLoading(error: "No data") }
                return
            }
            
            self.parsingQueue.async {
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    DispatchQueue.main.async { self.presenter?.didFailLoading(error: "Parse error") }
                    return
                }
                
                var offersArray: [[String: Any]] = []
                if let offers = json["offers"] as? [[String: Any]] {
                    offersArray = offers
                } else if let products = json["products"] as? [[String: Any]] {
                    offersArray = products
                }
                
                self.hasMore = offersArray.count >= self.offsetPageSize
                print("📦 '\(name)' offset=\(offset): received \(offersArray.count) offers, hasMore=\(self.hasMore)")
                
                DispatchQueue.main.async {
                    guard self.currentCategory == expectedCategory else {
                        self.presenter?.didFinishLoading()
                        return
                    }
                    self.presenter?.didLoadProducts(offersArray, append: append)
                }
            }
        }
        currentTask = task
        task.resume()
    }
    
    /// Отменяет текущий запрос (вызывается при закрытии экрана)
    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }
}



