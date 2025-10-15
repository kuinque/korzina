import UIKit

protocol ProfileInteractorProtocol: AnyObject {
    var presenter: ProfilePresenterProtocol? { get set }
    func viewDidLoad()
}

class ProfileInteractor: ProfileInteractorProtocol {
    weak var presenter: ProfilePresenterProtocol?
    
    func viewDidLoad() {
        presenter?.presentProfileScreen()
    }
}



