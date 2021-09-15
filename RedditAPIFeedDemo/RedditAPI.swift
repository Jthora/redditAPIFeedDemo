//
//  RedditAPI.swift
//  RedditAPIFeedDemo
//
//  Created by Jordan Trana on 9/14/21.
//

import CoreData
import Foundation

class RedditAPI {
    
    private let session = URLSession(configuration: URLSessionConfiguration.ephemeral)
    private let persistentContainer: NSPersistentContainer
    
    var isLoading:Bool = false
    var afterLink:String? = nil
    var onAfterLinkLoadComplete:(()->())? = nil
    
    private static let dataURL = "https://www.reddit.com/.json"
    private static let nextDataURL = "https://www.reddit.com/.json?after="
    
    static let shared = RedditAPI()
    
    private init() {
        persistentContainer = NSPersistentContainer(name: "Model")
        persistentContainer.loadPersistentStores(completionHandler: { (storeDescription, error) in
            self.refreshData()
        })
    }
    
    func refreshData(onComplete:(()->())? = nil) {
        
        guard !isLoading else {return}
        isLoading = true
        
        let afterLinkString = afterLink == nil ? "" : "?after=\(afterLink ?? "")"
        let dataURL = URL(string: "\(RedditAPI.dataURL)\(afterLinkString)")!
        let request = URLRequest(url: dataURL)
        
        let dataTask = session.dataTask(with: request) { (data, response, error) in
            guard error == nil else {
                print("Error refreshing data \(error!)")
                return
            }
            guard let someResponse = response as? HTTPURLResponse, someResponse.statusCode >= 200, someResponse.statusCode < 300  else {
                print("Invalid response or non-200 status code")
                return
            }
            guard let someData = data else {
                return
            }
            guard let postValues = (try? JSONSerialization.jsonObject(with: someData, options: [.allowFragments])) as? Dictionary<String, Any> else {
                return
            }
            let postInfo = postValues["data"]
            self.afterLink = (postInfo as! Dictionary<String, Any>)["after"] as? String
            self.parseData(postData: postInfo as! Dictionary<String, Any>, type: "posts")
            
            self.onAfterLinkLoadComplete?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isLoading = false
            }
        }
        dataTask.resume()
    }
    
    private func parseData(postData: Dictionary<String, Any>, type: String) {
        let context = persistentContainer.viewContext
        
        context.perform {
            
            let fetchRequest: NSFetchRequest<Posts> = Posts.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "type == %@", type)
            var allPosts = Set((try? context.fetch(fetchRequest)) ?? [])
            
            let postList = postData["children"] as! [Dictionary<String,Any>]
            
            for postValues in postList {
                let postUnwrap = postValues["data"] as! Dictionary<String,Any>
                
                let title = (postUnwrap["title"] as! String).replacingOccurrences(of: "&amp;", with: "&")
                let score = postUnwrap["score"] as! Int32
                let subreddit = postUnwrap["subreddit"] as! String
                let permalink = "https://www.reddit.com\(postUnwrap["permalink"]!)"
                
                let textContent = postUnwrap["selftext"] as! String
                
                let thumbnail = postUnwrap["thumbnail"] as! String
                let thumbnail_url = postUnwrap["thumbnail_url"] as? String
                let thumbnail_width = postUnwrap["thumbnail_width"] as? Int32
                let thumbnail_height = postUnwrap["thumbnail_height"] as? Int32
                
                let imageContent = postUnwrap["url"] as! String
                var newImageContent = imageContent.replacingOccurrences(of: "&amp;", with: "&")
                
                if newImageContent.range(of:"imgur.com") != nil{
                    newImageContent.append(".jpg")
                }
                
                var isImage:Bool = false
                if newImageContent.contains(".jpg") || newImageContent.contains(".png") || newImageContent.contains(".gif") {
                    isImage = true
                }
                    
                let author = postUnwrap["author"] as! String
                
                let existingPost = allPosts.first(where: { $0.title == title && $0.type == type})
                let posts: Posts
                if let someExistingPost = existingPost {
                    posts = someExistingPost
                    
                    allPosts.remove(someExistingPost)
                }
                else {
                    posts = Posts(context: context)
                }
                
                posts.score = score
                posts.title = title
                posts.author = author
                posts.type = type
                posts.subreddit = subreddit
                posts.permalink = permalink
                posts.textContent = textContent
                posts.imageContent = newImageContent
                posts.thumbnail_url = thumbnail_url ?? "null"
                posts.thumbnail_width = thumbnail_width ?? -1
                posts.thumbnail_height = thumbnail_height ?? -1
                
                if thumbnail == "self" || !isImage {
                    posts.textPost = true
                } else {
                    posts.textPost = false
                }
                
                let commentEncoded = "\(permalink.addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed)!).json"
                let commentURL = URL(string: commentEncoded)!
                let commentURLRequest = URLRequest(url: commentURL)

                let commentDataTask = self.session.dataTask(with: commentURLRequest) { (data, response, error) in
                    
                    guard error == nil else {
                        print("Error refreshing data \(error!)")
                        return
                    }
                    
                    guard let someResponse = response as? HTTPURLResponse, someResponse.statusCode >= 200, someResponse.statusCode < 300  else {
                        print("Invalid response or non-200 status code")
                        return
                    }
                    
                    guard let someData = data else {
                        return
                    }
                    
                    guard let commentValues = (try? JSONSerialization.jsonObject(with: someData, options: [.allowFragments])) as? [Any] else {
                        return
                    }
                    
                    let commentInfo = commentValues[1] as! Dictionary<String,Any>
                    let commentsTemp = commentInfo["data"] as! Dictionary<String,Any>
                    let commentsArray = commentsTemp["children"] as! [Dictionary<String,Any>]
                    
                    self.parseComments(commentsArray: commentsArray, context: context, posts: posts)
                }
                
                commentDataTask.resume()
                
            }
            
            for somePost in allPosts {
                context.delete(somePost)
            }
            
            try! context.save()
            
        }
    }
    
    func parseComments(commentsArray: [Dictionary<String,Any>], context: NSManagedObjectContext, posts: Posts) {
        context.perform {
            if let commentValues = posts.postsToComments as? Set<Comments> {
                commentValues.forEach({ context.delete($0) })
            }

            for someCommentValue in commentsArray {
                let comment = Comments(context: context)
                comment.author = (someCommentValue["data"] as? Dictionary<String,Any>)?["author"] as! String?
                comment.content = (someCommentValue["data"] as? Dictionary<String,Any>)?["body"] as! String?
                do {
                    guard let score = (someCommentValue["data"] as? Dictionary<String,Any>)?["score"] as! Int32? else {
                        continue
                    }
                    comment.score = score
                }
                comment.commentsToPosts = posts
            }
            try! context.save()
        }
    }
    
    func savePost(post: Posts) {
        let context = persistentContainer.viewContext
        context.perform {
            let fetchRequest: NSFetchRequest<History> = History.fetchRequest()
            var allHistory = Set((try? context.fetch(fetchRequest)) ?? [])
            
            let existingHistory = allHistory.first(where: { $0.title == post.title})
            let history: History
            if let someExistingHistory = existingHistory {
                history = someExistingHistory
                
                allHistory.remove(someExistingHistory)
            }
            else {
                history = History(context: context)
            }
            
            history.author = post.author
            history.imageContent = post.imageContent
            history.permalink = post.permalink
            history.score = post.score
            history.subreddit = post.subreddit
            history.textContent = post.textContent
            history.textPost = post.textPost
            history.title = post.title
            history.thumbnail_url = post.thumbnail_url
            history.thumbnail_width = post.thumbnail_width
            history.thumbnail_height = post.thumbnail_height
        
            if let commentValues = post.postsToComments as? Set<Comments> {
                for comment in commentValues{
                    comment.commentsToHistory = history
                }
            }
            history.time = Date()
        
            try! context.save()
        }
    }
    
    func deleteSaved() {
        let context = persistentContainer.viewContext
        context.perform {
            let fetchRequest: NSFetchRequest<History> = History.fetchRequest()
            let allHistory = Set((try? context.fetch(fetchRequest)) ?? [])
            
            for someHistory in allHistory {
                context.delete(someHistory)
            }
            
            try! context.save()
        }
    }
    
    func posts() -> NSFetchedResultsController<Posts> {
        let fetchRequest: NSFetchRequest<Posts> = Posts.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "type == %@", "posts")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "score", ascending: false)]
        
        return fetchedResultsController(for: fetchRequest)
    }
    
    func savedPosts() -> NSFetchedResultsController<History> {
        let fetchRequest: NSFetchRequest<History> = History.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "score", ascending: false)]
        
        return fetchedResultsController(for: fetchRequest)
    }
    
    func comments(for posts: Posts) -> NSFetchedResultsController<Comments> {
        let fetchRequest: NSFetchRequest<Comments> = Comments.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "commentsToPosts == %@", posts)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "score", ascending: false)]
        
        return fetchedResultsController(for: fetchRequest)
    }
    
    func commentsForSaved(for history: History) -> NSFetchedResultsController<Comments> {
        let fetchRequest: NSFetchRequest<Comments> = Comments.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "commentsToHistory == %@", history)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "score", ascending: false)]
        
        return fetchedResultsController(for: fetchRequest)
    }
    
    func fetchedResultsController<T>(for fetchRequest: NSFetchRequest<T>) -> NSFetchedResultsController<T> {
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: persistentContainer.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        do {
            try fetchedResultsController.performFetch()
        }
        catch let error {
            fatalError("Could not perform fetch for fetched results controller: \(error)")
        }
        
        return fetchedResultsController
    }

}
