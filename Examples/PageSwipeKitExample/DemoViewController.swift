//
//  DemoViewController.swift
//  ScrollViewTest
//
//  Demo view controller showcasing PageSwipeViewController with prepend/append.
//

import UIKit
import SwiftUI
import Combine
import PageSwipeKit

// MARK: - Configuration Store

class ConfigurationStore: ObservableObject {
    @Published var configuration: PageSwipeConfiguration = .default
}

// MARK: - Settings View Wrapper

struct SettingsViewWrapper: View {
    @ObservedObject var store: ConfigurationStore
    
    var body: some View {
        SettingsView(configuration: $store.configuration)
    }
}

// MARK: - DemoViewController

class DemoViewController: UIViewController {
    
    // MARK: - Properties
    
    private var pageSwipeVC: PageSwipeViewController!
    private let configStore = ConfigurationStore()
    private var cancellables = Set<AnyCancellable>()
    
    private var navigationBarView: UIView!
    private var pageLabel: UILabel!
    private var pageCountLabel: UILabel!
    private var settingsButton: UIButton!
    
    private var bottomControlsView: UIView!
    private var prependButton: UIButton!
    private var pageIndicatorLabel: UILabel!
    private var appendButton: UIButton!
    
    private var navigationControlsView: UIView!
    private var previousButton: UIButton!
    private var nextButton: UIButton!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPageSwipeViewController()
        setupNavigationBar()
        setupBottomControls()
        setupNavigationControls()
        setupConfigurationObserver()
        updateUI()
    }
    
    private func setupConfigurationObserver() {
        configStore.$configuration
            .sink { [weak self] newConfig in
                self?.pageSwipeVC.configuration = newConfig
            }
            .store(in: &cancellables)
    }
    
    private func setupPageSwipeBindings() {
        pageSwipeVC.currentPageDidChangePublisher
            .sink { [weak self] _ in
                self?.updateUI()
            }
            .store(in: &cancellables)
        
        pageSwipeVC.scrollingDidBeginPublisher
            .sink { [weak self] in
                self?.setControlsVisible(false, animated: true)
                print("📜 Scroll began")
            }
            .store(in: &cancellables)
        
        pageSwipeVC.scrollingDidEndPublisher
            .sink { [weak self] in
                self?.setControlsVisible(true, animated: true)
                print("📜 Scroll ended")
            }
            .store(in: &cancellables)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    // MARK: - Setup
    
    private func setupPageSwipeViewController() {
        // Create pages with view models using random names
        let pages = (1...3).map { _ -> SwipePage in
            let viewModel = SamplePageViewModel.withRandomName()
            return SwipePage(view: SamplePageView(viewModel: viewModel), prefetchable: viewModel)
        }
        
        pageSwipeVC = PageSwipeViewController(
            pages: pages,
            configuration: configStore.configuration
        )
        setupPageSwipeBindings()
        
        addChild(pageSwipeVC)
        view.addSubview(pageSwipeVC.view)
        pageSwipeVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            pageSwipeVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageSwipeVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageSwipeVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageSwipeVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        pageSwipeVC.didMove(toParent: self)
    }
    
    private func setupNavigationBar() {
        navigationBarView = UIView()
        navigationBarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBarView)
        
        // Gradient background
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.black.withAlphaComponent(0.6).cgColor, UIColor.clear.cgColor]
        gradientLayer.locations = [0, 1]
        navigationBarView.layer.insertSublayer(gradientLayer, at: 0)
        
        // Page label
        pageLabel = UILabel()
        pageLabel.translatesAutoresizingMaskIntoConstraints = false
        pageLabel.textColor = .white
        pageLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        pageLabel.textAlignment = .center
        navigationBarView.addSubview(pageLabel)
        
        // Page count label
        pageCountLabel = UILabel()
        pageCountLabel.translatesAutoresizingMaskIntoConstraints = false
        pageCountLabel.textColor = .white.withAlphaComponent(0.7)
        pageCountLabel.font = .systemFont(ofSize: 13)
        pageCountLabel.textAlignment = .center
        navigationBarView.addSubview(pageCountLabel)
        
        // Settings button
        settingsButton = UIButton(type: .system)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.setImage(UIImage(systemName: "gearshape.fill"), for: .normal)
        settingsButton.tintColor = .white
        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        navigationBarView.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            navigationBarView.topAnchor.constraint(equalTo: view.topAnchor),
            navigationBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationBarView.heightAnchor.constraint(equalToConstant: 110),
            
            pageLabel.centerXAnchor.constraint(equalTo: navigationBarView.centerXAnchor),
            pageLabel.bottomAnchor.constraint(equalTo: pageCountLabel.topAnchor, constant: -2),
            
            pageCountLabel.centerXAnchor.constraint(equalTo: navigationBarView.centerXAnchor),
            pageCountLabel.bottomAnchor.constraint(equalTo: navigationBarView.bottomAnchor, constant: -16),
            
            settingsButton.trailingAnchor.constraint(equalTo: navigationBarView.trailingAnchor, constant: -20),
            settingsButton.centerYAnchor.constraint(equalTo: pageLabel.centerYAnchor)
        ])
    }
    
    private func setupBottomControls() {
        bottomControlsView = UIView()
        bottomControlsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomControlsView)
        
        // Prepend button
        prependButton = createPillButton(title: "Prepend", icon: "plus.circle.fill")
        prependButton.addTarget(self, action: #selector(prependPage), for: .touchUpInside)
        bottomControlsView.addSubview(prependButton)
        
        // Page indicator
        pageIndicatorLabel = UILabel()
        pageIndicatorLabel.translatesAutoresizingMaskIntoConstraints = false
        pageIndicatorLabel.textColor = .white
        pageIndicatorLabel.font = .systemFont(ofSize: 13, weight: .medium)
        pageIndicatorLabel.textAlignment = .center
        pageIndicatorLabel.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        pageIndicatorLabel.layer.cornerRadius = 14
        pageIndicatorLabel.clipsToBounds = true
        bottomControlsView.addSubview(pageIndicatorLabel)
        
        // Append button
        appendButton = createPillButton(title: "Append", icon: "plus.circle.fill")
        appendButton.addTarget(self, action: #selector(appendPage), for: .touchUpInside)
        bottomControlsView.addSubview(appendButton)
        
        NSLayoutConstraint.activate([
            bottomControlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomControlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomControlsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            bottomControlsView.heightAnchor.constraint(equalToConstant: 40),
            
            prependButton.leadingAnchor.constraint(equalTo: bottomControlsView.leadingAnchor, constant: 20),
            prependButton.centerYAnchor.constraint(equalTo: bottomControlsView.centerYAnchor),
            
            pageIndicatorLabel.centerXAnchor.constraint(equalTo: bottomControlsView.centerXAnchor),
            pageIndicatorLabel.centerYAnchor.constraint(equalTo: bottomControlsView.centerYAnchor),
            pageIndicatorLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            pageIndicatorLabel.heightAnchor.constraint(equalToConstant: 28),
            
            appendButton.trailingAnchor.constraint(equalTo: bottomControlsView.trailingAnchor, constant: -20),
            appendButton.centerYAnchor.constraint(equalTo: bottomControlsView.centerYAnchor)
        ])
    }
    
    private func setupNavigationControls() {
        navigationControlsView = UIView()
        navigationControlsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationControlsView)
        
        // Previous button
        previousButton = UIButton(type: .system)
        previousButton.translatesAutoresizingMaskIntoConstraints = false
        previousButton.setImage(UIImage(systemName: "chevron.left.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44)), for: .normal)
        previousButton.tintColor = .white
        previousButton.addTarget(self, action: #selector(goToPrevious), for: .touchUpInside)
        navigationControlsView.addSubview(previousButton)
        
        // Next button
        nextButton = UIButton(type: .system)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setImage(UIImage(systemName: "chevron.right.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 44)), for: .normal)
        nextButton.tintColor = .white
        nextButton.addTarget(self, action: #selector(goToNext), for: .touchUpInside)
        navigationControlsView.addSubview(nextButton)
        
        NSLayoutConstraint.activate([
            navigationControlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationControlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navigationControlsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            navigationControlsView.heightAnchor.constraint(equalToConstant: 50),
            
            previousButton.leadingAnchor.constraint(equalTo: navigationControlsView.leadingAnchor, constant: 40),
            previousButton.centerYAnchor.constraint(equalTo: navigationControlsView.centerYAnchor),
            
            nextButton.trailingAnchor.constraint(equalTo: navigationControlsView.trailingAnchor, constant: -40),
            nextButton.centerYAnchor.constraint(equalTo: navigationControlsView.centerYAnchor)
        ])
    }
    
    private func createPillButton(title: String, icon: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: icon)
        config.title = title
        config.imagePadding = 4
        config.baseForegroundColor = .white
        config.background.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if let gradientLayer = navigationBarView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = navigationBarView.bounds
        }
    }
    
    // MARK: - Actions
    
    @objc private func showSettings() {
        let settingsView = SettingsViewWrapper(store: configStore)
        let hostingController = UIHostingController(rootView: settingsView)
        present(hostingController, animated: true)
    }
    
    @objc private func prependPage() {
        let viewModel = SamplePageViewModel.withRandomName()
        let page = SwipePage(view: SamplePageView(viewModel: viewModel), prefetchable: viewModel)
        pageSwipeVC.prepend(page)
        updateUI()
    }
    
    @objc private func appendPage() {
        let viewModel = SamplePageViewModel.withRandomName()
        let page = SwipePage(view: SamplePageView(viewModel: viewModel), prefetchable: viewModel)
        pageSwipeVC.append(page)
        updateUI()
    }
    
    @objc private func goToPrevious() {
        pageSwipeVC.goToPreviousPage()
    }
    
    @objc private func goToNext() {
        pageSwipeVC.goToNextPage()
    }
    
    private func updateUI() {
        let pages = pageSwipeVC.pages
        guard let currentPage = pageSwipeVC.currentPage,
        let currentIndex = pages.firstIndex(where: { $0.id == currentPage.id }) else { return }
        
        let displayIndex = currentIndex + 1
        
        pageLabel.text = "Page \(displayIndex) of \(pages.count)"
        pageCountLabel.text = "\(pages.count) pages"
        pageIndicatorLabel.text = "  \(displayIndex) / \(pages.count)  "
        
        previousButton.alpha = pageSwipeVC.hasPreviousPage ? 1.0 : 0.3
        previousButton.isEnabled = pageSwipeVC.hasPreviousPage
        
        nextButton.alpha = pageSwipeVC.hasNextPage ? 1.0 : 0.3
        nextButton.isEnabled = pageSwipeVC.hasNextPage
    }
    
    private func setControlsVisible(_ visible: Bool, animated: Bool) {
        let alpha: CGFloat = visible ? 1 : 0
        let offset: CGFloat = visible ? 0 : 20
        
        let animations = {
            self.navigationBarView.alpha = alpha
            self.navigationBarView.transform = CGAffineTransform(translationX: 0, y: visible ? 0 : -offset)
            
            self.bottomControlsView.alpha = alpha
            self.bottomControlsView.transform = CGAffineTransform(translationX: 0, y: visible ? 0 : offset)
            
            self.navigationControlsView.alpha = alpha
            self.navigationControlsView.transform = CGAffineTransform(translationX: 0, y: visible ? 0 : offset)
        }
        
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: animations)
        } else {
            animations()
        }
    }
}


