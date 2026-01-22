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
    private var logoNameLabel: UILabel?
    private var gradientView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        presenter?.viewDidLoad()
    }
    
    private func setUpUI() {
        // Устанавливаем фон - изображение из assets
        if let backgroundImage = UIImage(named: "mainscreen") {
            let backgroundImageView = UIImageView(image: backgroundImage)
            backgroundImageView.contentMode = .scaleAspectFill
            backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(backgroundImageView)
            view.sendSubviewToBack(backgroundImageView)
            
            NSLayoutConstraint.activate([
                backgroundImageView.topAnchor.constraint(equalTo: view.topAnchor),
                backgroundImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                backgroundImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                backgroundImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        } else {
            // Fallback на оранжевый цвет, если изображение не найдено
            view.backgroundColor = UIColor(hex: "#FF6C02")
        }
        
        setUpLogoName()
        // Убираем градиент, так как используем изображение
        // setUpGradient()
    }
    
    private func setUpGradient() {
        // Создаем UIView для радиального градиента
        let gradientView = UIView()
        gradientView.backgroundColor = .clear
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gradientView)
        view.sendSubviewToBack(gradientView)
        
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: view.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Начально градиент невидим (будет появляться анимированно)
        gradientView.alpha = 0
        
        self.gradientView = gradientView
        
        // Рисуем градиент
        drawRadialGradient(in: gradientView)
    }
    
    private func drawRadialGradient(in view: UIView) {
        // Создаем градиент с темными углами и светлым центром через Core Graphics
        let size = view.bounds.size
        guard size.width > 0 && size.height > 0 else { return }
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return
        }
        
        // Цвета градиента: оранжевый (#FF6C02) для фона, менее насыщенный светлый оттенок для краев
        let orangeColor = UIColor(hex: "#FF6C02") ?? UIColor(red: 1.0, green: 0.424, blue: 0.008, alpha: 1.0)
        // Используем менее насыщенный светлый оттенок для краев (не такой яркий белый)
        let lightOrangeColor = UIColor(hex: "#FF9A5C") ?? UIColor(red: 1.0, green: 0.604, blue: 0.361, alpha: 1.0)
        
        // Создаем цветовое пространство
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Создаем линейный градиент: светлый по краям, темный в центре
        // Светлый -> переход -> темный (центр) -> переход -> светлый
        let colors = [
            lightOrangeColor.cgColor,                    // Начало (светлый по краю)
            orangeColor.cgColor,                         // Переход к темному
            orangeColor.cgColor,                         // Центр (темный, основной оранжевый)
            orangeColor.cgColor,                         // Центр продолжается (темный)
            lightOrangeColor.cgColor                      // Конец (светлый по краю)
        ] as CFArray
        // Расположение: светлый по краям (0.0 и 1.0), темный в центре (0.4-0.6)
        let locations: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        // Создаем градиент
        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
            UIGraphicsEndImageContext()
            return
        }
        
        // Диагональный градиент от левого нижнего угла к правому верхнему углу
        // Это создаст светлую полосу по диагонали
        let startPoint = CGPoint(x: 0, y: 0)        // Левый нижний угол
        let endPoint = CGPoint(x: size.width, y: size.height)          // Правый верхний угол
        
        // Рисуем линейный градиент
        context.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: []
        )
        
        // Получаем изображение
        if let image = UIGraphicsGetImageFromCurrentImageContext() {
            // Удаляем предыдущие imageView
            view.subviews.forEach { if $0 is UIImageView { $0.removeFromSuperview() } }
            
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: view.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        UIGraphicsEndImageContext()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Перерисовываем градиент при изменении размера (только если он уже видим)
        if let gradientView = gradientView, gradientView.alpha > 0 && gradientView.bounds.width > 0 {
            gradientView.subviews.forEach { $0.removeFromSuperview() }
            drawRadialGradient(in: gradientView)
        }
    }
    
    private func setUpLogoName() {
        // Создаем UILabel с текстом "Корзина" вместо изображения
        let titleLabel = UILabel()
        titleLabel.text = "корзина"
        titleLabel.font = UIFont.onestSemibold(size: 48)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Initial state for entrance animation
        titleLabel.alpha = 0
        titleLabel.transform = CGAffineTransform(translationX: 0, y: 50)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Сохраняем ссылку для анимации
        logoNameLabel = titleLabel
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Запускаем анимацию названия
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.animateLogoName()
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
        // Больше не используется
    }
    
    func animateLogoName() {
        guard let label = logoNameLabel else { return }
        
        let duration: TimeInterval = 3.5
        let damping: CGFloat = 0.6
        let velocity: CGFloat = 0.15
        
        UIView.animate(withDuration: duration, delay: 0.0, usingSpringWithDamping: damping, initialSpringVelocity: velocity, options: [.curveEaseOut], animations: {
            label.alpha = 1
            label.transform = .identity
        }, completion: { _ in
            // После завершения анимации слово остается статично еще секунду, затем переходим на экран магазинов
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.presenter?.presentTabBar()
            }
        })
    }
    
    private func animateGradient() {
        guard let gradientView = gradientView else { return }
        
        // Рисуем градиент перед анимацией (с небольшой задержкой для правильного размера)
        DispatchQueue.main.async {
            self.drawRadialGradient(in: gradientView)
            
            // Анимация появления градиента
            UIView.animate(withDuration: 2.0, delay: 0.0, options: [.curveEaseInOut], animations: {
                gradientView.alpha = 1
            })
        }
    }
    
    func animateStartButton() {
        // Больше не используется - кнопка убрана
    }
}
