import UIKit

protocol ShopInteractorProtocol: AnyObject {
    var presenter: ShopPresenterProtocol? { get set }
    func viewDidLoad()
    func categorySelected(_ category: String)
    func fetchProducts(shopName: String, query: String?, category: String?)
}

class ShopInteractor: ShopInteractorProtocol {
    weak var presenter: ShopPresenterProtocol?
    
    private let session = URLSession.shared
    private let baseURLString = Config.apiBaseURL
    private var currentShopName: String = ""
    
    func viewDidLoad() {
        presenter?.presentShopScreen()
        presenter?.presentCategories()
    }
    
    func categorySelected(_ category: String) {
        presenter?.presentSelectedCategory(category)
        // Фильтруем продукты по выбранной категории
        let categoryToFilter = category == "Все" ? nil : category
        fetchProducts(shopName: currentShopName, query: nil, category: categoryToFilter)
    }
    
    func fetchProducts(shopName: String, query: String?, category: String?) {
        currentShopName = shopName
        guard var components = URLComponents(string: baseURLString + "/api/products") else { 
            print("❌ Failed to create URL components for baseURL: \(baseURLString)")
            return 
        }
        var items: [URLQueryItem] = [URLQueryItem(name: "shop", value: shopName)]
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        if let cat = category, !cat.isEmpty { items.append(URLQueryItem(name: "category", value: cat)) }
        components.queryItems = items
        guard let url = components.url else { 
            print("❌ Failed to create URL from components")
            return 
        }
        
        print("🌐 Making request to: \(url.absoluteString)")
        print("🔍 Shop name: '\(shopName)'")
        print("🔍 Query: '\(query ?? "nil")'")
        print("🔍 Category: '\(category ?? "nil")'")
        let request = URLRequest(url: url)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ Network error: \(error)")
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 HTTP Status: \(httpResponse.statusCode)")
            }
            
            guard let data = data else {
                print("❌ No data received")
                return
            }
            
            print("📦 Received data: \(data.count) bytes")
            
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Failed to parse JSON")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response: \(responseString)")
                }
                return
            }
            
            print("✅ JSON parsed successfully")
            
            guard let status = json["status"] as? String, status == "success" else {
                print("❌ API returned error status: \(json["status"] ?? "unknown")")
                return
            }
            
            guard let products = json["products"] as? [[String: Any]] else {
                print("❌ No products in response")
                return
            }
            
            print("✅ Found \(products.count) products")
            DispatchQueue.main.async {
                self.presenter?.didLoadProducts(products)
            }
        }
        task.resume()
    }
}



