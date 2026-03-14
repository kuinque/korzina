import UIKit
import ObjectiveC

protocol ShopViewProtocol: AnyObject {
    func displayShopScreen()
    func displayCategories(_ categories: [String])
    func displaySelectedCategory(_ category: String)
    func displayProducts(_ products: [ProductViewModel], append: Bool)
    func showLoadingIndicator()
    func hideLoadingIndicator()
    func updateCartTotal(_ total: Double)
    func refreshProductCells()
    func setShopHeader(for shopName: String)
}

class ShopView: UIViewController {
    
    var presenter: ShopPresenterProtocol?
    
    // Кэш изображений для мгновенной загрузки
    static let imageCache = NSCache<NSString, UIImage>()
    
    // Хранилище активных задач загрузки изображений для возможности их отмены
    private var imageLoadingTasks: [UIImageView: URLSessionDataTask] = [:]
    
    // URLSession с ограничением на количество одновременных соединений
    static let imageSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 6 // Ограничиваем до 6 одновременных соединений
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()
    
    private let topView = UIView()
    var logo = UIImageView()
    var logoName = UIImageView()
    var shopLogo = UIImageView()
    private var shopName: String = "Пятёрочка" // По умолчанию
    private var logoContainerView: UIView? // Контейнер для кружка с логотипом
    private let shopNameLabel = UILabel() // Название магазина
    private let addressLabel = UILabel() // Адрес
    private let menuButton = UIButton(type: .system) // Кнопка меню

    private let searchBar = UISearchBar()
    private let categoryScrollView = UIScrollView()
    private let categoryStackView = UIStackView()
    private let tableView = UITableView()
    private var products: [ProductViewModel] = []
    
