import UIKit

struct PriceComparison {
    let shopName: String
    let totalPrice: Double?
    let productsFound: Int
    let productsTotal: Int
    let matchPercentage: Double
    let isAvailable: Bool
    let currentShopPrice: Double? // Цена в текущем магазине для сравнения
    let isCurrentShop: Bool // Является ли это магазином, из которого собрана корзина
}

protocol BasketViewProtocol: AnyObject {
    func displayBasketScreen()
    func displayCartItems(_ items: [CartItem])
    func updateCartTotal(_ total: Double)
    func displayPriceComparisons(_ comparisons: [PriceComparison])
    func setShopHeader(for shopName: String)
}

class BasketView: UIViewController {
    
    var presenter: BasketPresenterProtocol?
    
    private let topView = UIView()
    var logo = UIImageView()
    var logoName = UIImageView()
    
    // Cart UI elements
    private let tableView = UITableView()
    private let cartContainerView = UIView()
    private let cartTotalLabel = UILabel()
    private let checkoutButton = UIButton(type: .system)
    
    // Price comparison elements
    private let priceComparisonScrollView = UIScrollView()
    private let priceComparisonStackView = UIStackView()
    private let priceComparisonLabel = UILabel()
    private let myCartLabel = UILabel() // Заголовок "Моя корзина"
    
    private var cartItems: [CartItem] = []
    private var priceComparisons: [PriceComparison] = []
    private var selectedShopName: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setUpView()
        presenter?.viewDidLoad()
        
