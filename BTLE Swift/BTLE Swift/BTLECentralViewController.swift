//
//  BTLECentralViewController.swift
//  BTLE Swift
//
//  Created by zhonghangxun on 2018/9/14.
//  Copyright © 2018年 zhonghangxun. All rights reserved.
//

/*
    客户端 接收服务的设备
 */

import UIKit
import CoreBluetooth

class BTLECentralViewController: UIViewController {
    
    var textview: UITextView!
    var centralManager: CBCentralManager!
    var discoveredPeripheral: CBPeripheral!
    var data: Data!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        textview = UITextView(frame: CGRect(x: 20, y: 100, width: screenW - 40 , height: 300))
        self.view.addSubview(textview)
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        data = Data()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super .viewDidDisappear(animated)
        /// Stops scanning for peripherals
        centralManager.stopScan()
    }
    
    /// Scan for peripherals - specifically for our service's 128bit CBUUID
    func scan() {
        centralManager.scanForPeripherals(withServices: [CBUUID(string: TRANSFER_SERVICE_UUID)], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true)])
        print("Scanning started...")
    }
    /** Call this when things either go wrong, or you're done with the connection.
     *  This cancels any subscriptions if there are any, or straight disconnects if not.
     *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
     */
    func cleanup() {
        // Don't do anything if we're not connected
        if discoveredPeripheral.state != .connected {
            return
        }
        
        // See if we are subscribed to a characteristic on the peripheral
        if discoveredPeripheral.services != nil {
            
            for itemServer in discoveredPeripheral.services! {
                for itemCharacteristic in itemServer.characteristics! {
                    if itemCharacteristic.uuid == CBUUID(string: TRANSFER_CHARACTERISTIC_UUID) {
                        if itemCharacteristic.isNotifying {
                            // It is notifying, so unsubscribe
                            discoveredPeripheral.setNotifyValue(false, for: itemCharacteristic)
                            // And we're done.
                            return
                        }
                    }
                }
            }
        }
        // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager .cancelPeripheralConnection(discoveredPeripheral)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension BTLECentralViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            return
        }
        /// so start scanning
        self.scan()
    }
    
    /*!
     *  @method centralManager:didDiscoverPeripheral:advertisementData:RSSI:
     *
     *  @param central              The central manager providing this update.
     *  @param peripheral           A <code>CBPeripheral</code> object.
     *  @param advertisementData    A dictionary containing any advertisement and scan response data.
     *  @param RSSI                 The current RSSI of <i>peripheral</i>, in dBm. A value of <code>127</code> is reserved and indicates the RSSI
     *                                was not available.
     *
     *  @discussion                 This method is invoked while scanning, upon the discovery of <i>peripheral</i> by <i>central</i>. A discovered peripheral must
     *                              be retained in order to use it; otherwise, it is assumed to not be of interest and will be cleaned up by the central manager. For
     *                              a list of <i>advertisementData</i> keys, see {@link CBAdvertisementDataLocalNameKey} and other similar constants.
     *
     *  @seealso                    CBAdvertisementData.h
     *
     */
    @available(iOS 5.0, *)
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber){
        // Reject any where the value is above reasonable range
        if RSSI.intValue > -15 {
            return
        }
        // Reject if the signal strength is too low to be close enough (Close is around -22dB)
        if RSSI.intValue < -35 {
            return
        }
        print("discovered \(peripheral.name ?? "no name") at \(RSSI)")
        // Ok, it's in range - have we already seen it?
        if self.discoveredPeripheral != peripheral {
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
            discoveredPeripheral = peripheral
            
            // and connect
            print("Connecting to peripheral \(peripheral)")
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    /*!
     *  @method centralManager:didFailToConnectPeripheral:error:
     *
     *  @param central      The central manager providing this information.
     *  @param peripheral   The <code>CBPeripheral</code> that has failed to connect.
     *  @param error        The cause of the failure.
     *
     *  @discussion         This method is invoked when a connection initiated by {@link connectPeripheral:options:} has failed to complete. As connection attempts do not
     *                      timeout, the failure of a connection is atypical and usually indicative of a transient issue.
     *
     */
    @available(iOS 5.0, *)
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?){
//        If the connection fails for whatever reason, we need to deal with it.
        
        print("Faile to connect to \(peripheral).(\(error?.localizedDescription ?? "no message error")")
        cleanup()
    }
    
    /*!
     *  @method centralManager:didConnectPeripheral:
     *
     *  @param central      The central manager providing this information.
     *  @param peripheral   The <code>CBPeripheral</code> that has connected.
     *
     *  @discussion         This method is invoked when a connection initiated by {@link connectPeripheral:options:} has succeeded.
     *
     */
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("peripheral connected")
        
        // stop scanning
        centralManager.stopScan()
        print("scanning stopped")
        
        // Clear the data that we may already have
        data = Data()
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices([CBUUID(string: TRANSFER_SERVICE_UUID)])
    }
    /** The Transfer Service was discovered
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            print("error discovering services: \(error?.localizedDescription ?? "no message error")")
            cleanup()
            return
        }
        // Discover the characteristic we want...
        
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        for service in peripheral.services! {
            peripheral.discoverCharacteristics([CBUUID(string: TRANSFER_CHARACTERISTIC_UUID)], for: service)
        }
    }
    /** The Transfer characteristic was discovered.
     *  Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
     */
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any)
        if error != nil {
            print("error discovering services: \(error?.localizedDescription ?? "no message error")")
            cleanup()
            return
        }
        // Again, we loop through the array, just in case.
        for characteristic in service.characteristics! {
            
            // And check if it's the right one
            if characteristic.uuid == CBUUID(string: TRANSFER_CHARACTERISTIC_UUID) {
                
                // If it is, subscribe to it
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    /** This callback lets us know more data has arrived via notification on the characteristic
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("error discovering services: \(error?.localizedDescription ?? "no message error")")
            return
        }
        
        let stringFromData = String.init(data: characteristic.value!, encoding: String.Encoding.utf8)
        
        
        // Have we got everything we need?
        if stringFromData == "EOM" {
            
            // We have, so show the data,
            self.textview.text = String.init(data: self.data, encoding: String.Encoding.utf8)
            
            // Cancel our subscription to the characteristic
            peripheral.setNotifyValue(false, for: characteristic)
            
            // and disconnect from the peripehral
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        // Otherwise, just add the data on to what we already have
        self.data.append(characteristic.value!)
        
        // Log it
        print("received: \(stringFromData ?? "null message")")
    }
    /** The peripheral letting us know whether our subscribe/unsubscribe happened or not
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print("error discovering services: \(error?.localizedDescription ?? "no message error")")
            return
        }
        
        // Exit if it's not the transfer characteristic
        if characteristic.uuid != CBUUID(string: TRANSFER_CHARACTERISTIC_UUID) {
            return;
        }
        
        // Notification has started
        if characteristic.isNotifying {
            print("notification began on \(characteristic)")
        }
            
            // Notification has stopped
        else {
            // so disconnect from the peripheral
            print("Notification stopped on \(characteristic).  Disconnecting")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }
    /** Once the disconnection happens, we need to clean up our local copy of the peripheral
     */
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        
        print("Peripheral Disconnected")
        self.discoveredPeripheral = nil;
        
        // We're disconnected, so start scanning again
        scan()
    }
}

extension BTLECentralViewController: CBPeripheralDelegate {
    
    
}









