//
//  ModeSelectionViewController.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import UIKit
import Herald

class ModeSelectionViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private let logger = Log(subsystem: "Herald", category: "ModeSelectionViewController")
    
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    override func viewDidLoad() {
        logger.debug("viewDidLoad")
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
      self.logger.debug("viewDidAppear")
    }
    
    @IBAction func openVenueBeaconMode(_ sender: UIButton) {
        let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let viewController = mainStoryboard.instantiateViewController(withIdentifier: "venuevc") as? UIViewController {
            self.present(viewController, animated: true, completion: {
                self.logger.debug("completion callback - venue")
                viewController.presentationController?.delegate = self
            })
        }
    }
    
    @IBAction func openPhoneMode(_ sender: UIButton) {
        let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let viewController = mainStoryboard.instantiateViewController(withIdentifier: "phonevc") as? UIViewController {
            self.present(viewController, animated: true, completion: {
                self.logger.debug("completion callback - phone")
                viewController.presentationController?.delegate = self
            })
        }
    }
    
    /// MARK: UIAdaptivePresentationControllerDelegate
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.logger.debug("presentationControllerDidDismiss")
        // TODO ensure this doesn't get called if a popup from a subview if cancelled
        self.appDelegate.stopBluetooth()
    }
}