    // Products grid - используем UICollectionView для переиспользования ячеек
    private lazy var productsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 20
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = true
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.prefetchDataSource = self // Включаем prefetching для оптимизации
        collectionView.register(ProductCollectionViewCell.self, forCellWithReuseIdentifier: "ProductCollectionViewCell")
        return collectionView
    }()
    
    // Индикатор загрузки
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = .systemBlue
        return indicator
    }()
    
    // Хранилище для расширенных кнопок товаров
    private var expandedButtons: [Int: (button: UIButton, quantityLabel: UILabel, minusButton: UIButton, plusButton: UIButton, widthConstraint: NSLayoutConstraint, leadingConstraint: NSLayoutConstraint?)] = [:]
    
    // Cart elements
    private let cartContainerView = UIView()
    private let cartTotalLabel = UILabel()
    private let cartButton = UIButton(type: .system)
    
    // Кнопка корзины (как в MainView)
    private let basketButton = UIButton(type: .system)
    private let basketPriceLabel = UILabel()
    
    // Background blocks
    private let topWhiteBlock = UIView() // Первый белый блок (верхний)
    private let bottomWhiteBlock = UIView() // Второй белый блок (нижний)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "F3F3F3") ?? .systemGray6
        
        // Настраиваем кэш для URLSession для более быстрой загрузки изображений
        let cache = URLCache(memoryCapacity: 50 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024, diskPath: "imageCache")
        URLCache.shared = cache
        
        // Скрываем стандартную кнопку "Назад" и navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationItem.hidesBackButton = true
        
        setUpView()
        setUpCustomBackButton()
        presenter?.viewDidLoad()
        
        // Слушаем изменения корзины
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cartDidChange),
            name: CartManager.cartDidChangeNotification,
            object: nil
        )
        
        // Слушаем изменения корзины для обновления цены на кнопке корзины
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBasketPrice),
            name: CartManager.cartDidChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func cartDidChange() {
        // Обновляем отображение корзины и товаров
        let total = CartManager.shared.getCartTotal()
        updateCartTotal(total)
        
        // Обновляем видимые ячейки в UICollectionView
        refreshProductCells()
    }

    private func setUpView() {
        setUpBackgroundBlocks()
        //setUpHead()
       // setUpLogo()
        setUpShopLogo()
        setUpShopNameAndAddress()
        setUpSearchBar()
        setUpCategoryScroll()
        setUpProductsGrid() // Сначала создаем scrollView
        setUpCart() // Потом кнопку корзины, чтобы она была поверх scrollView
     //   setUpTable()
        
        // Убеждаемся, что интерактивные элементы находятся поверх белых блоков
        view.bringSubviewToFront(categoryScrollView)
        view.bringSubviewToFront(categoryStackView)
        
        // Также убеждаемся, что все кнопки категорий находятся поверх
        for case let button as UIButton in categoryStackView.arrangedSubviews {
            view.bringSubviewToFront(button)
        }
    }
    
    private func setUpBackgroundBlocks() {
        // Первый белый блок (верхний) - от верха экрана до 57px ниже safeArea, нижние углы закруглены
        topWhiteBlock.backgroundColor = .white
        topWhiteBlock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topWhiteBlock)
        
        // Второй белый блок (нижний) - от 7 пикселей ниже первого до конца экрана, верхние углы закруглены
        bottomWhiteBlock.backgroundColor = .white
        bottomWhiteBlock.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomWhiteBlock)
        
        NSLayoutConstraint.activate([
            // Первый блок: сверху экрана до 57px ниже safeArea (что дает центрирование элементов)
            topWhiteBlock.topAnchor.constraint(equalTo: view.topAnchor),
            topWhiteBlock.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topWhiteBlock.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topWhiteBlock.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 57),
            
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
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Применяем закругления углов после layout
        applyCornerRadiusToBlocks()
        
        // Обновляем размеры градиентов для выбранных кнопок
        for case let button as UIButton in categoryStackView.arrangedSubviews {
            if let gradientLayer = button.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
                gradientLayer.frame = button.bounds
                gradientLayer.cornerRadius = 16
            }
            // Убеждаемся, что кнопка имеет правильное закругление
            button.layer.cornerRadius = 16
            button.layer.masksToBounds = true
        }
        
        // Убеждаемся, что кнопка корзины всегда поверх всех элементов
        view.bringSubviewToFront(basketButton)
        
        // Обновляем frame градиента на кнопке корзины
        if let gradientLayer = basketButton.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
            gradientLayer.frame = basketButton.bounds
        }
        
        // Обновляем frame градиентов на расширенных кнопках товаров
        for (_, expanded) in expandedButtons {
            if let gradientLayer = expanded.button.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
                gradientLayer.frame = expanded.button.bounds
            }
        }
    }
    
    private func applyCornerRadiusToBlocks() {
        // Первый блок: нижние углы закруглены (cornerRadius = 25)
        applyCornerRadius(to: topWhiteBlock, topLeft: 0, topRight: 0, bottomLeft: 25, bottomRight: 25)
        
        // Второй блок: верхние углы закруглены (cornerRadius = 25)
        applyCornerRadius(to: bottomWhiteBlock, topLeft: 25, topRight: 25, bottomLeft: 0, bottomRight: 0)
    }
    
    /// Применяет закругления углов к view (аналогично MainView)
    private func applyCornerRadius(to view: UIView, topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        guard view.bounds.width > 0 && view.bounds.height > 0 else { return }
        
        let bounds = view.bounds
        let width = bounds.width
        let height = bounds.height
        
        // Создаем path с правильными углами
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
    
    private func setUpCustomBackButton() {
        let backButton = UIButton(type: .system)
        // Используем backbutton1 из assets
        if let backImage = UIImage(named: "backbutton1") {
            backButton.setImage(backImage, for: .normal)
        } else {
            // Fallback на системную иконку, если изображение не найдено
            backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        }
        backButton.tintColor = .black
        // Убираем все внутренние отступы, чтобы изображение было точно на левом краю
       
        backButton.contentHorizontalAlignment = .left
        backButton.contentVerticalAlignment = .center
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
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
    
    private func setUpShopLogo() {
        // Создаем кружок размером 45x45
        let containerView = UIView()
        containerView.backgroundColor = getShopColor(for: shopName)
        containerView.layer.cornerRadius = 22.5 // Половина от 45 для круга
        containerView.clipsToBounds = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        logoContainerView = containerView
        
        // Получаем имя логотипа из MainView
        let logoImageName = getShopLogoName(for: shopName)
        // Загружаем изображение с правильным масштабом для Retina дисплеев
        let logoImage = UIImage(named: logoImageName)?.withRenderingMode(.alwaysOriginal)
        shopLogo = UIImageView(image: logoImage)
        shopLogo.contentMode = .scaleAspectFit
        // Улучшаем качество рендеринга
        shopLogo.layer.minificationFilter = .trilinear
        shopLogo.layer.magnificationFilter = .trilinear
        shopLogo.clipsToBounds = true
        shopLogo.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(shopLogo)
        
        // Размер логотипа (используем те же множители, что и в MainView)
        let logoMultiplier: CGFloat = {
            switch shopName {
            case "Перекрёсток":
                return 0.65
            case "Дикси":
                return 0.75
            case "Лента":
                return 0.75
            case "Пятёрочка":
                return 1
            case "Ашан":
                return 0.8
            case "Магнит", "Азбука Вкуса":
                return 0.8
            default:
                return 0.9
            }
        }()
        
        NSLayoutConstraint.activate([
            // Кружок: 41 пиксель от левой части экрана, 6 пикселей от safeArea сверху
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 41),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            containerView.widthAnchor.constraint(equalToConstant: 45),
            containerView.heightAnchor.constraint(equalToConstant: 45),
            
            // Логотип внутри кружка (центрирован, с учетом множителя размера)
            shopLogo.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            shopLogo.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: (shopName == "Азбука Вкуса" || shopName == "Метро") ? 2 : 0),
            shopLogo.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: logoMultiplier),
            shopLogo.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: logoMultiplier)
        ])
    }
    
    private func setUpShopNameAndAddress() {
        // Название магазина
        shopNameLabel.font = UIFont.onestMedium(size: 22)
        shopNameLabel.textColor = .black
        shopNameLabel.text = shopName
        shopNameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shopNameLabel)
        
        // Адрес
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addressLabel)
        
        // Загружаем сохраненный адрес
        if let savedAddress = UserDefaults.standard.string(forKey: "savedAddress"), !savedAddress.isEmpty {
            setAddressText(savedAddress)
        } else {
            setAddressText("Укажите адрес")
        }
        
        // Кнопка меню в правом верхнем углу (как в MainView)
        menuButton.setImage(createMenuIcon(), for: .normal)
        menuButton.tintColor = .black
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuButton)
        
        NSLayoutConstraint.activate([
            // Название магазина: 9 пикселей от safeArea сверху, 95 от левого края
            shopNameLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 9),
            shopNameLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 95),
            
            // Адрес: на 3 пикселя ниже названия магазина, тот же отступ слева
            addressLabel.topAnchor.constraint(equalTo: shopNameLabel.bottomAnchor, constant: -5),
            addressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 95),
            
            // Кнопка меню: на той же высоте, что и название магазина, справа с отступом
            menuButton.topAnchor.constraint(equalTo: shopNameLabel.topAnchor, constant: -5),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    /// Устанавливает текст адреса с серой галочкой вниз в конце (пропорционально уменьшенная версия из MainView)
    private func setAddressText(_ text: String) {
        let grayColor = UIColor(hex: "858585") ?? .systemGray
        
        // Создаем атрибутированную строку
        let font = UIFont.onestRegular(size: 13) // Размер шрифта для ShopView
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.foregroundColor, value: grayColor, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.count))
        
        // Добавляем расстояние 1.5 пробела перед галочкой
        // Один пробел
        attributedString.append(NSAttributedString(string: " ", attributes: [.font: font]))
        // Добавляем еще 0.5 пробела через пробел с уменьшенным размером шрифта
        let halfSpaceFont = UIFont.onestRegular(size: font.pointSize * 0.5)
        attributedString.append(NSAttributedString(string: " ", attributes: [.font: halfSpaceFont]))
        
        // Создаем иконку check1 из assets
        guard let checkImage = UIImage(named: "check1") else {
            // Если изображение не найдено, используем текст без иконки
            addressLabel.attributedText = attributedString
            return
        }
        
        // Применяем серый цвет напрямую к оригинальному изображению
        // Используем alwaysOriginal чтобы сохранить качество
        let tintedImage = checkImage.withTintColor(grayColor, renderingMode: .alwaysOriginal)
        
        let imageAttachment = NSTextAttachment()
        // Используем оригинальное изображение без перерисовки
        imageAttachment.image = tintedImage
        
        // Пропорционально уменьшенные размеры галочки
        // В MainView: width: 10, height: 6 для шрифта size 16
        // В ShopView: шрифт size 13, коэффициент: 13/16 = 0.8125
        let checkSize = CGSize(width: 8, height: 5) // Пропорционально уменьшено
        imageAttachment.bounds = CGRect(
            x: 0,
            y: (font.capHeight - checkSize.height) / 2,
            width: checkSize.width,
            height: checkSize.height
        )
        
        // Добавляем иконку к строке
        let imageString = NSAttributedString(attachment: imageAttachment)
        attributedString.append(imageString)
        
        addressLabel.attributedText = attributedString
    }

    
    func setShopHeader(for shopName: String) {
        print("ShopView: Setting header for shop: \(shopName)")
        self.shopName = shopName
        
        // Обновляем название магазина
        shopNameLabel.text = shopName
        
        // Обновляем цвет кружка
        if let containerView = logoContainerView {
            containerView.backgroundColor = getShopColor(for: shopName)
        }
        
        // Обновляем логотип
        let logoImageName = getShopLogoName(for: shopName)
        let logoImage = UIImage(named: logoImageName)?.withRenderingMode(.alwaysOriginal)
        shopLogo.image = logoImage
        
        // Обновляем размер логотипа
        let logoMultiplier: CGFloat = {
        switch shopName {
            case "Перекрёсток":
                return 0.65
            case "Дикси":
                return 0.75
        case "Лента":
                return 0.75
        case "Пятёрочка":
                return 1
        case "Ашан":
                return 0.8
            case "Магнит", "Азбука Вкуса":
                return 0.8
        default:
                return 0.9
            }
        }()
        
        // Обновляем constraints для размера логотипа
        if let containerView = logoContainerView {
            // Удаляем все старые constraints логотипа
            NSLayoutConstraint.deactivate(shopLogo.constraints)
            
            // Удаляем constraints, которые связывают shopLogo с containerView
            containerView.constraints.forEach { constraint in
                if constraint.firstItem === shopLogo || constraint.secondItem === shopLogo {
                    constraint.isActive = false
                }
            }
            
            // Создаем новые constraints с правильными значениями
            let centerYConstant: CGFloat = (shopName == "Азбука Вкуса" || shopName == "Метро") ? 2 : 0
            NSLayoutConstraint.activate([
                shopLogo.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                shopLogo.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: centerYConstant),
                shopLogo.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: logoMultiplier),
                shopLogo.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: logoMultiplier)
            ])
        }
    }
    
    /// Возвращает имя логотипа для магазина (из MainView.swift)
    private func getShopLogoName(for storeName: String) -> String {
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
        return mapping[storeName] ?? storeName.lowercased()
    }
    
    /// Создает иконку меню (три линии) - из MainView.swift
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
    
    /// Возвращает цвет для магазина (из MainView.swift)
    private func getShopColor(for storeName: String) -> UIColor {
        switch storeName {
        case "Ашан":
            return UIColor(hex: "#E0001A") ?? .systemRed
        case "Перекрёсток":
            return UIColor(hex: "#5FAF2D") ?? .systemGreen
        case "Лента":
            return UIColor(hex: "#003B95") ?? .systemBlue
        case "Магнит":
            return UIColor(hex: "#FF010B") ?? .systemRed
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
   

    private func setUpSearchBar() {
        searchBar.placeholder = ""
        // Убираем серые полоски (границы)
        searchBar.backgroundImage = UIImage()
        searchBar.scopeBarBackgroundImage = UIImage()
        // Настраиваем внешний вид для iOS 13+
        if #available(iOS 13.0, *) {
        searchBar.searchBarStyle = .minimal
        }
        
        view.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.pinTop(to: bottomWhiteBlock.topAnchor, 18)
        // Растягиваем searchBar с отступами от краев экрана
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 11),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -11),
            searchBar.heightAnchor.constraint(equalToConstant: 40)
        ])
        // Делаем сам searchBar прозрачным, чтобы был виден только textField
        searchBar.backgroundColor = .clear
        searchBar.barTintColor = .clear
        searchBar.delegate = self

        // Настраиваем textField внутри searchBar
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            // Применяем размеры также к textField, чтобы он заполнял весь searchBar
            textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor),
                textField.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor),
                textField.topAnchor.constraint(equalTo: searchBar.topAnchor),
                textField.bottomAnchor.constraint(equalTo: searchBar.bottomAnchor)
            ])
            // Цвет фона F2F2F2 (RGB: 242, 242, 242)
            let backgroundColor = UIColor(red: 242/255.0, green: 242/255.0, blue: 242/255.0, alpha: 1.0)
            textField.backgroundColor = backgroundColor
            // Скругление углов
            textField.layer.cornerRadius = 20
            textField.layer.cornerCurve = .continuous
            textField.clipsToBounds = true
            textField.textAlignment = .left // Выравнивание слева
            // Убираем стандартную иконку лупы слева
            textField.leftView = nil
            textField.leftViewMode = .never
            // Убираем border
            textField.borderStyle = .none
            
            // Создаем кастомный placeholder слева с иконкой
            let placeholderContainer = UIView()
            placeholderContainer.isUserInteractionEnabled = false
            
            let iconImageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
            iconImageView.tintColor = UIColor(hex: "939393")
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            
            let placeholderLabel = UILabel()
            placeholderLabel.text = "Поиск продуктов"
            placeholderLabel.font = UIFont.onestMedium(size: 16)
            placeholderLabel.textColor = UIColor(hex: "939393")
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            
            placeholderContainer.addSubview(iconImageView)
            placeholderContainer.addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
                iconImageView.leadingAnchor.constraint(equalTo: placeholderContainer.leadingAnchor),
                iconImageView.centerYAnchor.constraint(equalTo: placeholderContainer.centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: DesignTokens.Sizes.Icon.sm),
                iconImageView.heightAnchor.constraint(equalToConstant: DesignTokens.Sizes.Icon.sm),
                
                placeholderLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: DesignTokens.Spacing.xs + 2),
                placeholderLabel.centerYAnchor.constraint(equalTo: placeholderContainer.centerYAnchor),
                placeholderLabel.trailingAnchor.constraint(equalTo: placeholderContainer.trailingAnchor)
            ])
            
            searchBar.addSubview(placeholderContainer)
            placeholderContainer.translatesAutoresizingMaskIntoConstraints = false
            // Размещаем placeholder слева вместо центра
            NSLayoutConstraint.activate([
                placeholderContainer.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor, constant: 16),
                placeholderContainer.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor)
            ])
            
            // Скрываем placeholder когда начинается ввод
            NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: textField, queue: .main) { _ in
                placeholderContainer.isHidden = !(textField.text?.isEmpty ?? true)
            }
        }
    }

    private func setUpCategoryScroll() {
        categoryScrollView.showsHorizontalScrollIndicator = false
        categoryScrollView.translatesAutoresizingMaskIntoConstraints = false
        categoryScrollView.backgroundColor = .clear // Прозрачный фон
        categoryScrollView.isUserInteractionEnabled = true // Включаем взаимодействие
        view.addSubview(categoryScrollView)

        NSLayoutConstraint.activate([
            categoryScrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 15),
            categoryScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryScrollView.heightAnchor.constraint(equalToConstant: 40)
        ])

        categoryStackView.axis = .horizontal
        categoryStackView.spacing = 8
        categoryStackView.alignment = .center // Выравнивание по центру
        categoryStackView.distribution = .fill // Заполнение по содержимому
        categoryStackView.translatesAutoresizingMaskIntoConstraints = false
        categoryStackView.isUserInteractionEnabled = true // Включаем взаимодействие

        categoryScrollView.addSubview(categoryStackView)

        NSLayoutConstraint.activate([
            categoryStackView.topAnchor.constraint(equalTo: categoryScrollView.topAnchor),
            categoryStackView.bottomAnchor.constraint(equalTo: categoryScrollView.bottomAnchor),
            categoryStackView.leadingAnchor.constraint(equalTo: categoryScrollView.leadingAnchor, constant: 12),
            categoryStackView.trailingAnchor.constraint(equalTo: categoryScrollView.trailingAnchor, constant: -12),
            categoryStackView.heightAnchor.constraint(equalTo: categoryScrollView.heightAnchor)
        ])
    }

    private func setUpProductsGrid() {
        productsCollectionView.delegate = self
        productsCollectionView.dataSource = self
        productsCollectionView.prefetchDataSource = self
        view.addSubview(productsCollectionView)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            productsCollectionView.topAnchor.constraint(equalTo: categoryScrollView.bottomAnchor, constant: 20),
            productsCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            productsCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            productsCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: productsCollectionView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: productsCollectionView.centerYAnchor)
        ])
    }
    
    func showLoadingIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingIndicator.startAnimating()
            self?.productsCollectionView.alpha = 0.5
        }
    }
    
    func hideLoadingIndicator() {
        DispatchQueue.main.async { [weak self] in
            self?.loadingIndicator.stopAnimating()
            UIView.animate(withDuration: 0.2) {
                self?.productsCollectionView.alpha = 1.0
            }
        }
    }
    
    private var isAppendingProducts = false
    
    private func displayProductsGrid(_ products: [ProductViewModel]) {
        let previousCount = self.products.count
        
        if isAppendingProducts {
            self.products.append(contentsOf: products)
            if previousCount > 0 && !products.isEmpty {
                let indexPaths = (previousCount..<self.products.count).map { IndexPath(item: $0, section: 0) }
                productsCollectionView.performBatchUpdates({
                    productsCollectionView.insertItems(at: indexPaths)
                }, completion: nil)
            } else {
                productsCollectionView.reloadData()
            }
        } else {
            self.products = products
            productsCollectionView.reloadData()
        }
        
        isAppendingProducts = false
        productsCollectionView.layoutIfNeeded()
    }
    
    private func createProductCard(for product: ProductViewModel, index: Int) -> UIView {
        // Основной контейнер карточки
        let cardContainer = UIView()
        cardContainer.backgroundColor = UIColor(hex: "F3F3F3") ?? .systemGray6
        cardContainer.layer.cornerRadius = 15
        cardContainer.clipsToBounds = true
        
        // Белый прямоугольник внутри
        let whiteRect = UIView()
        whiteRect.backgroundColor = .white
        whiteRect.layer.cornerRadius = 15
        whiteRect.clipsToBounds = true
        whiteRect.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(whiteRect)
        
        // Картинка товара
        let productImageView = UIImageView()
        productImageView.contentMode = .scaleAspectFit
        productImageView.backgroundColor = .clear // Прозрачный фон для изображения
        productImageView.isOpaque = false // Позволяет прозрачность
        productImageView.clipsToBounds = true
        productImageView.translatesAutoresizingMaskIntoConstraints = false
        whiteRect.addSubview(productImageView)
        
        // Загружаем изображение с кэшированием
        if let imageURL = product.imageURL {
            loadProductImage(from: imageURL, into: productImageView)
        } else {
            productImageView.image = UIImage(named: "Image")
        }
        
        // Название товара
        let nameLabel = UILabel()
        nameLabel.text = product.name
        nameLabel.font = UIFont.onestMedium(size: 12)
        nameLabel.textColor = UIColor(hex: "5F5F5F") ?? .systemGray
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(nameLabel)
        
        // Цена
        let priceLabel = UILabel()
        priceLabel.text = String(format: "%.0f₽", product.price)
        priceLabel.font = UIFont.onestMedium(size: 18)
        priceLabel.textColor = UIColor(hex: "5F5F5F") ?? .systemGray
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(priceLabel)
        
        // Кнопка добавления товара (белый круг с плюсом)
        let addButton = UIButton(type: .system)
        addButton.backgroundColor = .white
        addButton.layer.cornerRadius = 15.5 // Радиус для круга (31/2)
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(UIColor(hex: "5F5F5F") ?? .systemGray, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .light) // Изменено на .light для более тонкого вида
        addButton.contentHorizontalAlignment = .center // Центрируем текст
        addButton.contentVerticalAlignment = .center // Центрируем текст
        // Сдвигаем текст немного правее и выше
        addButton.titleEdgeInsets = UIEdgeInsets(top: -2, left: 1, bottom: 0, right: 0)
        addButton.contentEdgeInsets = .zero // Убираем любые отступы для содержимого
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.tag = index // Сохраняем индекс продукта
        addButton.addTarget(self, action: #selector(addProductToCart(_:)), for: .touchUpInside)
        cardContainer.addSubview(addButton)
        
        // Сохраняем constraint ширины для последующей анимации
        let widthConstraint = addButton.widthAnchor.constraint(equalToConstant: 31)
        let heightConstraint = addButton.heightAnchor.constraint(equalToConstant: 31)
        
        NSLayoutConstraint.activate([
            // Белый прямоугольник: 170x170, отступ 5 от верха и краев
            whiteRect.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 5),
            whiteRect.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 5),
            whiteRect.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -5),
            whiteRect.widthAnchor.constraint(equalToConstant: 170),
            whiteRect.heightAnchor.constraint(equalToConstant: 170),
            
            // Картинка в центре белого прямоугольника
            productImageView.centerXAnchor.constraint(equalTo: whiteRect.centerXAnchor),
            productImageView.centerYAnchor.constraint(equalTo: whiteRect.centerYAnchor),
            productImageView.widthAnchor.constraint(lessThanOrEqualTo: whiteRect.widthAnchor, multiplier: 0.9),
            productImageView.heightAnchor.constraint(lessThanOrEqualTo: whiteRect.heightAnchor, multiplier: 0.9),
            
            // Название: на 12 пикселей ниже белого прямоугольника
            nameLabel.topAnchor.constraint(equalTo: whiteRect.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 5),
            nameLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -5),
            
            // Цена: левый нижний угол
            priceLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 5),
            priceLabel.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -5),
            
            // Кнопка добавления: правый нижний угол
            addButton.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -5),
            addButton.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -5),
            widthConstraint,
            heightConstraint
        ])
        
        // Сохраняем constraint в tag кнопки через objc_setAssociatedObject или просто сохраним в словаре
        // Используем простой способ - сохраним в расширенном словаре
        objc_setAssociatedObject(addButton, "widthConstraint", widthConstraint, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Проверяем, если товар уже в корзине, расширяем кнопку
        let quantity = CartManager.shared.getCartQuantity(for: product)
        if quantity > 0 {
            // Не используем async здесь, чтобы constraint был установлен сразу
            expandButton(addButton, for: index, product: product)
            updateQuantityLabel(for: index)
        }
        
        return cardContainer
    }
    
    @objc private func addProductToCart(_ sender: UIButton) {
        // Находим продукт по индексу
        let index = sender.tag
        guard index < products.count else { return }
        let product = products[index]
        
        // Если кнопка уже расширена, просто увеличиваем количество
        if let expanded = expandedButtons[index] {
            presenter?.addToCart(product: product)
            updateQuantityLabel(for: index)
            return
        }
        
        // Добавляем товар в корзину
        presenter?.addToCart(product: product)
        
        // Анимированно расширяем кнопку на главном потоке
        DispatchQueue.main.async { [weak self] in
            self?.expandButton(sender, for: index, product: product)
        }
    }
    
    /// Расширяет кнопку с анимацией и добавляет элементы управления
    private func expandButton(_ button: UIButton, for index: Int, product: ProductViewModel) {
        // Получаем сохраненный constraint ширины
        var widthConstraint: NSLayoutConstraint?
        
        // Сначала пытаемся получить из associated object
        if let savedConstraint = objc_getAssociatedObject(button, "widthConstraint") as? NSLayoutConstraint {
            // Проверяем, что constraint все еще активен и относится к этой кнопке
            if savedConstraint.isActive && (savedConstraint.firstItem === button || savedConstraint.secondItem === button) {
                widthConstraint = savedConstraint
                print("✅ Найден width constraint из associated object, текущее значение: \(savedConstraint.constant), isActive: \(savedConstraint.isActive)")
            } else {
                print("⚠️ Constraint из associated object не активен или не относится к кнопке")
            }
        }
        
        // Если не нашли в associated object, ищем в constraints кнопки
        if widthConstraint == nil {
            // Ищем constraint, где firstItem это кнопка и firstAttribute это width
            for constraint in button.constraints {
                if constraint.firstAttribute == .width && constraint.firstItem === button {
                    widthConstraint = constraint
                    print("✅ Найден width constraint через поиск в button.constraints, значение: \(constraint.constant), isActive: \(constraint.isActive)")
                    // Сохраняем найденный constraint для будущего использования
                    objc_setAssociatedObject(button, "widthConstraint", constraint, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    break
                }
            }
        }
        
        // Последняя попытка: ищем в superview constraints
        if widthConstraint == nil, let superview = button.superview {
            for constraint in superview.constraints {
                if (constraint.firstItem === button && constraint.firstAttribute == .width) ||
                   (constraint.secondItem === button && constraint.secondAttribute == .width) {
                    widthConstraint = constraint
                    print("✅ Найден width constraint в superview, значение: \(constraint.constant), isActive: \(constraint.isActive)")
                    // Сохраняем найденный constraint
                    objc_setAssociatedObject(button, "widthConstraint", constraint, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                    break
                }
            }
        }
        
        guard let finalWidthConstraint = widthConstraint else {
            print("❌ Не найден width constraint для кнопки. Все constraints кнопки: \(button.constraints.map { "\($0.firstAttribute.rawValue): \($0.constant), active: \($0.isActive)" })")
            if let superview = button.superview {
                print("❌ Constraints superview: \(superview.constraints.filter { $0.firstItem === button || $0.secondItem === button }.map { "\($0.firstAttribute.rawValue)-\($0.secondAttribute.rawValue): \($0.constant)" })")
            }
            return
        }
        
        expandButtonWithConstraint(button, widthConstraint: finalWidthConstraint, for: index, product: product)
    }
    
    /// Вспомогательная функция для расширения кнопки
    private func expandButtonWithConstraint(_ button: UIButton, widthConstraint: NSLayoutConstraint, for index: Int, product: ProductViewModel) {
        
        // Создаем контейнер для элементов управления
        let quantityLabel = UILabel()
        quantityLabel.text = "1"
        quantityLabel.textColor = .white
        quantityLabel.font = UIFont.onestMedium(size: 16)
        quantityLabel.textAlignment = .center
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(quantityLabel)
        
        // Кнопка минус слева
        let minusButton = UIButton(type: .system)
        minusButton.setTitle("−", for: .normal)
        minusButton.setTitleColor(.white, for: .normal)
        minusButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .light) // Изменено на .light для более тонкого вида
        minusButton.contentHorizontalAlignment = .center // Центрируем текст
        minusButton.contentVerticalAlignment = .center // Центрируем текст
        minusButton.tag = index
        minusButton.addTarget(self, action: #selector(decreaseQuantity(_:)), for: .touchUpInside)
        minusButton.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(minusButton)
        
        // Кнопка плюс справа
        let plusButton = UIButton(type: .system)
        plusButton.setTitle("+", for: .normal)
        plusButton.setTitleColor(.white, for: .normal)
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .light) // Изменено на .light для более тонкого вида
        plusButton.contentHorizontalAlignment = .center // Центрируем текст
        plusButton.contentVerticalAlignment = .center // Центрируем текст
        plusButton.tag = index
        plusButton.addTarget(self, action: #selector(increaseQuantity(_:)), for: .touchUpInside)
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(plusButton)
        
        // Убираем текст "+" с кнопки
        button.setTitle("", for: .normal)
        
        // Изменяем cornerRadius на 15.5 для овальной формы расширенной кнопки (31x81)
        // Для овала cornerRadius должен быть равен половине высоты (31/2 = 15.5)
        button.layer.cornerRadius = 15.5
        
        // Применяем градиент
        applyGradientToProductButton(button)
        
        NSLayoutConstraint.activate([
            // Минус слева
            minusButton.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 8),
            minusButton.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            minusButton.widthAnchor.constraint(equalToConstant: 20),
            minusButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Количество по центру
            quantityLabel.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            quantityLabel.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            
            // Плюс справа
            plusButton.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -8),
            plusButton.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 20),
            plusButton.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // Сохраняем ссылки
        expandedButtons[index] = (button: button, quantityLabel: quantityLabel, minusButton: minusButton, plusButton: plusButton, widthConstraint: widthConstraint, leadingConstraint: nil)
        
        // Анимация расширения: меняем ширину с 31 на 81
        // Правый край остается на месте (trailingAnchor), левый двигается влево
        print("🔄 Начинаем анимацию расширения кнопки с \(widthConstraint.constant) на 81")
        
        // Убеждаемся, что constraint активен и имеет правильный priority
        widthConstraint.isActive = true
        widthConstraint.priority = UILayoutPriority(1000)
        
        // Проверяем, нет ли других width constraints, которые могут конфликтовать
        let allWidthConstraints = button.constraints.filter { $0.firstAttribute == .width }
        print("🔍 Все width constraints кнопки: \(allWidthConstraints.map { "\($0.constant), active: \($0.isActive), item: \($0.firstItem === button)" })")
        
        // Деактивируем все другие width constraints, если есть
        for constraint in allWidthConstraints {
            if constraint !== widthConstraint {
                constraint.isActive = false
                print("❌ Деактивирован конфликтующий constraint: \(constraint.constant)")
            }
        }
        
        // Также проверяем constraints в superview
        if let superview = button.superview {
            let superviewWidthConstraints = superview.constraints.filter { 
                ($0.firstItem === button && $0.firstAttribute == .width) ||
                ($0.secondItem === button && $0.secondAttribute == .width)
            }
            print("🔍 Width constraints в superview: \(superviewWidthConstraints.map { "\($0.constant), active: \($0.isActive)" })")
            for constraint in superviewWidthConstraints {
                if constraint !== widthConstraint {
                    constraint.isActive = false
                    print("❌ Деактивирован конфликтующий constraint в superview: \(constraint.constant)")
                }
            }
        }
        
        // Изменяем constant ДО анимации
        let oldConstant = widthConstraint.constant
        widthConstraint.constant = 81
        print("📏 Изменили constraint с \(oldConstant) на \(widthConstraint.constant), isActive: \(widthConstraint.isActive), priority: \(widthConstraint.priority.rawValue)")
        
        // Анимация расширения
        // Нужно обновить layout на view, который содержит все constraints
        if let cardContainer = button.superview {
            // Принудительно обновляем layout перед анимацией
            cardContainer.setNeedsLayout()
            cardContainer.layoutIfNeeded()
            view.setNeedsLayout()
            view.layoutIfNeeded()
            
            print("📐 Перед анимацией: button.frame = \(button.frame), bounds = \(button.bounds), constraint = \(widthConstraint.constant), isActive = \(widthConstraint.isActive)")
            
            // Сохраняем ссылку на constraint в expandedButtons, чтобы он не был пересоздан
            // Анимация с spring эффектом
            // ВАЖНО: Сохраняем ссылку на constraint, чтобы он не был потерян
            let constraintToAnimate = widthConstraint
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction]) {
                // Обновляем layout на главном view внутри анимации
                self.view.layoutIfNeeded()
                // Также обновляем на cardContainer
                cardContainer.layoutIfNeeded()
            } completion: { _ in
                // Проверяем, что constraint все еще правильный и активный
                if constraintToAnimate.constant != 81 {
                    print("⚠️ Constraint изменился после анимации! Восстанавливаем...")
                    constraintToAnimate.constant = 81
                    constraintToAnimate.isActive = true
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                }
                print("✅ Анимация завершена, новая ширина кнопки: \(button.bounds.width), frame: \(button.frame), constraint: \(constraintToAnimate.constant), isActive: \(constraintToAnimate.isActive)")
                // Обновляем frame градиента после анимации
                if let gradientLayer = button.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
                    gradientLayer.frame = button.bounds
                    print("🎨 Обновлен frame градиента: \(gradientLayer.frame)")
                }
            }
        }
    }
    
    /// Применяет градиент к кнопке товара
    private func applyGradientToProductButton(_ button: UIButton) {
        // Удаляем старый градиент, если есть
        button.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // Убираем белый фон
        button.backgroundColor = .clear
        
        // Создаем градиентный слой
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "FF8733")?.cgColor ?? UIColor.orange.cgColor,
            UIColor(hex: "FE6900")?.cgColor ?? UIColor.orange.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        // Для овальной формы cornerRadius должен быть равен половине высоты (31/2 = 15.5)
        gradientLayer.cornerRadius = 15.5
        gradientLayer.masksToBounds = true
        gradientLayer.frame = button.bounds
        
        button.layer.insertSublayer(gradientLayer, at: 0)
        button.layer.cornerRadius = 15.5
        button.layer.masksToBounds = true
        
        // Обновляем frame градиента после layout
        DispatchQueue.main.async {
            gradientLayer.frame = button.bounds
        }
    }
    
    @objc private func increaseQuantity(_ sender: UIButton) {
        let index = sender.tag
        guard index < products.count else { return }
        let product = products[index]
        presenter?.addToCart(product: product)
        updateQuantityLabel(for: index)
    }
    
    @objc private func decreaseQuantity(_ sender: UIButton) {
        let index = sender.tag
        guard index < products.count else { return }
        let product = products[index]
        
        let currentQuantity = CartManager.shared.getCartQuantity(for: product)
        if currentQuantity > 1 {
            presenter?.removeFromCart(product: product)
            updateQuantityLabel(for: index)
        } else {
            // Если количество становится 0, сворачиваем кнопку
            collapseButton(for: index)
            presenter?.removeFromCart(product: product)
        }
    }
    
    /// Обновляет label с количеством товара
    private func updateQuantityLabel(for index: Int) {
        guard let expanded = expandedButtons[index],
              index < products.count else { return }
        let product = products[index]
        let quantity = CartManager.shared.getCartQuantity(for: product)
        expanded.quantityLabel.text = "\(quantity)"
    }
    
    /// Сворачивает кнопку обратно в круг
    private func collapseButton(for index: Int) {
        guard let expanded = expandedButtons[index] else { return }
        
        let button = expanded.button
        let widthConstraint = expanded.widthConstraint
        
        // Удаляем элементы управления
        expanded.quantityLabel.removeFromSuperview()
        expanded.minusButton.removeFromSuperview()
        expanded.plusButton.removeFromSuperview()
        
        // Удаляем градиент
        button.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // Возвращаем белый фон и текст "+"
        button.backgroundColor = .white
        button.setTitle("+", for: .normal)
        button.setTitleColor(UIColor(hex: "5F5F5F") ?? .systemGray, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .light) // Изменено на .light для более тонкого вида
        button.contentHorizontalAlignment = .center // Центрируем текст
        button.contentVerticalAlignment = .center // Центрируем текст
        // Сдвигаем текст немного правее и выше
        button.titleEdgeInsets = UIEdgeInsets(top: -2, left: 1, bottom: 0, right: 0)
        button.contentEdgeInsets = .zero // Убираем любые отступы для содержимого
        
        // Возвращаем cornerRadius на 15.5 (для круга 31x31)
        button.layer.cornerRadius = 15.5
        
        // Анимация сворачивания: возвращаем ширину с 81 на 31
        // Правый край остается на месте, левый двигается вправо
        widthConstraint.constant = 31
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            button.superview?.layoutIfNeeded()
        }
        
        // Удаляем из словаря
        expandedButtons.removeValue(forKey: index)
    }
    
    /// Загружает изображение товара с кэшированием и retry логикой
    private func loadProductImage(from urlString: String, into imageView: UIImageView, retryCount: Int = 0) {
        let cacheKey = urlString as NSString
        let maxRetries = 2 // Максимум 2 повторные попытки
        
        // Убеждаемся, что фон изображения прозрачный
        imageView.backgroundColor = .clear
        imageView.isOpaque = false
        
        // Проверяем кэш в памяти
        if let cachedImage = ShopView.imageCache.object(forKey: cacheKey) {
            imageView.image = cachedImage
            // Отменяем предыдущую задачу для этого imageView, если она есть
            imageLoadingTasks[imageView]?.cancel()
            imageLoadingTasks.removeValue(forKey: imageView)
            return
        }
        
        // Отменяем предыдущую задачу загрузки для этого imageView, если она есть
        imageLoadingTasks[imageView]?.cancel()
        
        // Устанавливаем placeholder
        imageView.image = UIImage(named: "Image")
        
        // Загружаем изображение
        guard let url = URL(string: urlString) else {
            return
        }
        
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        
        let task = ShopView.imageSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Удаляем задачу из словаря после завершения
            DispatchQueue.main.async {
                self.imageLoadingTasks.removeValue(forKey: imageView)
            }
            
            // Игнорируем ошибки отмены запроса
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }
            
            // Обрабатываем ошибки сети с retry логикой
            if let error = error {
                let nsError = error as NSError
                // Проверяем различные типы сетевых ошибок, которые можно повторить
                let isRetryableError = nsError.code == NSURLErrorTimedOut ||
                                      nsError.code == NSURLErrorNetworkConnectionLost || // -1005
                                      nsError.code == NSURLErrorNotConnectedToInternet ||
                                      nsError.code == NSURLErrorCannotConnectToHost ||
                                      nsError.code == -1005 || // Connection lost (дублируем для надежности)
                                      (nsError.domain == NSURLErrorDomain && nsError.code == -1005)
                
                if isRetryableError && retryCount < maxRetries {
                    // Повторная попытка с экспоненциальной задержкой
                    let delay = Double(retryCount + 1) * 0.5 // 0.5s, 1.0s
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.loadProductImage(from: urlString, into: imageView, retryCount: retryCount + 1)
                    }
                    return
                }
                
                // Не логируем ошибки, если это не последняя попытка
                if retryCount >= maxRetries {
                    print("❌ Error loading product image (after \(retryCount) retries): \(error.localizedDescription)")
                }
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                return
            }
            
            // Сохраняем в кэш
            ShopView.imageCache.setObject(image, forKey: cacheKey)
            
            // Устанавливаем изображение на главном потоке
            DispatchQueue.main.async {
                // Убеждаемся, что фон изображения прозрачный перед установкой
                imageView.backgroundColor = .clear
                imageView.isOpaque = false
                imageView.image = image
            }
        }
        
        // Сохраняем задачу для возможности отмены
        imageLoadingTasks[imageView] = task
        task.resume()
    }

    // Метод больше не используется, так как перешли на UICollectionView
    // Оставлен для возможного будущего использования
    private func setUpTable() {
        // tableView.dataSource = self  // Закомментировано - используем UICollectionView
        // tableView.delegate = self     // Закомментировано - используем UICollectionView
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(ProductCell.self, forCellReuseIdentifier: "ProductCell")
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: categoryScrollView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: cartContainerView.topAnchor, constant: -8)
        ])
    }

    private func addCategoryButtons(_ categories: [String]) {
        for (index, title) in categories.enumerated() {
            let button = UIButton(type: .system)
            
            // Используем UIButtonConfiguration вместо устаревшего contentEdgeInsets
            var config = UIButton.Configuration.plain()
            config.title = title
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = UIFont.onestMedium(size: 14)
                return outgoing
            }
            // Отступы: top: 10, bottom: 10, left: 14, right: 14
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 7, trailing: 14)
            
            // Цвета и фон
            if index == 0 {
                config.baseForegroundColor = .white
                config.background.backgroundColor = .clear // Прозрачный, так как градиент будет поверх
            } else {
                config.baseForegroundColor = UIColor(hex: "747474") ?? .systemGray
                config.background.backgroundColor = UIColor(white: 0.95, alpha: 1)
            }
            
            // Скругление углов
            config.background.cornerRadius = 18
            
            button.configuration = config
            
            // Применяем градиент для выбранной кнопки
            if index == 0 {
                applyGradientToButton(button)
            }
            
            // Устанавливаем высокий приоритет для сжатия, чтобы кнопка имела размер по содержимому
            button.setContentHuggingPriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.isUserInteractionEnabled = true // Включаем взаимодействие
            button.isEnabled = true // Убеждаемся, что кнопка включена
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryStackView.addArrangedSubview(button)
            
            // Убеждаемся, что кнопка находится поверх других элементов
            DispatchQueue.main.async {
                self.view.bringSubviewToFront(self.categoryScrollView)
                self.categoryScrollView.bringSubviewToFront(self.categoryStackView)
                self.categoryStackView.bringSubviewToFront(button)
            }
        }
    }

    private func setUpCart() {
        // Кнопка корзины (как в MainView.swift)
        basketButton.setTitle("корзина", for: .normal)
        basketButton.titleLabel?.font = UIFont.onestMedium(size: 22)
        basketButton.setTitleColor(.white, for: .normal)
        // Убираем сплошной цвет, будет градиент
        basketButton.backgroundColor = .clear
        basketButton.layer.cornerRadius = 25
        basketButton.layer.cornerCurve = .continuous
        basketButton.clipsToBounds = true
        
        // Устанавливаем отступ текста от левого края кнопки
        basketButton.contentHorizontalAlignment = .left
        basketButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 23, bottom: 0, right: 0)
      
        // Добавляем цену корзины слева от стрелочки
        basketPriceLabel.text = "0₽"
        basketPriceLabel.font = UIFont.onestMedium(size: 20)
        basketPriceLabel.textColor = .white
        basketPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        basketButton.addSubview(basketPriceLabel)
        
        // Добавляем картинку check2 справа в кнопке
        if let checkImage = UIImage(named: "check2") {
            let checkImageView = UIImageView(image: checkImage)
            checkImageView.contentMode = .scaleAspectFit
            checkImageView.tintColor = .white
            checkImageView.translatesAutoresizingMaskIntoConstraints = false
            basketButton.addSubview(checkImageView)
        
        NSLayoutConstraint.activate([
                // Цена корзины слева от стрелочки
                basketPriceLabel.trailingAnchor.constraint(equalTo: checkImageView.leadingAnchor, constant: -8),
                basketPriceLabel.centerYAnchor.constraint(equalTo: basketButton.centerYAnchor),
                
                // Стрелочка справа
                checkImageView.trailingAnchor.constraint(equalTo: basketButton.trailingAnchor, constant: -22),
                checkImageView.centerYAnchor.constraint(equalTo: basketButton.centerYAnchor),
                checkImageView.widthAnchor.constraint(equalToConstant: 10),
                checkImageView.heightAnchor.constraint(equalToConstant: 16)
            ])
        }
      
        basketButton.translatesAutoresizingMaskIntoConstraints = false
        // Добавляем кнопку корзины после всех элементов, чтобы она была поверх
        view.addSubview(basketButton)
        
        NSLayoutConstraint.activate([
            basketButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            basketButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -34),
            basketButton.widthAnchor.constraint(equalToConstant: 242),
            basketButton.heightAnchor.constraint(equalToConstant: 53)
        ])
        
        // Добавляем действие при нажатии
        basketButton.addTarget(self, action: #selector(basketButtonTapped), for: .touchUpInside)
        
        // Применяем градиент к кнопке корзины
        applyGradientToBasketButton(basketButton)
        
        // Обновляем цену корзины
        updateBasketPrice()
    }
    
    /// Применяет градиент к кнопке корзины
    private func applyGradientToBasketButton(_ button: UIButton) {
        // Удаляем старый градиент, если есть
        button.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // Создаем градиентный слой
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "FF8733")?.cgColor ?? UIColor.orange.cgColor,
            UIColor(hex: "FE6900")?.cgColor ?? UIColor.orange.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5) // Слева
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5) // Справа
        gradientLayer.cornerRadius = 25
        gradientLayer.masksToBounds = true
        gradientLayer.frame = button.bounds
        
        button.layer.insertSublayer(gradientLayer, at: 0)
        
        // Обновляем frame градиента после layout
        DispatchQueue.main.async {
            gradientLayer.frame = button.bounds
        }
    }
    
    @objc private func basketButtonTapped() {
        // Переход в корзину через navigationController для кнопки "Назад"
        let basketView = BasketBuilder.build()
        if let navigationController = self.navigationController {
            // Убеждаемся, что navigation bar скрыт
            navigationController.setNavigationBarHidden(true, animated: true)
            navigationController.pushViewController(basketView, animated: true)
        } else {
            // Если нет navigationController, создаем его
            let navController = UINavigationController(rootViewController: basketView)
            navController.setNavigationBarHidden(true, animated: false)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
        }
    }
    
    @objc private func updateBasketPrice() {
        let total = CartManager.shared.getCartTotal()
        basketPriceLabel.text = String(format: "%.0f₽", total)
    }
    
    @objc private func categoryTapped(_ sender: UIButton) {
        // С UIButtonConfiguration нужно использовать configuration?.title вместо currentTitle
        let title = sender.configuration?.title ?? sender.currentTitle ?? ""
        guard !title.isEmpty else {
            return
        }
        presenter?.categorySelected(title)
    }
    
    @objc private func cartButtonTapped() {
        print("🛒 ShopView: cartButtonTapped called")
        print("🛒 ShopView: navigationController = \(String(describing: navigationController))")
        print("🛒 ShopView: presenter = \(String(describing: presenter))")
        presenter?.navigateToBasket()
    }
}

