//
//  PostService.swift
//  FirebaseTestProject
//
//  Created by John Royal on 8/21/21.
//

import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseStorage

// MARK: - PostServiceProtocol

protocol PostServiceProtocol {
    var user: User { get }
    
    func fetchPosts() async throws -> [Post]
    func fetchPosts(by author: User) async throws -> [Post]
    func fetchFavoritePosts() async throws -> [Post]
    
    func create(_ editablePost: Post.EditableFields) async throws
    func delete(_ post: Post) async throws
    
    func favorite(_ post: Post) async throws
    func unfavorite(_ post: Post) async throws
    
    func canDelete(_ post: Post) -> Bool
}

extension PostServiceProtocol {
    func canDelete(_ post: Post) -> Bool {
        user.id == post.author.id
    }
}

// MARK: - PostFilter

enum PostFilter {
    case author(User)
    case favorites
}

extension PostServiceProtocol {
    func fetchPosts(matching filter: PostFilter?) async throws -> [Post] {
        switch filter {
        case .none:
            return try await fetchPosts()
        case let .author(author):
            return try await fetchPosts(by: author)
        case .favorites:
            return try await fetchFavoritePosts()
        }
    }
}

// MARK: - PostService

struct PostService: PostServiceProtocol {
    let user: User
    let postsReference = Firestore.firestore().collection("posts")
    let favoritesReference = Firestore.firestore().collection("favorites")
    let imageHelper = ImageStorageAdapter(namespace: "posts")
    
    func fetchPosts() async throws -> [Post] {
        let query = postsReference.order(by: "timestamp", descending: true)
        return try await fetchPosts(from: query)
    }
    
    func fetchPosts(by author: User) async throws -> [Post] {
        let query = postsReference
            .order(by: "timestamp", descending: true)
            .whereField("author.id", isEqualTo: author.id)
        return try await fetchPosts(from: query)
    }
    
    func fetchFavoritePosts() async throws -> [Post] {
        let favorites = try await fetchFavorites()
        if favorites.isEmpty {
            // Skip the Firestore query and return an empty array of posts.
            // This is a workaround for Firestore crashing when performing a where-in query with no allowed values.
            return []
        }
        return try await postsReference
            .order(by: "timestamp", descending: true)
            .whereField("id", in: favorites)
            .getDocuments(as: Post.self)
            .map {
                Post($0, isFavorite: true)
            }
    }
    
    func create(_ editablePost: Post.EditableFields) async throws {
        let postReference = postsReference.document()
        var post = Post(
            title: editablePost.title,
            content: editablePost.content,
            author: user,
            id: postReference.documentID
        )
        if let image = editablePost.image {
            post.imageURL = try await imageHelper.createImage(image, named: post.id)
        }
        try await postReference.setData(from: post)
    }
    
    func delete(_ post: Post) async throws {
        precondition(canDelete(post), "User not authorized to delete post")
        
        let postReference = postsReference.document(post.id)
        try await postReference.delete()
        
        guard post.imageURL != nil else { return }
        try await imageHelper.deleteImage(named: post.id)
    }
    
    func favorite(_ post: Post) async throws {
        let favorite = Favorite(postID: post.id, userID: user.id)
        try await favoritesReference.document().setData(from: favorite)
    }
    
    func unfavorite(_ post: Post) async throws {
        let snapshot = try await favoritesReference
            .whereField("postID", isEqualTo: post.id)
            .whereField("userID", isEqualTo: user.id)
            .getDocuments()
        assert(snapshot.count == 1, "Expected 1 favorite reference but found \(snapshot.count)")
        guard let favoriteReference = snapshot.documents.first?.reference else { return }
        try await favoriteReference.delete()
    }
}

private extension PostService {
    func fetchPosts(from query: Query) async throws -> [Post] {
        async let posts = query.getDocuments(as: Post.self)
        let favorites = try await fetchFavorites()
        return try await posts.map {
            Post($0, isFavorite: favorites.contains($0.id))
        }
    }
    
    func fetchFavorites() async throws -> [Post.ID] {
        return try await favoritesReference
            .whereField("userID", isEqualTo: user.id)
            .getDocuments(as: Favorite.self)
            .map(\.postID)
    }
    
    struct Favorite: Codable {
        let postID: Post.ID
        let userID: User.ID
    }
}

private extension Post {
    init(_ post: Post, isFavorite: Bool) {
        self.title = post.title
        self.content = post.content
        self.author = post.author
        self.id = post.id
        self.timestamp = post.timestamp
        self.imageURL = post.imageURL
        self.isFavorite = isFavorite
    }
}