        // Добавляем обработчик уведомления для навигации
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNavigateToBasket),
            name: NSNotification.Name("NavigateToBasket"),
            object: nil
        )
        
        // Слушаем изменения корзины (только для обновления UI, не для пересбора корзин)
        // NotificationCenter.default.addObserver(
        //     self,
        //     selector: #selector(cartDidChange),
        //     name: CartManager.cartDidChangeNotification,
        //     object: nil
        // )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleNavigateToBasket(notification: Notification) {
        // Обработчик уведомления для навигации
        if let shopName = notification.userInfo?["shopName"] as? String {
            presenter?.setCurrentShop(shopName)
        }
    }
    
    // Метод больше не используется - обновление происходит в презентере
    // @objc private func cartDidChange() {
    //     // Обновляется инкрементально в BasketPresenter
    // }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter?.viewWillAppear()
    }
    
    private func setUpView() {
        setUpHead()
        setUpLogo()
        setUpPriceComparison()
        setUpCart() // Добавляем cartContainerView в иерархию сначала
        setUpTableView() // Затем устанавливаем ограничения для tableView
    }
    
    private func setUpHead() {
        view.addSubview(topView)
        topView.translatesAutoresizingMaskIntoConstraints = false
        topView.backgroundColor = .barColor
        topView.pinLeft(to: view)
        topView.pinRight(to: view)
        topView.pinTop(to: view)
        topView.setHeight(150)
    }
    
    func setShopHeader(for shopName: String) {
        print("BasketView: Setting header for shop: \(shopName)")
        // В корзине просто оставляем стандартный фон
        topView.backgroundColor = .barColor
    }
    
    private func setUpLogo() {
        logo = UIImageView(image: UIImage(named: "logo"))
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.contentMode = .scaleAspectFit
        topView.addSubview(logo)
        logo.setWidth(120 * 1.43)
        logo.setHeight(120)
        logo.pinTop(to: topView, 25)
        logo.pinLeft(to: topView, 25)
        
        logoName = UIImageView(image: UIImage(named: "name"))
        logoName.translatesAutoresizingMaskIntoConstraints = false
        logoName.contentMode = .scaleAspectFit
        topView.addSubview(logoName)
        logoName.setWidth(35 * 5.26)
        logoName.setHeight(35)
        logoName.pinTop(to: topView, 70)
        logoName.pinLeft(to: logo.trailingAnchor, -45)
    }
    
    private func setUpPriceComparison() {
        // Price comparison label
        priceComparisonLabel.text = "Сравнение стоимости корзины"
        priceComparisonLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        priceComparisonLabel.textColor = .black
        priceComparisonLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(priceComparisonLabel)
        
        // My cart label
        myCartLabel.text = "Моя корзина"
        myCartLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        myCartLabel.textColor = .black
        myCartLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(myCartLabel)
        
        // Horizontal scroll view for price comparisons
        priceComparisonScrollView.showsHorizontalScrollIndicator = false
        priceComparisonScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(priceComparisonScrollView)
        
        // Stack view for comparison cards
        priceComparisonStackView.axis = .horizontal
        priceComparisonStackView.spacing = 12
        priceComparisonStackView.alignment = .fill
        priceComparisonStackView.distribution = .fillEqually
        priceComparisonStackView.translatesAutoresizingMaskIntoConstraints = false
        priceComparisonScrollView.addSubview(priceComparisonStackView)
        
        NSLayoutConstraint.activate([
            priceComparisonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            priceComparisonLabel.topAnchor.constraint(equalTo: topView.bottomAnchor, constant: 16),
            priceComparisonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            priceComparisonScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            priceComparisonScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            priceComparisonScrollView.topAnchor.constraint(equalTo: priceComparisonLabel.bottomAnchor, constant: 8),
            priceComparisonScrollView.heightAnchor.constraint(equalToConstant: 120),
            
            priceComparisonStackView.leadingAnchor.constraint(equalTo: priceComparisonScrollView.leadingAnchor, constant: 16),
            priceComparisonStackView.trailingAnchor.constraint(equalTo: priceComparisonScrollView.trailingAnchor, constant: -16),
            priceComparisonStackView.topAnchor.constraint(equalTo: priceComparisonScrollView.topAnchor),
            priceComparisonStackView.bottomAnchor.constraint(equalTo: priceComparisonScrollView.bottomAnchor),
            priceComparisonStackView.heightAnchor.constraint(equalTo: priceComparisonScrollView.heightAnchor),
            
            myCartLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            myCartLabel.topAnchor.constraint(equalTo: priceComparisonScrollView.bottomAnchor, constant: 16),
            myCartLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
    }
    
    private func setUpTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(BasketItemCell.self, forCellReuseIdentifier: "BasketItemCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .white
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: myCartLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: cartContainerView.topAnchor, constant: -8)
        ])
    }
    
    private func setUpCart() {
        // Cart container
        cartContainerView.backgroundColor = UIColor.primaryColor
        cartContainerView.layer.cornerRadius = 25
        cartContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cartContainerView)
        
        // Cart total label
        cartTotalLabel.text = "0 ₽"
        cartTotalLabel.textColor = .white
        cartTotalLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        cartTotalLabel.textAlignment = .center
        cartTotalLabel.translatesAutoresizingMaskIntoConstraints = false
        cartContainerView.addSubview(cartTotalLabel)
        
        // Checkout button
        checkoutButton.setTitle("Оформить заказ", for: .normal)
        checkoutButton.setTitleColor(.white, for: .normal)
        checkoutButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        checkoutButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        checkoutButton.layer.cornerRadius = 20
        checkoutButton.translatesAutoresizingMaskIntoConstraints = false
        checkoutButton.addTarget(self, action: #selector(checkoutButtonTapped), for: .touchUpInside)
        cartContainerView.addSubview(checkoutButton)
        
        NSLayoutConstraint.activate([
            cartContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cartContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cartContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            cartContainerView.heightAnchor.constraint(equalToConstant: 50),
            
            cartTotalLabel.leadingAnchor.constraint(equalTo: cartContainerView.leadingAnchor, constant: 20),
            cartTotalLabel.centerYAnchor.constraint(equalTo: cartContainerView.centerYAnchor),
            
            checkoutButton.trailingAnchor.constraint(equalTo: cartContainerView.trailingAnchor, constant: -20),
            checkoutButton.centerYAnchor.constraint(equalTo: cartContainerView.centerYAnchor),
            checkoutButton.widthAnchor.constraint(equalToConstant: 140),
            checkoutButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func checkoutButtonTapped() {
        // Используем выбранный магазин из scrollview (или текущий, если не выбран)
        let shopName: String
        let orderTotal: Double
        
        if let selectedShop = selectedShopName {
            // Проверяем, является ли выбранный магазин текущим магазином пользователя
            let isCurrentShop = priceComparisons.first(where: { $0.shopName == selectedShop })?.isCurrentShop ?? false
            
            if isCurrentShop {
                // Для текущего магазина берем цену из реальной корзины
                shopName = selectedShop
                orderTotal = CartManager.shared.getCartTotal()
                print("💰 Using current shop (\(selectedShop)) with real cart total: \(orderTotal) ₽")
            } else {
                // Для других магазинов берем цену из кэша
                let cachedCarts = CartManager.shared.getCachedShopCarts()
                if let cachedCart = cachedCarts.first(where: { $0.shopName == selectedShop }) {
                    shopName = selectedShop
                    orderTotal = cachedCart.totalPrice
                    print("💰 Using selected shop (\(selectedShop)) with cached price: \(orderTotal) ₽")
                } else {
                    // Если кэш не найден, используем текущую корзину
                    shopName = CartManager.shared.getCurrentShop() ?? "Неизвестный магазин"
                    orderTotal = CartManager.shared.getCartTotal()
                    print("⚠️ Selected shop not found in cache, using current shop: \(shopName)")
                }
            }
        } else {
            // Если магазин не выбран, используем текущий магазин
            shopName = CartManager.shared.getCurrentShop() ?? "Неизвестный магазин"
            orderTotal = CartManager.shared.getCartTotal()
            print("💰 No shop selected, using current shop: \(shopName)")
        }
        
        // Проверяем, что сумма заказа больше нуля
        guard orderTotal > 0 else {
            showAlert(title: "Корзина пуста", message: "Добавьте товары в корзину перед оформлением заказа")
            return
        }
        
        // Отправляем уведомление о новом заказе
        NotificationCenter.default.post(
            name: NSNotification.Name("NewOrderCreated"),
            object: nil,
            userInfo: [
                "storeName": shopName,
                "total": orderTotal
            ]
        )
        
        // Очищаем корзину после оформления заказа
        CartManager.shared.clearCart()
        CartManager.shared.invalidateCache()
        
        // Обновляем UI
        presenter?.viewWillAppear()
        
        // Показываем подтверждение
        showAlert(title: "Заказ оформлен", message: "Ваш заказ из магазина \"\(shopName)\" на сумму \(String(format: "%.2f", orderTotal)) ₽ добавлен в историю заказов")
        
        print("✅ Order created: \(shopName), total: \(orderTotal) ₽")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - BasketViewProtocol
extension BasketView: BasketViewProtocol {
    func displayBasketScreen() {
        // UI уже настроен в viewDidLoad()
    }
    
    func displayCartItems(_ items: [CartItem]) {
        cartItems = items
        tableView.reloadData()
    }
    
    func updateCartTotal(_ total: Double) {
        cartTotalLabel.text = String(format: "%.2f ₽", total)
    }
    
    func displayPriceComparisons(_ comparisons: [PriceComparison]) {
        // Сортируем по цене (сначала дешевые)
        let sortedComparisons = comparisons.sorted { c1, c2 in
            let price1 = c1.totalPrice ?? Double.infinity
            let price2 = c2.totalPrice ?? Double.infinity
            return price1 < price2
        }
        priceComparisons = sortedComparisons
        
        // Всегда устанавливаем текущий магазин пользователя как выбранный (если есть)
        if let currentShop = sortedComparisons.first(where: { $0.isCurrentShop }) {
            selectedShopName = currentShop.shopName
            print("🏪 Setting selected shop to current shop: \(currentShop.shopName)")
        } else if selectedShopName == nil {
            // Если текущего магазина нет, выбираем первый доступный
            if let firstShop = sortedComparisons.first(where: { $0.isAvailable }) {
                selectedShopName = firstShop.shopName
                print("🏪 Setting selected shop to first available: \(firstShop.shopName)")
            }
        }
        
        // Полностью очищаем все существующие карточки
        while !priceComparisonStackView.arrangedSubviews.isEmpty {
            let view = priceComparisonStackView.arrangedSubviews.first!
            priceComparisonStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Если корзина пустая, скрываем скроллвью
        if sortedComparisons.isEmpty || sortedComparisons.allSatisfy({ !$0.isAvailable }) {
            priceComparisonScrollView.isHidden = true
            priceComparisonLabel.isHidden = true
            selectedShopName = nil
            return
        }
        
        // Показываем скроллвью если есть данные
        priceComparisonScrollView.isHidden = false
        priceComparisonLabel.isHidden = false
        
        // Создаем карточки для каждого магазина (уже отсортированы по цене)
        for comparison in sortedComparisons {
            let cardView = createPriceComparisonCard(for: comparison)
            priceComparisonStackView.addArrangedSubview(cardView)
        }
        
        // Обновляем размер контента скроллвью
        priceComparisonScrollView.layoutIfNeeded()
        
        // Загружаем товары выбранного магазина
        loadSelectedShopItems()
    }
    
    private func createPriceComparisonCard(for comparison: PriceComparison) -> UIView {
        let cardView = UIView()
        
        // Определяем, является ли это выбранным магазином
        let isSelectedShop = comparison.shopName == selectedShopName
        
        if isSelectedShop {
            // Выделяем выбранный магазин зеленой обводкой
            cardView.backgroundColor = UIColor.primaryColor?.withAlphaComponent(0.1)
            cardView.layer.borderWidth = 2
            cardView.layer.borderColor = UIColor.primaryColor?.cgColor
        } else {
            // Серый стиль для всех остальных магазинов
            cardView.backgroundColor = UIColor.systemGray.withAlphaComponent(0.1)
            cardView.layer.borderWidth = 1
            cardView.layer.borderColor = UIColor.systemGray.cgColor
        }
        
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        // Добавляем возможность тапать по карточке
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(shopCardTapped(_:)))
        cardView.addGestureRecognizer(tapGesture)
        cardView.isUserInteractionEnabled = true
        cardView.tag = priceComparisons.firstIndex(where: { $0.shopName == comparison.shopName }) ?? 0
        
        // Shop logo image view - растягиваем на всю верхнюю часть
        let shopLogoImageView = UIImageView()
        shopLogoImageView.contentMode = .scaleAspectFill
        shopLogoImageView.clipsToBounds = true
        shopLogoImageView.layer.cornerRadius = 10 // Скругляем углы логотипа
        shopLogoImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(shopLogoImageView)
        
        // Set shop logo based on shop name
        let logoImageName = getShopLogoImageName(for: comparison.shopName)
        shopLogoImageView.image = UIImage(named: logoImageName)
        
        // Price label (основная цена корзины)
        let priceLabel = UILabel()
        
        // Difference label (разница под ценой)
        let differenceLabel = UILabel()
        differenceLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        differenceLabel.textAlignment = .center
        differenceLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(differenceLabel)
        
        // Получаем цену ВЫБРАННОГО магазина для сравнения
        let selectedShopPrice: Double?
        if let selectedShop = selectedShopName {
            // Проверяем, является ли выбранный магазин текущим магазином пользователя
            let isCurrentShop = priceComparisons.first(where: { $0.shopName == selectedShop })?.isCurrentShop ?? false
            
            if isCurrentShop {
                // Для текущего магазина берем цену из реальной корзины
                selectedShopPrice = CartManager.shared.getCartTotal()
                print("💰 Using current cart total for comparison: \(selectedShopPrice ?? 0) ₽")
            } else {
                // Для других магазинов берем цену из кэша
                let cachedCarts = CartManager.shared.getCachedShopCarts()
                selectedShopPrice = cachedCarts.first(where: { $0.shopName == selectedShop })?.totalPrice
                print("💰 Using cached price for \(selectedShop): \(selectedShopPrice ?? 0) ₽")
            }
        } else {
            selectedShopPrice = CartManager.shared.getCartTotal()
            print("💰 Using default cart total: \(selectedShopPrice ?? 0) ₽")
        }
        
        // Для текущего магазина используем реальную цену корзины, а не цену из comparison
        let actualPrice: Double?
        if comparison.isCurrentShop {
            actualPrice = CartManager.shared.getCartTotal()
            print("🏪 \(comparison.shopName) (CURRENT): actualPrice=\(actualPrice ?? 0) ₽ (from real cart)")
        } else {
            actualPrice = comparison.totalPrice
            print("🏪 \(comparison.shopName): actualPrice=\(actualPrice ?? 0) ₽ (from API)")
        }
        
        if let price = actualPrice, let basePrice = selectedShopPrice, basePrice > 0 {
            let difference = price - basePrice
            
            print("   base=\(basePrice) ₽, diff=\(difference) ₽")
            
            // Всегда показываем цену корзины
            priceLabel.text = String(format: "%.0f ₽", price)
            priceLabel.textColor = .systemGray
            
            if abs(difference) < 0.01 {
                // Это выбранный магазин (разница около нуля) - скрываем разницу
                differenceLabel.isHidden = true
                print("   ✅ Selected shop (zero difference)")
            } else if difference > 0 {
                // Дороже выбранного магазина
                differenceLabel.text = String(format: "+%.0f ₽", difference)
                differenceLabel.textColor = .systemRed
                differenceLabel.isHidden = false
                print("   📈 More expensive by \(difference) ₽")
            } else {
                // Дешевле выбранного магазина
                differenceLabel.text = String(format: "%.0f ₽", difference)
                differenceLabel.textColor = .systemGreen
                differenceLabel.isHidden = false
                print("   📉 Cheaper by \(difference) ₽")
            }
        } else if let price = actualPrice {
            // Есть цена, но нет выбранного магазина для сравнения
            priceLabel.text = String(format: "%.0f ₽", price)
            priceLabel.textColor = .systemGray
            differenceLabel.isHidden = true
        } else {
            priceLabel.text = "Не найдено"
            priceLabel.textColor = .systemGray
            differenceLabel.isHidden = true
            print("   ⚠️ No price available")
        }
        priceLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        priceLabel.textAlignment = .center
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(priceLabel)
        
        // Единый размер логотипа для всех магазинов
        let logoHeight: CGFloat = 40
        let logoTopMargin: CGFloat = 10
        
        NSLayoutConstraint.activate([
            cardView.widthAnchor.constraint(equalToConstant: 140),
            
            // Shop logo constraints - адаптивный размер
            shopLogoImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: logoTopMargin),
            shopLogoImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            shopLogoImageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8),
            shopLogoImageView.heightAnchor.constraint(equalToConstant: logoHeight),
            
            // Price label - под логотипом с большим отступом
            priceLabel.topAnchor.constraint(equalTo: shopLogoImageView.bottomAnchor, constant: 16),
            priceLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            priceLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8),
            
            // Difference label - под ценой
            differenceLabel.topAnchor.constraint(equalTo: priceLabel.bottomAnchor, constant: 4),
            differenceLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            differenceLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8),
            differenceLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12)
        ])
        
        return cardView
    }
    
    private func getShopLogoImageName(for shopName: String) -> String {
        switch shopName {
        case "Пятёрочка":
            return "pyat_select"
        case "Лента":
            return "lenta_line"
        case "Ашан":
            return "ashan_line"
        case "Магнит":
            return "magnit_line"
        case "Перекрёсток":
            return "perek_line"
        default:
            return "pyat_select" // Default fallback
        }
    }
    
    @objc private func shopCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let cardView = gesture.view else { return }
        let index = cardView.tag
        
        guard index < priceComparisons.count else { return }
        let selectedComparison = priceComparisons[index]
        
        // Обновляем выбранный магазин
        selectedShopName = selectedComparison.shopName
        
        print("🏪 Selected shop: \(selectedComparison.shopName)")
        
        // Загружаем товары выбранного магазина
        loadSelectedShopItems()
        
        // Перерисовываем карточки с новыми ценами относительно выбранного магазина
        redrawComparisonCards()
    }
    
    private func loadSelectedShopItems() {
        guard let selectedShop = selectedShopName else {
            // Если магазин не выбран, показываем текущую корзину
            let items = CartManager.shared.getAllCartItems()
            let total = CartManager.shared.getCartTotal()
            cartItems = items
            tableView.reloadData()
            cartTotalLabel.text = String(format: "%.2f ₽", total)
            print("📦 Loaded \(items.count) items from current cart")
            return
        }
        
        // Проверяем, является ли выбранный магазин текущим магазином пользователя
        let isCurrentShop = priceComparisons.first(where: { $0.shopName == selectedShop })?.isCurrentShop ?? false
        
        if isCurrentShop {
            // Для текущего магазина показываем РЕАЛЬНУЮ корзину пользователя
            let items = CartManager.shared.getAllCartItems()
            let total = CartManager.shared.getCartTotal()
            cartItems = items
            tableView.reloadData()
            cartTotalLabel.text = String(format: "%.2f ₽", total)
            
            print("📦 Loaded \(items.count) items from CURRENT CART (\(selectedShop)):")
            for (index, item) in cartItems.enumerated() {
                print("  [\(index)] \(item.product.name)")
                print("      Price: \(item.product.price) ₽")
                print("      Image: \(item.product.imageURL?.prefix(50) ?? "nil")...")
            }
        } else {
            // Для других магазинов показываем кэш
            let cachedCarts = CartManager.shared.getCachedShopCarts()
            if let selectedCart = cachedCarts.first(where: { $0.shopName == selectedShop }) {
                cartItems = selectedCart.items
                
                print("📦 Loaded \(cartItems.count) items from CACHED \(selectedShop):")
                for (index, item) in cartItems.enumerated() {
                    print("  [\(index)] \(item.product.name)")
                    print("      Price: \(item.product.price) ₽")
                    print("      Image: \(item.product.imageURL?.prefix(50) ?? "nil")...")
                }
                
                tableView.reloadData()
                cartTotalLabel.text = String(format: "%.2f ₽", selectedCart.totalPrice)
            } else {
                print("⚠️ No cached cart found for \(selectedShop)")
                cartItems = []
                tableView.reloadData()
            }
        }
    }
    
    private func redrawComparisonCards() {
        // Пересчитываем priceComparisons из актуального кэша
        let cachedCarts = CartManager.shared.getCachedShopCarts()
        let currentShopName = CartManager.shared.getCurrentShop()
        let currentCartTotal = CartManager.shared.getCartTotal()
        let currentCartItems = CartManager.shared.getAllCartItems()
        
        var updatedComparisons: [PriceComparison] = []
        var hasCurrentShop = false
        
        for cart in cachedCarts {
            let isCurrentShop = cart.shopName == currentShopName
            if isCurrentShop {
                hasCurrentShop = true
            }
            
            // Для текущего магазина берем цену из реальной корзины
            let totalPrice = isCurrentShop ? currentCartTotal : cart.totalPrice
            
            let comparison = PriceComparison(
                shopName: cart.shopName,
                totalPrice: totalPrice > 0 ? totalPrice : nil,
                productsFound: isCurrentShop ? currentCartItems.count : cart.productsFound,
                productsTotal: currentCartItems.count,
                matchPercentage: cart.matchPercentage,
                isAvailable: totalPrice > 0,
                currentShopPrice: currentCartTotal,
                isCurrentShop: isCurrentShop
            )
            updatedComparisons.append(comparison)
        }
        
        // Если текущий магазин не в кэше - добавляем его
        if !hasCurrentShop, let shopName = currentShopName, currentCartTotal > 0 {
            let currentShopComparison = PriceComparison(
                shopName: shopName,
                totalPrice: currentCartTotal,
                productsFound: currentCartItems.count,
                productsTotal: currentCartItems.count,
                matchPercentage: 1.0,
                isAvailable: true,
                currentShopPrice: currentCartTotal,
                isCurrentShop: true
            )
            updatedComparisons.append(currentShopComparison)
        }
        
        // Сортируем по цене
        updatedComparisons.sort { ($0.totalPrice ?? Double.infinity) < ($1.totalPrice ?? Double.infinity) }
        
        priceComparisons = updatedComparisons
        
        // Полностью очищаем карточки
        while !priceComparisonStackView.arrangedSubviews.isEmpty {
            let view = priceComparisonStackView.arrangedSubviews.first!
            priceComparisonStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        
        // Создаем карточки заново с пересчитанными ценами
        for comparison in priceComparisons {
            let cardView = createPriceComparisonCard(for: comparison)
            priceComparisonStackView.addArrangedSubview(cardView)
        }
        
        priceComparisonScrollView.layoutIfNeeded()
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension BasketView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cartItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BasketItemCell", for: indexPath) as! BasketItemCell
        let item = cartItems[indexPath.row]
        
        // Определяем, является ли товар альтернативой (есть originalProductName и название отличается)
        let isAlternative = item.originalProductName != nil && item.originalProductName != item.product.name
        
        cell.configure(with: item, isAlternative: isAlternative)
        cell.onQuantityChanged = { [weak self] newQuantity in
            guard let self = self else { return }
            
            if newQuantity <= 0 {
                // Удаляем товар
                self.removeItemFromSelectedShop(item: item)
            } else {
                // Обновляем количество
                self.updateItemQuantityInSelectedShop(item: item, quantity: newQuantity)
            }
        }
        
        cell.onAlternativeTapped = { [weak self] in
            guard let self = self else { return }
            self.showAlternativesPopup(for: item)
        }
        
        return cell
    }
    
    private func showAlternativesPopup(for item: CartItem) {
        guard let offerId = item.product.offerId,
              let shopName = selectedShopName else {
            print("⚠️ Cannot show alternatives: missing offerId or shopName")
            return
        }
        
        print("🔍 Loading alternatives for offer \(offerId) in \(shopName)")
        
        // Показываем индикатор загрузки
        let loadingAlert = UIAlertController(title: nil, message: "Загрузка альтернатив...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)
        
        // Запрос к API
        fetchAlternatives(offerId: offerId, shopName: shopName) { [weak self] alternatives in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    guard let self = self else { return }
                    
                    if alternatives.isEmpty {
                        self.showAlert(title: "Нет альтернатив", message: "Не найдено других похожих товаров в этом магазине")
                    } else {
                        self.presentAlternativesSheet(alternatives: alternatives, for: item)
                    }
                }
            }
        }
    }
    
    private func fetchAlternatives(offerId: Int, shopName: String, completion: @escaping ([ProductViewModel]) -> Void) {
        let encodedShop = shopName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shopName
        let urlString = "\(Config.apiBaseURL)/api/offers/similar?offer_id=\(offerId)&limit=10"
        
        guard let url = URL(string: urlString) else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let similarOffers = json["similar_offers"] as? [[String: Any]] else {
                completion([])
                return
            }
            
            let alternatives = similarOffers.compactMap { similarOffer -> ProductViewModel? in
                // Данные товара находятся во вложенном объекте "offer"
                guard let offerData = similarOffer["offer"] as? [String: Any],
                      let title = offerData["title"] as? String else { return nil }
                
                var price: Double = 0
                if let priceNum = offerData["price"] as? NSNumber {
                    price = priceNum.doubleValue
                } else if let priceString = offerData["price"] as? String, let parsed = Double(priceString) {
                    price = parsed
                }
                
                let images = offerData["images"] as? [String]
                
                return ProductViewModel(
                    name: title,
                    price: price,
                    imageURL: images?.first,
                    description: offerData["description"] as? String,
                    category: offerData["category_name"] as? String,
                    offerId: offerData["offer_id"] as? Int
                )
            }
            
            completion(alternatives)
        }.resume()
    }
    
    private func presentAlternativesSheet(alternatives: [ProductViewModel], for item: CartItem) {
        // Создаем затемненный фон
        let dimView = UIView(frame: view.bounds)
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        dimView.tag = 999
        view.addSubview(dimView)
        
        // Контейнер для popup
        let containerHeight: CGFloat = min(CGFloat(alternatives.count) * 100 + 120, 500)
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.tag = 1000
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.heightAnchor.constraint(equalToConstant: containerHeight)
        ])
        
        // Заголовок
        let titleLabel = UILabel()
        titleLabel.text = "Выберите альтернативу"
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Кнопка закрытия
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .systemGray
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeAlternativesPopup), for: .touchUpInside)
        containerView.addSubview(closeButton)
        
        // ScrollView для альтернатив
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        containerView.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            closeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        // Добавляем карточки альтернатив
        for alternative in alternatives {
            let cardView = createAlternativeCard(product: alternative, originalItem: item)
            stackView.addArrangedSubview(cardView)
        }
        
        // Анимация появления
        containerView.transform = CGAffineTransform(translationX: 0, y: 300)
        dimView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            containerView.transform = .identity
            dimView.alpha = 1
        }
        
        // Закрытие по тапу на фон
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeAlternativesPopup))
        dimView.addGestureRecognizer(tapGesture)
    }
    
    private func createAlternativeCard(product: ProductViewModel, originalItem: CartItem) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemBackground
        cardView.layer.cornerRadius = 12
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        // Изображение
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(imageView)
        
        if let urlString = product.imageURL, let url = URL(string: urlString) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data, let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        imageView.image = image
                    }
                }
            }.resume()
        }
        
        // Название
        let nameLabel = UILabel()
        nameLabel.text = product.name
        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(nameLabel)
        
        // Цена
        let priceLabel = UILabel()
        priceLabel.text = String(format: "%.0f ₽", product.price)
        priceLabel.font = .systemFont(ofSize: 16, weight: .bold)
        priceLabel.textColor = .systemGreen
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(priceLabel)
        
        // Кнопка выбора
        let selectButton = UIButton(type: .system)
        selectButton.setTitle("Выбрать", for: .normal)
        selectButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        selectButton.backgroundColor = UIColor.primaryColor
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.layer.cornerRadius = 8
        selectButton.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(selectButton)
        
        // Сохраняем данные для замены
        selectButton.accessibilityHint = product.name
        selectButton.addAction(UIAction { [weak self] _ in
            self?.closeAlternativesPopup()
            self?.replaceProduct(item: originalItem, with: product)
        }, for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            cardView.heightAnchor.constraint(equalToConstant: 90),
            
            imageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            imageView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 70),
            imageView.heightAnchor.constraint(equalToConstant: 70),
            
            nameLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: selectButton.leadingAnchor, constant: -8),
            
            priceLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            priceLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            
            selectButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            selectButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            selectButton.widthAnchor.constraint(equalToConstant: 80),
            selectButton.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        return cardView
    }
    
    @objc private func closeAlternativesPopup() {
        if let dimView = view.viewWithTag(999),
           let containerView = view.viewWithTag(1000) {
            UIView.animate(withDuration: 0.25, animations: {
                dimView.alpha = 0
                containerView.transform = CGAffineTransform(translationX: 0, y: 300)
            }) { _ in
                dimView.removeFromSuperview()
                containerView.removeFromSuperview()
            }
        }
    }
    
    private func replaceProduct(item: CartItem, with newProduct: ProductViewModel) {
        guard let shopName = selectedShopName else { return }
        
        print("🔄 Replacing \(item.product.name) with \(newProduct.name) in \(shopName)")
        
        // Обновляем товар в кэше
        var cachedCarts = CartManager.shared.getCachedShopCarts()
        if var cart = cachedCarts.first(where: { $0.shopName == shopName }),
           let index = cart.items.firstIndex(where: { $0.product.name == item.product.name }) {
            
            // Сохраняем количество и оригинальное название
            let quantity = cart.items[index].quantity
            let originalName = cart.items[index].originalProductName ?? item.product.name
            
            // Создаем новый CartItem с заменой
            let newItem = CartItem(
                product: newProduct,
                quantity: quantity,
                originalProductName: originalName
            )
            
            cart.items[index] = newItem
            cart.totalPrice = cart.items.reduce(0) { $0 + $1.totalPrice }
            CartManager.shared.updateCachedCart(shopName: shopName, cart: cart)
            
            print("✅ Replaced product in \(shopName)")
        }
        
        // Перезагружаем товары
        loadSelectedShopItems()
        
        // Обновляем карточки
        redrawComparisonCards()
    }
    
    private func removeItemFromSelectedShop(item: CartItem) {
        // Определяем имя для поиска (оригинальное или текущее)
        let searchName = item.originalProductName ?? item.product.name
        print("🗑️ Removing item: \(item.product.name) (original: \(searchName)) from ALL shops")
        
        // Удаляем из основной корзины
        CartManager.shared.updateCartQuantity(product: item.product, quantity: 0)
        
        // Удаляем похожий товар из ВСЕХ кэшированных магазинов
        let cachedCarts = CartManager.shared.getCachedShopCarts()
        for var cart in cachedCarts {
            // Ищем товар используя метод matchesProduct
            if let index = cart.items.firstIndex(where: { $0.matchesProduct(named: searchName) }) {
                cart.items.remove(at: index)
                cart.totalPrice = cart.items.reduce(0) { $0 + $1.totalPrice }
                cart.productsFound = cart.items.count
                CartManager.shared.updateCachedCart(shopName: cart.shopName, cart: cart)
                print("✅ Removed from \(cart.shopName), remaining: \(cart.items.count) items")
            }
        }
        
        // Перезагружаем товары
        loadSelectedShopItems()
        
        // Обновляем карточки
        redrawComparisonCards()
    }
    
    private func updateItemQuantityInSelectedShop(item: CartItem, quantity: Int) {
        // Определяем имя для поиска (оригинальное или текущее)
        let searchName = item.originalProductName ?? item.product.name
        print("📝 Updating quantity: \(item.product.name) (original: \(searchName)) to \(quantity) in ALL shops")
        
        // Обновляем в основной корзине
            CartManager.shared.updateCartQuantity(product: item.product, quantity: quantity)
        
        // Обновляем количество похожего товара во ВСЕХ кэшированных магазинах
        let cachedCarts = CartManager.shared.getCachedShopCarts()
        for var cart in cachedCarts {
            // Ищем товар используя метод matchesProduct
            if let index = cart.items.firstIndex(where: { $0.matchesProduct(named: searchName) }) {
                var updatedItem = cart.items[index]
                updatedItem.quantity = quantity
                cart.items[index] = updatedItem
                cart.totalPrice = cart.items.reduce(0) { $0 + $1.totalPrice }
                CartManager.shared.updateCachedCart(shopName: cart.shopName, cart: cart)
                print("✅ Updated \(cart.shopName): \(cart.items.count) items, total: \(cart.totalPrice) ₽")
            }
        }
        
        // Перезагружаем товары
        loadSelectedShopItems()
        
        // Обновляем карточки с новыми ценами
        redrawComparisonCards()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - BasketItemCell
final class BasketItemCell: UITableViewCell {
    private let productImageView = UIImageView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let quantityStackView = UIStackView()
    private let minusButton = UIButton(type: .system)
    private let quantityLabel = UILabel()
    private let plusButton = UIButton(type: .system)
    private let alternativeButton = UIButton(type: .system) // Кнопка для альтернатив
    
    var onQuantityChanged: ((Int) -> Void)?
    var onAlternativeTapped: (() -> Void)? // Callback для показа альтернатив
    
    private var isAlternativeProduct = false
    
    // Для отслеживания загружаемого URL и задачи
    private var currentImageURL: String?
    private var currentProductName: String? // Для проверки соответствия товара
    private var imageLoadTask: URLSessionDataTask?
    
    // Простой кэш изображений
    private static var imageCache = NSCache<NSString, UIImage>()
    
    // Метод для очистки кэша (полезно при отладке)
    static func clearImageCache() {
        imageCache.removeAllObjects()
        print("🗑️ Image cache cleared")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        selectionStyle = .none
        backgroundColor = .white
        
        // Product image
        productImageView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        productImageView.layer.cornerRadius = 8
        productImageView.contentMode = .scaleAspectFit
        productImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(productImageView)
        
        // Alternative button (A)
        alternativeButton.setTitle("А", for: .normal)
        alternativeButton.setTitleColor(.white, for: .normal)
        alternativeButton.backgroundColor = UIColor.primaryColor
        alternativeButton.layer.cornerRadius = 10
        alternativeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        alternativeButton.translatesAutoresizingMaskIntoConstraints = false
        alternativeButton.addTarget(self, action: #selector(alternativeButtonTapped), for: .touchUpInside)
        alternativeButton.isHidden = true // По умолчанию скрыта
        contentView.addSubview(alternativeButton)
        
        // Title label
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Price label
        priceLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        priceLabel.textColor = UIColor.primaryColor
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(priceLabel)
        
        // Quantity controls
        quantityStackView.axis = .horizontal
        quantityStackView.spacing = 8
        quantityStackView.alignment = .center
        quantityStackView.distribution = .fillEqually
        quantityStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(quantityStackView)
        
        minusButton.setTitle("-", for: .normal)
        minusButton.setTitleColor(.white, for: .normal)
        minusButton.backgroundColor = UIColor.primaryColor
        minusButton.layer.cornerRadius = 15
        minusButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        minusButton.addTarget(self, action: #selector(minusButtonTapped), for: .touchUpInside)
        
        quantityLabel.text = "1"
        quantityLabel.textAlignment = .center
        quantityLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        quantityLabel.textColor = .black
        
        plusButton.setTitle("+", for: .normal)
        plusButton.setTitleColor(.white, for: .normal)
        plusButton.backgroundColor = UIColor.primaryColor
        plusButton.layer.cornerRadius = 15
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
        
        quantityStackView.addArrangedSubview(minusButton)
        quantityStackView.addArrangedSubview(quantityLabel)
        quantityStackView.addArrangedSubview(plusButton)
        
        NSLayoutConstraint.activate([
            productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            productImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            productImageView.widthAnchor.constraint(equalToConstant: 50),
            productImageView.heightAnchor.constraint(equalToConstant: 50),
            
            alternativeButton.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: -8),
            alternativeButton.topAnchor.constraint(equalTo: productImageView.topAnchor, constant: -4),
            alternativeButton.widthAnchor.constraint(equalToConstant: 20),
            alternativeButton.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: quantityStackView.leadingAnchor, constant: -8),
            
            priceLabel.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 12),
            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            priceLabel.trailingAnchor.constraint(lessThanOrEqualTo: quantityStackView.leadingAnchor, constant: -8),
            
            quantityStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            quantityStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            quantityStackView.widthAnchor.constraint(equalToConstant: 100),
            quantityStackView.heightAnchor.constraint(equalToConstant: 30),
            
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: priceLabel.bottomAnchor, constant: 12)
        ])
    }
    
    @objc private func minusButtonTapped() {
        let currentQuantity = Int(quantityLabel.text ?? "1") ?? 1
        onQuantityChanged?(currentQuantity - 1)
    }
    
    @objc private func plusButtonTapped() {
        let currentQuantity = Int(quantityLabel.text ?? "1") ?? 1
        onQuantityChanged?(currentQuantity + 1)
    }
    
    @objc private func alternativeButtonTapped() {
        onAlternativeTapped?()
    }
    
    func configure(with item: CartItem, isAlternative: Bool = false) {
        print("🔧 Configuring cell for: \(item.product.name)")
        print("   Image URL: \(item.product.imageURL?.prefix(70) ?? "nil")")
        print("   Is alternative: \(isAlternative)")
        
        isAlternativeProduct = isAlternative
        
        // Сохраняем название товара ДО отмены загрузки
        let productName = item.product.name
        
        titleLabel.text = productName
        priceLabel.text = String(format: "%.2f ₽", item.product.price)
        quantityLabel.text = "\(item.quantity)"
        
        // Показываем/скрываем кнопку альтернатив
        alternativeButton.isHidden = !isAlternative
        
        // Отменяем предыдущую загрузку и сбрасываем URL
        imageLoadTask?.cancel()
        imageLoadTask = nil
        currentImageURL = nil
        currentProductName = nil
        
        // Сбрасываем изображение
        productImageView.image = UIImage(named: "Image")
        
        // Устанавливаем новый URL и название товара СИНХРОННО перед началом загрузки
        if let imageURL = item.product.imageURL {
            currentImageURL = imageURL
            currentProductName = productName
            loadImage(from: imageURL, for: productName)
        } else {
            currentImageURL = nil
            currentProductName = nil
            productImageView.image = UIImage(named: "Image")
            print("   No image URL provided")
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Отменяем загрузку при переиспользовании ячейки
        imageLoadTask?.cancel()
        imageLoadTask = nil
        
        // Очищаем URL и название товара перед сбросом изображения
        currentImageURL = nil
        currentProductName = nil
        
        // Сбрасываем изображение на placeholder
        productImageView.image = UIImage(named: "Image")
        
        // Также сбрасываем текст (на случай быстрого переиспользования)
        titleLabel.text = nil
        priceLabel.text = nil
        quantityLabel.text = nil
    }
    
    private func loadImage(from urlString: String, for productName: String) {
        // Проверяем, что URL и название товара все еще актуальны (на случай быстрого переиспользования)
        guard currentImageURL == urlString && currentProductName == productName else {
            print("⚠️ URL or product changed before load started")
            print("   Expected URL: '\(currentImageURL ?? "nil")', got: '\(urlString)'")
            print("   Expected product: '\(currentProductName ?? "nil")', got: '\(productName)'")
            return
        }
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid image URL: \(urlString)")
            productImageView.image = UIImage(named: "Image")
            return
        }
        
        let cacheKey = urlString as NSString
        
        print("🔑 Cache key: \(cacheKey)")
        
        // Проверяем кэш
        if let cachedImage = BasketItemCell.imageCache.object(forKey: cacheKey) {
            // Проверяем, что URL и название товара все еще актуальны перед установкой изображения из кэша
            guard currentImageURL == urlString && currentProductName == productName else {
                print("⚠️ URL or product changed while checking cache, skipping cached image")
                return
            }
            
            // Дополнительная проверка: название товара в label должно совпадать
            guard titleLabel.text == productName else {
                print("⚠️ Product name mismatch in label, skipping cached image")
                print("   Label text: '\(titleLabel.text ?? "nil")', expected: '\(productName)'")
                return
            }
            
            print("✅ Using cached image for: \(urlString)")
            print("   Cache hit for product: \(productName)")
            productImageView.image = cachedImage
            return
        }
        
        print("🖼️ Loading basket image from: \(urlString)")
        print("   No cache, downloading for product: \(productName)")
        
        // Создаем и сохраняем задачу загрузки
        imageLoadTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Проверяем, что URL и название товара все еще актуальны для этой ячейки
                guard self.currentImageURL == urlString && self.currentProductName == productName else {
                    print("⚠️ Image URL or product changed during load, skipping: \(urlString)")
                    print("   Current URL is now: \(self.currentImageURL ?? "nil")")
                    print("   Current product is now: \(self.currentProductName ?? "nil")")
                    return
                }
                
                // Проверяем, что название товара в label все еще совпадает
                guard self.titleLabel.text == productName else {
                    print("⚠️ Product name changed in label during load, skipping")
                    print("   Label text: '\(self.titleLabel.text ?? "nil")', expected: '\(productName)'")
                    return
                }
                
                if let error = error {
                    // Игнорируем ошибки отмены
                    if (error as NSError).code != NSURLErrorCancelled {
                        print("❌ Error loading basket image: \(error)")
                        // Проверяем URL и название еще раз перед установкой placeholder
                        if self.currentImageURL == urlString && self.currentProductName == productName && self.titleLabel.text == productName {
                            self.productImageView.image = UIImage(named: "Image")
                        }
                    }
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    print("❌ Invalid basket image data")
                    // Проверяем URL и название еще раз перед установкой placeholder
                    if self.currentImageURL == urlString && self.currentProductName == productName && self.titleLabel.text == productName {
                        self.productImageView.image = UIImage(named: "Image")
                    }
                    return
                }
                
                // Финальная проверка URL и названия товара перед установкой изображения
                guard self.currentImageURL == urlString && self.currentProductName == productName else {
                    print("⚠️ Image URL or product changed after load completed, skipping: \(urlString)")
                    print("   Current URL is now: \(self.currentImageURL ?? "nil")")
                    print("   Current product is now: \(self.currentProductName ?? "nil")")
                    return
                }
                
                // Проверяем, что название товара в label все еще совпадает
                guard self.titleLabel.text == productName else {
                    print("⚠️ Product name changed in label after load, skipping")
                    print("   Label text: '\(self.titleLabel.text ?? "nil")', expected: '\(productName)'")
                    return
                }
                
                print("✅ Basket image loaded successfully for: \(urlString)")
                print("   Image size: \(image.size.width) x \(image.size.height)")
                print("   Saving to cache with key: \(String(describing: cacheKey))")
                print("   For product: \(productName)")
                
                // Сохраняем в кэш
                BasketItemCell.imageCache.setObject(image, forKey: cacheKey)
                
                // Устанавливаем изображение только если URL и название товара все еще актуальны
                self.productImageView.image = image
            }
        }
        
        imageLoadTask?.resume()
    }
}
