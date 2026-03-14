import UIKit

protocol ProfileInteractorProtocol: AnyObject {
    var presenter: ProfileInteractorOutput? { get set }
    func fetchProfile()
    func saveAvatarImageData(_ data: Data?)
    func addOrder(_ order: OrderHistoryItemEntity)
}

final class ProfileInteractor: ProfileInteractorProtocol {
    weak var presenter: ProfileInteractorOutput?
    
    private enum Keys {
        static let fullName = "profile.fullName"
        static let phone = "profile.phone"
        static let avatar = "profile.avatar"
        static let orders = "profile.orders"
    }
    
    private let defaults: UserDefaults
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func fetchProfile() {
        presenter?.didLoadProfile(loadProfile())
    }
    
    func saveAvatarImageData(_ data: Data?) {
        if let data {
            defaults.set(data, forKey: Keys.avatar)
        } else {
            defaults.removeObject(forKey: Keys.avatar)
        }
        presenter?.didUpdateProfile(loadProfile())
    }
    
    private func loadProfile() -> UserProfileEntity {
        let name = defaults.string(forKey: Keys.fullName) ?? "Анна Корзина"
        let phone = defaults.string(forKey: Keys.phone) ?? "+7 (999) 123-45-67"
        let avatar = defaults.data(forKey: Keys.avatar)
        
        // Загружаем заказы из UserDefaults или используем sampleOrders
        let orders = loadOrders()
        
        return UserProfileEntity(
            fullName: name,
            phoneNumber: phone,
            orders: orders,
            avatarData: avatar
        )
    }
    
    func addOrder(_ order: OrderHistoryItemEntity) {
        // Заказы теперь сохраняются через OrderHistoryManager при получении уведомления
        // Этот метод вызывается только для обновления UI, если экран профиля открыт
        print("💾 ProfileInteractor: Order added (already saved by OrderHistoryManager) - ID: \(order.id), shop: \(order.storeName), total: \(order.total) ₽")
        presenter?.didUpdateProfile(loadProfile())
    }
    
    private func loadOrders() -> [OrderHistoryItemEntity] {
        // Загружаем заказы через OrderHistoryManager
        let orders = OrderHistoryManager.shared.loadOrders()
        
        // Если заказов нет в UserDefaults, используем sampleOrders только при первом запуске
        // Проверяем, были ли уже сохранены заказы ранее
        if orders.isEmpty && !defaults.bool(forKey: "profile.orders.initialized") {
            // Первый запуск - используем sampleOrders и помечаем, что инициализация выполнена
            let samples = sampleOrders()
            defaults.set(true, forKey: "profile.orders.initialized")
            // Сохраняем sampleOrders через OrderHistoryManager
            if let encoded = try? JSONEncoder().encode(samples) {
                defaults.set(encoded, forKey: Keys.orders)
            }
            return samples
        }
        
        return orders
    }
    
    private func saveOrders(_ orders: [OrderHistoryItemEntity]) {
        if let encoded = try? JSONEncoder().encode(orders) {
            defaults.set(encoded, forKey: Keys.orders)
        }
    }
    
    private func sampleOrders() -> [OrderHistoryItemEntity] {
        let calendar = Calendar.current
        let today = Date()
        let date1 = calendar.date(byAdding: .day, value: -2, to: today) ?? today
        let date2 = calendar.date(byAdding: .day, value: -12, to: today) ?? today
        let date3 = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        
        return [
            OrderHistoryItemEntity(id: "A-5210", storeName: "Пятёрочка", date: date1, total: 1890, status: .inProgress),
            OrderHistoryItemEntity(id: "M-1188", storeName: "Магнит", date: date2, total: 2450, status: .delivered),
            OrderHistoryItemEntity(id: "L-9920", storeName: "Лента", date: date3, total: 3240, status: .canceled)
        ]
    }
}
