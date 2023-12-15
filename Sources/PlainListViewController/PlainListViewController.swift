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

open class PlainListCell<Item>: UICollectionViewCell {
    open func render(_ item: Item) {
        fatalError("must overrided in subclass")
    }
}

open class PlainListViewController<Item: Hashable, Cell: PlainListCell<Item>>: UIViewController, UICollectionViewDelegate {
    
    public struct Section: Hashable {
        
        public let id: String
        
        public static var main: Section { Section(id: "main") }
    }
    
    struct ItemLayout {
        var layout: NSCollectionLayoutItem
        var item: Item
    }
    
    /// A Boolean value indicates current list supports pull to refresh.
    open var supportPullToRefresh: Bool { true }
    
    /// A Boolean value indicates current list supports auto load more.
    open var supportAutoLoadMore: Bool { true }
    
    open var displayInititalLoadingIndicator: Bool { true }
    
    open var emptyView: UIView? {
        let view = EmptyView()
        view.updateUI(title: "暂无内容")
        return view
    }
    
    public var collectionView: UICollectionView!
    private(set) var nextOffset = 0
    private(set) var total: Int? = nil
    private(set) var hasShownLoadingIndicator = false
    
    var layoutItems: [ItemLayout] = []
    var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    let loadingIndicator = UIActivityIndicatorView(style: .medium)
    
    public let dataProvider: AnyPlainListDataProvider<Item>
    public init(dataProvider: AnyPlainListDataProvider<Item>) {
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
    
    open func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout.init { [weak self] index, environment in
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(UIScreen.main.bounds.height * 2))
            let subItems: [NSCollectionLayoutItem]
            if let items = self?.layoutItems, !items.isEmpty {
                subItems = items.map({ $0.layout })
            } else {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(10))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                subItems = [item]
            }
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: subItems)
            let section = NSCollectionLayoutSection(group: group)
            return section
        }
        return layout
    }
    
    open func setupDataSource() {
        let cellRegistration: UICollectionView.CellRegistration<Cell, Item>
        if let c = Cell.self as? NibInstantiatable.Type {
            let nib = UINib(nibName: c.nibName, bundle: nil)
            cellRegistration = UICollectionView.CellRegistration(cellNib: nib) { [weak self] cell, indexPath, itemIdentifier in
                self?.configure(cell: cell, indexPath: indexPath, item: itemIdentifier)
                cell.render(itemIdentifier)
                self?.update(cell: cell, indexPath: indexPath, item: itemIdentifier)
            }
        } else {
            cellRegistration = UICollectionView.CellRegistration<Cell, Item> { [weak self] (cell, indexPath, itemIdentifier) in
                self?.configure(cell: cell, indexPath: indexPath, item: itemIdentifier)
                cell.render(itemIdentifier)
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
    
    open func setupEmptyView() {
        collectionView.backgroundView = emptyView
        collectionView.backgroundView?.isHidden = true
    }
    
    func checkEmptyView() {
        let hidden = dataSource.snapshot().itemIdentifiers.isEmpty == false
        collectionView.backgroundView?.isHidden = hidden
        if supportAutoLoadMore {
            collectionView.mj_footer?.isHidden = !hidden
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
    
    func generateLayout(items: [Item]) -> [ItemLayout] {
        if #available(iOS 16, *) {
            return []
        }
        let layoutItems = items.map({ item in
            let contentView: UIView
            if let c = Cell.self as? NibInstantiatable.Type {
                let cell = c.instantiateFromNib() as! PlainListCell<Item>
                cell.render(item)
                contentView = cell
            } else {
                let cell = Cell()
                cell.render(item)
                contentView = cell
            }
            let fittingSize = CGSize(width: view.bounds.width, height: UIView.layoutFittingCompressedSize.height)
            let size = contentView.systemLayoutSizeFitting(fittingSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            let layoutItem = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(ceil(size.height))))
            return ItemLayout(layout: layoutItem, item: item)
        })
        return layoutItems
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
                    let items = Array(response.list.uniqued())
                    layoutItems = generateLayout(items: items)
                    var snapshot = NSDiffableDataSourceSectionSnapshot<Item>()
                    snapshot.append(items)
                    dataSource.apply(snapshot, to: .main, animatingDifferences: false)
                } else {
                    var snapshot = dataSource.snapshot(for: .main)
                    let currentItems = self.dataSource.snapshot(for: .main).items
                    let newItems = Array(Array((currentItems + response.list).uniqued()).dropFirst(currentItems.count))
                    layoutItems += generateLayout(items: newItems)
                    snapshot.append(newItems)
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
    
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
    }
    
}
