//
//  ARManager.swift
//  XmasPresentGo
//
//  Created by 藤井陽介 on 2017/11/17.
//  Copyright © 2017年 touyou. All rights reserved.
//

import SceneKit
import ARKit
import CoreLocation
import GLKit.GLKMatrix4

/// SCNModelGeneratable Protocol
///
/// usage:
/// - ModelEnumType ... Model enumerations.
/// - generateModel ... Generating model method.
protocol SCNModelGeneratable {
    
    associatedtype ModelEnumType
    func generateModel(_ model: ModelEnumType) -> SCNNode
}

/// ARKit Manager
///
/// It will make some matrix method easier.
public class ARManager: NSObject {
    
    static let shared = ARManager()
    
    
}

/// CoreLocation Manager
///
/// Get longitude attitude altitude
public class ARCLManager: NSObject {
    
    static let shared = ARCLManager()
    
    weak var delegate: LocationServiceDelegate?
    
    private override init() {
        super.init()
        
        locationManager = CLLocationManager()
        
        guard let locationManager = locationManager else {
            
            return
        }
        
        requestAuthorization(locationManager: locationManager)
        
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.delegate = self
        
        startUpdatingLocation(locationManager: locationManager)
        print("start location")
    }
    
    deinit {
        
        guard let locationManager = locationManager else {
            
            return
        }
        
        stopUpdatingLocation(locationManager: locationManager)
    }
    
    // MARK: - Private
    
    private var locationManager: CLLocationManager?
    private var _latitude: CLLocationDistance? = nil
    private var _longitude: CLLocationDistance? = nil
    private var _altitude: CLLocationDistance? = nil
    private var _coordinate: CLLocationCoordinate2D? = nil
    private var _location: CLLocation? = nil
    
    // MARK: - Internal
    
    /// Latitude (default is 0.0)
    var latitude: CLLocationDistance {
        
        guard let latitude = self._latitude else {
            
            return 0.0
        }
        
        return latitude
    }
    /// Longitude (default is 0.0)
    var longitude: CLLocationDistance {
        
        guard let longitude = self._longitude else {
            
            return 0.0
        }
        
        return longitude
    }
    /// Coordinate2D
    var coordinate: CLLocationCoordinate2D {
        
        guard let coordinate = self._coordinate else {
            
            return CLLocationCoordinate2D(latitude: self.latitude, longitude: self.longitude)
        }
        
        return coordinate
    }
    /// Altitude (default is 0.0)
    var altitude: CLLocationDistance {
        
        guard let altitude = self._altitude else {
            
            return 0.0
        }
        
        return altitude
    }
    var location: CLLocation {
        
        guard let location = self._location else {
            
            return CLLocation(latitude: self.latitude, longitude: self.longitude)
        }
        
        return location
    }
    var userHeading: CLLocationDirection!
    
    /// request authorize corelocation
    func requestAuthorization(locationManager: CLLocationManager) {
        
        locationManager.requestWhenInUseAuthorization()
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            startUpdatingLocation(locationManager: locationManager)
        case .notDetermined, .restricted, .denied:
            stopUpdatingLocation(locationManager: locationManager)
        }
    }
    
    /// start up location manager
    func startUpdatingLocation(locationManager: CLLocationManager) {
        
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    /// end location manager
    func stopUpdatingLocation(locationManager: CLLocationManager) {
        
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }
    
    /// for init shared instance
    func run() {}
}

extension ARCLManager: CLLocationManagerDelegate {
    
    // MARK: - CLLocationManager delegate
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        for location in locations {
            
            self.delegate?.trackingLocation(for: location)
        }
        
        let newLocation = manager.location
        _altitude = newLocation?.altitude
        _coordinate = newLocation?.coordinate
        _longitude = newLocation?.coordinate.longitude
        _latitude = newLocation?.coordinate.latitude
        _location = newLocation
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        
        if newHeading.headingAccuracy < 0 {
            
            return
        }
        
        let heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        userHeading = heading
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        self.delegate?.trackingLocationDidFail(with: error)
    }
}

/// Location Service Delegate
protocol LocationServiceDelegate: class {
    
