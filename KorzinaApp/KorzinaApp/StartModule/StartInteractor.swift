import UIKit

protocol StartInteractorProtocol: AnyObject {
    var presenter: StartPresenterProtocol? { get set }
    func viewDidLoad()
    func viewDidAppear()
    func startButtonTapped()
}

class StartInteractor: StartInteractorProtocol {
    weak var presenter: StartPresenterProtocol?
    
    
    func viewDidLoad() {
        presenter?.presentStartScreen()
    }
    
    func viewDidAppear() {
        presenter?.presentAnimations()
    }
    
    func startButtonTapped() {
        presenter?.presentTabBar()
    }
}
