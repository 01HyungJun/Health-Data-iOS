import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()
    private let locationManager = CLLocationManager()
    
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // 현재 권한 상태 저장
        authorizationStatus = locationManager.authorizationStatus
        print("📍 초기 위치 권한 상태: \(authorizationStatus.rawValue)")
        
        // 초기 권한 요청
        DispatchQueue.main.async { [weak self] in
            self?.locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func startUpdatingLocation() {
        let authStatus = locationManager.authorizationStatus
        print("📍 현재 위치 권한 상태: \(authStatus.rawValue)")
        
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            print("📍 위치 업데이트 시작")
            locationManager.startUpdatingLocation()
        } else {
            print("⚠️ 위치 권한이 없습니다: \(authStatus.rawValue)")
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    func stopUpdatingLocation() {
        print("📍 위치 업데이트 중지")
        locationManager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        print("📍 위치 정보 수집됨: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        lastLocation = location
        // 위치 정보를 받은 후 업데이트 중지
        stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("❌ 위치 정보 수집 실패: \(error.localizedDescription)")
        stopUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("📍 위치 권한 상태 변경: \(authorizationStatus.rawValue)")
    }
} 