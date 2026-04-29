import FirebaseFirestore
import FirebaseStorage
import Foundation

final class FirestoreRecipeService: RecipeServicing {
    private var database: Firestore {
        Firestore.firestore()
    }

    private var storage: Storage {
        Storage.storage()
    }

    func observeRecipes(householdID: String, onChange: @escaping (Result<[Recipe], Error>) -> Void) -> RealtimeListening {
        let listener = database.collection("households")
            .document(householdID)
            .collection("recipes")
            .order(by: "savedDate", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let recipes = snapshot?.documents.compactMap(mapRecipe) ?? []
                onChange(.success(recipes))
            }

        return FirestoreRealtimeListener(listener: listener)
    }

    func observeTags(householdID: String, onChange: @escaping (Result<[Tag], Error>) -> Void) -> RealtimeListening {
        let listener = database.collection("households")
            .document(householdID)
            .collection("tags")
            .order(by: "normalizedName")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let tags = snapshot?.documents.compactMap(mapTag) ?? []
                onChange(.success(tags))
            }

        return FirestoreRealtimeListener(listener: listener)
    }

    func observeComments(householdID: String, recipeID: String, onChange: @escaping (Result<[Comment], Error>) -> Void) -> RealtimeListening {
        let listener = commentsCollection(householdID: householdID, recipeID: recipeID)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let comments = snapshot?.documents.compactMap(mapComment) ?? []
                onChange(.success(comments))
            }

        return FirestoreRealtimeListener(listener: listener)
    }

    func observeReviews(householdID: String, recipeID: String, onChange: @escaping (Result<[Review], Error>) -> Void) -> RealtimeListening {
        let listener = reviewsCollection(householdID: householdID, recipeID: recipeID)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let reviews = snapshot?.documents.compactMap(mapReview) ?? []
                onChange(.success(reviews))
            }

        return FirestoreRealtimeListener(listener: listener)
    }

    func createRecipe(input: RecipeCreationInput, householdID: String, author: UserProfile) async throws {
        let recipeID = UUID().uuidString
        let now = Date()
        let tags = try await ensureTags(tagNames: input.tagNames, householdID: householdID)
        let imageURL = try await uploadImageIfNeeded(input.imageData, householdID: householdID, recipeID: recipeID)

        let recipeRef = recipesCollection(householdID: householdID).document(recipeID)
        try await recipeRef.setData([
            "householdID": householdID,
            "title": input.title,
            "description": input.description,
            "sourceURL": input.sourceURL.isEmpty ? NSNull() : input.sourceURL,
            "imageURL": imageURL ?? NSNull(),
            "savedDate": Timestamp(date: now),
            "createdByUserID": author.id,
            "createdByName": author.displayName,
            "updatedAt": Timestamp(date: now),
            "tagIDs": tags.map(\.id),
            "tagNames": tags.map(\.name),
            "isFavorite": false,
            "averageRating": input.initialRating > 0 ? Double(input.initialRating) : NSNull(),
            "reviewCount": input.initialRating > 0 ? 1 : 0
        ])

        if !input.initialComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try await commentsCollection(householdID: householdID, recipeID: recipeID).document().setData([
                "recipeID": recipeID,
                "authorID": author.id,
                "authorName": author.displayName,
                "text": input.initialComment,
                "createdAt": Timestamp(date: now)
            ])
        }

        if input.initialRating > 0 {
            try await reviewsCollection(householdID: householdID, recipeID: recipeID).document(author.id).setData([
                "recipeID": recipeID,
                "authorID": author.id,
                "authorName": author.displayName,
                "rating": input.initialRating,
                "note": input.initialComment,
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ])
        }
    }

    func updateTags(recipe: Recipe, householdID: String, tagNames: [String]) async throws {
        let tags = try await ensureTags(tagNames: tagNames, householdID: householdID)
        try await recipesCollection(householdID: householdID).document(recipe.id).setData([
            "tagIDs": tags.map(\.id),
            "tagNames": tags.map(\.name),
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    func updateFavorite(recipe: Recipe, householdID: String, isFavorite: Bool) async throws {
        try await recipesCollection(householdID: householdID).document(recipe.id).setData([
            "isFavorite": isFavorite,
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
    }

    func addComment(recipe: Recipe, householdID: String, text: String, author: UserProfile) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        try await commentsCollection(householdID: householdID, recipeID: recipe.id).document().setData([
            "recipeID": recipe.id,
            "authorID": author.id,
            "authorName": author.displayName,
            "text": trimmed,
            "createdAt": Timestamp(date: Date())
        ])
    }

    func upsertReview(recipe: Recipe, householdID: String, rating: Int, note: String, author: UserProfile) async throws {
        let now = Date()
        let reviewRef = reviewsCollection(householdID: householdID, recipeID: recipe.id).document(author.id)
        let existingReview = try await reviewRef.getDocument()
        let createdAt = (existingReview.data()?["createdAt"] as? Timestamp)?.dateValue() ?? now

        try await reviewRef.setData([
            "recipeID": recipe.id,
            "authorID": author.id,
            "authorName": author.displayName,
            "rating": rating,
            "note": note,
            "createdAt": Timestamp(date: createdAt),
            "updatedAt": Timestamp(date: now)
        ])

        let reviews = try await reviewsCollection(householdID: householdID, recipeID: recipe.id).getDocuments().documents.compactMap(mapReview)
        let average = reviews.isEmpty ? nil : Double(reviews.map(\.rating).reduce(0, +)) / Double(reviews.count)

        try await recipesCollection(householdID: householdID).document(recipe.id).setData([
            "averageRating": average ?? NSNull(),
            "reviewCount": reviews.count,
            "updatedAt": Timestamp(date: now)
        ], merge: true)
    }

    private func recipesCollection(householdID: String) -> CollectionReference {
        database.collection("households").document(householdID).collection("recipes")
    }

    private func commentsCollection(householdID: String, recipeID: String) -> CollectionReference {
        recipesCollection(householdID: householdID).document(recipeID).collection("comments")
    }

    private func reviewsCollection(householdID: String, recipeID: String) -> CollectionReference {
        recipesCollection(householdID: householdID).document(recipeID).collection("reviews")
    }

    private func ensureTags(tagNames: [String], householdID: String) async throws -> [Tag] {
        let cleaned = Array(Set(tagNames.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })).sorted()

        let now = Date()
        let tagsRef = database.collection("households").document(householdID).collection("tags")

        for tagName in cleaned {
            let normalized = tagName.normalizedTag
            try await tagsRef.document(normalized).setData([
                "householdID": householdID,
                "name": tagName,
                "normalizedName": normalized,
                "createdAt": Timestamp(date: now),
                "updatedAt": Timestamp(date: now)
            ], merge: true)
        }

        return cleaned.map {
            Tag(id: $0.normalizedTag, householdID: householdID, name: $0, normalizedName: $0.normalizedTag, createdAt: now, updatedAt: now)
        }
    }

    private func uploadImageIfNeeded(_ data: Data?, householdID: String, recipeID: String) async throws -> String? {
        guard let data else { return nil }

        let reference = storage.reference(withPath: "households/\(householdID)/recipes/\(recipeID).jpg")
        _ = try await reference.putDataAwaitingResult(data)
        return try await reference.downloadURLAwaitingResult().absoluteString
    }
}

private final class FirestoreRealtimeListener: RealtimeListening {
    private var listener: ListenerRegistration?

    init(listener: ListenerRegistration) {
        self.listener = listener
    }

    func remove() {
        listener?.remove()
        listener = nil
    }

    deinit {
        remove()
    }
}

private func mapRecipe(_ document: QueryDocumentSnapshot) -> Recipe {
    let data = document.data()
    return Recipe(
        id: document.documentID,
        householdID: data["householdID"] as? String ?? "",
        title: data["title"] as? String ?? "Untitled Recipe",
        description: data["description"] as? String ?? "",
        sourceURL: data["sourceURL"] as? String,
        imageURL: data["imageURL"] as? String,
        savedDate: (data["savedDate"] as? Timestamp)?.dateValue() ?? Date(),
        createdByUserID: data["createdByUserID"] as? String ?? "",
        createdByName: data["createdByName"] as? String ?? "",
        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
        tagIDs: data["tagIDs"] as? [String] ?? [],
        tagNames: data["tagNames"] as? [String] ?? [],
        isFavorite: data["isFavorite"] as? Bool ?? false,
        averageRating: data["averageRating"] as? Double,
        reviewCount: data["reviewCount"] as? Int ?? 0
    )
}

private func mapTag(_ document: QueryDocumentSnapshot) -> Tag {
    let data = document.data()
    return Tag(
        id: document.documentID,
        householdID: data["householdID"] as? String ?? "",
        name: data["name"] as? String ?? "",
        normalizedName: data["normalizedName"] as? String ?? "",
        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    )
}

private func mapComment(_ document: QueryDocumentSnapshot) -> Comment {
    let data = document.data()
    return Comment(
        id: document.documentID,
        recipeID: data["recipeID"] as? String ?? "",
        authorID: data["authorID"] as? String ?? "",
        authorName: data["authorName"] as? String ?? "",
        text: data["text"] as? String ?? "",
        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
    )
}

private func mapReview(_ document: QueryDocumentSnapshot) -> Review {
    let data = document.data()
    return Review(
        id: document.documentID,
        recipeID: data["recipeID"] as? String ?? "",
        authorID: data["authorID"] as? String ?? "",
        authorName: data["authorName"] as? String ?? "",
        rating: data["rating"] as? Int ?? 0,
        note: data["note"] as? String ?? "",
        createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
        updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
    )
}
