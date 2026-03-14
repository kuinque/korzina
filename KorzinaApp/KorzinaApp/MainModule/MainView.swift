import UIKit

protocol MainViewProtocol: AnyObject {
    func displayMainScreen()
    func displayStores(_ stores: [StoreViewModel])
}

struct StoreViewModel {
    let imageName: String
    let storeName: String
}

class MainView: UIViewController {
    
    var presenter: MainPresenterProtocol?
    
    private let topView = UIView()
    var logo = UIImageView()
    var logoName = UIImageView()
    private let headerView = UIView()
    private let locationButton = UIButton(type: .system)
    private let addressLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let searchBar = UISearchBar()
    private let basketPriceLabel = UILabel()
    private var basketButton: UIButton?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        // Скрываем navigation bar на главном экране, чтобы заголовок был на правильной позиции
        // Кнопка "Назад" будет на других экранах
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        setUpView()
        loadSavedAddress()
        presenter?.viewDidLoad()
        setupCartObserver()
        updateBasketPrice()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Убеждаемся, что navigation bar скрыт при возврате на этот экран
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Применяем цвет фона F2F2F2 ТОЛЬКО к textField внутри searchBar
        let backgroundColor = UIColor(red: 242/255.0, green: 242/255.0, blue: 242/255.0, alpha: 1.0)
        
        // Убеждаемся, что сам searchBar прозрачный
        searchBar.backgroundColor = .clear
        searchBar.barTintColor = .clear
        
