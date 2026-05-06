# Firestore Schema

This starter uses a cooking-book-centric schema so multiple users can collaborate on the same recipe collection with simple Firestore listeners.

## Collections

### `users/{userId}`

```json
{
  "displayName": "Taylor",
  "email": "taylor@example.com",
  "activeHouseholdID": "household_123",
  "householdIDs": ["household_123"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### `households/{householdId}`

```json
{
  "name": "Sunday Dinner",
  "inviteCode": "A1B2C3",
  "memberIDs": ["user_1", "user_2"],
  "createdByUserID": "user_1",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### `households/{householdId}/tags/{tagId}`

`tagId` is the normalized tag string, for example `weeknight-dinner`.

```json
{
  "householdID": "household_123",
  "name": "Weeknight Dinner",
  "normalizedName": "weeknight-dinner",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### `households/{householdId}/recipes/{recipeId}`

```json
{
  "householdID": "household_123",
  "title": "Creamy Tomato Pasta",
  "description": "Imported or manually added recipe content...",
  "sourceURL": "https://example.com/recipe",
  "imageURL": "https://firebasestorage.googleapis.com/...",
  "savedDate": "timestamp",
  "createdByUserID": "user_1",
  "createdByName": "Taylor",
  "updatedAt": "timestamp",
  "tagIDs": ["pasta", "weeknight-dinner"],
  "tagNames": ["Pasta", "Weeknight Dinner"],
  "averageRating": 4.5,
  "reviewCount": 2
}
```

### `households/{householdId}/recipes/{recipeId}/comments/{commentId}`

```json
{
  "recipeID": "recipe_123",
  "authorID": "user_2",
  "authorName": "Jordan",
  "text": "Tried this with rigatoni and added basil.",
  "createdAt": "timestamp"
}
```

### `households/{householdId}/recipes/{recipeId}/reviews/{userId}`

The review document ID is the author user ID so each user keeps one editable rating per recipe.

```json
{
  "recipeID": "recipe_123",
  "authorID": "user_2",
  "authorName": "Jordan",
  "rating": 5,
  "note": "Would absolutely make this again.",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Storage

Recipe images upload to:

```text
households/{householdId}/recipes/{recipeId}.jpg
```

## Security rule direction

At minimum, production rules should ensure:

- A user can read/write only their own `users/{userId}` document.
- A user can read a cookbook only if their UID is in `memberIDs`.
- A user can read/write recipes, comments, reviews, and tags only within cookbooks they belong to.
- A user can write only their own review document at `reviews/{userId}`.

## Why this shape

- Cooking-book-level subcollections make it easy to subscribe to a shared recipe set.
- Tags live per cookbook so filters stay collaborative.
- Denormalized `tagNames`, `averageRating`, and `reviewCount` keep the home screen fast.
- Comments and reviews remain queryable and independently attributable to users.
