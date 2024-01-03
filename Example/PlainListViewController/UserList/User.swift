//
//  User.swift
//  Example
//
//  Created by li.wenxiu on 2023/9/10.
//

import Foundation

struct User: Codable, Hashable {
    var id: String
    var nick: String
    var intro: String
}
