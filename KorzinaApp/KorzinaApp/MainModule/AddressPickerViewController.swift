import UIKit
import MapKit
import CoreLocation

class AddressPickerViewController: UIViewController {
    
    var onAddressSelected: ((String) -> Void)?
    
    private let mapView = MKMapView()
    private let searchBar = UISearchBar()
    private let addressLabel = UILabel()
    private let confirmButton = UIButton(type: .system)
    private let locationManager = CLLocationManager()
    private var selectedCoordinate: CLLocationCoordinate2D?
    private var currentAddress: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupLocationManager()
        setupMapView()
    }
    
    private func setupUI() {
        title = "Выберите адрес"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        // Search bar
        searchBar.placeholder = "Поиск адреса"
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        // Map view
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        
        // Address label
        addressLabel.text = "Нажмите на карту для выбора адреса"
        addressLabel.font = .systemFont(ofSize: 16, weight: .medium)
        addressLabel.textColor = .label
        addressLabel.numberOfLines = 0
        addressLabel.textAlignment = .center
        addressLabel.backgroundColor = .secondarySystemBackground
        addressLabel.layer.cornerRadius = 8
        addressLabel.layer.masksToBounds = true
        addressLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addressLabel)
        
        // Confirm button
        confirmButton.setTitle("Подтвердить адрес", for: .normal)
        confirmButton.backgroundColor = UIColor.primaryColor
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        confirmButton.layer.cornerRadius = 12
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        confirmButton.isEnabled = false
        confirmButton.alpha = 0.5
        view.addSubview(confirmButton)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            mapView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: addressLabel.topAnchor, constant: -16),
            
            addressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addressLabel.bottomAnchor.constraint(equalTo: confirmButton.topAnchor, constant: -16),
            addressLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            
            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            confirmButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Добавляем жест для выбора точки на карте
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(mapTapped(_:)))
        mapView.addGestureRecognizer(tapGesture)
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
    
    private func setupMapView() {
        // Устанавливаем начальную позицию (Москва)
        let initialLocation = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)
        let region = MKCoordinateRegion(
            center: initialLocation,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        mapView.setRegion(region, animated: false)
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func mapTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        selectedCoordinate = coordinate
        
        // Удаляем предыдущие аннотации
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        // Добавляем новую аннотацию
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
        
        // Получаем адрес для выбранной координаты
        reverseGeocode(coordinate: coordinate)
    }
    
    @objc private func confirmTapped() {
        guard !currentAddress.isEmpty else { return }
        onAddressSelected?(currentAddress)
        dismiss(animated: true)
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Reverse geocoding error: \(error)")
                self.addressLabel.text = "Не удалось определить адрес"
                self.currentAddress = ""
                self.confirmButton.isEnabled = false
                self.confirmButton.alpha = 0.5
                return
            }
            
            guard let placemark = placemarks?.first else {
                self.addressLabel.text = "Адрес не найден"
                self.currentAddress = ""
                self.confirmButton.isEnabled = false
                self.confirmButton.alpha = 0.5
                return
            }
            
            // Формируем адрес
            var addressComponents: [String] = []
            
            if let street = placemark.thoroughfare {
                addressComponents.append(street)
            }
            if let houseNumber = placemark.subThoroughfare {
                addressComponents.append(houseNumber)
            }
            if let locality = placemark.locality {
                addressComponents.append(locality)
            }
            
            let address = addressComponents.joined(separator: ", ")
            self.currentAddress = address.isEmpty ? "Выбранная точка на карте" : address
            self.addressLabel.text = self.currentAddress
            
            self.confirmButton.isEnabled = true
            self.confirmButton.alpha = 1.0
        }
    }
    
    private func searchAddress(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Search error: \(error)")
                return
            }
            
            guard let mapItem = response?.mapItems.first else {
                return
            }
            
            let coordinate = mapItem.placemark.coordinate
            self.selectedCoordinate = coordinate
            
            // Удаляем предыдущие аннотации
            self.mapView.removeAnnotations(self.mapView.annotations.filter { !($0 is MKUserLocation) })
            
            // Добавляем аннотацию
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            self.mapView.addAnnotation(annotation)
            
            // Центрируем карту на найденном адресе
            let region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            self.mapView.setRegion(region, animated: true)
            
            // Получаем адрес
            self.reverseGeocode(coordinate: coordinate)
        }
    }
}

// MARK: - MKMapViewDelegate
extension AddressPickerViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let identifier = "SelectedLocation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView == nil {
            annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        return annotationView
    }
}

// MARK: - UISearchBarDelegate
extension AddressPickerViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else { return }
        searchBar.resignFirstResponder()
        searchAddress(query: query)
    }
}

// MARK: - CLLocationManagerDelegate
extension AddressPickerViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        locationManager.stopUpdatingLocation()
        
        // Центрируем карту на текущем местоположении при первом запуске
        if selectedCoordinate == nil {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            mapView.setRegion(region, animated: true)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }
}