// MARK: - ShopViewProtocol
extension ShopView: ShopViewProtocol {
    func displayShopScreen() {
        // UI уже настроен в viewDidLoad()
    }
    
    func displayCategories(_ categories: [String]) {
        addCategoryButtons(categories)
    }
    
    func displaySelectedCategory(_ category: String) {
        for case let button as UIButton in categoryStackView.arrangedSubviews {
            guard var config = button.configuration else { continue }
            let isSelected = button.configuration?.title == category
            
            // Удаляем старый градиент, если есть
            removeGradientFromButton(button)
            
            // Обновляем цвета и фон через UIButtonConfiguration
            if isSelected {
                config.baseForegroundColor = .white
                config.background.backgroundColor = .clear // Прозрачный, так как градиент будет поверх
                // Применяем градиент
                applyGradientToButton(button)
            } else {
                config.baseForegroundColor = UIColor(hex: "747474") ?? .systemGray
                config.background.backgroundColor = UIColor(white: 0.95, alpha: 1)
            }
            
            button.configuration = config
        }
    }
    
    /// Применяет градиент слева направо от FF8733 до FE6900 к кнопке
    private func applyGradientToButton(_ button: UIButton) {
        // Удаляем старый градиент, если есть
        removeGradientFromButton(button)
        
        // Ждем, пока кнопка будет иметь правильные размеры
        guard button.bounds.width > 0 && button.bounds.height > 0 else {
            // Если размеры еще не установлены, применяем градиент после layout
            DispatchQueue.main.async {
                self.applyGradientToButton(button)
            }
            return
        }
        
        // Создаем градиентный слой
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "FF8733")?.cgColor ?? UIColor.orange.cgColor,
            UIColor(hex: "FE6900")?.cgColor ?? UIColor.orange.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5) // Слева
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5) // Справа
        gradientLayer.cornerRadius = 18
        gradientLayer.masksToBounds = true // Важно: обрезаем по закругленным углам
        gradientLayer.frame = button.bounds
        
        // Сохраняем ссылку на градиент для последующего удаления
        button.layer.insertSublayer(gradientLayer, at: 0)
        
        // Убеждаемся, что кнопка также имеет правильное закругление
        button.layer.cornerRadius = 18
        button.layer.masksToBounds = true
    }
    
    /// Удаляет градиентный слой с кнопки
    private func removeGradientFromButton(_ button: UIButton) {
        // Удаляем все CAGradientLayer из sublayers
        button.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
    }
    
    func displayProducts(_ products: [ProductViewModel], append: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAppendingProducts = append
            self.displayProductsGrid(products)
        }
    }
    
    func updateCartTotal(_ total: Double) {
        cartTotalLabel.text = String(format: "%.2f ₽", total)
        
        // Показываем/скрываем кнопку корзины в зависимости от наличия товаров
        cartContainerView.isHidden = total <= 0
    }
    
    func refreshProductCells() {
        // Обновляем видимые ячейки в UICollectionView
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Обновляем только видимые ячейки для производительности
            let visibleIndexPaths = self.productsCollectionView.indexPathsForVisibleItems
            for indexPath in visibleIndexPaths {
                if let cell = self.productsCollectionView.cellForItem(at: indexPath) as? ProductCollectionViewCell,
                   indexPath.item < self.products.count {
                    let product = self.products[indexPath.item]
                let quantity = CartManager.shared.getCartQuantity(for: product)
                    cell.updateQuantity(quantity)
                }
            }
        }
    }
}

