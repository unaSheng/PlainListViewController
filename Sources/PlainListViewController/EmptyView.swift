import UIKit

public class EmptyView: UIView {
    
    private let textLabel = UILabel()
    private let imageView = UIImageView()
    private var stackView = UIStackView()
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    public func updateUI(title: String?) {
        self.textLabel.text = title
    }
    
    private func setup() {
        textLabel.textAlignment = .center
        textLabel.font = .systemFont(ofSize: 12)
        textLabel.textColor = .secondaryLabel
        
        imageView.image = UIImage(systemName: "hand.raised")
        imageView.tintColor = UIColor.black
        stackView = UIStackView(arrangedSubviews: [imageView, textLabel])
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.spacing = 14
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -150),
        ])
    }
}
