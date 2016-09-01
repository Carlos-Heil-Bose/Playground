//
//  ViewController.swift
//  BMAP2
//
//  Created by Carlos Heil on 8/29/16.
//  Copyright © 2016 Bose Corporation. All rights reserved.
//

import UIKit
import CoreBluetooth

let BLEServiceChangedStatusNotification = "kBLEServiceChangedStatusNotification"

public class BLEManager : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var peripheral: CBPeripheral?
    var BMAPCharacteristic: CBCharacteristic?
    let BOSE_UUID:[CBUUID] =  [CBUUID(string:"FEBE")]
    let BMAP_CHARACTERISTIC:CBUUID = CBUUID(string:"D417C028-9818-4354-99D1-2AC09D074591")
    
    public func ScanForBOSEbuildDevices(timeout:Int8) -> Bool{
        
        return true
    }
    
    
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        // Determine the state of the peripheral
        if (central.state == .PoweredOff) {
            NSLog("CoreBluetooth BLE hardware is powered off")
        }
        else if (central.state == .PoweredOn) {
            
            NSLog("CoreBluetooth BLE hardware is powered on and ready")
            central.scanForPeripheralsWithServices(BOSE_UUID, options:nil)
        }
        else if (central.state == .Unauthorized) {
            NSLog("CoreBluetooth BLE state is unauthorized");
        }
        else if (central.state == .Unknown) {
            NSLog("CoreBluetooth BLE state is unknown");
        }
        else if (central.state == .Unsupported) {
            NSLog("CoreBluetooth BLE hardware is unsupported on this platform");
        }
    }
    
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        if (localName != nil) {
            print("local name", localName!, " RSSI", RSSI)
            if (localName == "BOSEbuild 9999") {
                central.stopScan()
                peripheral.delegate = self
                self.peripheral = peripheral
                central.connectPeripheral(peripheral, options:nil);
            }
        }
    }
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("Connected")
        peripheral.discoverServices(BOSE_UUID)
        
    }
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        for service in peripheral.services! {
            print("service ", service.UUID.UUIDString)
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
            
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        for service in peripheral.services! {
            print("service ", service.UUID.UUIDString)
            for characteristic in service.characteristics! {
                if (characteristic.UUID == BMAP_CHARACTERISTIC) {
                    print("characteristic ", characteristic.UUID.UUIDString)
                    self.BMAPCharacteristic = characteristic
                    peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                    break
                }
            }
        }
        let connectionDetails = ["isConnected": true]
        NSNotificationCenter.defaultCenter().postNotificationName(BLEServiceChangedStatusNotification, object: self, userInfo: connectionDetails)
    }
    
    public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Error")
    }
    public func WriteBMAP()
    {
        var data : [UInt8]
        var xxx :NSData
        data = [0x00,0x0B,0x08,0x00,0x05,0x00, 0x01, 0x00, 0xff, 0x00]
        xxx = NSData(bytes: data, length:data.count)
        self.peripheral!.writeValue(xxx, forCharacteristic: self.BMAPCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
        data = [0x00,0x0B,0x04,0x00,0x01,0x00]
        xxx = NSData(bytes: data, length:data.count)
        self.peripheral!.writeValue(xxx, forCharacteristic: self.BMAPCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
    }
}

class ViewController: UIViewController {
    
    let btman = BLEManager()
    var centralmanager : CBCentralManager!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        centralmanager = CBCentralManager(delegate: btman, queue:nil, options: nil);
        // Watch Bluetooth connection
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(ViewController.connectionChanged(_:)), name: BLEServiceChangedStatusNotification, object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    func connectionChanged(notification: NSNotification) {
        btman.WriteBMAP()
    }
}
