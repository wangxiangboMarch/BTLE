//
//  BTLEPeripheralViewController.swift
//  BTLE Swift
//
//  Created by zhonghangxun on 2018/9/14.
//  Copyright © 2018年 zhonghangxun. All rights reserved.
//

import UIKit
import CoreBluetooth

let NOTIFY_MTU = 20

class BTLEPeripheralViewController: UIViewController {

    var textView : UITextView!
    var advertisingSwitch: UISwitch!
    var peripheralManager: CBPeripheralManager!
    var transferCharacteristic: CBMutableCharacteristic!
    var dataToSend: NSData!
    var sendDataIndex: Int!

    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // Start up the CBPeripheralManager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        advertisingSwitch.addTarget(self, action: Selector(("switchChanged")), for: .valueChanged)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        peripheralManager.stopAdvertising()
    }

    
    var sendingEOM = false
    /*
     * Sends the next amount of data to the connected central
     */
    func sendData() {
        // first up , check if we`re meant to be senging an EOM
        if sendingEOM {
            // send it
            let didSend = peripheralManager.updateValue("EOM".data(using: String.Encoding.utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)
            // Did it send?
            if didSend {
                // It did, so mark it as sent
                sendingEOM = false
                print("send : EOM")
            }
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        
        // Is there any left to send?
        if self.sendDataIndex >= self.dataToSend.length {
            // No data left.  Do nothing
            return
        }
        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        
        while didSend {
            // Make the next chunk
            
            // Work out how big it should be
            var amountToSend = self.dataToSend.length - self.sendDataIndex;
            
            // Can't be longer than 20 bytes
            if amountToSend > NOTIFY_MTU {
                amountToSend = NOTIFY_MTU
            }
            
            // Copy out the data we want
            let chunk = NSData(bytes: self.dataToSend.bytes+self.sendDataIndex, length: amountToSend)
            
            
            // Send it
            didSend = peripheralManager.updateValue(chunk as Data, for: transferCharacteristic, onSubscribedCentrals: nil)

            
            // If it didn't work, drop out and wait for the callback
            if (!didSend) {
                return;
            }
            
            let stringFromData = String(data: chunk as Data, encoding: String.Encoding.utf8)
            
            print("sent: \(stringFromData ?? "no message")")
            
            // It did send, so update our index
            self.sendDataIndex! += amountToSend
            
            // Was it the last one?
            if self.sendDataIndex >= self.dataToSend.length {
                
                // It was - send an EOM
                
                // Set this so if the send fails, we'll send it next time
                sendingEOM = true;
                
                // Send it
                let eomSent = peripheralManager.updateValue("EOM".data(using: String.Encoding.utf8)!, for: transferCharacteristic, onSubscribedCentrals: nil)

                
                if (eomSent) {
                    // It sent, we're all done
                    sendingEOM = true
                    print("sent: EOm")
                }
                
                return;
            }
        }
    }
    /*
     * Start advertising
     */
    func switchChanged() {
        if self.advertisingSwitch.isOn {
            // All we advertise is our service's UUID
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: TRANSFER_SERVICE_UUID)]])
        }else {
            peripheralManager.stopAdvertising()
        }
    }

    /*
     * Finishes the editing
     */
    
    @objc func dismissKeyboard() {
        self.textView.resignFirstResponder()
        self.navigationItem.rightBarButtonItem = nil
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension BTLEPeripheralViewController: CBPeripheralManagerDelegate {
    /*
     * Required protocol method.  A full app should take care of all the possible states,
     *  but we're just waiting for  to know when the CBPeripheralManager is ready
     */
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Opt out from any other state
        if peripheral.state != .poweredOn {
            return;
        }
        
        // We're in CBPeripheralManagerStatePoweredOn state...
        print("self.peripheralManager powered on")
        
        // ... so build our service.
        
        // Start with the CBMutableCharacteristic
        self.transferCharacteristic = CBMutableCharacteristic(type: CBUUID(string: TRANSFER_CHARACTERISTIC_UUID), properties: .notify, value: nil, permissions: .readable)
        
        // Then the service
        let transferService = CBMutableService(type: CBUUID(string: TRANSFER_SERVICE_UUID), primary: true)

        
        // Add the characteristic to the service
        transferService.characteristics = [self.transferCharacteristic];
        
        // And add it to the peripheral manager
        peripheralManager.add(transferService)
    }
    /*
     * Catch when someone subscribes to our characteristic, then start sending them data
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Central subscribed to characteristic")
        // Get the data
        self.dataToSend = self.textView.text.data(using: String.Encoding.utf8)! as NSData
        
        // Reset the index
        self.sendDataIndex = 0;
        
        // Start sending
        sendData()
    }
    /*
     * Recognise when the central unsubscribes
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central unsubscribed from characteristic")
    }
    /*
     * This callback comes in when the PeripheralManager is ready to send the next chunk of data.
     *  This is to ensure that packets will arrive in the order they are sent
     */
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Start sending again
        sendData()
    }
}

extension BTLEPeripheralViewController: UITextViewDelegate {
    /*
     * This is called when a change happens, so we know to stop advertising
     */
    func textViewDidChange(_ textView: UITextView) {
        // If we're already advertising, stop
        if advertisingSwitch.isOn {
            advertisingSwitch.setOn(false, animated: true)
            peripheralManager.stopAdvertising()
        }
    }

    /*
     * Adds the 'Done' button to the title bar
     */
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        // We need to add this manually so we have a way to dismiss the keyboard  #selector(ViewController.cyanButtonClick)
        let rightButton = UIBarButtonItem(title: "done", style: .plain, target: self, action: #selector(BTLEPeripheralViewController.dismissKeyboard))
        self.navigationItem.rightBarButtonItem = rightButton
    }
    
}
