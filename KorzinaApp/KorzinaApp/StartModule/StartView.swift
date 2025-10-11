import UIKit

protocol StartViewProtocol: AnyObject {
    func displayStartScreen()
    func animateLogo()
    func animateLogoName()
    func animateStartButton()
    func startButtonTapped()
}

class StartView: UIViewController {
    
    var presenter: StartPresenterProtocol?
    
    var logo = UIImageView()
    var logoName = UIImageView()
    var startButton = UIButton()
    var bodyView = UIView()
    
    private var topGradientLayer = CAGradientLayer()
    private var bottomGradientLayer = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        presenter?.viewDidLoad()
    }
    
    private func setUpUI() {
        view.backgroundColor = .black
        setUpBodyView()
        setUpLogo()
        setUpStartButton()
        setUpGradientLayers()
    }
    
    private func setUpLogo() {
        logo = UIImageView(image: UIImage(named: "logo"))
        logo.translatesAutoresizingMaskIntoConstraints = false
        logo.contentMode = .scaleAspectFit
        bodyView.addSubview(logo)
        // Initial state for entrance animation
        logo.alpha = 0
        logo.transform = CGAffineTransform(translationX: 0, y: 80)
        logo.pinCenterX(to: bodyView)
        logo.setWidth(280 * 1.43)
        logo.setHeight(280)
        logo.pinTop(to: bodyView.topAnchor, -20)
        
        logoName = UIImageView(image: UIImage(named: "name"))
        logoName.translatesAutoresizingMaskIntoConstraints = false
        logoName.contentMode = .scaleAspectFit
        bodyView.addSubview(logoName)
        // Initial state for entrance animation
        logoName.alpha = 0
        logoName.transform = CGAffineTransform(translationX: 0, y: 80)
        logoName.setHeight(60)
        logoName.setWidth(60 * 5.26)
        logoName.pinTop(to: logo.bottomAnchor, -70)
        logoName.pinCenterX(to: bodyView)
    }
    
    private func setUpStartButton() {
        startButton.setTitle("Начать", for: .normal)
        startButton.backgroundColor = UIColor.primaryColor
        startButton.tintColor = .black
        startButton.layer.cornerRadius = 20
        startButton.titleLabel?.font = UIFont(name : "Montserrat-Regular", size: 25)
        
        startButton.layer.shadowColor = UIColor.black.cgColor
        startButton.layer.shadowOpacity = 0.5
        startButton.layer.shadowOffset = CGSize(width: 0, height: 10)
        startButton.layer.shadowRadius = 10
        
        // Убеждаемся, что кнопка активна
        startButton.isUserInteractionEnabled = true
        startButton.isEnabled = true
        
        bodyView.addSubview(startButton)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setWidth(170 * 1.5)
        startButton.setHeight(50)
        startButton.pinTop(to: logoName.bottomAnchor, 17)
        startButton.pinCenterX(to: bodyView)
        startButton.addTarget(self, action: #selector(handleStartButton), for: .touchUpInside)
        // Initial state for entrance animation
        startButton.alpha = 0
        startButton.transform = CGAffineTransform(translationX: 0, y: 80)
    }
    
    @objc private func handleStartButton() {
        presenter?.startButtonTapped()
    }
    
    private func setUpGradientLayers() {
        view.layer.insertSublayer(topGradientLayer, at: 0)
        view.layer.insertSublayer(bottomGradientLayer, at: 0)
        updateGradientFrames()
    }

    private func setUpBodyView() {
        view.addSubview(bodyView)
        bodyView.translatesAutoresizingMaskIntoConstraints = false
        bodyView.backgroundColor = UIColor.barColor
        bodyView.pinTop(to: view, 200)
        bodyView.pinBottom(to: view, 300)
        bodyView.pinLeft(to: view)
        bodyView.pinRight(to: view)
    }

    private func updateGradientFrames() {
        let cl1 = UIColor.firstMC ?? .clear
        let cl2 = UIColor.secondMC ?? .clear
        let bar = UIColor.barColor ?? .clear
        let bodyFrame = bodyView.frame
        let bounds = view.bounds

        topGradientLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: max(bodyFrame.minY, 0))
        topGradientLayer.colors = [cl1.cgColor, bar.cgColor]
        topGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        topGradientLayer.endPoint = CGPoint(x: 0, y: 1)

        let bottomY = max(bodyFrame.maxY, 0)
        bottomGradientLayer.frame = CGRect(x: 0, y: bottomY, width: bounds.width, height: max(bounds.height - bottomY, 0))
        bottomGradientLayer.colors = [bar.cgColor, cl2.cgColor]
        bottomGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        bottomGradientLayer.endPoint = CGPoint(x: 0, y: 1)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGradientFrames()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Запускаем анимации напрямую
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.animateLogo()
            self.animateLogoName()
            self.animateStartButton()
        }
        
        
        presenter?.viewDidAppear()
    }
}

// MARK: - StartViewProtocol
extension StartView: StartViewProtocol {
    func displayStartScreen() {
        // UI уже настроен в viewDidLoad()
    }
    
    func startButtonTapped() {
        // Этот метод вызывается из presenter
        // Вызываем presenter напрямую
        presenter?.startButtonTapped()
    }
    
    func animateLogo() {
        let duration: TimeInterval = 1.0
        let damping: CGFloat = 0.9
        let velocity: CGFloat = 0.3
        
        UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: [.curveEaseOut], animations: {
            self.logo.alpha = 1
            self.logo.transform = .identity
        })
    }
    
    func animateLogoName() {
        let duration: TimeInterval = 1.0
        let damping: CGFloat = 0.9
        let velocity: CGFloat = 0.3
        
        UIView.animate(withDuration: duration, delay: 0.1, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: [.curveEaseOut], animations: {
            self.logoName.alpha = 1
            self.logoName.transform = .identity
        })
    }
    
    func animateStartButton() {
        let duration: TimeInterval = 1.0
        let damping: CGFloat = 0.9
        let velocity: CGFloat = 0.3
        
        UIView.animate(withDuration: duration, delay: 0.2, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: [.curveEaseOut], animations: {
            self.startButton.alpha = 1
            self.startButton.transform = .identity
        }, completion: { _ in
            // Убеждаемся, что кнопка активна после анимации
            self.startButton.isUserInteractionEnabled = true
            self.startButton.isEnabled = true
        })
    }
}