// MARK: - UISearchBarDelegate
extension ShopView: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        presenter?.searchTextChanged(searchText)
    }
}

// MARK: - UICollectionViewDataSource
extension ShopView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return products.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < products.count else {
            print("❌ Index out of range: \(indexPath.item) >= \(products.count)")
            return UICollectionViewCell()
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCollectionViewCell", for: indexPath) as! ProductCollectionViewCell
        let product = products[indexPath.item]
        
        cell.configure(with: product, at: indexPath.item)
        cell.onAddToCart = { [weak self] in
            self?.presenter?.addToCart(product: product)
        }
        cell.onRemoveFromCart = { [weak self] in
            self?.presenter?.removeFromCart(product: product)
        }
        
        // Обновляем состояние кнопки в зависимости от количества в корзине
        let quantity = CartManager.shared.getCartQuantity(for: product)
        cell.updateQuantity(quantity)
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ShopView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Проверяем, достигли ли мы конца списка
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let height = scrollView.frame.size.height
        
        // Загружаем следующую страницу, когда осталось прокрутить 300 точек до конца
        if offsetY > contentHeight - height - 300 && contentHeight > 0 {
            presenter?.loadMoreProducts()
        }
    }
}

// MARK: - UICollectionViewDataSourcePrefetching
extension ShopView: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // Предзагружаем изображения для товаров, которые скоро появятся на экране
        for indexPath in indexPaths {
            guard indexPath.item < products.count else { continue }
            let product = products[indexPath.item]
            
            // Предзагружаем изображение в кэш
            if let imageURL = product.imageURL, let url = URL(string: imageURL) {
                // Используем существующий кэш изображений
                let cacheKey = imageURL as NSString
                if ShopView.imageCache.object(forKey: cacheKey) == nil {
                    // Загружаем изображение в фоне
                    URLSession.shared.dataTask(with: url) { data, _, _ in
                        guard let data = data, let image = UIImage(data: data) else { return }
                        ShopView.imageCache.setObject(image, forKey: cacheKey)
                    }.resume()
                }
            }
        }
        
        // Предзагружаем следующую страницу, если приближаемся к концу
        let maxIndex = indexPaths.map { $0.item }.max() ?? 0
        if maxIndex >= products.count - 3 {
            presenter?.loadMoreProducts()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Отменяем предзагрузку, если она больше не нужна
        // Можно добавить отмену задач загрузки изображений, если нужно
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension ShopView: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = (screenWidth - 180 * 2) / 3 // Отступы по краям и между карточками
        let cardWidth: CGFloat = 180
        let cardHeight: CGFloat = 259
        return CGSize(width: cardWidth, height: cardHeight)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = (screenWidth - 180 * 2) / 3
        return UIEdgeInsets(top: 0, left: horizontalPadding, bottom: 20, right: horizontalPadding)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let horizontalPadding: CGFloat = (screenWidth - 180 * 2) / 3
        return horizontalPadding
    }
}

