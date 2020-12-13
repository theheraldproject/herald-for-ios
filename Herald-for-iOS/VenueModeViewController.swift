//
//  VenueModeViewController.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import UIKit
import Herald

class VenueModeViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    private let logger = Log(subsystem: "Herald", category: "VenueModeViewController")
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var sensor: SensorArray!
    
    @IBOutlet weak var pickerVenue: UIPickerView!
    @IBOutlet weak var buttonStart: UIButton!
    
    var venues : [UInt32] = []
    
    var venueCodeSelected : UInt32? = nil
    
    override func viewDidLoad() {
        // Initialise list of venues - just codes for now
        venues.append(UInt32(12345))
        venues.append(UInt32(22334))
        venues.append(UInt32(55566))
        venues.append(UInt32(123123))
        
        pickerVenue.delegate = self
        pickerVenue.dataSource = self
        
        super.viewDidLoad()
    }
    
    @IBAction func beginBeaconing(_ sender: UIButton) {
        guard let venueCodeSelected = venueCodeSelected else {
            return
        }
        logger.debug("beginBeaconing for: \(venueCodeSelected)")
        
        // Now enable phone mode - initialises SensorArray
        appDelegate.startBeacon(ConcreteBeaconPayloadDataSupplierV1(countryCode: 826, stateCode: 4, code: venueCodeSelected))
        
        sensor = appDelegate.sensor
    }
    
    // MARK: UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return venues.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(venues[row])"
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        venueCodeSelected = venues[row]
        logger.debug("Selected: \(venueCodeSelected!)")
    }
    
}
