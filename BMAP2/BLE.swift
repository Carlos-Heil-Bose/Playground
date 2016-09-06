////////////////////////////////////////////////////////////////////////////////
///  @file   BLE.swift
///  @brief  Bluetooth Low Energy (BLE) interface
///
///  @details
///          Provides access to BLE services on iOS
///
///  Copyright © 2016 Bose Corporation. All rights reserved.
///
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// Module dependencies
import CoreBluetooth

////////////////////////////////////////////////////////////////////////////////
/// Notifications issued
let BLEPoweredOnNotification             = "kBLEPoweredOn"
let BLEPoweredOffNotification            = "kBLEPoweredOff"
let BLEBMAPServiceAvailableNotification  = "kBLEBMAPServiceAvailable"
let BLEBOSEbuildDeviceFoundNotification  = "kBLEBOSEbuildDeviceFound"

////////////////////////////////////////////////////////////////////////////////
/// Constants
let BOSE_SERVICE_UUID        = "FEBE"
let BMAP_CHARACTERISTIC_UUID = "D417C028-9818-4354-99D1-2AC09D074591"

////////////////////////////////////////////////////////////////////////////////
/// BLEManager class
/// The BLEManager class provides the following interface:
///
///     - ScanForBOSEbuildDevices(central:CBCentralManager, timeout:Int8)
///       Scans for BOSEbuild devices (i.e., BLE devices containing "BOSEbuild"
///       in their device name) for a period of "timeout" seconds.
///       Once "timeout" expires, a list containing the name and associated RSSI
///       of all devices found is sent via the "kBLEBOSEbuildDeviceFound"
///       notification.
///
///     - ConnectToDevice(DeviceName:String)
///       Establishes a BLE connection to the device with the specified "DeviceName".
///       In addition looks for the presence of a service with the Bose UUID and
///       then for the BMAP characteristic within that service.
///       The DeviceName specified has to be one of the devices reported in the
///       kBLEBOSEbuildDeviceFound notification.
///       If the connection is successful and the BMAP characteristic is found,
///       the "kBLEBMAPServiceAvailableNotification" notification is issued.
///
///     - WriteBMAP(BMAPMessage : BMAP)
///       Sends the contents of the "BMAPMessage" object as a BMAP message to the
///       BOSEbuild device previously connected.
///
///     - kBLEPoweredOn notification
///       This notification is issued when BLE hw interface is found to be powered
///       on and available for use.
///
///     - kBLEPoweredOff notification
///       This notification is issued when BLE hw interface is powered off.
///
////////////////////////////////////////////////////////////////////////////////
public class BLEManager : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Local constants
    ///@brief Bose service UUID
    private let BOSE_UUID:[CBUUID]         = [CBUUID(string:BOSE_SERVICE_UUID)]

    ///@brief BMAP characteristic UUID
    private let BMAP_CHARACTERISTIC:CBUUID =  CBUUID(string:BMAP_CHARACTERISTIC_UUID)

    // Local variables
    ///@brief BLE central manager instance
    private var central            : CBCentralManager!

    ///@brief BLE peripheral instance
    private var peripheral         : CBPeripheral?

    ///@brief BMAP characteristic instance
    private var BMAPCharacteristic : CBCharacteristic?

    ///@brief Timer used during BLE device discovery
    private var ScanTimer          : NSTimer?

    /// List of BOSEbuild devices found during the scan period and their 
    /// associated RSSI
    private var BOSEbuildDevicesFound = [String() : Int()]

    /// List of BOSEbuild devices found with their name and associated CBPeripheral
    /// instance
    private var BOSEbuildPeripheral   = [String() : CBPeripheral?()]

    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   ScanForBOSEbuildDevices
    /// 
    /// @brief
    ///   Scans for BLE devices with the BOSE UUID (0xFEBE) for a period of
    ///   <timeout> seconds.
    ///   The list of devices found is later refined to remove any device which
    ///   don't contain "BOSEbuild" in their name.
    ///   Once the complete scan procedure is completed, the "kBLEBOSEbuildDeviceFound"
    ///   will be issued with a list of the BOSEbuild devices found.
    ///
    /// @param [in] central : CBCentralManager
    ///        Instance of the CBCentralManager class representing the BLE
    ///        interface.
    ///
    /// @param [in] timeout : UInt8
    ///         Period of time in seconds that we'll scan for BLE devices
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func ScanForBOSEbuildDevices(central:CBCentralManager, timeout:UInt8) {
        // Start the scan timer
        ScanTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(timeout),
                            target:self, selector:#selector(ScanTimeout), userInfo:nil, repeats: false)

        // Search for devices with the BOSE UUID
        self.central = central
        self.central.scanForPeripheralsWithServices(BOSE_UUID, options:nil)
    }
    
    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   ConnectToDevice
    ///
    /// @brief
    ///    Establishes a BLE connection to the device with the specified name.
    ///    The connection is only considered "complete" once the BMAP characteristic
    ///    is found to be available on the selected device.
    ///    Once the connection is complete, the "BLEBMAPServiceAvailableNotification"
    ///    notification is issued.
    ///
    /// @param [in] DeviceName : String
    ///         Device name selected to establish connection. The device name
    ///         has to be one of the devices presented in the "kBLEBOSEbuildDeviceFound"
    ///         notification.
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func ConnectToDevice(DeviceName:String) {
        // Find the CBPeripheral instance associated with the device name specified
        self.peripheral = BOSEbuildPeripheral[DeviceName]!

        // Clear the found peripheral list since we'll no longer use it
        BOSEbuildPeripheral.removeAll()

        // Establish BLE connection
        self.peripheral!.delegate = self
        central.connectPeripheral(self.peripheral!, options:nil);
    }
    
    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   WriteBMAP
    ///
    /// @brief
    ///   Sends the BLE BMAP message associated with the BMAP object passed as 
    ///   argument
    ///
    /// @param [in] BMAPMessage : BMAP
    ///        BMAP object representing the message that will be sent over BLE
    ///        as a BMAP packet.
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func WriteBMAP(BMAPMessage : BMAP) {
        // Obtain the actual bytes to be sent
        var BMAPbytes : NSData
        BMAPbytes = NSData(bytes: BMAPMessage.getBytes(), length:BMAPMessage.getSize())

        // Send the BMAP message over BLE
        self.peripheral!.writeValue(BMAPbytes, forCharacteristic: self.BMAPCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
    }
    
    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   centralManagerDidUpdateState
    ///
    /// @brief
    ///   Called by iOS upon instantiation of a CBCentralManager object and when
    ///   there is a change in the state of BLE hardware.
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func centralManagerDidUpdateState(central: CBCentralManager) {
        // Determine the state of the peripheral

        if (central.state == .PoweredOff) {
            // Send notification indicating BLE hardware interface is powered off
            NSNotificationCenter.defaultCenter().postNotificationName(BLEPoweredOffNotification, object: self, userInfo: nil)
            NSLog("CoreBluetooth BLE hardware is powered off")
        }
        else if (central.state == .PoweredOn) {
            // Send notification indicating BLE hardware interface is powered on
            NSNotificationCenter.defaultCenter().postNotificationName(BLEPoweredOnNotification, object: self, userInfo: nil)
            NSLog("CoreBluetooth BLE hardware is powered on and ready")
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
    
    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   didDiscoverPeripheral
    ///
    /// @brief
    ///   Called by iOS when a BLE device is discovered during a scan operation.
    ///   We build a list of BOSEbuild devices found with their names and 
    ///   associated RSSI. That list is later sent as part of a kBLEBOSEbuildDeviceFound
    ///   notification
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        if (localName != nil) {
            if (localName!.containsString("BOSEbuild")) {
                BOSEbuildDevicesFound[localName!] = RSSI.integerValue
                BOSEbuildPeripheral[localName!]   = peripheral
            }
        }
    }


    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   didConnectPeripheral
    ///
    /// @brief
    ///   Called by iOS when a connection is established to the BLE device.
    ///   Once the connection is established we look for the Bose service UUID.
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        print("Connected")

        // Go look for the Bose service UUID on the connected device
        peripheral.discoverServices(BOSE_UUID)
        
    }
    
    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   didFailToConnectPeripheral
    ///
    /// @brief
    ///   Called by iOS when a connection fails to be established.
    ///   Currently we take no action in this case (but we should!).
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func centralManager(central: CBCentralManager, didFailToConnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        print("Error")
    }
    
    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   didDiscoverServices
    ///
    /// @brief
    ///   Called by iOS when the selected service is available on the connected
    ///   device (in this case the Bose service (0xFEBE).
    ///   We then look for the BMAP characteristic of the Bose service.
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        // Look for the BMAP characteristic on the available services 
        // (should be only the Bose service (oxFEBE) since we only tried to 
        //  discover this service).
        for service in peripheral.services! {
            print("service ", service.UUID.UUIDString)
            // Find the BMAP characteristic on this service
            peripheral.discoverCharacteristics([BMAP_CHARACTERISTIC],
                                               forService: service)
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   didDiscoverCharacteristicsForService
    ///
    /// @brief
    ///   Called by iOS when the selected characteristic is available on the 
    ///   connected device (in this case, the BMAP characteristic).
    ///
    ////////////////////////////////////////////////////////////////////////////
    public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        // Go through the list of returned services (there should be only one!)
        for service in peripheral.services! {
            // Go through the list of returned characteristics (there should be only one!)
            for characteristic in service.characteristics! {
                // Make sure it is the BMAP characteristic
                if (characteristic.UUID == BMAP_CHARACTERISTIC) {
                    print("characteristic ", characteristic.UUID.UUIDString)
                    self.BMAPCharacteristic = characteristic
                    peripheral.setNotifyValue(true, forCharacteristic: characteristic)

                    // Notify BLEManager user that BMAP service is available
                    let connectionDetails = ["isConnected": true]
                    NSNotificationCenter.defaultCenter().postNotificationName(BLEBMAPServiceAvailableNotification, object: self, userInfo: connectionDetails)
                    break
                }
            }
        }
    }
    
    ////////////////////////////////////////////////////////////////////////////
    /// @fn
    ///   ScanTimeout
    ///
    /// @brief
    ///   Called when the BLE scan timer expires.
    ///
    ////////////////////////////////////////////////////////////////////////////
    @objc private func ScanTimeout() {
        // Stop the BLE scan
        self.central.stopScan()
        // Notify the user of the BOSEbuild devices found
        NSNotificationCenter.defaultCenter().postNotificationName(BLEBOSEbuildDeviceFoundNotification,
                                                                  object: self, userInfo: BOSEbuildDevicesFound)
    }
}

