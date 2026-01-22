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
    private let orderButton = UIButton(type: .system) // Кнопка "заказать" (как basketButton в MainView/ShopView)
    private let orderPriceLabel = UILabel() // Цена корзины в кнопке
    
    // Price comparison elements
    private let priceComparisonScrollView = UIScrollView()
    private let priceComparisonStackView = UIStackView()
    private let priceComparisonLabel = UILabel()
    private let myCartLabel = UILabel() // Заголовок "Моя корзина"
    
    // Background blocks (как в ShopView)
    private let topWhiteBlock = UIView() // Первый белый блок (верхний)
    private let bottomWhiteBlock = UIView() // Второй белый блок (нижний)
    
    // Header elements (как в ShopView)
    private let basketTitleLabel = UILabel() // Надпись "корзина" по центру
    private let backButton = UIButton(type: .system) // Кнопка назад
    private let menuButton = UIButton(type: .system) // Кнопка меню
    
    private var cartItems: [CartItem] = []
    private var priceComparisons: [PriceComparison] = []
    private var shopOrder: [String] = [] // Сохраняем порядок магазинов (без текущего)
    private var selectedShopName: String?
    
    // Вычисляем лучшую цену один раз для всех карточек
    private var bestPrice: Double? {
        let availablePrices = priceComparisons
            .filter { $0.isAvailable }
            .compactMap { $0.totalPrice }
        return availablePrices.min()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "F3F3F3") ?? .systemGray6
        
        // Скрываем стандартный navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationItem.hidesBackButton = true
        
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
        // Убеждаемся, что navigation bar скрыт
        navigationController?.setNavigationBarHidden(true, animated: animated)
        presenter?.viewWillAppear()
    }
    
    private func setUpView() {
        setUpBackgroundBlocks()
        setUpCustomBackButton()
        setUpBasketTitle()
        setUpMenuButton()
        setUpPriceComparison() // Добавляем scrollview сравнения цен
        setUpCart() // Сначала создаем cartContainerView
        setUpTableView() // Затем устанавливаем constraints для tableView, которые ссылаются на cartContainerView
    }
    
    private func setUpBackgroundBlocks() {
        // Первый белый блок (верхний) - высота 115, нижние углы закруглены
        topWhiteBlock.backgroundColor = .white
        topWhiteBlock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topWhiteBlock)
        
        // Второй белый блок (нижний) - от 7 пикселей ниже первого до конца экрана, верхние углы закруглены
        bottomWhiteBlock.backgroundColor = .white
        bottomWhiteBlock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomWhiteBlock)
        
        NSLayoutConstraint.activate([
            // Первый блок: сверху экрана, высота 115
            topWhiteBlock.topAnchor.constraint(equalTo: view.topAnchor),
            topWhiteBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topWhiteBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topWhiteBlock.heightAnchor.constraint(equalToConstant: 115),
            
            // Второй блок: на 7 пикселей ниже первого, до конца экрана
            bottomWhiteBlock.topAnchor.constraint(equalTo: topWhiteBlock.bottomAnchor, constant: 7),
            bottomWhiteBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomWhiteBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomWhiteBlock.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Отправляем белые блоки вниз иерархии, чтобы другие элементы были поверх них
        view.sendSubviewToBack(bottomWhiteBlock)
        view.sendSubviewToBack(topWhiteBlock)
        
        // Применяем закругления углов после layout
        view.layoutIfNeeded()
        DispatchQueue.main.async {
            self.applyCornerRadiusToBlocks()
        }
    }
    
    private func setUpCustomBackButton() {
        // Используем backbutton1 из assets
        if let backImage = UIImage(named: "backbutton1") {
            backButton.setImage(backImage, for: .normal)
        } else {
            // Fallback на системную иконку, если изображение не найдено
            backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        }
        backButton.tintColor = .black
        backButton.contentEdgeInsets = .zero
        backButton.imageEdgeInsets = .zero
        backButton.contentHorizontalAlignment = .left
        backButton.contentVerticalAlignment = .center
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            // Такое же расположение как в ShopView (2 пикселя от safeArea сверху, 12 от левого края)
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 2),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            backButton.widthAnchor.constraint(equalToConstant: 50),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setUpBasketTitle() {
        basketTitleLabel.text = "корзина"
        basketTitleLabel.font = UIFont.onestMedium(size: 22)
        basketTitleLabel.textColor = .black
        basketTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(basketTitleLabel)
        
        NSLayoutConstraint.activate([
            // По центру сверху, на той же высоте что и название магазина в ShopView (9 пикселей от safeArea)
            basketTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 9),
            basketTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setUpMenuButton() {
        menuButton.setImage(createMenuIcon(), for: .normal)
        menuButton.tintColor = .black
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        view.addSubview(menuButton)
        
        NSLayoutConstraint.activate([
            menuButton.topAnchor.constraint(equalTo: basketTitleLabel.topAnchor, constant: -5),
            menuButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 328.5),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    @objc private func menuButtonTapped() {
        let profileView = ProfileBuilder.build()
        
        if let navigationController = navigationController {
            navigationController.pushViewController(profileView, animated: true)
        } else {
            // Если нет navigation controller, создаем новый
            let navController = UINavigationController(rootViewController: profileView)
            navController.modalPresentationStyle = .fullScreen
            present(navController, animated: true)
        }
    }
    
    /// Создает иконку меню (три линии)
    private func createMenuIcon() -> UIImage {
        let lineLength: CGFloat = 21
        let lineWidth: CGFloat = 2
        let spacing: CGFloat = 4 // Расстояние между линиями
        let totalHeight = lineWidth * 3 + spacing * 2 // 3 линии + 2 промежутка
        
        let size = CGSize(width: lineLength, height: totalHeight)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        format.opaque = false
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.black.setFill()
            
            // Первая линия (сверху)
            let line1Rect = CGRect(x: 0, y: 0, width: lineLength, height: lineWidth)
            context.cgContext.fill(line1Rect)
            
            // Вторая линия (посередине)
            let line2Rect = CGRect(x: 0, y: lineWidth + spacing, width: lineLength, height: lineWidth)
            context.cgContext.fill(line2Rect)
            
            // Третья линия (снизу)
            let line3Rect = CGRect(x: 0, y: (lineWidth + spacing) * 2, width: lineLength, height: lineWidth)
            context.cgContext.fill(line3Rect)
        }
    }
    
    /// Применяет закругления углов к белым блокам
    private func applyCornerRadiusToBlocks() {
        // Первый блок: нижние углы закруглены (cornerRadius = 25)
        applyCornerRadius(to: topWhiteBlock, topLeft: 0, topRight: 0, bottomLeft: 25, bottomRight: 25)
        
        // Второй блок: верхние углы закруглены (cornerRadius = 25)
        applyCornerRadius(to: bottomWhiteBlock, topLeft: 25, topRight: 25, bottomLeft: 0, bottomRight: 0)
    }
    
    /// Применяет mixed corner radius к view
    private func applyCornerRadius(to view: UIView, topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return }
        
        let bounds = view.bounds
        let width = bounds.width
        let height = bounds.height
        
        let path = UIBezierPath()
        
        // Начинаем с точки на верхней грани (после левого верхнего скругления)
        path.move(to: CGPoint(x: topLeft, y: 0))
        
        // Верхняя грань до правого верхнего угла
        path.addLine(to: CGPoint(x: width - topRight, y: 0))
        
        // Правый верхний угол
        if topRight > 0 {
            path.addArc(
                withCenter: CGPoint(x: width - topRight, y: topRight),
                radius: topRight,
                startAngle: -CGFloat.pi / 2,
                endAngle: 0,
                clockwise: true
            )
        }
        
        // Правая грань до правого нижнего угла
        path.addLine(to: CGPoint(x: width, y: height - bottomRight))
        
        // Правый нижний угол
        if bottomRight > 0 {
            path.addArc(
                withCenter: CGPoint(x: width - bottomRight, y: height - bottomRight),
                radius: bottomRight,
                startAngle: 0,
                endAngle: CGFloat.pi / 2,
                clockwise: true
            )
        }
        
        // Нижняя грань до левого нижнего угла
        path.addLine(to: CGPoint(x: bottomLeft, y: height))
        
        // Левый нижний угол
        if bottomLeft > 0 {
            path.addArc(
                withCenter: CGPoint(x: bottomLeft, y: height - bottomLeft),
                radius: bottomLeft,
                startAngle: CGFloat.pi / 2,
                endAngle: CGFloat.pi,
                clockwise: true
            )
        }
        
        // Левая грань до левого верхнего угла
        path.addLine(to: CGPoint(x: 0, y: topLeft))
        
        // Левый верхний угол
        if topLeft > 0 {
            path.addArc(
                withCenter: CGPoint(x: topLeft, y: topLeft),
                radius: topLeft,
                startAngle: CGFloat.pi,
                endAngle: -CGFloat.pi / 2,
                clockwise: true
            )
        }
        
        path.close()
        
        // Применяем маску
        let maskLayer = CAShapeLayer()
        maskLayer.frame = bounds
        maskLayer.path = path.cgPath
        view.layer.mask = maskLayer
        view.layer.masksToBounds = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Применяем закругления углов после layout
        applyCornerRadiusToBlocks()
        
        // Обновляем frame градиента на кнопке "заказать"
        if let gradientLayer = orderButton.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
            gradientLayer.frame = orderButton.bounds
        }
        
        // Убеждаемся, что кнопка "заказать" всегда поверх всех элементов
        view.bringSubviewToFront(orderButton)
    }
    
    func setShopHeader(for shopName: String) {
        print("BasketView: Setting header for shop: \(shopName)")
        // Заголовок уже установлен в setUpBasketTitle
    }
    
    private func setUpPriceComparison() {
        // Price comparison label
        priceComparisonLabel.text = "Умное сравнение"
        priceComparisonLabel.font = UIFont.onestMedium(size: 22)
        priceComparisonLabel.textColor = UIColor(hex: "0D0D0D") ?? .black
        priceComparisonLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(priceComparisonLabel)
        
        // My cart label - больше не используется, убрано
        
        // Horizontal scroll view for price comparisons
        priceComparisonScrollView.showsHorizontalScrollIndicator = false
        priceComparisonScrollView.translatesAutoresizingMaskIntoConstraints = false
        priceComparisonScrollView.clipsToBounds = false // Отключаем обрезку, чтобы овалы не обрезались сверху
        view.addSubview(priceComparisonScrollView)
        
        // Stack view for comparison cards
        priceComparisonStackView.axis = .horizontal
        priceComparisonStackView.spacing = 12
        priceComparisonStackView.alignment = .center
        priceComparisonStackView.distribution = .fill
        priceComparisonStackView.translatesAutoresizingMaskIntoConstraints = false
        priceComparisonStackView.clipsToBounds = false // Отключаем обрезку, чтобы овалы не обрезались
        priceComparisonScrollView.addSubview(priceComparisonStackView)
        
        NSLayoutConstraint.activate([
            // Заголовок "Сравнение стоимости корзины" - от нижнего белого блока
            priceComparisonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 11),
            priceComparisonLabel.topAnchor.constraint(equalTo: bottomWhiteBlock.topAnchor, constant: 12),
            priceComparisonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            // ScrollView для карточек сравнения
            priceComparisonScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            priceComparisonScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            priceComparisonScrollView.topAnchor.constraint(equalTo: priceComparisonLabel.bottomAnchor, constant: 4), // Чуть выше
            // Увеличиваем высоту scrollview, чтобы овалы (поднятые на -8px) полностью помещались
            priceComparisonScrollView.heightAnchor.constraint(equalToConstant: 65), // 51 (высота карточки) + 8 (отступ овала)
            
            // StackView внутри ScrollView
            priceComparisonStackView.leadingAnchor.constraint(equalTo: priceComparisonScrollView.leadingAnchor, constant: 16),
            priceComparisonStackView.trailingAnchor.constraint(equalTo: priceComparisonScrollView.trailingAnchor, constant: -16),
            priceComparisonStackView.topAnchor.constraint(equalTo: priceComparisonScrollView.topAnchor, constant: 10), // Отступ сверху для овалов (соответствует -10 в constraints овалов)
            priceComparisonStackView.bottomAnchor.constraint(equalTo: priceComparisonScrollView.bottomAnchor),
            priceComparisonStackView.heightAnchor.constraint(equalToConstant: 51) // Фиксированная высота для карточек
        ])
    }
    
    private func setUpTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(BasketItemCell.self, forCellReuseIdentifier: "BasketItemCell")
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            // tableView начинается от scrollview сравнения цен
            tableView.topAnchor.constraint(equalTo: priceComparisonScrollView.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: orderButton.topAnchor, constant: -8)
        ])
    }
    
    private func setUpCart() {
        // Кнопка "заказать" (как basketButton в MainView/ShopView)
        orderButton.setTitle("заказать", for: .normal)
        orderButton.titleLabel?.font = UIFont.onestMedium(size: 22)
        orderButton.setTitleColor(.white, for: .normal)
        // Убираем сплошной цвет, будет градиент
        orderButton.backgroundColor = .clear
        orderButton.layer.cornerRadius = 25
        orderButton.layer.cornerCurve = .continuous
        orderButton.clipsToBounds = true
        
        // Устанавливаем отступ текста от левого края кнопки
        orderButton.contentHorizontalAlignment = .left
        orderButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 17, bottom: 0, right: 0)
      
        // Добавляем цену корзины слева от стрелочки
        orderPriceLabel.text = "0₽"
        orderPriceLabel.font = UIFont.onestMedium(size: 20)
        orderPriceLabel.textColor = .white
        orderPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        orderButton.addSubview(orderPriceLabel)
        
        // Добавляем картинку check2 справа в кнопке
        if let checkImage = UIImage(named: "check2") {
            let checkImageView = UIImageView(image: checkImage)
            checkImageView.contentMode = .scaleAspectFit
            checkImageView.translatesAutoresizingMaskIntoConstraints = false
            orderButton.addSubview(checkImageView)
        
        NSLayoutConstraint.activate([
                // Цена корзины слева от стрелочки
                orderPriceLabel.trailingAnchor.constraint(equalTo: checkImageView.leadingAnchor, constant: -8),
                orderPriceLabel.centerYAnchor.constraint(equalTo: orderButton.centerYAnchor),
                
                // Стрелочка справа
                checkImageView.trailingAnchor.constraint(equalTo: orderButton.trailingAnchor, constant: -22),
                checkImageView.centerYAnchor.constraint(equalTo: orderButton.centerYAnchor),
                checkImageView.widthAnchor.constraint(equalToConstant: 10),
                checkImageView.heightAnchor.constraint(equalToConstant: 16)
            ])
        }
      
        orderButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(orderButton)
        
        NSLayoutConstraint.activate([
            orderButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 77),
            orderButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -34),
            orderButton.widthAnchor.constraint(equalToConstant: 242),
            orderButton.heightAnchor.constraint(equalToConstant: 53)
        ])
        
        // Добавляем действие при нажатии
        orderButton.addTarget(self, action: #selector(checkoutButtonTapped), for: .touchUpInside)
        
        // Применяем градиент к кнопке
        applyGradientToOrderButton(orderButton)
        
        // Обновляем цену корзины
        updateOrderPrice()
    }
    
    /// Применяет градиент к кнопке "заказать"
    private func applyGradientToOrderButton(_ button: UIButton) {
        applyGradientToButton(button, cornerRadius: 25)
    }
    
    /// Применяет градиент к кнопке с указанным радиусом скругления
    private func applyGradientToButton(_ button: UIButton, cornerRadius: CGFloat) {
        // Удаляем старый градиент, если есть
        button.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // Убираем сплошной цвет фона
        button.backgroundColor = .clear
        
        // Создаем градиентный слой
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "FF8733")?.cgColor ?? UIColor.orange.cgColor,
            UIColor(hex: "FE6900")?.cgColor ?? UIColor.orange.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5) // Слева
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5) // Справа
        gradientLayer.cornerRadius = cornerRadius
        gradientLayer.masksToBounds = true
        gradientLayer.frame = button.bounds
        
        button.layer.insertSublayer(gradientLayer, at: 0)
        // Обновляем frame градиента после layout
        DispatchQueue.main.async {
            gradientLayer.frame = button.bounds
        }
    }
    
    /// Обновляет цену в кнопке "заказать"
    private func updateOrderPrice() {
        let total = CartManager.shared.getCartTotal()
        orderPriceLabel.text = "\(Int(total))₽"
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
        print("📦 BasketView: Sending NewOrderCreated notification for shop: \(shopName), total: \(orderTotal) ₽")
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
        
        print("✅ BasketView: Order created and notification sent: \(shopName), total: \(orderTotal) ₽")
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
        orderPriceLabel.text = "\(Int(total))₽"
    }
    
    func displayPriceComparisons(_ comparisons: [PriceComparison]) {
        // Сортируем: текущий магазин первый, остальные по выгоде (от меньшей цены к большей)
        // При переключении между магазинами порядок остальных магазинов сохраняется
        let sortedComparisons: [PriceComparison]
        
        // Находим текущий магазин
        let currentShop = comparisons.first(where: { $0.isCurrentShop })
        let otherShops = comparisons.filter { !$0.isCurrentShop }
        
        if shopOrder.isEmpty || shopOrder.count != otherShops.count {
            // Первая загрузка: сортируем остальные магазины по выгоде
            let sortedOtherShops = otherShops.sorted { c1, c2 in
                let price1 = c1.totalPrice ?? Double.infinity
                let price2 = c2.totalPrice ?? Double.infinity
                return price1 < price2
            }
            // Сохраняем порядок остальных магазинов
            shopOrder = sortedOtherShops.map { $0.shopName }
            
            // Текущий магазин первый, затем остальные по выгоде
            if let current = currentShop {
                sortedComparisons = [current] + sortedOtherShops
            } else {
                sortedComparisons = sortedOtherShops
            }
        } else {
            // При переключении: сохраняем порядок остальных магазинов
            let sortedOtherShops = shopOrder.compactMap { shopName in
                otherShops.first(where: { $0.shopName == shopName })
            }
            // Добавляем новые магазины, которых нет в сохраненном порядке (сортируем по выгоде)
            let existingShopNames = Set(shopOrder)
            let newShops = otherShops.filter { !existingShopNames.contains($0.shopName) }
                .sorted { c1, c2 in
                    let price1 = c1.totalPrice ?? Double.infinity
                    let price2 = c2.totalPrice ?? Double.infinity
                    return price1 < price2
                }
            
            // Текущий магазин первый, затем остальные в сохраненном порядке + новые
            if let current = currentShop {
                sortedComparisons = [current] + sortedOtherShops + newShops
            } else {
                sortedComparisons = sortedOtherShops + newShops
            }
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
            shopOrder = [] // Очищаем порядок при очистке корзины
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
        
        // Определяем, является ли это магазином с лучшей ценой
        let isBestPrice = comparison.isAvailable && 
                          comparison.totalPrice != nil && 
                          comparison.totalPrice == bestPrice
        
        // Зеленая обводка и овал "лучшая цена" показываются только если магазин выбран И имеет лучшую цену
        let showBestPriceIndicator = isSelectedShop && isBestPrice
        
        // Овальная карточка 143x51, цвет F3F3F3 (как у карточек товаров в ShopView)
        cardView.backgroundColor = UIColor(hex: "F3F3F3") ?? .systemGray6
        cardView.layer.cornerRadius = 25.5 // Половина от 51 для овала
        cardView.clipsToBounds = false // Отключаем обрезку, чтобы овалы могли выходить за границы и не перекрывались обводкой
        cardView.translatesAutoresizingMaskIntoConstraints = false
        
        // Добавляем возможность тапать по карточке
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(shopCardTapped(_:)))
        cardView.addGestureRecognizer(tapGesture)
        cardView.isUserInteractionEnabled = true
        cardView.tag = priceComparisons.firstIndex(where: { $0.shopName == comparison.shopName }) ?? 0
        
        // Круг 34x34 с логотипом магазина (в левой части)
        let logoContainerView = UIView()
        logoContainerView.backgroundColor = getShopColor(for: comparison.shopName)
        logoContainerView.layer.cornerRadius = 17 // Половина от 34 для круга
        logoContainerView.clipsToBounds = true
        logoContainerView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(logoContainerView)
        
        // Логотип магазина внутри круга
        let shopLogoImageView = UIImageView()
        shopLogoImageView.contentMode = .scaleAspectFit
        shopLogoImageView.clipsToBounds = true
        shopLogoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoContainerView.addSubview(shopLogoImageView)
        
        // Set shop logo based on shop name
        let logoImageName = getShopLogoImageName(for: comparison.shopName)
        shopLogoImageView.image = UIImage(named: logoImageName)
        
        // Контейнер для цены доставки и времени доставки (справа от круга)
        let infoContainerView = UIView()
        infoContainerView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(infoContainerView)
        
        // Цена корзины (сверху) - показываем реальную цену корзины
        let deliveryPriceLabel = UILabel()
        if let price = comparison.totalPrice {
            deliveryPriceLabel.text = "\(Int(price))₽"
        } else {
            deliveryPriceLabel.text = "—"
        }
        deliveryPriceLabel.font = UIFont.onestMedium(size: 18.23)
        deliveryPriceLabel.textColor = UIColor(hex: "4E4E4E") ?? .darkGray
        deliveryPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainerView.addSubview(deliveryPriceLabel)
        
        // Время доставки (внизу от цены)
        let deliveryTimeLabel = UILabel()
        deliveryTimeLabel.text = "25-35 мин" // Можно заменить на реальное время доставки
        deliveryTimeLabel.font = UIFont.onestMedium(size: 12)
        deliveryTimeLabel.textColor = UIColor(hex: "B1B0B0") ?? .lightGray
        deliveryTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        infoContainerView.addSubview(deliveryTimeLabel)
        
        // Овал "лучшая цена" (показывается только если магазин выбран И имеет лучшую цену)
        let bestPriceOval = UIView()
        bestPriceOval.backgroundColor = UIColor(hex: "5FAF2D") ?? .systemGreen
        bestPriceOval.layer.cornerRadius = 9.5 // Половина от высоты для овала
        bestPriceOval.clipsToBounds = true
        bestPriceOval.translatesAutoresizingMaskIntoConstraints = false
        bestPriceOval.isHidden = !showBestPriceIndicator // Показываем только для выбранного магазина с лучшей ценой
        bestPriceOval.layer.zPosition = 1000 // Устанавливаем высокий zPosition, чтобы овал был поверх обводки
        cardView.addSubview(bestPriceOval)
        
        // Текст "лучшая цена"
        let bestPriceLabel = UILabel()
        bestPriceLabel.text = "лучшая цена"
        bestPriceLabel.font = UIFont.onestMedium(size: 11)
        bestPriceLabel.textColor = .white
        bestPriceLabel.textAlignment = .center
        bestPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        bestPriceOval.addSubview(bestPriceLabel)
        
        // Овал с разницей в цене (в верхней правой части карточки)
        let priceDifferenceOval = UIView()
        priceDifferenceOval.layer.cornerRadius = 9.5 // Половина от высоты для овала
        priceDifferenceOval.clipsToBounds = true
        priceDifferenceOval.translatesAutoresizingMaskIntoConstraints = false
        priceDifferenceOval.layer.zPosition = 1000 // Устанавливаем высокий zPosition, чтобы овал был поверх обводки
        cardView.addSubview(priceDifferenceOval)
        
        // Текст разницы в цене
        let priceDifferenceLabel = UILabel()
        priceDifferenceLabel.font = UIFont.onestMedium(size: 10)
        priceDifferenceLabel.textColor = .white
        priceDifferenceLabel.textAlignment = .center
        priceDifferenceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceDifferenceOval.addSubview(priceDifferenceLabel)
        
        // Вычисляем разницу в цене относительно выбранного магазина
        var priceDifference: Double? = nil
        var isCheaper = false
        
        if let selectedShop = selectedShopName, selectedShop != comparison.shopName {
            // Получаем цену выбранного магазина
        let selectedShopPrice: Double?
            let isSelectedCurrentShop = priceComparisons.first(where: { $0.shopName == selectedShop })?.isCurrentShop ?? false
            
            if isSelectedCurrentShop {
                selectedShopPrice = CartManager.shared.getCartTotal()
            } else {
                let cachedCarts = CartManager.shared.getCachedShopCarts()
                selectedShopPrice = cachedCarts.first(where: { $0.shopName == selectedShop })?.totalPrice
            }
            
            // Вычисляем разницу
            if let currentPrice = comparison.totalPrice, let selectedPrice = selectedShopPrice {
                priceDifference = currentPrice - selectedPrice
                isCheaper = priceDifference! < 0
            }
        }
        
        // Настраиваем овал с разницей в цене (скрываем только если выбран магазин с лучшей ценой)
        if showBestPriceIndicator {
            // Скрываем овал разницы, если это выбранный магазин с лучшей ценой (показываем только "лучшая цена")
            priceDifferenceOval.isHidden = true
        } else if let difference = priceDifference, abs(difference) > 0.01 {
            // Показываем разницу
            if isCheaper {
                priceDifferenceOval.backgroundColor = UIColor(hex: "5FAF2D") ?? .systemGreen
                priceDifferenceLabel.text = "-\(Int(abs(difference)))₽"
            } else {
                priceDifferenceOval.backgroundColor = UIColor(hex: "E0001A") ?? .systemRed
                priceDifferenceLabel.text = "+\(Int(difference))₽"
            }
            priceDifferenceOval.isHidden = false
        } else {
            // Скрываем овал, если это выбранный магазин или разница незначительна
            priceDifferenceOval.isHidden = true
        }
        
        NSLayoutConstraint.activate([
            // Размеры карточки: 143x51
            cardView.widthAnchor.constraint(equalToConstant: 143),
            cardView.heightAnchor.constraint(equalToConstant: 51),
            
            // Круг с логотипом: 34x34, слева с отступом
            logoContainerView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 8),
            logoContainerView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            logoContainerView.widthAnchor.constraint(equalToConstant: 34),
            logoContainerView.heightAnchor.constraint(equalToConstant: 34),
            
            // Логотип внутри круга (с отступами)
            shopLogoImageView.centerXAnchor.constraint(equalTo: logoContainerView.centerXAnchor),
            shopLogoImageView.centerYAnchor.constraint(equalTo: logoContainerView.centerYAnchor),
            shopLogoImageView.widthAnchor.constraint(equalToConstant: 24),
            shopLogoImageView.heightAnchor.constraint(equalToConstant: 24),
            
            // Контейнер с информацией справа от круга (сдвинут правее)
            infoContainerView.leadingAnchor.constraint(equalTo: logoContainerView.trailingAnchor, constant: 16),
            infoContainerView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -8),
            infoContainerView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            
            // Цена доставки сверху
            deliveryPriceLabel.topAnchor.constraint(equalTo: infoContainerView.topAnchor),
            deliveryPriceLabel.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor), // Левый край совпадает с левым краем времени доставки
            deliveryPriceLabel.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor),
            
            // Время доставки внизу от цены
            deliveryTimeLabel.topAnchor.constraint(equalTo: deliveryPriceLabel.bottomAnchor, constant: 2),
            deliveryTimeLabel.leadingAnchor.constraint(equalTo: infoContainerView.leadingAnchor), // Левый край совпадает с левым краем цены
            deliveryTimeLabel.trailingAnchor.constraint(equalTo: infoContainerView.trailingAnchor),
            deliveryTimeLabel.bottomAnchor.constraint(equalTo: infoContainerView.bottomAnchor),
            
            // Овал "лучшая цена" в верхней правой части карточки (там же, где овал с разницей цены)
            bestPriceOval.topAnchor.constraint(equalTo: cardView.topAnchor, constant: -10), // Поднимаем выше
            bestPriceOval.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: 8), // Сдвигаем правее
            bestPriceOval.heightAnchor.constraint(equalToConstant: 19),
            bestPriceOval.widthAnchor.constraint(greaterThanOrEqualToConstant: 19), // Минимальная ширина
            
            // Текст "лучшая цена" внутри овала
            bestPriceLabel.centerYAnchor.constraint(equalTo: bestPriceOval.centerYAnchor),
            bestPriceLabel.leadingAnchor.constraint(equalTo: bestPriceOval.leadingAnchor, constant: 8),
            bestPriceLabel.trailingAnchor.constraint(equalTo: bestPriceOval.trailingAnchor, constant: -8),
            bestPriceOval.widthAnchor.constraint(equalTo: bestPriceLabel.widthAnchor, constant: 16), // Ширина = ширина текста + отступы (8+8)
            
            // Овал с разницей в цене в верхней правой части (скрыт, если это лучшая цена)
            priceDifferenceOval.topAnchor.constraint(equalTo: cardView.topAnchor, constant: -10), // Поднимаем выше
            priceDifferenceOval.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: 8), // Сдвигаем правее
            priceDifferenceOval.heightAnchor.constraint(equalToConstant: 19),
            priceDifferenceOval.widthAnchor.constraint(greaterThanOrEqualToConstant: 19), // Минимальная ширина
            
            // Текст разницы в цене внутри овала - определяет ширину овала
            priceDifferenceLabel.centerYAnchor.constraint(equalTo: priceDifferenceOval.centerYAnchor),
            priceDifferenceLabel.leadingAnchor.constraint(equalTo: priceDifferenceOval.leadingAnchor, constant: 8),
            priceDifferenceLabel.trailingAnchor.constraint(equalTo: priceDifferenceOval.trailingAnchor, constant: -8),
            priceDifferenceOval.widthAnchor.constraint(equalTo: priceDifferenceLabel.widthAnchor, constant: 16) // Ширина = ширина текста + отступы (8+8)
        ])
        
        // Создаем отдельный слой для обводки, который будет под овалами
        let borderLayer = CAShapeLayer()
        borderLayer.frame = cardView.bounds
        borderLayer.path = UIBezierPath(roundedRect: cardView.bounds, cornerRadius: 25.5).cgPath
        borderLayer.fillColor = UIColor.clear.cgColor
        
        if showBestPriceIndicator {
            // Зеленая обводка для выбранного магазина с лучшей ценой
            borderLayer.strokeColor = (UIColor(hex: "5FAF2D") ?? UIColor.systemGreen).cgColor
            borderLayer.lineWidth = 1
        } else if isSelectedShop {
            // Серая обводка для выбранного магазина (без лучшей цены)
            borderLayer.strokeColor = (UIColor(hex: "9A9A9A") ?? UIColor.systemGray).cgColor
            borderLayer.lineWidth = 1
        } else {
            borderLayer.strokeColor = UIColor.clear.cgColor
            borderLayer.lineWidth = 0
        }
        
        // Добавляем border layer в самый низ стека слоев
        cardView.layer.insertSublayer(borderLayer, at: 0)
        
        // Обновляем frame border layer после установки constraints
        DispatchQueue.main.async {
            borderLayer.frame = cardView.bounds
            borderLayer.path = UIBezierPath(roundedRect: cardView.bounds, cornerRadius: 25.5).cgPath
        }
        
        // Убеждаемся, что овалы находятся поверх обводки карточки
        cardView.bringSubviewToFront(bestPriceOval)
        cardView.bringSubviewToFront(priceDifferenceOval)
        
        return cardView
    }
    
    private func getShopLogoImageName(for shopName: String) -> String {
        let mapping: [String: String] = [
            "Ашан": "Логотип Ашана",
            "Перекрёсток": "Логотип перекресток",
            "Лента": "Логотип Лента",
            "Магнит": "Логотип Магнит",
            "Дикси": "Логотип Дикси",
            "Азбука Вкуса": "Логотив Азбука Вкуса",
            "Метро": "Логотип метро",
            "Пятёрочка": "Логотип Пятерочка"
        ]
        return mapping[shopName] ?? "Логотип Пятерочка"
    }
    
    /// Возвращает цвет для магазина
    private func getShopColor(for storeName: String) -> UIColor {
        switch storeName {
        case "Ашан":
            return UIColor(hex: "#E0001A") ?? .systemRed
        case "Перекрёсток":
            return UIColor(hex: "#00A651") ?? .systemGreen
        case "Лента":
            return UIColor(hex: "#1E88E5") ?? .systemBlue
        case "Магнит":
            return UIColor(hex: "#FF0000") ?? .systemRed
        case "Дикси":
            return UIColor(hex: "#F17D0A") ?? .systemOrange
        case "Азбука Вкуса":
            return UIColor(hex: "#134727") ?? .systemGreen
        case "Метро":
            return UIColor(hex: "#1B4A88") ?? .systemBlue
        case "Пятёрочка":
            return UIColor(hex: "#FE0006") ?? .systemRed
        default:
            return UIColor.primaryColor ?? .systemGray
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
            orderPriceLabel.text = "\(Int(total))₽"
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
            orderPriceLabel.text = "\(Int(total))₽"
            
            print("📦 Loaded \(items.count) items from CURRENT CART (\(selectedShop))")
        } else {
            // Для других магазинов показываем кэш
            let cachedCarts = CartManager.shared.getCachedShopCarts()
            if let selectedCart = cachedCarts.first(where: { $0.shopName == selectedShop }) {
                cartItems = selectedCart.items
                
                print("📦 Loaded \(cartItems.count) items from CACHED \(selectedShop)")
                
                tableView.reloadData()
                orderPriceLabel.text = "\(Int(selectedCart.totalPrice))₽"
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
        
        // Сохраняем порядок магазинов перед обновлением
        // Используем сохраненный порядок, если он есть, иначе сохраняем текущий
        if shopOrder.isEmpty && !updatedComparisons.isEmpty {
            // Первая загрузка: сохраняем порядок (текущий магазин первый, остальные по выгоде)
            let currentShop = updatedComparisons.first(where: { $0.isCurrentShop })
            let otherShops = updatedComparisons.filter { !$0.isCurrentShop }
                .sorted { c1, c2 in
                    let price1 = c1.totalPrice ?? Double.infinity
                    let price2 = c2.totalPrice ?? Double.infinity
                    return price1 < price2
                }
            shopOrder = otherShops.map { $0.shopName }
        }
        
        // Сортируем обновленные сравнения, сохраняя порядок
        let sortedComparisons: [PriceComparison]
        let currentShop = updatedComparisons.first(where: { $0.isCurrentShop })
        let otherShops = updatedComparisons.filter { !$0.isCurrentShop }
        
        if !shopOrder.isEmpty {
            // Используем сохраненный порядок для остальных магазинов
            let sortedOtherShops = shopOrder.compactMap { shopName in
                otherShops.first(where: { $0.shopName == shopName })
            }
            // Добавляем новые магазины, которых нет в сохраненном порядке (сортируем по выгоде)
            let existingShopNames = Set(shopOrder)
            let newShops = otherShops.filter { !existingShopNames.contains($0.shopName) }
                .sorted { c1, c2 in
                    let price1 = c1.totalPrice ?? Double.infinity
                    let price2 = c2.totalPrice ?? Double.infinity
                    return price1 < price2
                }
            
            // Текущий магазин первый, затем остальные в сохраненном порядке + новые
            if let current = currentShop {
                sortedComparisons = [current] + sortedOtherShops + newShops
            } else {
                sortedComparisons = sortedOtherShops + newShops
            }
        } else {
            // Если порядок не сохранен, сортируем по выгоде
            let sortedOtherShops = otherShops.sorted { c1, c2 in
                let price1 = c1.totalPrice ?? Double.infinity
                let price2 = c2.totalPrice ?? Double.infinity
                return price1 < price2
            }
            if let current = currentShop {
                sortedComparisons = [current] + sortedOtherShops
            } else {
                sortedComparisons = sortedOtherShops
            }
        }
        
        priceComparisons = sortedComparisons
        
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
        
        // Определяем, является ли товар альтернативой
        // Кнопка альтернативы показывается только если:
        // 1. Есть originalProductName (товар был заменен)
        // 2. Название отличается от оригинального
        // 3. И товар НЕ идентичен (is_identical = false)
        let hasOriginalName = item.originalProductName != nil
        let nameDiffers = item.originalProductName != nil && item.originalProductName != item.product.name
        
        // Если is_identical = true, кнопка должна быть скрыта
        let isAlternative: Bool
        if item.isIdentical {
            // Товар идентичен - кнопка всегда скрыта
            isAlternative = false
            print("🔍 BasketView: Product '\(item.product.name)' has is_identical=true → alternative button HIDDEN")
        } else {
            // Товар не идентичен - проверяем другие условия
            isAlternative = hasOriginalName && nameDiffers
            print("🔍 BasketView: Product '\(item.product.name)' has is_identical=false → checking other conditions")
        }
        
        // Логируем информацию о товаре и кнопке альтернативы
        print("   📦 Product name: '\(item.product.name)'")
        print("   🎯 Original name: '\(item.originalProductName ?? "nil")'")
        print("   ✅ is_identical: \(item.isIdentical)")
        print("   🔘 hasOriginalName: \(hasOriginalName), nameDiffers: \(nameDiffers)")
        print("   👁️ Will show alternative button: \(isAlternative)")
        
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
        titleLabel.font = UIFont.onestBold(size: 18)
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
        nameLabel.font = UIFont.onestMedium(size: 14)
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(nameLabel)
        
        // Цена
        let priceLabel = UILabel()
        priceLabel.text = String(format: "%.0f ₽", product.price)
        priceLabel.font = UIFont.onestBold(size: 16)
        priceLabel.textColor = .systemGreen
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(priceLabel)
        
        // Кнопка выбора
        let selectButton = UIButton(type: .system)
        selectButton.setTitle("Выбрать", for: .normal)
        selectButton.titleLabel?.font = UIFont.onestSemibold(size: 14)
        selectButton.setTitleColor(.white, for: .normal)
        selectButton.layer.cornerRadius = 8
        selectButton.clipsToBounds = true
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
        
        // Применяем градиент после установки constraints
        DispatchQueue.main.async { [weak self] in
            self?.applyGradientToButton(selectButton, cornerRadius: 8)
        }
        
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
            
            // Сохраняем количество, оригинальное название и флаг isIdentical
            let quantity = cart.items[index].quantity
            let originalName = cart.items[index].originalProductName ?? item.product.name
            let isIdentical = cart.items[index].isIdentical
            
            // Создаем новый CartItem с заменой
            // При замене через альтернативу новый товар не может быть идентичным
            let newItem = CartItem(
                product: newProduct,
                quantity: quantity,
                originalProductName: originalName,
                isIdentical: false // Замененный товар всегда не идентичен
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
        return 120 // Уменьшена высота для меньшего расстояния между ячейками
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
        backgroundColor = .clear
        
        // Контейнер-квадрат 110x110 для картинки товара
        let imageContainer = UIView()
        imageContainer.backgroundColor = .white
        imageContainer.layer.cornerRadius = 8
        imageContainer.clipsToBounds = true
        imageContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageContainer)
        
        // Product image - внутри квадрата 110x110
        productImageView.backgroundColor = .clear
        productImageView.contentMode = .scaleAspectFit
        productImageView.clipsToBounds = true
        productImageView.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.addSubview(productImageView)
        
        // Alternative button - овал с текстом "+ Альтернатива"
        alternativeButton.setTitle("+ Альтернатива", for: .normal)
        alternativeButton.setTitleColor(UIColor(hex: "FF6C02") ?? .systemOrange, for: .normal)
        alternativeButton.backgroundColor = UIColor(hex: "FBFBFB") ?? .systemGray6
        alternativeButton.titleLabel?.font = UIFont.onestMedium(size: 12)
        alternativeButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        alternativeButton.layer.cornerRadius = 12 // Для овальной формы (высота 24, радиус 12)
        alternativeButton.clipsToBounds = true
        alternativeButton.translatesAutoresizingMaskIntoConstraints = false
        alternativeButton.addTarget(self, action: #selector(alternativeButtonTapped), for: .touchUpInside)
        alternativeButton.isHidden = true // По умолчанию скрыта
        contentView.addSubview(alternativeButton)
        
        // Title label - справа от картинки
        titleLabel.font = UIFont.onestMedium(size: 12)
        titleLabel.textColor = UIColor(hex: "4E4E4E") ?? .darkGray
        titleLabel.numberOfLines = 2 // Максимум 2 строки
        titleLabel.lineBreakMode = .byTruncatingTail // Обрезаем текст после максимально возможного текста в 2 строки
        titleLabel.adjustsFontSizeToFitWidth = false // Не уменьшаем шрифт
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Прямоугольник с кнопками + и - (цвет EDEDED) - под названием
        let quantityOval = UIView()
        quantityOval.backgroundColor = UIColor(hex: "EDEDED") ?? .systemGray5
        quantityOval.layer.cornerRadius = 13.5 // Для прямоугольника 80x27 (27/2 = 13.5)
        quantityOval.clipsToBounds = true
        quantityOval.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(quantityOval)
        
        // Кнопка минус
        minusButton.setTitle("−", for: .normal)
        minusButton.setTitleColor(UIColor(hex: "747474") ?? .gray, for: .normal)
        minusButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        minusButton.addTarget(self, action: #selector(minusButtonTapped), for: .touchUpInside)
        minusButton.translatesAutoresizingMaskIntoConstraints = false
        quantityOval.addSubview(minusButton)
        
        // Label количества
        quantityLabel.text = "1"
        quantityLabel.textAlignment = .center
        quantityLabel.font = UIFont.onestMedium(size: 16)
        quantityLabel.textColor = UIColor(hex: "747474") ?? .gray
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false
        quantityOval.addSubview(quantityLabel)
        
        // Кнопка плюс
        plusButton.setTitle("+", for: .normal)
        plusButton.setTitleColor(UIColor(hex: "747474") ?? .gray, for: .normal)
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        quantityOval.addSubview(plusButton)
        
        // Price label - в правой части карточки
        priceLabel.font = UIFont.onestMedium(size: 18)
        priceLabel.textColor = UIColor(hex: "4E4E4E") ?? .darkGray
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(priceLabel)
        
        NSLayoutConstraint.activate([
            // Контейнер-квадрат 80x80 для картинки, слева с отрицательным отступом для сдвига левее
            imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageContainer.widthAnchor.constraint(equalToConstant: 80),
            imageContainer.heightAnchor.constraint(equalToConstant: 80),
            
            // Product image - заполняет весь контейнер
            productImageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor),
            productImageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor),
            productImageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            productImageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            
            // Alternative button - овал внизу картинки
            alternativeButton.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            alternativeButton.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: -4),
            alternativeButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Title label - справа от контейнера картинки, ширина 147 пикселей, до 2 строк
            titleLabel.leadingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: 26),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            titleLabel.widthAnchor.constraint(equalToConstant: 147),
            
            // Прямоугольник с кнопками - под названием, левый край совпадает с левым краем названия
            quantityOval.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            quantityOval.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            quantityOval.widthAnchor.constraint(equalToConstant: 80),
            quantityOval.heightAnchor.constraint(equalToConstant: 27),
            
            // Кнопка минус слева в овале
            minusButton.leadingAnchor.constraint(equalTo: quantityOval.leadingAnchor, constant: 8),
            minusButton.centerYAnchor.constraint(equalTo: quantityOval.centerYAnchor),
            minusButton.widthAnchor.constraint(equalToConstant: 20),
            minusButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Количество по центру овала
            quantityLabel.centerXAnchor.constraint(equalTo: quantityOval.centerXAnchor),
            quantityLabel.centerYAnchor.constraint(equalTo: quantityOval.centerYAnchor),
            
            // Кнопка плюс справа в овале
            plusButton.trailingAnchor.constraint(equalTo: quantityOval.trailingAnchor, constant: -8),
            plusButton.centerYAnchor.constraint(equalTo: quantityOval.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 20),
            plusButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Price label - ближе к правому краю, на уровне с прямоугольником (сдвинута левее)
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            priceLabel.centerYAnchor.constraint(equalTo: quantityOval.centerYAnchor),
            priceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: quantityOval.trailingAnchor, constant: 8),
            
            // Высота contentView (с минимальным отступом снизу)
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: imageContainer.bottomAnchor, constant: 0),
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: quantityOval.bottomAnchor, constant: 0)
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
        
        isAlternativeProduct = isAlternative
        
        // Сохраняем название товара ДО отмены загрузки
        let productName = item.product.name
        
        titleLabel.text = productName
        priceLabel.text = String(format: "%.2f₽", item.product.price)
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
            return
        }
        
        guard let url = URL(string: urlString) else {
            productImageView.image = UIImage(named: "Image")
            return
        }
        
        let cacheKey = urlString as NSString
        
        // Проверяем кэш
        if let cachedImage = BasketItemCell.imageCache.object(forKey: cacheKey) {
            // Проверяем, что URL и название товара все еще актуальны перед установкой изображения из кэша
            guard currentImageURL == urlString && currentProductName == productName && titleLabel.text == productName else {
                return
            }
            
            productImageView.image = cachedImage
            return
        }
        
        // Создаем и сохраняем задачу загрузки
        imageLoadTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Проверяем, что URL и название товара все еще актуальны для этой ячейки
                guard self.currentImageURL == urlString && self.currentProductName == productName && self.titleLabel.text == productName else {
                    return
                }
                
                if let error = error {
                    // Игнорируем ошибки отмены
                    if (error as NSError).code != NSURLErrorCancelled {
                        if self.currentImageURL == urlString && self.currentProductName == productName && self.titleLabel.text == productName {
                            self.productImageView.image = UIImage(named: "Image")
                        }
                    }
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    if self.currentImageURL == urlString && self.currentProductName == productName && self.titleLabel.text == productName {
                        self.productImageView.image = UIImage(named: "Image")
                    }
                    return
                }
                
                // Финальная проверка URL и названия товара перед установкой изображения
                guard self.currentImageURL == urlString && self.currentProductName == productName && self.titleLabel.text == productName else {
                    return
                }
                
                // Сохраняем в кэш
                BasketItemCell.imageCache.setObject(image, forKey: cacheKey)
                
                // Устанавливаем изображение только если URL и название товара все еще актуальны
                self.productImageView.image = image
            }
        }
        
        imageLoadTask?.resume()
    }
}
