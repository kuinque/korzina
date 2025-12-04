import UIKit

protocol ProfileViewProtocol: AnyObject {
    func displayProfileScreen()
    func displayProfile(_ viewModel: ProfileViewModel)
    func updateAvatar(_ image: UIImage?)
}

struct ProfileViewModel {
    let fullName: String
    let phoneNumber: String
    let orders: [OrderViewModel]
    let avatarImage: UIImage?
}

struct OrderViewModel {
    let id: String
    let storeName: String
    let dateString: String
    let status: String
    let totalString: String
}

final class ProfileView: UIViewController {
    
    var presenter: ProfilePresenterProtocol?
    
    private let topView = UIView()
    private let profileContainerView = UIView() // Статичный контейнер для профиля
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let avatarImageView = UIImageView()
    private let nameLabel = UILabel()
    private let phoneLabel = UILabel()
    private let changeAvatarButton = UIButton(type: .system)
    
    private var logo = UIImageView()
    private var logoName = UIImageView()
    
    private var currentProfile: ProfileViewModel?
    private var orderViewModels: [OrderViewModel] = []
    
    private lazy var imagePicker: UIImagePickerController = {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.mediaTypes = ["public.image"]
        return picker
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setUpView()
        presenter?.viewDidLoad()
    }
    
    private func setUpView() {
        setUpHead()
        setUpLogo()
        setUpProfileContainer()
        setUpTableView()
        applyPlaceholderHeader()
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
    
    private func setUpProfileContainer() {
        view.addSubview(profileContainerView)
        profileContainerView.translatesAutoresizingMaskIntoConstraints = false
        profileContainerView.backgroundColor = .systemBackground
        profileContainerView.pinTop(to: topView.bottomAnchor)
        profileContainerView.pinLeft(to: view)
        profileContainerView.pinRight(to: view)
        
        // Настройка элементов профиля
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.layer.cornerRadius = 50
        avatarImageView.backgroundColor = UIColor.unselect?.withAlphaComponent(0.1)
        
        changeAvatarButton.translatesAutoresizingMaskIntoConstraints = false
        changeAvatarButton.setTitle("Изменить фото", for: .normal)
        changeAvatarButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        changeAvatarButton.tintColor = .primaryColor
        changeAvatarButton.addTarget(self, action: #selector(changeAvatarTapped), for: .touchUpInside)
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.textAlignment = .center
        
        phoneLabel.translatesAutoresizingMaskIntoConstraints = false
        phoneLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        phoneLabel.textColor = .secondaryLabel
        phoneLabel.textAlignment = .center
        
        profileContainerView.addSubview(avatarImageView)
        profileContainerView.addSubview(changeAvatarButton)
        profileContainerView.addSubview(nameLabel)
        profileContainerView.addSubview(phoneLabel)
        
        NSLayoutConstraint.activate([
            avatarImageView.centerXAnchor.constraint(equalTo: profileContainerView.centerXAnchor),
            avatarImageView.topAnchor.constraint(equalTo: profileContainerView.topAnchor, constant: 24),
            avatarImageView.widthAnchor.constraint(equalToConstant: 100),
            avatarImageView.heightAnchor.constraint(equalToConstant: 100),
            
            changeAvatarButton.centerXAnchor.constraint(equalTo: profileContainerView.centerXAnchor),
            changeAvatarButton.topAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 12),
            
            nameLabel.centerXAnchor.constraint(equalTo: profileContainerView.centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: changeAvatarButton.bottomAnchor, constant: 18),
            nameLabel.leadingAnchor.constraint(greaterThanOrEqualTo: profileContainerView.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: profileContainerView.trailingAnchor, constant: -16),
            
            phoneLabel.centerXAnchor.constraint(equalTo: profileContainerView.centerXAnchor),
            phoneLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            phoneLabel.leadingAnchor.constraint(greaterThanOrEqualTo: profileContainerView.leadingAnchor, constant: 16),
            phoneLabel.trailingAnchor.constraint(lessThanOrEqualTo: profileContainerView.trailingAnchor, constant: -16),
            phoneLabel.bottomAnchor.constraint(equalTo: profileContainerView.bottomAnchor, constant: -24)
        ])
    }
    
    private func setUpTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.pinTop(to: profileContainerView.bottomAnchor)
        tableView.pinLeft(to: view)
        tableView.pinRight(to: view)
        tableView.pinBottom(to: view.safeAreaLayoutGuide.bottomAnchor)
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        tableView.register(ProfileOrderCell.self, forCellReuseIdentifier: ProfileOrderCell.reuseIdentifier)
    }
    
    private func applyPlaceholderHeader() {
        let placeholder = ProfileViewModel(
            fullName: "Загрузка...",
            phoneNumber: "+7 *** *** **",
            orders: [],
            avatarImage: nil
        )
        updateHeader(with: placeholder)
    }
    
