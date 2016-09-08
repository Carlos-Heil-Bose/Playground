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
open class BLEManager : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    // Local constants
    ///@brief Bose service UUID
    fileprivate let BOSE_UUID:[CBUUID]         = [CBUUID(string:BOSE_SERVICE_UUID)]

    ///@brief BMAP characteristic UUID
    fileprivate let BMAP_CHARACTERISTIC:CBUUID =  CBUUID(string:BMAP_CHARACTERISTIC_UUID)

    // Local variables
    ///@brief BLE central manager instance
    fileprivate var central            : CBCentralManager?

    ///@brief BLE peripheral instance
    fileprivate var peripheral         : CBPeripheral?

    ///@brief BMAP characteristic instance
    fileprivate var BMAPCharacteristic : CBCharacteristic?

    ///@brief Timer used during BLE device discovery
    fileprivate var ScanTimer          : Timer?

    /// List of BOSEbuild devices found during the scan period and their 
    /// associated RSSI
    fileprivate var BOSEbuildDevicesFound = [String() : Int()]

    /// List of BOSEbuild devices found with their name and associated CBPeripheral
    /// instance
    fileprivate var BOSEbuildPeripheral   = [String : CBPeripheral]()

    override init() {

    }

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
    open func ScanForBOSEbuildDevices(_ central:CBCentralManager, timeout:UInt8) {
        // Start the scan timer
        ScanTimer = Timer.scheduledTimer(timeInterval: TimeInterval(timeout),
                            target:self, selector:#selector(ScanTimeout), userInfo:nil, repeats: false)

        // Search for devices with the BOSE UUID
        self.central = central
        self.central!.scanForPeripherals(withServices: BOSE_UUID, options:nil)
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
    open func ConnectToDevice(_ DeviceName:String) {
        // Find the CBPeripheral instance associated with the device name specified
        self.peripheral = BOSEbuildPeripheral[DeviceName]!

        // Clear the found peripheral list since we'll no longer use it
        BOSEbuildPeripheral.removeAll()

        // Establish BLE connection
        self.peripheral!.delegate = self
        central!.connect(self.peripheral!, options:nil);
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
    open func WriteBMAP(_ BMAPMessage : BMAP) {
        // Obtain the actual bytes to be sent
        var BMAPbytes : Data
        BMAPbytes = Data(bytes: UnsafePointer<UInt8>(BMAPMessage.getBytes()), count:BMAPMessage.getSize())

        // Send the BMAP message over BLE
        self.peripheral!.writeValue(BMAPbytes, for: self.BMAPCharacteristic!, type: CBCharacteristicWriteType.withResponse)
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
    open func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Determine the state of the peripheral

        if (central.state == .poweredOff) {
            // Send notification indicating BLE hardware interface is powered off
            NotificationCenter.default.post(name: Notification.Name(rawValue: BLEPoweredOffNotification), object: self, userInfo: nil)
            NSLog("CoreBluetooth BLE hardware is powered off")
        }
        else if (central.state == .poweredOn) {
            // Send notification indicating BLE hardware interface is powered on
            NotificationCenter.default.post(name: Notification.Name(rawValue: BLEPoweredOnNotification), object: self, userInfo: nil)
            NSLog("CoreBluetooth BLE hardware is powered on and ready")
        }
        else if (central.state == .unauthorized) {
            NSLog("CoreBluetooth BLE state is unauthorized");
        }
        else if (central.state == .unknown) {
            NSLog("CoreBluetooth BLE state is unknown");
        }
        else if (central.state == .unsupported) {
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
    open func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        if (localName != nil) {
            if (localName!.contains("BOSEbuild")) {
                BOSEbuildDevicesFound[localName!] = RSSI.intValue
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
    open func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
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
    open func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
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
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Look for the BMAP characteristic on the available services 
        // (should be only the Bose service (oxFEBE) since we only tried to 
        //  discover this service).
        for service in peripheral.services! {
            print("service ", service.uuid.uuidString)
            // Find the BMAP characteristic on this service
            peripheral.discoverCharacteristics([BMAP_CHARACTERISTIC],
                                               for: service)
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
    open func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Go through the list of returned services (there should be only one!)
        for service in peripheral.services! {
            // Go through the list of returned characteristics (there should be only one!)
            for characteristic in service.characteristics! {
                // Make sure it is the BMAP characteristic
                if (characteristic.uuid == BMAP_CHARACTERISTIC) {
                    print("characteristic ", characteristic.uuid.uuidString)
                    self.BMAPCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)

                    // Notify BLEManager user that BMAP service is available
                    let connectionDetails = ["isConnected": true]
                    NotificationCenter.default.post(name: Notification.Name(rawValue: BLEBMAPServiceAvailableNotification), object: self, userInfo: connectionDetails)
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
    @objc fileprivate func ScanTimeout() {
        // Stop the BLE scan
        self.central!.stopScan()
        // Notify the user of the BOSEbuild devices found
        NotificationCenter.default.post(name: Notification.Name(rawValue: BLEBOSEbuildDeviceFoundNotification),
                                                                  object: self, userInfo: BOSEbuildDevicesFound)
    }
}

