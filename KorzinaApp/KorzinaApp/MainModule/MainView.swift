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
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setUpView()
        presenter?.viewDidLoad()
    }
    
    private func setUpView() {
        setUpHead()
        setUpLogo()
        setUpHeader()
        setUpScrollGrid()
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
    
    private func setUpHeader() {
        view.addSubview(headerView)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.pinTop(to: topView.bottomAnchor)
        headerView.pinLeft(to: view)
        headerView.pinRight(to: view)
        
        let locationButton = UIButton(type: .system)
        var pinImage = Self.resizeImage(named: "location1", to: CGSize(width: 30, height: 45))
        locationButton.setImage(pinImage, for: .normal)
        locationButton.setTitle(" Укажите адрес >", for: .normal)
        locationButton.titleLabel?.font = .systemFont(ofSize: 18)
        locationButton.tintColor = .locColor
        locationButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        headerView.addSubview(locationButton)
        locationButton.translatesAutoresizingMaskIntoConstraints = false
        locationButton.pinTop(to: headerView, 8)
        locationButton.pinLeft(to: headerView, 16)
        
        let titleLabel = UILabel()
        titleLabel.text = "Магазины"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        headerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.pinTop(to: locationButton.bottomAnchor, 8)
        titleLabel.pinLeft(to: headerView, 16)
        
        let searchBar = UISearchBar()
        searchBar.placeholder = "Поиск продуктов"
        headerView.addSubview(searchBar)
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.pinTop(to: titleLabel.bottomAnchor, 8)
        searchBar.pinLeft(to: headerView, 16)
        searchBar.pinRight(to: headerView, 16)
        
        headerView.pinBottom(to: searchBar.bottomAnchor, 8)
    }

    private func setUpScrollGrid() {
        // ScrollView setup
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.pinTop(to: headerView.bottomAnchor)
        scrollView.pinLeft(to: view)
        scrollView.pinRight(to: view)
        scrollView.pinBottom(to: view.safeAreaLayoutGuide.bottomAnchor)
        scrollView.alwaysBounceVertical = true

        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.pinTop(to: scrollView.contentLayoutGuide.topAnchor)
        contentView.pinLeft(to: scrollView.contentLayoutGuide.leadingAnchor)
        contentView.pinRight(to: scrollView.contentLayoutGuide.trailingAnchor)
        contentView.pinBottom(to: scrollView.contentLayoutGuide.bottomAnchor)
        contentView.pinWidth(to: scrollView.frameLayoutGuide.widthAnchor)
    }
    
    private func displayStoresGrid(_ stores: [StoreViewModel]) {
        let horizontalPadding: CGFloat = 4
        let verticalPadding: CGFloat = 30
        let cellSpacing: CGFloat = 4

        var previousRowBottom: NSLayoutYAxisAnchor? = contentView.topAnchor
        var cellWidthAnchor: NSLayoutDimension?

        for rowStart in stride(from: 0, to: stores.count, by: 2) {
            let leftStore = stores[rowStart]
            let leftCell = makeCell(imageName: leftStore.imageName, storeName: leftStore.storeName)
            contentView.addSubview(leftCell)
            leftCell.translatesAutoresizingMaskIntoConstraints = false
            leftCell.pinLeft(to: contentView, horizontalPadding)
            leftCell.pinTop(to: previousRowBottom!, rowStart == 0 ? verticalPadding : verticalPadding)
            leftCell.setHeight(210)

            let nextIndex = rowStart + 1
            if nextIndex < stores.count {
                let rightStore = stores[nextIndex]
                let rightCell = makeCell(imageName: rightStore.imageName, storeName: rightStore.storeName)
                contentView.addSubview(rightCell)
                rightCell.translatesAutoresizingMaskIntoConstraints = false
                rightCell.pinRight(to: contentView, horizontalPadding)
                rightCell.pinTop(to: leftCell.topAnchor)
                rightCell.setHeight(210)

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

        // Content bottom
        if let lastBottom = previousRowBottom {
            contentView.pinBottom(to: lastBottom, 16)
        }
    }

    private func makeCell(imageName: String, storeName: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        container.isUserInteractionEnabled = true

        let resizedImage = Self.resizeImage(named: imageName, to: CGSize(width: 250, height: 200))
        let imageView = UIImageView(image: resizedImage)
        imageView.contentMode = .scaleAspectFit
        container.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.pinTop(to: container)
        imageView.pinLeft(to: container, 4)
        imageView.pinRight(to: container, 4)

        let label = UILabel()
        label.text = storeName
        label.textAlignment = .center
        label.font = UIFont(name: "Montserrat-Regular", size: 20)
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.pinTop(to: imageView.bottomAnchor, -15)
        label.pinLeft(to: container, 4)
        label.pinRight(to: container, 4)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cellTapped(_:)))
        container.addGestureRecognizer(tapGesture)
        container.accessibilityLabel = storeName

        return container
    }
    
    @objc private func cellTapped(_ sender: UITapGestureRecognizer) {
        if let view = sender.view, let storeName = view.accessibilityLabel {
            presenter?.storeSelected(storeName: storeName)
        }
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