final class ProductCell: UITableViewCell {
    private let productImageView = UIImageView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let addToCartButton = UIButton(type: .system)
    private let quantityStackView = UIStackView()
    private let minusButton = UIButton(type: .system)
    private let quantityLabel = UILabel()
    private let plusButton = UIButton(type: .system)
    
    var onAddToCart: (() -> Void)?
    var onRemoveFromCart: (() -> Void)?
    var onUpdateQuantity: ((Int) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        productImageView.translatesAutoresizingMaskIntoConstraints = false
        productImageView.contentMode = .scaleAspectFit
        productImageView.image = UIImage(named: "Image")
        contentView.addSubview(productImageView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.onestRegular(size: 16)
        contentView.addSubview(titleLabel)
        
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.font = UIFont.onestSemibold(size: 16)
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
        minusButton.titleLabel?.font = UIFont.onestRegular(size: 18) // Используем onestRegular для более тонкого вида
        minusButton.contentHorizontalAlignment = .center // Центрируем текст
        minusButton.contentVerticalAlignment = .center // Центрируем текст
        minusButton.addTarget(self, action: #selector(minusButtonTapped), for: .touchUpInside)
        
        quantityLabel.text = "0"
        quantityLabel.textAlignment = .center
        quantityLabel.font = UIFont.onestSemibold(size: 16)
        quantityLabel.textColor = .black
        
        plusButton.setTitle("+", for: .normal)
        plusButton.setTitleColor(.white, for: .normal)
        plusButton.backgroundColor = UIColor.primaryColor
        plusButton.layer.cornerRadius = 15
        plusButton.titleLabel?.font = UIFont.onestRegular(size: 18) // Используем onestRegular для более тонкого вида
        plusButton.contentHorizontalAlignment = .center // Центрируем текст
        plusButton.contentVerticalAlignment = .center // Центрируем текст
        plusButton.addTarget(self, action: #selector(plusButtonTapped), for: .touchUpInside)
        
        quantityStackView.addArrangedSubview(minusButton)
        quantityStackView.addArrangedSubview(quantityLabel)
        quantityStackView.addArrangedSubview(plusButton)
        
        // Add to cart button (initially visible)
        addToCartButton.setTitle("+", for: .normal)
        addToCartButton.setTitleColor(.white, for: .normal)
        addToCartButton.backgroundColor = UIColor.primaryColor
        addToCartButton.layer.cornerRadius = 15
        addToCartButton.titleLabel?.font = UIFont.onestRegular(size: 18) // Используем onestRegular для более тонкого вида
        addToCartButton.contentHorizontalAlignment = .center // Центрируем текст
        addToCartButton.contentVerticalAlignment = .center // Центрируем текст
        addToCartButton.translatesAutoresizingMaskIntoConstraints = false
        addToCartButton.addTarget(self, action: #selector(addToCartTapped), for: .touchUpInside)
        contentView.addSubview(addToCartButton)
        
        NSLayoutConstraint.activate([
            productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            productImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            productImageView.widthAnchor.constraint(equalToConstant: 48),
            productImageView.heightAnchor.constraint(equalToConstant: 48),
            
            titleLabel.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: quantityStackView.leadingAnchor, constant: -8),
            
            priceLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            priceLabel.trailingAnchor.constraint(lessThanOrEqualTo: quantityStackView.leadingAnchor, constant: -8),
            
            quantityStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            quantityStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            quantityStackView.widthAnchor.constraint(equalToConstant: 100),
            quantityStackView.heightAnchor.constraint(equalToConstant: 30),
            
            addToCartButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            addToCartButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            addToCartButton.widthAnchor.constraint(equalToConstant: 30),
            addToCartButton.heightAnchor.constraint(equalToConstant: 30),
            
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: priceLabel.bottomAnchor, constant: 12)
        ])
    }
    
    @objc private func addToCartTapped() {
        onAddToCart?()
    }
    
    @objc private func minusButtonTapped() {
        onRemoveFromCart?()
    }
    
    @objc private func plusButtonTapped() {
        onAddToCart?()
    }
    
    func configure(name: String, price: Double, imageURL: String? = nil) {
        titleLabel.text = name
        priceLabel.text = String(format: "%.2f ₽", price)
        
        if let imageURL = imageURL {
            loadImage(from: imageURL)
        } else {
            productImageView.image = UIImage(named: "Image")
        }
    }
    
    private func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else {
            print("❌ Invalid image URL: \(urlString)")
            productImageView.image = UIImage(named: "Image")
            return
        }
        
        print("🖼️ Loading image from: \(urlString)")
        
        // Показываем placeholder пока загружается
        productImageView.image = UIImage(named: "Image")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Error loading image: \(error)")
                    self?.productImageView.image = UIImage(named: "Image")
                    return
                }
                
                guard let data = data, let image = UIImage(data: data) else {
                    print("❌ Invalid image data")
                    self?.productImageView.image = UIImage(named: "Image")
                    return
                }
                
                print("✅ Image loaded successfully")
                self?.productImageView.image = image
            }
        }.resume()
    }
    
    func updateQuantity(_ quantity: Int) {
        quantityLabel.text = "\(quantity)"
        
        if quantity > 0 {
            addToCartButton.isHidden = true
            quantityStackView.isHidden = false
        } else {
            addToCartButton.isHidden = false
            quantityStackView.isHidden = true
        }
    }
}

