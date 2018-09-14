//
//  ViewController.swift
//  BTLE Swift
//
//  Created by zhonghangxun on 2018/9/14.
//  Copyright © 2018年 zhonghangxun. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func CentralModelAction(_ sender: UIButton) {
        let sss = BTLECentralViewController()
        self.navigationController?.pushViewController(sss, animated: true)
        
    }
    
    @IBAction func peripheralModelAction(_ sender: UIButton) {
        let sss = BTLEPeripheralViewController()
        self.navigationController?.pushViewController(sss, animated: true)
    }
    

}

