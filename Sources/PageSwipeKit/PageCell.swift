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
        hostedView?.removeFromSuperview()
        hostedView = nil
        transform = .identity
        layer.cornerRadius = 0
    }
}

// MARK: - Public Methods

extension PageCell {
    
    func configure(with view: UIView) {
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

// MARK: - Private Setup

extension PageCell {
    
    private func setupCell() {
        clipsToBounds = false
        contentView.clipsToBounds = false
        insetsLayoutMarginsFromSafeArea = false
        contentView.insetsLayoutMarginsFromSafeArea = false
    }
}