// MARK: - ProductCollectionViewCell
final class ProductCollectionViewCell: UICollectionViewCell {
    private let cardContainer = UIView()
    private let whiteRect = UIView()
    private let productImageView = UIImageView()
    private let nameLabel = UILabel()
    private let priceLabel = UILabel()
    private let addButton = UIButton(type: .system)
    
    // Хранилище для расширенной кнопки
    private var expandedButtons: (quantityLabel: UILabel, minusButton: UIButton, plusButton: UIButton, widthConstraint: NSLayoutConstraint)?
    
    // Сохраняем ссылку на width constraint кнопки
    private var addButtonWidthConstraint: NSLayoutConstraint?
    
    var onAddToCart: (() -> Void)?
    var onRemoveFromCart: (() -> Void)?
    
    private var currentProduct: ProductViewModel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    private func setupCell() {
        // Основной контейнер карточки
        cardContainer.backgroundColor = UIColor(hex: "F3F3F3") ?? .systemGray6
        cardContainer.layer.cornerRadius = 15
        cardContainer.clipsToBounds = true
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardContainer)
        
        // Белый прямоугольник внутри
        whiteRect.backgroundColor = .white
        whiteRect.layer.cornerRadius = 15
        whiteRect.clipsToBounds = true
        whiteRect.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(whiteRect)
        
