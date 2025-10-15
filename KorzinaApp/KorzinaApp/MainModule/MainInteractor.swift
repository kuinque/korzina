import UIKit

protocol MainInteractorProtocol: AnyObject {
    var presenter: MainPresenterProtocol? { get set }
    func viewDidLoad()
    func storeSelected(storeName: String)
}

class MainInteractor: MainInteractorProtocol {
    weak var presenter: MainPresenterProtocol?
    
    func viewDidLoad() {
        presenter?.presentMainScreen()
        presenter?.presentStores()
    }
    
    func storeSelected(storeName: String) {
        presenter?.presentShopScreen(storeName: storeName)
    }
}



