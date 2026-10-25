//
//  NativeLocation.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 06.02.26.
//

public import CoreLocation
public import Foundation

public protocol NativeLocation: AnyObject {
  var location: CLLocation { get }
}