        // Картинка товара
        productImageView.contentMode = .scaleAspectFit
        productImageView.backgroundColor = .clear // Прозрачный фон для изображения
        productImageView.isOpaque = false // Позволяет прозрачность
        productImageView.clipsToBounds = true
        productImageView.translatesAutoresizingMaskIntoConstraints = false
        whiteRect.addSubview(productImageView)
        
        // Название товара
        nameLabel.font = UIFont.onestMedium(size: 12)
        nameLabel.textColor = UIColor(hex: "5F5F5F") ?? .systemGray
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(nameLabel)
        
        // Цена
        priceLabel.font = UIFont.onestMedium(size: 18)
        priceLabel.textColor = UIColor(hex: "5F5F5F") ?? .systemGray
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(priceLabel)
        
        // Кнопка добавления товара
        addButton.backgroundColor = .white
        addButton.layer.cornerRadius = 15.5
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(UIColor(hex: "5F5F5F") ?? .systemGray, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .light) // Изменено на .light для более тонкого вида
        addButton.contentHorizontalAlignment = .center // Центрируем текст
        addButton.contentVerticalAlignment = .center // Центрируем текст
        // Сдвигаем текст немного правее и выше
        addButton.titleEdgeInsets = UIEdgeInsets(top: -2, left: 1, bottom: 0, right: 0)
        addButton.contentEdgeInsets = .zero // Убираем любые отступы для содержимого
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        cardContainer.addSubview(addButton)
        
