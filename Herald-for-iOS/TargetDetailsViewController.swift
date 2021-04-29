//
//  TargetDetailsViewController.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import UIKit
import Herald

class TargetDetailsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private let logger = Log(subsystem: "Herald", category: "ViewController")
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate

    @IBOutlet weak var lblId: UILabel!
    @IBOutlet weak var lblPayload: UILabel!
    @IBOutlet weak var lblType: UILabel!
    @IBOutlet weak var lblVersion: UILabel!
    @IBOutlet weak var lblCountry: UILabel!
    @IBOutlet weak var lblState: UILabel!
    @IBOutlet weak var lblIdentifier: UILabel!
    
    @IBOutlet weak var tableExtendedData: UITableView!
    
    var target: TargetIdentifier? = nil
    var payloadData: PayloadData? = nil
    var extendedData: ExtendedData? = nil
    
    // MARK:- UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableExtendedData.dataSource = self
        tableExtendedData.delegate = self
    }
    
    public func display(_ target: TargetIdentifier, payload: PayloadData) {
        self.target = target
        self.payloadData = payload
        
        lblId.text = target.description
        if (target.description.count > 17) {
            lblId.text = target.description.prefix(17) + "..."
        }
        
        lblPayload.text = payload.hexEncodedString
        // TODO trim the above text if very long
        
        // vary display based on data in Payload
        do {
            let beacon = try VenueEncounter(
                Proximity(unit: .RSSI, value: 0),
                payload
            )
            let uv = beacon!.getVenue()!
            lblType.text = "Venue Beacon"
            lblVersion.text = "TODO"
            lblCountry.text = "\(uv.getCountry())"
            lblState.text = "\(uv.getState())"
            lblIdentifier.text = "\(uv.getCode())"
        } catch {
            // try next format
            // TODO Simple and Secured and Custom - for now, default to default
        }
    }
    
    // MARK:- UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "targetIdentifier", for: indexPath)
        
        // TODO initialise content
        
        return cell
    }
    
}
