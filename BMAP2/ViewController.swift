//
//  ViewController.swift
//  BMAP2
//
//  Created by Carlos Heil on 8/29/16.
//  Copyright © 2016 Bose Corporation. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {

    var centralmanager : CBCentralManager!

    // Instantiate the BLE manager
    var BLEmanager = BLEManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Instantiate the BLE central manager with the BLEmanager as a delegate
        centralmanager = CBCentralManager(delegate: BLEmanager, queue:nil, options: nil);

        // Establish handlers for the notification coming from BLEmanager
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.BLEPoweredOn(_:)), name: NSNotification.Name(rawValue: BLEPoweredOnNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.BLEDevicesFound(_:)), name: NSNotification.Name(rawValue: BLEBOSEbuildDeviceFoundNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.BLEConnectionUpdate(_:)), name: NSNotification.Name(rawValue: BLEBMAPServiceAvailableNotification), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // Handler for BLEPoweredOnNotification
    internal func BLEPoweredOn(_ notification: Notification) {
        // BLE is up. Search for BOSEbuild devices
        BLEmanager.ScanForBOSEbuildDevices(centralmanager, timeout: 5)
    }
    
    // Handler for BLEBOSEbuildDeviceFoundNotification
    internal func BLEDevicesFound(_ DeviceList: Notification) {
        var SelectedDevice : String
        if ((DeviceList as NSNotification).userInfo != nil) {
            SelectedDevice = FindHighestRSSI(DeviceList)
            BLEmanager.ConnectToDevice(SelectedDevice)
        }
        else {
            NSLog("No BOSEbuild devices found")
        }
    }
    
    // Handler for BLEBMAPServiceAvailableNotification
    internal func BLEConnectionUpdate(_ notification: Notification) {
        let userInfo = (notification as NSNotification).userInfo as! [String: Bool]
        // Check if connection is successful
        if let isConnected: Bool = userInfo["isConnected"] {
            if (isConnected) {
                // We are good to go. Set the cube red!
                // Set the color red...
                let SetLEDColor = BMAP(FunctionBlock:.bosEbuild, Function:.bb_LEDUserControlValue, Operator:.op_Set, Data :[0,1,0xff,0,0] )
                BLEmanager.WriteBMAP(SetLEDColor)
                
                // Now change the LED mode to RGB...
                let SetLEDModeRGB = BMAP(FunctionBlock:.bosEbuild, Function:.bb_LEDMode, Operator:.op_Set, Data :[BB_LEDModes.ledMode_RGB.rawValue] )
                BLEmanager.WriteBMAP(SetLEDModeRGB)
            }
        }
    }
    
    fileprivate func FindHighestRSSI(_ notification:Notification) -> String {
        var HighRSSI : Int = -255
        var HighRSSIName : String = ""
        let DeviceList = (notification as NSNotification).userInfo
        if (DeviceList != nil) {
            for (DeviceName, DeviceRSSI) in DeviceList! {
                if ((DeviceRSSI as AnyObject).intValue < 0) {
                    NSLog("Device \(DeviceName): RSSI = \(DeviceRSSI)" )
                    if (HighRSSI < (DeviceRSSI as AnyObject).intValue) {
                        HighRSSI = (DeviceRSSI as AnyObject).intValue
                        HighRSSIName = DeviceName as! String
                    }
                }
            }
        }
        return HighRSSIName
    }
}
