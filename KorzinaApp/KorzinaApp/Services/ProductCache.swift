import Foundation
import UIKit

/// Кэш для продуктов с автоматическим управлением памятью
class ProductCache {
    static let shared = ProductCache()
    
    private let cache = NSCache<NSString, NSArray>()
    private let cacheQueue = DispatchQueue(label: "com.korzina.productCache", attributes: .concurrent)
    
    private init() {
        // Настраиваем лимиты кэша
        cache.countLimit = 50 // Максимум 50 страниц
        cache.totalCostLimit = 10 * 1024 * 1024 // 10 MB
    }
    
    func cacheProducts(_ products: [ProductViewModel], for key: String) {
        cacheQueue.async(flags: .barrier) {
            let nsArray = products as NSArray
            self.cache.setObject(nsArray, forKey: key as NSString)
        }
    }
    
    func getCachedProducts(for key: String) -> [ProductViewModel]? {
        return cacheQueue.sync {
            guard let cached = cache.object(forKey: key as NSString) as? [ProductViewModel] else {
                return nil
            }
            return cached
        }
    }
    
    func clearCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
}

