//
//  UserListViewController.swift
//  Example
//
//  Created by li.wenxiu on 2023/9/10.
//

import UIKit
import PlainListViewController

class UserListViewController: PlainListViewController<User, UserListCell>, UIGestureRecognizerDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "用户"
    }
}

class UserListDataProvider: AnyPlainListDataProvider<User> {
    override func fetchData(offset: Int) async throws -> PlainListResponse<User> {
        if offset == 0 {
            return .init(list: [
                User(id: "", nick: "吃不胖1", intro: "我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖2", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖3", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖4", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖5", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖6", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖7", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖8", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖9", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖10", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖11", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖12", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖13", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖14", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖15", intro: "我有养生秘诀，想知道吗？"),], hasNext: true, nextOffset: 1)
        } else {
            return .init(list: [
                User(id: "", nick: "吃不胖16", intro: "我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖15", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖17", intro: "我有养生秘诀，想知道吗？"),
                User(id: "", nick: "吃不胖18", intro: "我有养生秘诀，想知道吗？"),], hasNext: false, nextOffset: 2)
        }
    }
}
