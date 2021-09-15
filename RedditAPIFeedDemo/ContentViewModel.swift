//
//  ContentViewModel.swift
//  RedditAPIFeedDemo
//
//  Created by Jordan Trana on 9/14/21.
//

import Foundation
import Combine
import CoreData

class ContentViewModel<T: Scheduler>: ObservableObject {
    
    let contentViewModelRequestDelegate = ContentViewModelRequestDelegate()
    @Published var posts = [Post]()
    @Published var loading:Bool = false
    private var page = 1
    private var subscriptions = Set<AnyCancellable>()
    
    init(scheduler: T) {
        contentViewModelRequestDelegate.setup(onDidChangeContent:{ posts in
            self.posts = posts ?? []
        })
    }
    
    func loadMore() {
        guard !RedditAPI.shared.isLoading else { return }
        page += 1
        RedditAPI.shared.refreshData()
    }
}

class ContentViewModelRequestDelegate: NSObject, NSFetchedResultsControllerDelegate {
    
    var resultsController: NSFetchedResultsController<Posts>!
    var onDidChangeContent:(([Post]?)->())? = nil
    
    override init() {
        resultsController = RedditAPI.shared.posts()
    }
    
    func setup(onDidChangeContent:(([Post]?)->())?) {
        resultsController.delegate = self
        self.onDidChangeContent = onDidChangeContent
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        guard let rawPosts = resultsController.fetchedObjects else {return}
        var posts:[Post] = []
        for rawPost in rawPosts {
            
            if let post = Post(title: rawPost.title,
                               textOnly: rawPost.textPost,
                           image: rawPost.imageContent,
                           width: Int(rawPost.thumbnail_width),
                           height: Int(rawPost.thumbnail_height),
                           commentCount: rawPost.postsToComments?.count ?? 0,
                           score: Int(rawPost.score)) {
                posts.append(post)
            }
        }
        onDidChangeContent?(posts)
    }
    
}
