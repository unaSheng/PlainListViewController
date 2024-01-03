//
//  ViewController.swift
//  PlainListViewController
//
//  Created by unaSheng on 01/03/2024.
//  Copyright (c) 2024 unaSheng. All rights reserved.
//

import UIKit
import PlainListViewController

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func simpleListButtonTapped(_ sender: Any) {
        let userListVC = UserListViewController(dataProvider: UserListDataProvider())
        navigationController?.pushViewController(userListVC, animated: true)
    }
}

