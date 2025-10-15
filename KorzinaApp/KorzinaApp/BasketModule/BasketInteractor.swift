import UIKit

protocol BasketInteractorProtocol: AnyObject {
    var presenter: BasketPresenterProtocol? { get set }
    func viewDidLoad()
}

class BasketInteractor: BasketInteractorProtocol {
    weak var presenter: BasketPresenterProtocol?
    
    func viewDidLoad() {
        presenter?.presentBasketScreen()
    }
}



