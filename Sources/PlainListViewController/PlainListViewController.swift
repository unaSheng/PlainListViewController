import Foundation
import UIKit
import MJRefresh

public struct PlainListResponse<T> {
    public let list: [T]
    public let hasNext: Bool
    public let nextOffset: Int
    public var total: Int?
    
    public init(list: [T], hasNext: Bool, nextOffset: Int, total: Int? = nil) {
        self.list = list
        self.hasNext = hasNext
        self.nextOffset = nextOffset
        self.total = total
    }
}

@MainActor
public protocol PlainListDataProvider {
    associatedtype T = Hashable
    func fetchData(offset: Int) async throws -> PlainListResponse<T>
}

open class AnyPlainListDataProvider<U>: PlainListDataProvider {
    
    public init() {}
    
    open func fetchData(offset: Int) async throws -> PlainListResponse<U> {
        fatalError("subclass must implement fetchData")
    }
}

open class PlainListCell<DataModel>: UICollectionViewCell {
    
    open func render(_ item: DataModel) {
        fatalError("must overrided in subclass")
    }
}

open class PlainListViewController<DataModel: Hashable, Cell: PlainListCell<DataModel>>: UIViewController, UICollectionViewDelegate {
    
    public struct Section: Hashable {
        
        public let id: String
        
        public static var main: Section { Section(id: "main") }
    }
    
    public struct Item: Hashable {
        public let value: DataModel
    }
    
    /// A Boolean value indicates current list supports pull to refresh.
    open var supportPullToRefresh: Bool { true }
    
    /// A Boolean value indicates current list supports auto load more.
    open var supportAutoLoadMore: Bool { true }
    
    open var displayEmptyPlaceholder: Bool { true }
    
    open var displayInititalLoadingIndicator: Bool { true }
    
    open var emptyPlaceholder: String? { return nil }
    
    open var emptyView: EmptyView!
    
    var emptyPlaceholderProvider: (() -> UIViewController)?
    var placeholderViewController: UIViewController?
    
    private(set) var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private(set) var nextOffset = 0
    private(set) var total: Int? = nil
    let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private(set) var hasShownLoadingIndicator = false
    
    public let dataProvider: AnyPlainListDataProvider<DataModel>
    public init(dataProvider: AnyPlainListDataProvider<DataModel>) {
        self.dataProvider = dataProvider
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        setupCollectionView()
        setupDataSource()
        setupEmptyView()
        setupLoadingIndicator()
        applySnapshot()
    }
    
    // MARK: - Setup
    
    private func setupCollectionView() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        view.addSubview(collectionView)
        
        if supportPullToRefresh {
            collectionView.mj_header = RefreshHeader(refreshingBlock: { [weak self] in
                self?.applySnapshot(loadMore: false)
            })
        }
        
        if supportAutoLoadMore {
            collectionView.mj_footer = RefreshFooter(refreshingBlock: { [weak self] in
                self?.applySnapshot(loadMore: true)
            })
        }
    }
    
    open func setupDataSource() {
        let cellRegistration: UICollectionView.CellRegistration<Cell, Item>
        if let c = Cell.self as? NibInstantiatable.Type {
            let nib = UINib(nibName: c.nibName, bundle: nil)
            cellRegistration = UICollectionView.CellRegistration(cellNib: nib) { [weak self] cell, indexPath, itemIdentifier in
                self?.configure(cell: cell, indexPath: indexPath, item: itemIdentifier)
                cell.render(itemIdentifier.value)
                self?.update(cell: cell, indexPath: indexPath, item: itemIdentifier)
            }
        } else {
            cellRegistration = UICollectionView.CellRegistration<Cell, Item> { [weak self] (cell, indexPath, itemIdentifier) in
                self?.configure(cell: cell, indexPath: indexPath, item: itemIdentifier)
                cell.render(itemIdentifier.value)
                self?.update(cell: cell, indexPath: indexPath, item: itemIdentifier)
            }
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView, cellProvider: { collectionView, indexPath, itemIdentifier in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: itemIdentifier)
        })
    }
    
    open func configure(cell: Cell, indexPath: IndexPath, item: Item) {
        // subclass can configure cell
    }
    
    open func update(cell: Cell, indexPath: IndexPath, item: Item) {
        // subclass can configure cell
    }
    
    open func createLayout() -> UICollectionViewLayout {
        var config = UICollectionLayoutListConfiguration(appearance: .plain)
        config.backgroundColor = .clear
        config.showsSeparators = false
        return UICollectionViewCompositionalLayout.list(using: config)
    }
    
    open func setupEmptyView() {
        guard displayEmptyPlaceholder else {
            return
        }
        if let vc = emptyPlaceholderProvider?() {
            placeholderViewController = vc
            view.addSubview(vc.view)
            vc.view.frame = view.bounds
            addChild(vc)
            vc.didMove(toParent: self)
            vc.view.isHidden = true
        } else {
            emptyView = EmptyView(frame: collectionView.bounds)
            emptyView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            emptyView.updateUI(title: emptyPlaceholder)
            emptyView.isHidden = true
            collectionView.addSubview(emptyView)
        }
    }
    
    public func checkEmptyView() {
        let hidden = dataSource.snapshot().itemIdentifiers.isEmpty == false
        if let vc = placeholderViewController {
            vc.view?.isHidden = hidden
        } else {
            emptyView?.isHidden = hidden
        }
    }
    
    func setupLoadingIndicator() {
        if displayInititalLoadingIndicator {
            view.addSubview(loadingIndicator)
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
        }
    }
    
    // MARK: - Snapshot
    
    /// Apply snapshot, subclass can override this method to implement complex snapshot.
    /// - Parameter loadMore: is load more data
    open func applySnapshot(loadMore: Bool = false) {
        Task { @MainActor in
            do {
                try await beforeApplySnapshot(loadMore: loadMore)
                if !loadMore && !hasShownLoadingIndicator {
                    hasShownLoadingIndicator = true
                    loadingIndicator.startAnimating()
                }
                
                let offset = loadMore ? nextOffset : 0
                let response = try await dataProvider.fetchData(offset: offset)
                self.nextOffset = response.nextOffset
                self.total = response.total
                if !loadMore {
                    var snapshot = NSDiffableDataSourceSectionSnapshot<Item>()
                    let items = Array(response.list.map { Item(value: $0) }.uniqued())
                    snapshot.append(items)
                    dataSource.apply(snapshot, to: .main)
                    
                } else {
                    var snapshot = dataSource.snapshot(for: .main)
                    var items = dataSource.snapshot(for: .main).items
                    items.append(contentsOf: response.list.map { Item(value: $0) })
                    items = Array(items.uniqued())
                    snapshot.deleteAll()
                    snapshot.append(items)
                    dataSource.apply(snapshot, to: .main, animatingDifferences: false)
                }
                
                loadingIndicator.stopAnimating()
                checkEmptyView()
                collectionView.endMJRefresh(hasMore: response.hasNext)
            } catch {
                loadingIndicator.stopAnimating()
                collectionView.endMJRefresh(hasMore: false)
                debugPrint(error)
            }
        }
    }
    
    open func beforeApplySnapshot(loadMore: Bool) async throws {
        
    }
    
    // MARK: - UICollectionViewDelegate
    open func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
    }
    
    open func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
    }
    
    open func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    open func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    open func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return nil
    }
    
    open func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
    }
    
    open func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
    }
}
