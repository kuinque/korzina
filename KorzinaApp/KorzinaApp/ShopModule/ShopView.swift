import UIKit

protocol ShopViewProtocol: AnyObject {
    func displayShopScreen()
    func displayCategories(_ categories: [String])
    func displaySelectedCategory(_ category: String)
    func displayProducts(_ products: [ProductViewModel])
    func updateCartTotal(_ total: Double)
    func refreshProductCells()
    func setShopHeader(for shopName: String)
}

class ShopView: UIViewController {
    
    var presenter: ShopPresenterProtocol?
    
    private let topView = UIView()
    var logo = UIImageView()
    var logoName = UIImageView()
    var shopLogo = UIImageView()

    private let searchBar = UISearchBar()
    private let categoryScrollView = UIScrollView()
    private let categoryStackView = UIStackView()
    private let tableView = UITableView()
    private var products: [ProductViewModel] = []
    
    // Cart elements
    private let cartContainerView = UIView()
    private let cartTotalLabel = UILabel()
    private let cartButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setUpView()
        presenter?.viewDidLoad()
        
        // Слушаем изменения корзины
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cartDidChange),
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
        tableView.reloadData()
    }

    private func setUpView() {
        setUpHead()
        setUpLogo()
        setUpShopLogo()
        setUpSearchBar()
        setUpCategoryScroll()
        setUpCart()
        setUpTable()
    }
    
    private func setUpShopLogo() {
        shopLogo = UIImageView(image: UIImage(named: "pyat_select")) // По умолчанию
        shopLogo.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shopLogo)

        shopLogo.pinLeft(to: view)
        shopLogo.pinRight(to: view)
        shopLogo.pinTop(to: topView.bottomAnchor)
        shopLogo.setHeight(80)
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
        print("ShopView: Setting header for shop: \(shopName)")
        
        // Устанавливаем изображение магазина в зависимости от магазина
        var shopImageName: String?
        switch shopName {
        case "Пятёрочка":
            shopImageName = "pyat_select"
        case "Лента":
            shopImageName = "lenta_line"
        case "Ашан":
            shopImageName = "ashan_line"
        case "Магнит":
            shopImageName = "magnit_line"
        case "Перекрёсток":
            shopImageName = "perek_line"
        default:
            shopImageName = "pyat_select" // По умолчанию
        }
        
        if let imageName = shopImageName {
            let image = UIImage(named: imageName)
            print("ShopView: \(imageName) image: \(image != nil ? "found" : "not found")")
            
            if let image = image {
                shopLogo.image = image
            }
        }
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

    private func setUpSearchBar() {
        searchBar.placeholder = "Поиск продуктов"
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .clear
        searchBar.searchTextField.backgroundColor = UIColor(white: 0.95, alpha: 1)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.delegate = self
        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: shopLogo.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12)
        ])
    }

    private func setUpCategoryScroll() {
        categoryScrollView.showsHorizontalScrollIndicator = false
        categoryScrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(categoryScrollView)

        NSLayoutConstraint.activate([
            categoryScrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 12),
            categoryScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryScrollView.heightAnchor.constraint(equalToConstant: 40)
        ])

        categoryStackView.axis = .horizontal
        categoryStackView.spacing = 8
        categoryStackView.alignment = .fill
        categoryStackView.distribution = .fill
        categoryStackView.translatesAutoresizingMaskIntoConstraints = false

        categoryScrollView.addSubview(categoryStackView)

        NSLayoutConstraint.activate([
            categoryStackView.topAnchor.constraint(equalTo: categoryScrollView.topAnchor),
            categoryStackView.bottomAnchor.constraint(equalTo: categoryScrollView.bottomAnchor),
            categoryStackView.leadingAnchor.constraint(equalTo: categoryScrollView.leadingAnchor, constant: 12),
            categoryStackView.trailingAnchor.constraint(equalTo: categoryScrollView.trailingAnchor, constant: -12),
            categoryStackView.heightAnchor.constraint(equalTo: categoryScrollView.heightAnchor)
        ])
    }

    private func setUpTable() {
        tableView.dataSource = self
        tableView.delegate = self
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
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            button.setTitleColor(index == 0 ? .white : .black, for: .normal)
            button.backgroundColor = index == 0 ? UIColor.primaryColor : UIColor(white: 0.95, alpha: 1)
            button.layer.cornerRadius = 18
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryStackView.addArrangedSubview(button)
        }
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
        
        // Cart button
        cartButton.setTitle("В корзину", for: .normal)
        cartButton.setTitleColor(.white, for: .normal)
        cartButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cartButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        cartButton.layer.cornerRadius = 20
        cartButton.translatesAutoresizingMaskIntoConstraints = false
        cartButton.addTarget(self, action: #selector(cartButtonTapped), for: .touchUpInside)
        cartContainerView.addSubview(cartButton)
        
        // Изначально скрываем кнопку корзины, если корзина пуста
        cartContainerView.isHidden = true
        
        NSLayoutConstraint.activate([
            cartContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cartContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cartContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            cartContainerView.heightAnchor.constraint(equalToConstant: 50),
            
            cartTotalLabel.leadingAnchor.constraint(equalTo: cartContainerView.leadingAnchor, constant: 20),
            cartTotalLabel.centerYAnchor.constraint(equalTo: cartContainerView.centerYAnchor),
            
            cartButton.trailingAnchor.constraint(equalTo: cartContainerView.trailingAnchor, constant: -20),
            cartButton.centerYAnchor.constraint(equalTo: cartContainerView.centerYAnchor),
            cartButton.widthAnchor.constraint(equalToConstant: 100),
            cartButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func categoryTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        presenter?.categorySelected(title)
    }
    
    @objc private func cartButtonTapped() {
        presenter?.navigateToBasket()
        
        // Альтернативная навигация напрямую
        if let tabBarController = self.tabBarController {
            tabBarController.selectedIndex = 1
        }
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
            let isSelected = button.currentTitle == category
            button.backgroundColor = isSelected ? UIColor.primaryColor : UIColor(white: 0.95, alpha: 1)
            button.setTitleColor(isSelected ? .white : .black, for: .normal)
        }
    }
    
    func displayProducts(_ products: [ProductViewModel]) {
        print("📱 ShopView: Displaying \(products.count) products")
        self.products = products
        tableView.reloadData()
        print("📱 ShopView: Table view reloaded")
    }
    
    func updateCartTotal(_ total: Double) {
        cartTotalLabel.text = String(format: "%.2f ₽", total)
        
        // Показываем/скрываем кнопку корзины в зависимости от наличия товаров
        cartContainerView.isHidden = total <= 0
    }
    
    func refreshProductCells() {
        tableView.reloadData()
    }
}

// MARK: - UISearchBarDelegate
extension ShopView: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        presenter?.searchTextChanged(searchText)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension ShopView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath) as! ProductCell
        let vm = products[indexPath.row]
        cell.configure(name: vm.name, price: vm.price, imageURL: vm.imageURL)
        
        // Update quantity display
        let quantity = presenter?.getCartQuantity(for: vm) ?? 0
        cell.updateQuantity(quantity)
        
        cell.onAddToCart = { [weak self] in
            self?.presenter?.addToCart(product: vm)
        }
        
        cell.onRemoveFromCart = { [weak self] in
            self?.presenter?.removeFromCart(product: vm)
        }
        
        return cell
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
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        contentView.addSubview(titleLabel)
        
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
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
        
        quantityLabel.text = "0"
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
        
        // Add to cart button (initially visible)
        addToCartButton.setTitle("+", for: .normal)
        addToCartButton.setTitleColor(.white, for: .normal)
        addToCartButton.backgroundColor = UIColor.primaryColor
        addToCartButton.layer.cornerRadius = 15
        addToCartButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
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
