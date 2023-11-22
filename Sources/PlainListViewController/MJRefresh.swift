import MJRefresh

public class RefreshHeader: MJRefreshNormalHeader {
    
    public override func prepare() {
        super.prepare()
        loadingView?.style = .medium
        stateLabel?.isHidden = true
        lastUpdatedTimeLabel?.isHidden = true
        autoChangeTransparency(true)
    }
}

public class RefreshFooter: MJRefreshAutoNormalFooter {
    
    public override func prepare() {
        super.prepare()
        stateLabel?.isHidden = true
        isRefreshingTitleHidden = true
    }
}

extension UICollectionView {
    
    func endMJRefresh(hasMore: Bool = false) {
        mj_header?.endRefreshing()
        if hasMore {
            mj_footer?.resetNoMoreData()
        } else {
            mj_footer?.endRefreshingWithNoMoreData()
        }
    }
}