        NSLayoutConstraint.activate([
            // Card container заполняет contentView
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            // Белый прямоугольник
            whiteRect.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 5),
            whiteRect.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 5),
            whiteRect.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -5),
            whiteRect.widthAnchor.constraint(equalToConstant: 170),
            whiteRect.heightAnchor.constraint(equalToConstant: 170),
            
            // Картинка в центре белого прямоугольника
            productImageView.centerXAnchor.constraint(equalTo: whiteRect.centerXAnchor),
            productImageView.centerYAnchor.constraint(equalTo: whiteRect.centerYAnchor),
            productImageView.widthAnchor.constraint(lessThanOrEqualTo: whiteRect.widthAnchor, multiplier: 0.9),
            productImageView.heightAnchor.constraint(lessThanOrEqualTo: whiteRect.heightAnchor, multiplier: 0.9),
            
            // Название
            nameLabel.topAnchor.constraint(equalTo: whiteRect.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 5),
            nameLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -5),
            
            // Цена
            priceLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 5),
            priceLabel.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -5),
            
            // Кнопка добавления - правый край зафиксирован, левый будет двигаться при расширении
            addButton.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -5),
            addButton.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -5),
            addButton.heightAnchor.constraint(equalToConstant: 31)
        ])
        
        // Сохраняем width constraint отдельно для последующей анимации
        let widthConstraint = addButton.widthAnchor.constraint(equalToConstant: 31)
        widthConstraint.isActive = true
        addButtonWidthConstraint = widthConstraint
    }
    
    func configure(with product: ProductViewModel, at index: Int) {
        currentProduct = product
        
        nameLabel.text = product.name
        priceLabel.text = String(format: "%.0f₽", product.price)
        
        // Загружаем изображение
        if let imageURL = product.imageURL {
            loadProductImage(from: imageURL)
        } else {
            productImageView.image = UIImage(named: "Image")
        }
        
        // Проверяем состояние корзины
        let quantity = CartManager.shared.getCartQuantity(for: product)
        updateQuantity(quantity)
    }
    
    private func loadProductImage(from urlString: String) {
        let cacheKey = urlString as NSString
        
        // Убеждаемся, что фон изображения прозрачный
        productImageView.backgroundColor = .clear
        productImageView.isOpaque = false
        
        // Проверяем кэш
        if let cachedImage = ShopView.imageCache.object(forKey: cacheKey) {
            productImageView.image = cachedImage
            return
        }
        
        // Устанавливаем placeholder
        productImageView.image = UIImage(named: "Image")
        
        guard let url = URL(string: urlString) else { return }
        
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        
        ShopView.imageSession.dataTask(with: request) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }
            
            guard let data = data, let image = UIImage(data: data) else {
                return
            }
            
            ShopView.imageCache.setObject(image, forKey: cacheKey)
            
            DispatchQueue.main.async {
                // Убеждаемся, что фон изображения прозрачный перед установкой
                self.productImageView.backgroundColor = .clear
                self.productImageView.isOpaque = false
                self.productImageView.image = image
            }
        }.resume()
    }
    
    func updateQuantity(_ quantity: Int) {
        if quantity > 0 {
            if expandedButtons == nil {
                expandButton()
            }
            expandedButtons?.quantityLabel.text = "\(quantity)"
        } else {
            if expandedButtons != nil {
                collapseButton()
            }
        }
    }
    
    @objc private func addButtonTapped() {
        if let expanded = expandedButtons {
            // Уже расширена - увеличиваем количество
            onAddToCart?()
        } else {
            // Добавляем товар и расширяем кнопку
            onAddToCart?()
            expandButton()
        }
    }
    
    private func expandButton() {
        guard expandedButtons == nil else { return }
        
        // Используем сохраненный width constraint или ищем его
        var widthConstraint = addButtonWidthConstraint
        
        if widthConstraint == nil {
            // Ищем в constraints кнопки
            widthConstraint = addButton.constraints.first(where: { $0.firstAttribute == .width })
            if let constraint = widthConstraint {
                addButtonWidthConstraint = constraint
            }
        }
        
        guard let finalWidthConstraint = widthConstraint else {
            print("❌ ProductCollectionViewCell: Could not find width constraint")
            return
        }
        
        // Создаем элементы управления
        let quantityLabel = UILabel()
        quantityLabel.text = "1"
        quantityLabel.textColor = .white
        quantityLabel.font = UIFont.onestMedium(size: 16)
        quantityLabel.textAlignment = .center
        quantityLabel.translatesAutoresizingMaskIntoConstraints = false
        addButton.addSubview(quantityLabel)
        
        let minusButton = UIButton(type: .system)
        minusButton.setTitle("−", for: .normal)
        minusButton.setTitleColor(.white, for: .normal)
        minusButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .light) // Изменено на .light для более тонкого вида
        minusButton.contentHorizontalAlignment = .center // Центрируем текст
        minusButton.contentVerticalAlignment = .center // Центрируем текст
        minusButton.addTarget(self, action: #selector(decreaseQuantity), for: .touchUpInside)
        minusButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addSubview(minusButton)
        
        let plusButton = UIButton(type: .system)
        plusButton.setTitle("+", for: .normal)
        plusButton.setTitleColor(.white, for: .normal)
        plusButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .light) // Изменено на .light для более тонкого вида
        plusButton.contentHorizontalAlignment = .center // Центрируем текст
        plusButton.contentVerticalAlignment = .center // Центрируем текст
        plusButton.addTarget(self, action: #selector(increaseQuantity), for: .touchUpInside)
        plusButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.addSubview(plusButton)
        
        addButton.setTitle("", for: .normal)
        addButton.layer.cornerRadius = 15.5
        applyGradientToButton(addButton)
        
        NSLayoutConstraint.activate([
            minusButton.leadingAnchor.constraint(equalTo: addButton.leadingAnchor, constant: 8),
            minusButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            minusButton.widthAnchor.constraint(equalToConstant: 20),
            minusButton.heightAnchor.constraint(equalToConstant: 20),
            
            quantityLabel.centerXAnchor.constraint(equalTo: addButton.centerXAnchor),
            quantityLabel.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            
            plusButton.trailingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: -8),
            plusButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            plusButton.widthAnchor.constraint(equalToConstant: 20),
            plusButton.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        expandedButtons = (quantityLabel: quantityLabel, minusButton: minusButton, plusButton: plusButton, widthConstraint: finalWidthConstraint)
        
        // Анимация расширения - правый край остается на месте, левый двигается влево
        finalWidthConstraint.constant = 81
        
        // Обновляем layout на cardContainer для правильной анимации
        if let cardContainer = addButton.superview?.superview {
            cardContainer.setNeedsLayout()
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction]) {
                cardContainer.layoutIfNeeded()
                self.layoutIfNeeded()
            }
        } else {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.layoutIfNeeded()
            }
        }
    }
    
    private func collapseButton() {
        guard let expanded = expandedButtons else { return }
        
        expanded.quantityLabel.removeFromSuperview()
        expanded.minusButton.removeFromSuperview()
        expanded.plusButton.removeFromSuperview()
        
        addButton.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        addButton.backgroundColor = .white
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(UIColor(hex: "5F5F5F") ?? .systemGray, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .light) // Изменено на .light для более тонкого вида
        addButton.contentHorizontalAlignment = .center // Центрируем текст
        addButton.contentVerticalAlignment = .center // Центрируем текст
        // Сдвигаем текст немного правее и выше
        addButton.titleEdgeInsets = UIEdgeInsets(top: -2, left: 1, bottom: 0, right: 0)
        addButton.contentEdgeInsets = .zero // Убираем любые отступы для содержимого
        addButton.layer.cornerRadius = 15.5
        
        expanded.widthConstraint.constant = 31
        
        // Обновляем layout на cardContainer для правильной анимации
        if let cardContainer = addButton.superview?.superview {
            cardContainer.setNeedsLayout()
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction]) {
                cardContainer.layoutIfNeeded()
                self.layoutIfNeeded()
            }
        } else {
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseInOut, .allowUserInteraction]) {
                self.layoutIfNeeded()
            }
        }
        
        expandedButtons = nil
    }
    
    private func applyGradientToButton(_ button: UIButton) {
        button.layer.sublayers?.forEach { layer in
            if layer is CAGradientLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        button.backgroundColor = .clear
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hex: "FF8733")?.cgColor ?? UIColor.orange.cgColor,
            UIColor(hex: "FE6900")?.cgColor ?? UIColor.orange.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerRadius = 15.5
        gradientLayer.masksToBounds = true
        gradientLayer.frame = button.bounds
        
        button.layer.insertSublayer(gradientLayer, at: 0)
        button.layer.cornerRadius = 15.5
        button.layer.masksToBounds = true
        
        DispatchQueue.main.async {
            gradientLayer.frame = button.bounds
        }
    }
    
    @objc private func increaseQuantity() {
        onAddToCart?()
    }
    
    @objc private func decreaseQuantity() {
        onRemoveFromCart?()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Отменяем загрузку изображения
        productImageView.image = UIImage(named: "Image")
        
        // Сворачиваем кнопку если была расширена
        if expandedButtons != nil {
            collapseButton()
        }
        
        currentProduct = nil
    }
}
