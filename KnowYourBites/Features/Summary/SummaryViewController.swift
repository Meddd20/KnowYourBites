//
//  SummaryViewController.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 18/09/25.
//

import UIKit

class SummaryViewController: UIViewController {
    private let result: SummaryResult
    private let productImage: UIImage
    
    private lazy var text = UILabel()
    
    init(
        result: SummaryResult,
         productImage: UIImage
    ) {
        self.result = result
        self.productImage = productImage
        super.init(nibName: nil, bundle: nil)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "Summary"
        
        view.addSubview(text)
        
        text.text = result.roast
        text.font = .systemFont(ofSize: 17, weight: .medium)
        text.textColor = .black
        text.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            text.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            text.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        
    }
}
