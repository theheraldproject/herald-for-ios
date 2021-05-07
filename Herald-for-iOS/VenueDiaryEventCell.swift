//
//  VenueDiaryEventCell.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//
//

import UIKit
import Herald

public class VenueDiaryEventCell: UITableViewCell {
    private let dateFormatter = DateFormatter()
    private let dateFormatterTime = DateFormatter()
    
    @IBOutlet weak var venueName: UILabel!
    @IBOutlet weak var venueCode: UILabel!
    @IBOutlet weak var checkInDate: UILabel!
    @IBOutlet weak var checkInTime: UILabel!
    @IBOutlet weak var checkOutTime: UILabel!
    
    public func display(_ evt: VenueDiaryEvent) {
        dateFormatter.dateFormat = "dd MMM"
        dateFormatterTime.dateFormat = "HH:mm"
        
        let first = evt.getFirstTime()
        let last = evt.getLastTime()
        checkInDate.text = dateFormatter.string(from: first)
        checkInTime.text = dateFormatterTime.string(from: first)
        if first == last {
            checkOutTime.text = "N/A"
        } else {
            // are we closed yet?
            if evt.isClosed() {
                checkOutTime.text = dateFormatterTime.string(from: last)
            } else {
                checkOutTime.text = dateFormatterTime.string(from: last) + "..."
            }
        }
        
        venueCode.text = "\(evt.getCode())"
        
        if let name = evt.getName() {
            venueName.text = name
        } else {
            venueName.text = "Unknown name"
        }
    }
}