    private func updateHeader(with viewModel: ProfileViewModel) {
        // Обновляем статичные элементы профиля
        avatarImageView.image = viewModel.avatarImage ?? UIImage(systemName: "person.crop.circle")?.withTintColor(.unselect!, renderingMode: .alwaysOriginal)
        nameLabel.text = viewModel.fullName
        phoneLabel.text = viewModel.phoneNumber
    }
    
    @objc
    private func changeAvatarTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true)
    }
}

// MARK: - ProfileViewProtocol
extension ProfileView: ProfileViewProtocol {
    func displayProfileScreen() {
        // Placeholder already applied in setUpView.
    }
    
    func displayProfile(_ viewModel: ProfileViewModel) {
        currentProfile = viewModel
        orderViewModels = viewModel.orders
        updateHeader(with: viewModel)
        tableView.reloadData()
    }
    
    func updateAvatar(_ image: UIImage?) {
        let renderedImage = image ?? UIImage(systemName: "person.crop.circle")?.withTintColor(.unselect!, renderingMode: .alwaysOriginal)
        avatarImageView.image = renderedImage
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension ProfileView: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        orderViewModels.isEmpty ? 1 : orderViewModels.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        orderViewModels.isEmpty ? nil : "История заказов"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if orderViewModels.isEmpty {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "PlaceholderCell")
            cell.textLabel?.text = "Заказов пока нет"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = .secondaryLabel
            cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            return cell
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ProfileOrderCell.reuseIdentifier, for: indexPath) as? ProfileOrderCell else {
            return UITableViewCell()
        }
        let item = orderViewModels[indexPath.row]
        cell.configure(with: item)
        return cell
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ProfileView: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        guard let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage else { return }
        updateAvatar(image)
        presenter?.avatarUpdated(with: image)
    }
}

// MARK: - ProfileOrderCell
final class ProfileOrderCell: UITableViewCell {
    static let reuseIdentifier = "ProfileOrderCell"
    
    private let container = UIView()
    private let orderIdLabel = UILabel()
    private let storeLabel = UILabel()
    private let dateLabel = UILabel()
    private let totalLabel = UILabel()
    private let statusBadge = UILabel()
    private var statusBadgeWidthConstraint: NSLayoutConstraint?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }
    
    private func setUpViews() {
        selectionStyle = .none
        backgroundColor = .clear
        
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .secondarySystemBackground
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        
        contentView.addSubview(container)
        container.pinTop(to: contentView, 8)
        container.pinBottom(to: contentView, 8)
        container.pinLeft(to: contentView, 16)
        container.pinRight(to: contentView, 16)
        
        orderIdLabel.translatesAutoresizingMaskIntoConstraints = false
        orderIdLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        orderIdLabel.textColor = .secondaryLabel
        
        storeLabel.translatesAutoresizingMaskIntoConstraints = false
        storeLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        storeLabel.textColor = .label
        
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        dateLabel.textColor = .secondaryLabel
        
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        totalLabel.textColor = .primaryColor
        
        statusBadge.translatesAutoresizingMaskIntoConstraints = false
        statusBadge.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        statusBadge.textColor = .white
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 10
        statusBadge.layer.masksToBounds = true
        
        container.addSubview(orderIdLabel)
        container.addSubview(storeLabel)
        container.addSubview(dateLabel)
        container.addSubview(totalLabel)
        container.addSubview(statusBadge)
        
        orderIdLabel.pinTop(to: container, 12)
        orderIdLabel.pinLeft(to: container, 12)
        
        statusBadge.pinCenterY(to: orderIdLabel)
        statusBadge.pinRight(to: container, 12)
        statusBadge.setHeight(20)
        statusBadgeWidthConstraint = statusBadge.widthAnchor.constraint(equalToConstant: 80)
        statusBadgeWidthConstraint?.isActive = true
        
        storeLabel.pinTop(to: orderIdLabel.bottomAnchor, 8)
        storeLabel.pinLeft(to: container, 12)
        storeLabel.pinRight(to: container, 12)
        
        dateLabel.pinTop(to: storeLabel.bottomAnchor, 6)
        dateLabel.pinLeft(to: container, 12)
        dateLabel.pinBottom(to: container, 12)
        
        totalLabel.pinCenterY(to: dateLabel)
        totalLabel.pinRight(to: container, 12)
    }
    
    func configure(with viewModel: OrderViewModel) {
        orderIdLabel.text = "#\(viewModel.id)"
        storeLabel.text = viewModel.storeName
        dateLabel.text = viewModel.dateString
        totalLabel.text = viewModel.totalString
        
        statusBadge.text = viewModel.status.uppercased()
        switch viewModel.status.lowercased() {
        case "доставлен":
            statusBadge.backgroundColor = UIColor.primaryColor
        case "отменен":
            statusBadge.backgroundColor = UIColor.systemRed
        default:
            statusBadge.backgroundColor = UIColor.systemOrange
        }
        let badgeWidth = max(statusBadge.intrinsicContentSize.width + 16, 60)
        statusBadgeWidthConstraint?.constant = badgeWidth
    }
}
