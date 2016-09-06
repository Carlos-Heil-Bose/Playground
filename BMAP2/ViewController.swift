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
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.BLEPoweredOn(_:)), name: BLEPoweredOnNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.BLEDevicesFound(_:)), name: BLEBOSEbuildDeviceFoundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.BLEConnectionUpdate(_:)), name: BLEBMAPServiceAvailableNotification, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // Handler for BLEPoweredOnNotification
    internal func BLEPoweredOn(notification: NSNotification) {
        // BLE is up. Search for BOSEbuild devices
        BLEmanager.ScanForBOSEbuildDevices(centralmanager, timeout: 5)
    }
    
    // Handler for BLEBOSEbuildDeviceFoundNotification
    internal func BLEDevicesFound(DeviceList: NSNotification) {
        var SelectedDevice : String
        if (DeviceList.userInfo != nil) {
            SelectedDevice = FindHighestRSSI(DeviceList)
            BLEmanager.ConnectToDevice(SelectedDevice)
        }
        else {
            NSLog("No BOSEbuild devices found")
        }
    }
    
    // Handler for BLEBMAPServiceAvailableNotification
    internal func BLEConnectionUpdate(notification: NSNotification) {
        let userInfo = notification.userInfo as! [String: Bool]
        // Check if connection is successful
        if let isConnected: Bool = userInfo["isConnected"] {
            if (isConnected) {
                // We are good to go. Set the cube red!
                // Set the color red...
                let SetLEDColor = BMAP(FunctionBlock:.BOSEbuild, Function:.BB_LEDUserControlValue, Operator:.Op_Set, Data :[0,1,0xff,0,0] )
                BLEmanager.WriteBMAP(SetLEDColor)
                
                // Now change the LED mode to RGB...
                let SetLEDModeRGB = BMAP(FunctionBlock:.BOSEbuild, Function:.BB_LEDMode, Operator:.Op_Set, Data :[BB_LEDModes.LEDMode_RGB.rawValue] )
                BLEmanager.WriteBMAP(SetLEDModeRGB)
            }
        }
    }
    
    private func FindHighestRSSI(notification:NSNotification) -> String {
        var HighRSSI : Int = -255
        var HighRSSIName : String = ""
        let DeviceList = notification.userInfo
        if (DeviceList != nil) {
            for (DeviceName, DeviceRSSI) in DeviceList! {
                if (DeviceRSSI.integerValue < 0) {
                    NSLog("Device \(DeviceName): RSSI = \(DeviceRSSI)" )
                    if (HighRSSI < DeviceRSSI.integerValue) {
                        HighRSSI = DeviceRSSI.integerValue
                        HighRSSIName = DeviceName as! String
                    }
                }
            }
        }
        return HighRSSIName
    }
}
