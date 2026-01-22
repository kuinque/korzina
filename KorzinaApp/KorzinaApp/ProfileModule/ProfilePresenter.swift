import UIKit

enum OrderStatus: String, Codable {
    case delivered
    case canceled
    case inProgress
}

struct OrderHistoryItemEntity: Codable {
    let id: String
    let storeName: String
    let date: Date
    let total: Double
    let status: OrderStatus
}

struct UserProfileEntity {
    let fullName: String
    let phoneNumber: String
    let orders: [OrderHistoryItemEntity]
    let avatarData: Data?
}

protocol ProfilePresenterProtocol: AnyObject {
    var view: ProfileViewProtocol? { get set }
    var interactor: ProfileInteractorProtocol? { get set }
    var router: ProfileRouterProtocol? { get set }
    func viewDidLoad()
    func avatarUpdated(with image: UIImage)
    func addOrder(storeName: String, total: Double)
}

protocol ProfileInteractorOutput: AnyObject {
    func didLoadProfile(_ profile: UserProfileEntity)
    func didUpdateProfile(_ profile: UserProfileEntity)
}

final class ProfilePresenter: ProfilePresenterProtocol {
    weak var view: ProfileViewProtocol?
    var interactor: ProfileInteractorProtocol?
    var router: ProfileRouterProtocol?
    
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.currencySymbol = "₽"
        return formatter
    }()
    
    init(view: ProfileViewProtocol, interactor: ProfileInteractorProtocol, router: ProfileRouterProtocol) {
        self.view = view
        self.interactor = interactor
        self.router = router
        
        // Заказы теперь обрабатываются через OrderHistoryManager, который подписан на уведомления при запуске приложения
        // Подписка здесь больше не нужна
    }
    
    func viewDidLoad() {
        view?.displayProfileScreen()
        interactor?.fetchProfile()
    }
    
    func avatarUpdated(with image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) ?? image.pngData() else { return }
        interactor?.saveAvatarImageData(data)
    }
    
    func addOrder(storeName: String, total: Double) {
        // Генерируем ID заказа
        let orderId = generateOrderId(storeName: storeName)
        print("📝 ProfilePresenter: Generated order ID: \(orderId)")
        
        // Создаем новый заказ со статусом "в пути"
        let newOrder = OrderHistoryItemEntity(
            id: orderId,
            storeName: storeName,
            date: Date(),
            total: total,
            status: .inProgress
        )
        
        // Добавляем заказ через interactor
        interactor?.addOrder(newOrder)
        print("✅ ProfilePresenter: Order added to interactor")
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
        default:
            prefix = "O"
        }
        
        let randomNumber = Int.random(in: 1000...9999)
        return "\(prefix)-\(randomNumber)"
    }
}

extension ProfilePresenter: ProfileInteractorOutput {
    func didLoadProfile(_ profile: UserProfileEntity) {
        present(profile)
    }
    
    func didUpdateProfile(_ profile: UserProfileEntity) {
        present(profile)
    }
    
    private func present(_ profile: UserProfileEntity) {
        let orders = profile.orders.map { item -> OrderViewModel in
            let dateString = dateFormatter.string(from: item.date)
            let total = currencyFormatter.string(from: NSNumber(value: item.total)) ?? "\(Int(item.total)) ₽"
            let status: String
            switch item.status {
            case .delivered:
                status = "доставлен"
            case .canceled:
                status = "отменен"
            case .inProgress:
                status = "в пути"
            }
            
            return OrderViewModel(
                id: item.id,
                storeName: item.storeName,
                dateString: dateString,
                status: status,
                totalString: total
            )
        }
        
        let avatarImage: UIImage?
        if let data = profile.avatarData {
            avatarImage = UIImage(data: data)
        } else {
            avatarImage = nil
        }
        
        let viewModel = ProfileViewModel(
            fullName: profile.fullName,
            phoneNumber: profile.phoneNumber,
            orders: orders,
            avatarImage: avatarImage
        )
        
        view?.displayProfile(viewModel)
    }
}
