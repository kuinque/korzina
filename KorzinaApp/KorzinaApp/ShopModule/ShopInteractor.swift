import UIKit

protocol ShopInteractorProtocol: AnyObject {
    var presenter: ShopPresenterProtocol? { get set }
    func viewDidLoad()
    func categorySelected(_ category: String)
    func fetchProducts(shopName: String, query: String?)
}

class ShopInteractor: ShopInteractorProtocol {
    weak var presenter: ShopPresenterProtocol?
    
    private let session = URLSession.shared
    private let baseURLString = "http://127.0.0.1:5000" // adjust if needed
    
    func viewDidLoad() {
        presenter?.presentShopScreen()
        presenter?.presentCategories()
    }
    
    func categorySelected(_ category: String) {
        presenter?.presentSelectedCategory(category)
    }
    
    func fetchProducts(shopName: String, query: String?) {
        guard var components = URLComponents(string: baseURLString + "/api/products") else { return }
        var items: [URLQueryItem] = [URLQueryItem(name: "shop", value: shopName)]
        if let q = query, !q.isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        components.queryItems = items
        guard let url = components.url else { return }
        
        let request = URLRequest(url: url)
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                print("Network error: \(error)")
                return
            }
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let status = json["status"] as? String, status == "success",
                let products = json["products"] as? [[String: Any]]
            else {
                return
            }
            DispatchQueue.main.async {
                self.presenter?.didLoadProducts(products)
            }
        }
        task.resume()
    }
}



