import SwiftUI
import MapKit
import CoreLocation

/// Where the car is parked, from the vehicle's own GPS over the local BLE
/// session. No Tesla account and no network access is involved. The owner's
/// position is only used to show the straight-line distance when location
/// permission has been granted.
struct VehicleLocationView: View {
    @Environment(VehicleController.self) private var vehicle
    @State private var locationProvider = LocationProvider()
    @State private var hasPosition: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if let coordinate = vehicle.vehicleCoordinate {
                Map(position: $hasPosition) {
                    Annotation("车辆位置", coordinate: coordinate) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(10)
                            .background(.white, in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.16), lineWidth: 1))
                            .shadow(radius: 3)
                    }
                    UserAnnotation()
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .overlay(alignment: .bottom) { footer(coordinate: coordinate) }
                .onAppear { hasPosition = .region(MKCoordinateRegion(
                    center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)) }
            } else {
                ContentUnavailableView(
                    "尚未获取车辆位置",
                    systemImage: "map",
                    description: Text("保持车辆连接后点击右上角刷新，即可读取车辆 GPS 位置。")
                )
            }
        }
        .appDestinationPage(title: "车辆位置")
        .toolbar {
            Button {
                Task { await vehicle.refreshVehicleLocation() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("刷新车辆位置")
        }
        .task {
            locationProvider.requestPermissionIfNeeded()
            await vehicle.refreshVehicleLocation()
        }
    }

    private func footer(coordinate: CLLocationCoordinate2D) -> some View {
        VStack(spacing: 6) {
            if let userCoordinate = locationProvider.userCoordinate {
                let meters = CLLocation(
                    latitude: coordinate.latitude, longitude: coordinate.longitude
                ).distance(from: CLLocation(
                    latitude: userCoordinate.latitude, longitude: userCoordinate.longitude))
                Label(distanceText(meters), systemImage: "figure.walk")
                    .font(.subheadline.weight(.semibold))
            }
            if let updated = vehicle.vehicleLocationUpdatedAt {
                Text("车辆位置更新于 \(updated.formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(AppTheme.muted)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.bottom, 16)
    }

    private func distanceText(_ meters: CLLocationDistance) -> String {
        if meters < 1000 { return "距车辆约 \(Int(meters.rounded())) 米" }
        return String(format: "距车辆约 %.1f 公里", meters / 1000)
    }
}

/// Minimal when-in-use location access for the distance label. Declined
/// permission only hides the distance; the vehicle position still shows.
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var userCoordinate: CLLocationCoordinate2D?
    private let manager = CLLocationManager()

    func requestPermissionIfNeeded() {
        manager.delegate = self
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userCoordinate = locations.last?.coordinate
        manager.stopUpdatingLocation()
    }
}
