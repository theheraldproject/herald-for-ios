//
//  VenueDiaryViewController.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import UIKit
import Herald

class VenueDiaryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    
    private let logger = Log(subsystem: "Herald", category: "VenueDiaryViewController")
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    @IBOutlet weak var tableVenueDiary: UITableView!
    
    private var diary: VenueDiary? = nil
    
    // MARK:- UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableVenueDiary.delegate = self
        tableVenueDiary.dataSource = self
    }
    
    // MARK:- instance methods
    
    public func setDiary(_ diary: VenueDiary) {
        self.diary = diary
        logger.debug("setDiary")
        tableVenueDiary.reloadData()
    }
    
    // MARK:- TableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let diary = diary else {
            return 0
        }
        logger.debug("Diary checkin count: \(diary.eventListCount())")
        return diary.eventListCount()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "venueDiaryCell",
                              for: indexPath) as! VenueDiaryEventCell
        let events = diary!.listRecordableEvents()
        let evt = events[indexPath.row]
        cell.display(evt)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}
