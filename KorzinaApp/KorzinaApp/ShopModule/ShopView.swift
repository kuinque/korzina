import UIKit

protocol ShopViewProtocol: AnyObject {
    func displayShopScreen()
    func displayCategories(_ categories: [String])
    func displaySelectedCategory(_ category: String)
    func displayProducts(_ products: [ShopPresenter.ProductViewModel])
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
    private var products: [ShopPresenter.ProductViewModel] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setUpView()
        presenter?.viewDidLoad()
    }

    private func setUpView() {
        setUpHead()
        setUpLogo()
        setUpShopLogo()
        setUpSearchBar()
        setUpCategoryScroll()
        setUpTable()
    }
    
    private func setUpShopLogo() {
        shopLogo = UIImageView(image: UIImage(named: "pyat_select"))
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
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func addCategoryButtons(_ categories: [String]) {
        for (index, title) in categories.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            button.setTitleColor(index == 0 ? .white : .black, for: .normal)
            button.backgroundColor = index == 0 ? UIColor(red: 0.89, green: 0.0, blue: 0.0, alpha: 1.0) : UIColor(white: 0.95, alpha: 1)
            button.layer.cornerRadius = 18
            button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            categoryStackView.addArrangedSubview(button)
        }
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        guard let title = sender.currentTitle else { return }
        presenter?.categorySelected(title)
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
            button.backgroundColor = isSelected ? UIColor(red: 0.89, green: 0.0, blue: 0.0, alpha: 1.0) : UIColor(white: 0.95, alpha: 1)
            button.setTitleColor(isSelected ? .white : .black, for: .normal)
        }
    }
    
    func displayProducts(_ products: [ShopPresenter.ProductViewModel]) {
        self.products = products
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
        cell.configure(name: vm.name, price: vm.price)
        return cell
    }
}

final class ProductCell: UITableViewCell {
    private let productImageView = UIImageView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    
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
        
        NSLayoutConstraint.activate([
            productImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            productImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            productImageView.widthAnchor.constraint(equalToConstant: 48),
            productImageView.heightAnchor.constraint(equalToConstant: 48),
            
            titleLabel.leadingAnchor.constraint(equalTo: productImageView.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: priceLabel.leadingAnchor, constant: -8),
            
            priceLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            priceLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            contentView.bottomAnchor.constraint(greaterThanOrEqualTo: titleLabel.bottomAnchor, constant: 12)
        ])
    }
    
    func configure(name: String, price: Double) {
        titleLabel.text = name
        priceLabel.text = String(format: "%.2f ₽", price)
    }
}
