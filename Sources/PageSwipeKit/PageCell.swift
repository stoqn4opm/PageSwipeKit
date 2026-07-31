//
//  PageCell.swift
//  PageSwipeKit
//
//  Created by stoyan on 23.02.26.
//

import UIKit

// MARK: - PageCell

/// A collection view cell that hosts a view controller's view for page swiping.
final class PageCell: UICollectionViewCell {
    
    // MARK: - Constants
    
    static let identifier = "PageCell"
    
    // MARK: - Private Properties
    
    private var hostedView: UIView?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle

    override func prepareForReuse() {
        super.prepareForReuse()
        removeHostedViewIfStillOwned()
        hostedView = nil
        transform = .identity
        layer.cornerRadius = 0
    }
}

// MARK: - Public Methods

extension PageCell {

    /// Hosts the given view inside the cell's content view.
    ///
    /// Idempotent: re-configuring with the view the cell already hosts is a
    /// no-op, so repeated configuration (e.g. after a size transition) never
    /// accumulates duplicate constraints. If the view currently lives in
    /// another cell — a transient animation cell can steal it during a size
    /// transition — it is re-parented here and constrained afresh.
    func configure(with view: UIView) {
        guard hostedView !== view || view.superview !== contentView else { return }

        removeHostedViewIfStillOwned()
        hostedView = view
        view.translatesAutoresizingMaskIntoConstraints = false
        view.insetsLayoutMarginsFromSafeArea = false
        contentView.addSubview(view)

        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: contentView.topAnchor),
            view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}

// MARK: - Private Helpers

extension PageCell {

    /// Removes the hosted view only while this cell is still its parent.
    /// After a size transition another cell may already host the view; a
    /// discarded transient cell being recycled must not rip it back out.
    private func removeHostedViewIfStillOwned() {
        guard let hostedView, hostedView.superview === contentView else { return }
        hostedView.removeFromSuperview()
    }
}

// MARK: - Private Setup

extension PageCell {
    
    private func setupCell() {
        clipsToBounds = false
        contentView.clipsToBounds = false
        insetsLayoutMarginsFromSafeArea = false
        contentView.insetsLayoutMarginsFromSafeArea = false
    }
}