    func trackingLocation(for currentLocation: CLLocation)
    func trackingLocationDidFail(with error: Error)
}

// MARK: - Matrix Helper

/// Matrix calcuration helpers
/// matrix_float4x4 is
/// column 0 to 3 and row is x, y, z, w
class MatrixHelper {
    
    static func rotateAroundY(with matrix: matrix_float4x4, for degrees: Float) -> matrix_float4x4 {
        
        var matrix: matrix_float4x4 = matrix
        
        matrix.columns.0.x = cos(degrees)
        matrix.columns.0.z = -sin(degrees)
        
        matrix.columns.2.x = sin(degrees)
        matrix.columns.2.z = cos(degrees)
        return matrix.inverse
    }

    static func rotateAroundX(with matrix: matrix_float4x4, for degrees: Float) -> matrix_float4x4 {
        
        var matrix: matrix_float4x4 = matrix
        
        matrix.columns.1.y = cos(degrees)
        matrix.columns.1.z = -sin(degrees)
        
        matrix.columns.2.y = sin(degrees)
        matrix.columns.2.z = cos(degrees)
        return matrix.inverse
    }
    
    static func translationMatrix(with matrix: matrix_float4x4, for translation: vector_float4) -> matrix_float4x4 {
        
        var matrix = matrix
        matrix.columns.3 = translation
        return matrix
    }

    /// This method calcurate distance and bearing between one and the other location
    static func transformMatrix(for matrix: simd_float4x4, originLocation: CLLocation, location: CLLocation) -> simd_float4x4 {
        
        let (s: distance, a1: bearing, a2: a2) = VincentyHelper.shared.calcurateDistanceAndAzimuths(at: originLocation.coordinate, and: location.coordinate)
        let position = vector_float4(0.0, 0.0, Float(-distance), 0.0)
        let translationMatrix = MatrixHelper.translationMatrix(with: matrix_identity_float4x4, for: position)
        let rotationMatrix = MatrixHelper.rotateAroundY(with: matrix_identity_float4x4, for: Float(bearing.radian))
//        let rotationMatrix2 = MatrixHelper.rotateAroundX(with: matrix_identity_float4x4, for: Float(a2.radian))
        let rotationMatrix2 = matrix_identity_float4x4
        let transformMatrix = simd_mul(simd_mul(rotationMatrix, translationMatrix), rotationMatrix2)
        return simd_mul(matrix, transformMatrix)
    }

    /// This method calcurate ar location to real world location
    static func transformLocation(for matrix: simd_float4x4, originLocation: CLLocation, location: SCNVector3) -> CLLocation {
        
        let x2 = pow(location.x, 2.0)
        let y2 = pow(location.y, 2.0)
        let z2 = pow(location.z, 2.0)
        // Bearing and distance in AR World
        let distance = sqrt(x2 + y2 + z2)
        let a1 = atan2(Double(location.x), Double(location.z)).degree
        
        let (location: location, a2: _) = VincentyHelper.shared.calcurateNextPointLocation(from: originLocation.coordinate, s: Double(distance), a1: a1)
        
        return CLLocation(latitude: location.latitude, longitude: location.longitude)
    }
}

// MARK: - ARKit Extensions

extension SCNScene {}

protocol PropertyStoring {
    
    associatedtype T
    
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T
}

extension PropertyStoring {
    func getAssociatedObject(_ key: UnsafeRawPointer!, defaultValue: T) -> T {
        guard let value = objc_getAssociatedObject(self, key) as? T else {
            return defaultValue
        }
        return value
    }
}

extension SCNNode: PropertyStoring {
    
    typealias T = ObjectData
    
    private struct CustomProperties {
        static var objectData = ObjectData.init(latitude: 0, longitude: 0, object: ARManager.Model.present.rawValue, userID: "unknown")
    }
    
    var objectData: ObjectData {
        
        get {
            return getAssociatedObject(&CustomProperties.objectData, defaultValue: CustomProperties.objectData)
        }
        set {
            return objc_setAssociatedObject(self, &CustomProperties.objectData, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

extension ARSCNView {}