        // Применяем ТОЛЬКО к textField, не к другим элементам
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.backgroundColor = backgroundColor
            textField.borderStyle = .none
            // Также применяем к прямому родителю textField (контейнеру)
            if let container = textField.superview {
                container.backgroundColor = .clear
            }
        }
        
        // Применяем закругление к карточкам магазинов
        applyCornerRadiusToStoreCells()
        
        // Обновляем frame градиента на кнопке корзины
        if let basketButton = basketButton {
            // Убеждаемся, что кнопка корзины всегда поверх всех элементов
            view.bringSubviewToFront(basketButton)
            
            if let gradientLayer = basketButton.layer.sublayers?.first(where: { $0 is CAGradientLayer }) as? CAGradientLayer {
                gradientLayer.frame = basketButton.bounds
            }
        }
    }
    
    /// Применяет corner radius к одной карточке
    private func applyCornerRadiusToCell(_ cell: UIView) {
        // Ничего не делаем - закругление применяется к backgroundView внутри ячейки
        // Контейнер остается без обрезки, чтобы текст не обрезался
    }
    
    /// Применяет mixed corner radius ко всем карточкам магазинов
    private func applyCornerRadiusToStoreCells() {
        // Ищем все view с tag 999 (карточки магазинов) в contentView
        func findStoreCells(in view: UIView) -> [UIView] {
            var cells: [UIView] = []
            // Ищем view с tag 999
            if view.tag == 999 {
                cells.append(view)
            }
            for subview in view.subviews {
                cells.append(contentsOf: findStoreCells(in: subview))
            }
            return cells
        }
        
        // Сначала делаем layout для всего contentView
        contentView.layoutIfNeeded()
        
        let cells = findStoreCells(in: contentView)
        for cell in cells {
            // Применяем маску только если размеры больше 0
            if cell.bounds.width > 0 && cell.bounds.height > 0 {
                applyCornerRadiusToCell(cell)
            }
        }
    }
    
    
    
    private func loadSavedAddress() {
        if let savedAddress = UserDefaults.standard.string(forKey: "savedAddress"), !savedAddress.isEmpty {
            setAddressText(savedAddress)
        } else {
            setAddressText("Укажите адрес")
        }
    }
    
    /// Устанавливает текст адреса с серой галочкой вниз в конце
    private func setAddressText(_ text: String) {
        let grayColor = UIColor(hex: "858585") ?? .systemGray
        
        // Создаем атрибутированную строку
        let attributedString = NSMutableAttributedString(string: text)
        attributedString.addAttribute(.foregroundColor, value: grayColor, range: NSRange(location: 0, length: text.count))
        attributedString.addAttribute(.font, value: UIFont.onestRegular(size: 16), range: NSRange(location: 0, length: text.count))
        
        // Добавляем расстояние 1.5 пробела перед галочкой
        let font = UIFont.onestRegular(size: 16)
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
        
        // Задаем конкретные размеры галочки: ширина 3.5, длина (высота) 8
        let checkSize = CGSize(width: 10, height: 6)
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
    
    private func setUpView() {
        setUpHeader()
        setUpScrollGrid()
        setUpBasketButton()
    }
    
    private func setUpBasketButton() {
        let basketButton = UIButton(type: .system)
        self.basketButton = basketButton
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
        view.addSubview(basketButton)
        
        NSLayoutConstraint.activate([
            basketButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            basketButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -34),
            basketButton.widthAnchor.constraint(equalToConstant: 242),
            basketButton.heightAnchor.constraint(equalToConstant: 53)
        ])
        
        // Убеждаемся, что кнопка корзины всегда поверх всех элементов (включая scrollView)
        view.bringSubviewToFront(basketButton)
        
        // Добавляем действие при нажатии
        basketButton.addTarget(self, action: #selector(basketButtonTapped), for: .touchUpInside)
        
        // Применяем градиент после того, как кнопка добавлена в view
        DispatchQueue.main.async {
            self.applyGradientToBasketButton(basketButton)
        }
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
    
    private func setupCartObserver() {
        // Слушаем изменения корзины
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBasketPrice),
            name: CartManager.cartDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func updateBasketPrice() {
        let total = CartManager.shared.getCartTotal()
        basketPriceLabel.text = String(format: "%.0f₽", total)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setUpHeader() {
        if headerView.superview == nil {
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        headerView.pinLeft(to: view)
        headerView.pinRight(to: view)
        }
        
        // Тайтл магазины
        let titleLabel = UILabel()
        titleLabel.text = "Магазины"
        titleLabel.font = UIFont.onestMedium(size: 30)
        titleLabel.textColor = .black
        view.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4).isActive = true
        titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 21).isActive = true
        
        // Кнопка меню в правом верхнем углу
        let menuButton = UIButton(type: .system)
        menuButton.setImage(createMenuIcon(), for: .normal)
        menuButton.tintColor = .black
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuButton)
        NSLayoutConstraint.activate([
            menuButton.topAnchor.constraint(equalTo: titleLabel.topAnchor),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            menuButton.widthAnchor.constraint(equalToConstant: DesignTokens.Sizes.Button.height),
            menuButton.heightAnchor.constraint(equalToConstant: DesignTokens.Sizes.Button.height)
        ])
        
        // Адрес под "Магазины" (серый цвет)
        setAddressText("Укажите адрес")
        addressLabel.isUserInteractionEnabled = true
        view.addSubview(addressLabel) // Добавляем в view, чтобы был общий предок с titleLabel
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        addressLabel.topAnchor.constraint(equalTo: titleLabel.lastBaselineAnchor, constant: 8.5).isActive = true
        addressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 23).isActive = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(locationButtonTapped))
        addressLabel.addGestureRecognizer(tapGesture)
        
        setUpCustomSearchBar()
        
        // Устанавливаем нижнюю границу headerView по searchBar
        headerView.pinBottom(to: searchBar.bottomAnchor, DesignTokens.Spacing.sm)
    }

    private func setUpScrollGrid() {
        // ScrollView setup
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.pinTop(to: searchBar.bottomAnchor, 15)
        scrollView.pinLeft(to: view)
        scrollView.pinRight(to: view)
        // ScrollView идет до самого низа экрана
        scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        
        // Добавляем contentInset снизу, чтобы контент не закрывался кнопкой корзины
        // (высота кнопки 53 + отступ от низа 34 + зазор 10 = 97)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 97, right: 0)
        scrollView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 97, right: 0)

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.pinTop(to: scrollView.contentLayoutGuide.topAnchor)
        contentView.pinLeft(to: scrollView.contentLayoutGuide.leadingAnchor)
        contentView.pinRight(to: scrollView.contentLayoutGuide.trailingAnchor)
        contentView.pinBottom(to: scrollView.contentLayoutGuide.bottomAnchor)
        contentView.pinWidth(to: scrollView.frameLayoutGuide.widthAnchor)
    }
    
    private func displayStoresGrid(_ stores: [StoreViewModel]) {
        let horizontalPadding: CGFloat = 25 // Отступ от краев экрана до карточек магазинов
        let verticalPadding = -5.0
        let cellSpacing: CGFloat = 20 // Расстояние между карточками в одной линии

        var previousRowBottom: NSLayoutYAxisAnchor? = contentView.topAnchor
        var cellWidthAnchor: NSLayoutDimension?

        for rowStart in stride(from: 0, to: stores.count, by: 2) {
            let leftStore = stores[rowStart]
            let leftCell = makeCell(imageName: leftStore.imageName, storeName: leftStore.storeName)
            contentView.addSubview(leftCell)
            leftCell.translatesAutoresizingMaskIntoConstraints = false
            leftCell.pinLeft(to: contentView, horizontalPadding)
            leftCell.pinTop(to: previousRowBottom!, rowStart == 0 ? verticalPadding : verticalPadding)
            leftCell.setHeight(DesignTokens.Sizes.StoreCell.height)

            let nextIndex = rowStart + 1
            if nextIndex < stores.count {
                let rightStore = stores[nextIndex]
                let rightCell = makeCell(imageName: rightStore.imageName, storeName: rightStore.storeName)
                contentView.addSubview(rightCell)
                rightCell.translatesAutoresizingMaskIntoConstraints = false
                rightCell.pinRight(to: contentView, horizontalPadding)
                rightCell.pinTop(to: leftCell.topAnchor)
                rightCell.setHeight(DesignTokens.Sizes.StoreCell.height)

                leftCell.pinRight(to: rightCell.leadingAnchor, cellSpacing)
                leftCell.pinWidth(to: rightCell.widthAnchor)

                if cellWidthAnchor == nil {
                    cellWidthAnchor = leftCell.widthAnchor
                }

                previousRowBottom = leftCell.bottomAnchor
            } else {
                if let widthAnchor = cellWidthAnchor {
                    leftCell.pinWidth(to: widthAnchor)
                }
                previousRowBottom = leftCell.bottomAnchor
            }
        }

        // Content bottom - небольшой отступ снизу (contentInset scrollView позаботится о видимости)
        if let lastBottom = previousRowBottom {
            contentView.pinBottom(to: lastBottom, DesignTokens.Spacing.lg)
        }
    }

    private func makeCell(imageName: String, storeName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear // Прозрачный фон для контейнера
        container.isUserInteractionEnabled = true
        container.tag = 999 // Маркер для применения маски
        
        // Создаем подложку с белым фоном и закруглением
        let backgroundView = UIView()
        backgroundView.backgroundColor = .white
        backgroundView.layer.cornerRadius = 20
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.layer.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(backgroundView)
        container.sendSubviewToBack(backgroundView)
        
        // Цветной прямоугольник для логотипа
        let coloredView = UIView()
        coloredView.backgroundColor = getShopColor(for: storeName)
        coloredView.layer.cornerRadius = DesignTokens.Sizes.StoreCell.logoCornerRadius
        coloredView.layer.masksToBounds = true // Обрезаем содержимое по границам
        coloredView.clipsToBounds = true // Дополнительная гарантия
        coloredView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(coloredView)
        
        // Логотип из ShopLogos
        let logoImageName = getShopLogoName(for: storeName)
        // Загружаем изображение с правильным масштабом для Retina дисплеев
        let logoImage = UIImage(named: logoImageName)?.withRenderingMode(.alwaysOriginal)
        let logoImageView = UIImageView(image: logoImage)
        logoImageView.contentMode = .scaleAspectFit
        // Улучшаем качество рендеринга
        logoImageView.layer.minificationFilter = .trilinear
        logoImageView.layer.magnificationFilter = .trilinear
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        coloredView.addSubview(logoImageView)
        
        // Размер логотипа (меньше для Перекрёстка, Дикси и Азбуки Вкуса)
        let logoMultiplier: CGFloat = {
            switch storeName {
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
            case "Магнит","Азбука Вкуса":
                return 0.8
            default:
                return 0.9
            }
        }()
        
        // Название магазина
        let label = UILabel()
        label.text = storeName
        label.textAlignment = .left
        label.font = UIFont.onestRegular(size: 16)
        label.textColor = .black
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Белая подложка с закруглением - заполняет карточку от верха до низа coloredView
            backgroundView.topAnchor.constraint(equalTo: container.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: coloredView.bottomAnchor, constant: 4),
            
            // Цветной прямоугольник (сильно уменьшенная ширина - квадратный)
            coloredView.topAnchor.constraint(equalTo: container.topAnchor, constant: DesignTokens.Spacing.sm),
            coloredView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            coloredView.widthAnchor.constraint(equalToConstant: DesignTokens.Sizes.StoreCell.logoContainerWidth),
            coloredView.heightAnchor.constraint(equalToConstant: DesignTokens.Sizes.StoreCell.logoContainerHeight),
            
            // Логотип внутри прямоугольника (размер зависит от магазина)
            logoImageView.centerXAnchor.constraint(equalTo: coloredView.centerXAnchor),
            // Для Азбуки Вкуса и Метро немного опускаем логотип вниз
            logoImageView.centerYAnchor.constraint(equalTo: coloredView.centerYAnchor, constant: (storeName == "Азбука Вкуса" || storeName == "Метро") ? 4 : 0),
            logoImageView.widthAnchor.constraint(equalTo: coloredView.widthAnchor, multiplier: logoMultiplier),
            logoImageView.heightAnchor.constraint(equalTo: coloredView.heightAnchor, multiplier: logoMultiplier),
            
            // Название магазина (выровнено по левому краю прямоугольника)
            label.topAnchor.constraint(equalTo: coloredView.bottomAnchor, constant: DesignTokens.Spacing.xs),
            label.leadingAnchor.constraint(equalTo: coloredView.leadingAnchor, constant: 2.0),
            label.trailingAnchor.constraint(equalTo: coloredView.trailingAnchor)
            
        ])
        
        // Овал с размытием для времени доставки в левой нижней части
        let deliveryTimeView = UIView()
        deliveryTimeView.backgroundColor = .clear
        deliveryTimeView.layer.cornerRadius = 8
        deliveryTimeView.clipsToBounds = true
        deliveryTimeView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(deliveryTimeView)
        
        // Эффект размытия фона (более светлый)
        let blurEffect = UIBlurEffect(style: .light)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.translatesAutoresizingMaskIntoConstraints = false
        deliveryTimeView.addSubview(blurEffectView)
        
        // Полупрозрачный светлый фон для лучшей видимости (баланс между светлым и прозрачным)
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.gray.withAlphaComponent(0.2)
        overlayView.layer.cornerRadius = 8
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        deliveryTimeView.addSubview(overlayView)
        
        // Текст времени доставки
        let deliveryTimeLabel = UILabel()
        deliveryTimeLabel.text = getDeliveryTime(for: storeName)
        deliveryTimeLabel.font = UIFont.onestMedium(size: 12)
        deliveryTimeLabel.textColor = .white
        deliveryTimeLabel.textAlignment = .center
        deliveryTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        deliveryTimeView.addSubview(deliveryTimeLabel)
        
        NSLayoutConstraint.activate([
            // Овал с размытием - отступы от видимых краев карточки (coloredView)
            deliveryTimeView.leadingAnchor.constraint(equalTo: coloredView.leadingAnchor, constant: 9),
            deliveryTimeView.bottomAnchor.constraint(equalTo: coloredView.bottomAnchor, constant: -9),
            deliveryTimeView.heightAnchor.constraint(equalToConstant: 16),
            
            // Текст времени доставки (ширина определяется содержимым)
            deliveryTimeLabel.topAnchor.constraint(equalTo: deliveryTimeView.topAnchor, constant: 2),
            deliveryTimeLabel.leadingAnchor.constraint(equalTo: deliveryTimeView.leadingAnchor, constant: 8),
            deliveryTimeLabel.trailingAnchor.constraint(equalTo: deliveryTimeView.trailingAnchor, constant: -8),
            deliveryTimeLabel.bottomAnchor.constraint(equalTo: deliveryTimeView.bottomAnchor, constant: -2),
            
            // Blur effect view заполняет весь deliveryTimeView
            blurEffectView.topAnchor.constraint(equalTo: deliveryTimeView.topAnchor),
            blurEffectView.leadingAnchor.constraint(equalTo: deliveryTimeView.leadingAnchor),
            blurEffectView.trailingAnchor.constraint(equalTo: deliveryTimeView.trailingAnchor),
            blurEffectView.bottomAnchor.constraint(equalTo: deliveryTimeView.bottomAnchor),
            
            // Overlay view заполняет весь deliveryTimeView
            overlayView.topAnchor.constraint(equalTo: deliveryTimeView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: deliveryTimeView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: deliveryTimeView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: deliveryTimeView.bottomAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.accessibilityLabel = storeName

        return container
    }
    
    /// Возвращает время доставки для магазина
    private func getDeliveryTime(for storeName: String) -> String {
        switch storeName {
        case "Пятёрочка":
            return "25-35 мин"
        case "Перекрёсток":
            return "35-45 мин"
        case "Лента":
            return "2-3 часа"
        case "Магнит":
            return "30-40 мин"
        case "Ашан":
            return "1-2 часа"
        case "Дикси":
            return "40-60 мин"
        case "Азбука Вкуса":
            return "25-35 мин"
        case "Метро":
            return "1-2 часа"
        default:
            return "30-40мин"
        }
    }
    
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
    
    @objc private func cellTapped(_ sender: UITapGestureRecognizer) {
        if let view = sender.view, let storeName = view.accessibilityLabel {
            presenter?.storeSelected(storeName: storeName)
        }
    }
    
    @objc private func locationButtonTapped() {
        let addressPickerVC = AddressPickerViewController()
        addressPickerVC.onAddressSelected = { [weak self] address in
            // Сохраняем адрес
            UserDefaults.standard.set(address, forKey: "savedAddress")
            // Обновляем текст адреса с галочкой
            self?.setAddressText(address)
        }
        let navController = UINavigationController(rootViewController: addressPickerVC)
        present(navController, animated: true)
    }
    
    private static func resizeImage(named: String, to size: CGSize) -> UIImage? {
        guard let image = UIImage(named: named) else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered
    }
    
    
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
    

    private func applyMixedCornerRadius(to view: UIView, topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat) {
        // Ждем пока view будет иметь размеры
        DispatchQueue.main.async {
            let path = UIBezierPath()
            let bounds = view.bounds
            
            // Начинаем с левого верхнего угла
            path.move(to: CGPoint(x: topLeft, y: 0))
            
            // Верхняя грань до правого верхнего угла
            path.addLine(to: CGPoint(x: bounds.width - topRight, y: 0))
            // Правый верхний угол
            path.addArc(withCenter: CGPoint(x: bounds.width - topRight, y: topRight),
                       radius: topRight,
                       startAngle: -CGFloat.pi / 2,
                       endAngle: 0,
                       clockwise: true)
            
            // Правая грань до правого нижнего угла
            path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - bottomRight))
            // Правый нижний угол
            path.addArc(withCenter: CGPoint(x: bounds.width - bottomRight, y: bounds.height - bottomRight),
                       radius: bottomRight,
                       startAngle: 0,
                       endAngle: CGFloat.pi / 2,
                       clockwise: true)
            
            // Нижняя грань до левого нижнего угла
            path.addLine(to: CGPoint(x: bottomLeft, y: bounds.height))
            // Левый нижний угол
            path.addArc(withCenter: CGPoint(x: bottomLeft, y: bounds.height - bottomLeft),
                       radius: bottomLeft,
                       startAngle: CGFloat.pi / 2,
                       endAngle: CGFloat.pi,
                       clockwise: true)
            
            // Левая грань до левого верхнего угла
            path.addLine(to: CGPoint(x: 0, y: topLeft))
            // Левый верхний угол
            path.addArc(withCenter: CGPoint(x: topLeft, y: topLeft),
                       radius: topLeft,
                       startAngle: CGFloat.pi,
                       endAngle: -CGFloat.pi / 2,
                       clockwise: true)
            
            path.close()
            
            // Применяем маску
            let maskLayer = CAShapeLayer()
            maskLayer.path = path.cgPath
            view.layer.mask = maskLayer
        }
    }
    
    /// Настраивает кастомный searchBar согласно дизайну
    private func setUpCustomSearchBar() {
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
        searchBar.pinTop(to: addressLabel.bottomAnchor, DesignTokens.Spacing.searchBarTop)
        // Растягиваем searchBar с отступами от краев экрана
        NSLayoutConstraint.activate([
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 23),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -23),
            searchBar.heightAnchor.constraint(equalToConstant: 40)
        ])
        // Делаем сам searchBar прозрачным, чтобы был виден только textField
        searchBar.backgroundColor = .clear
        searchBar.barTintColor = .clear
        
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
            textField.textAlignment = .center
            // Убираем стандартную иконку лупы слева
            textField.leftView = nil
            textField.leftViewMode = .never
            // Убираем border
            textField.borderStyle = .none
            
            // Создаем кастомный центрированный placeholder с иконкой
            let placeholderContainer = UIView()
            placeholderContainer.isUserInteractionEnabled = false
            
            let iconImageView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
            iconImageView.tintColor = UIColor(hex: "939393")
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            
            let placeholderLabel = UILabel()
            placeholderLabel.text = "Поиск"
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
            NSLayoutConstraint.activate([
                placeholderContainer.centerXAnchor.constraint(equalTo: searchBar.centerXAnchor),
                placeholderContainer.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor)
            ])
            
            // Скрываем placeholder когда начинается ввод
            NotificationCenter.default.addObserver(forName: UITextField.textDidChangeNotification, object: textField, queue: .main) { _ in
                placeholderContainer.isHidden = !(textField.text?.isEmpty ?? true)
            }
        }
    }
    
}

// MARK: - MainViewProtocol
extension MainView: MainViewProtocol {
    func displayMainScreen() {
        // UI уже настроен в viewDidLoad()
    }
    
    func displayStores(_ stores: [StoreViewModel]) {
        displayStoresGrid(stores)
    }
}
