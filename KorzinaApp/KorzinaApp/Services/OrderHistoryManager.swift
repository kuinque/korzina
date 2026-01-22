import UIKit

// Используем типы, определенные в ProfilePresenter
// OrderHistoryItemEntity и OrderStatus определены в ProfilePresenter.swift

/// Менеджер для управления историей заказов
/// Всегда активен и подписан на уведомления о новых заказах
class OrderHistoryManager {
    static let shared = OrderHistoryManager()
    
    private enum Keys {
        static let orders = "profile.orders"
    }
    
    private let defaults: UserDefaults
    
    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        
        // Подписываемся на уведомления о новых заказах при инициализации
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewOrder(_:)),
            name: NSNotification.Name("NewOrderCreated"),
            object: nil
        )
        
        print("✅ OrderHistoryManager: Initialized and subscribed to NewOrderCreated notifications")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleNewOrder(_ notification: Notification) {
        print("📦 OrderHistoryManager: Received NewOrderCreated notification")
        guard let userInfo = notification.userInfo,
              let storeName = userInfo["storeName"] as? String,
              let total = userInfo["total"] as? Double else {
            print("⚠️ OrderHistoryManager: Invalid notification data")
            return
        }
        
        print("✅ OrderHistoryManager: Adding order to history - shop: \(storeName), total: \(total) ₽")
        addOrder(storeName: storeName, total: total)
    }
    
    private func addOrder(storeName: String, total: Double) {
        // Генерируем ID заказа
        let orderId = generateOrderId(storeName: storeName)
        print("📝 OrderHistoryManager: Generated order ID: \(orderId)")
        
        // Создаем новый заказ со статусом "в пути"
        let newOrder = OrderHistoryItemEntity(
            id: orderId,
            storeName: storeName,
            date: Date(),
            total: total,
            status: .inProgress
        )
        
        // Загружаем существующие заказы
        var orders = loadOrders()
        print("📋 OrderHistoryManager: Current orders count: \(orders.count)")
        
        // Добавляем новый заказ в начало списка
        orders.insert(newOrder, at: 0)
        
        // Сохраняем заказы
        saveOrders(orders)
        print("✅ OrderHistoryManager: Order saved, new orders count: \(orders.count)")
    }
    
    private func generateOrderId(storeName: String) -> String {
        // Генерируем ID на основе первой буквы магазина и случайного числа
        let prefix: String
        switch storeName {
        case "Пятёрочка":
            prefix = "P"
        case "Лента":
            prefix = "L"
        case "Магнит":
            prefix = "M"
        case "Ашан":
            prefix = "A"
        case "Перекрёсток":
            prefix = "K"
        case "Дикси":
            prefix = "D"
        case "Азбука Вкуса":
            prefix = "B"
        case "Метро":
            prefix = "M"
        default:
            prefix = "O"
        }
        
        let randomNumber = Int.random(in: 1000...9999)
        return "\(prefix)-\(randomNumber)"
    }
    
    func loadOrders() -> [OrderHistoryItemEntity] {
        guard let data = defaults.data(forKey: Keys.orders),
              let decoded = try? JSONDecoder().decode([OrderHistoryItemEntity].self, from: data) else {
            return []
        }
        return decoded
    }
    
    private func saveOrders(_ orders: [OrderHistoryItemEntity]) {
        if let encoded = try? JSONEncoder().encode(orders) {
            defaults.set(encoded, forKey: Keys.orders)
        }
    }
}

