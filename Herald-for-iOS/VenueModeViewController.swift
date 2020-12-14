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
    
    var venues : [UniqueVenue] = []
    
    var venueSelected : UniqueVenue? = nil
    
    override func viewDidLoad() {
        // Initialise list of venues - just codes for now
        venues.append(UniqueVenue(country: 826, state: 4, venue: UInt32(12345), name: "Joe's Pizza"))
        venues.append(UniqueVenue(country: 826, state: 3, venue: UInt32(22334), name: "Adam's Fish Shop"))
        venues.append(UniqueVenue(country: 832, state: 1, venue: UInt32(55566), name: "Max's Fine Dining"))
        venues.append(UniqueVenue(country: 826, state: 4, venue: UInt32(123123), name: "Erin's Stakehouse"))
        
        pickerVenue.delegate = self
        pickerVenue.dataSource = self
        
        super.viewDidLoad()
    }
    
    @IBAction func beginBeaconing(_ sender: UIButton) {
        guard let venueSelected = venueSelected else {
            return
        }
        logger.debug("beginBeaconing for: \(venueSelected.getName())")
        
        // Now enable phone mode - initialises SensorArray
        let ext = ConcreteExtendedDataV1()
        ext.addSection(code: ExtendedDataSegmentCodesV1.TextPremises.rawValue , value: venueSelected.getName())
        let pds = ConcreteBeaconPayloadDataSupplierV1(countryCode: venueSelected.getCountry(), stateCode: venueSelected.getState(), code: venueSelected.getCode(), extendedData: ext)
        appDelegate.startBeacon(pds)
        
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
        return venues[row].getName()
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        venueSelected = venues[row]
        logger.debug("Selected: \(venueSelected!.getName())")
    }
    
}
