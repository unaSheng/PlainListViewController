import Foundation
import UIKit

public protocol NibInstantiatable: AnyObject {
    static var nibName: String { get }
}

public extension NibInstantiatable where Self: UIView {
    static var nibName: String {
        return String(describing: self)
    }
    static var nib: UINib {
        return UINib(nibName: nibName, bundle: nil)
    }
}

public extension NibInstantiatable {
    static func instantiateFromNib() -> Self {
        UINib(nibName: nibName, bundle: nil).instantiate(withOwner: nil, options: nil).first(where: { $0 is Self }) as! Self
    }
}
