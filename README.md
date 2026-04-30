# WeCookin

WeCookin is a SwiftUI iPhone app for saving recipes from websites, Instagram posts, and other apps through the iOS Share Sheet. This starter focuses on an MVP with Firebase Authentication, Cloud Firestore, a shared household model, and a Share Extension that saves import drafts into an App Group for the main app to ingest.

## What is included

- SwiftUI app shell with login and sign up
- Household creation and invite-code join flow
- Home screen with search, tag filters, and recipe cards
- Manual recipe creation flow with tags, notes, rating, and optional image
- Recipe detail screen with tag editing, comments, reviews, and external sharing
- iOS Share Extension that accepts shared text, URLs, and images
- Shared draft storage through an App Group for extension-to-app handoff
- Firebase-ready service layer with Auth, Firestore, and Storage integration

## Project structure

```text
WeCookin/
├── project.yml
├── Config/
├── Docs/
│   └── FirestoreSchema.md
├── RecipeCore/
│   ├── Models/
│   ├── Services/
│   └── Utilities/
├── WeCookin/
│   ├── App/
│   ├── Assets.xcassets/
│   ├── Design/
│   ├── Services/
│   ├── ViewModels/
│   └── Views/
└── ShareExtension/
```

## Architecture

- `RecipeCore` contains shared models and share-import storage used by both targets.
- `WeCookin` contains the SwiftUI app, view models, theme, and Firebase-backed services.
- `ShareExtension` contains the UIKit host controller and SwiftUI import flow for the Share Extension.
- Firestore is the source of truth for households, recipes, comments, reviews, and tags.
- The Share Extension saves a `RecipeDraft` into the shared App Group container. The main app imports those pending drafts into Firestore when the home screen starts.

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you do not already have it.
2. Open [project.yml](/Users/szy/Documents/GitHub/recipe/project.yml) and replace:
   - `com.example.wecookin`
   - `group.com.example.wecookin`
3. Create a Firebase project.
4. Add an iOS app in Firebase for the main app bundle identifier.
5. Download `GoogleService-Info.plist` and add it to the `WeCookin` app target in Xcode.
6. In Firebase Console, enable:
   - Authentication with Email/Password
   - Cloud Firestore
   - Cloud Storage
7. In Apple Developer / Xcode Signing & Capabilities, enable:
   - App Groups for both the app and the Share Extension
   - The same group identifier used in [AppConstants.swift](/Users/szy/Documents/GitHub/recipe/RecipeCore/Utilities/AppConstants.swift:3)
8. Generate the Xcode project:

```bash
xcodegen generate
```

9. Open `WeCookin.xcodeproj`.
10. Add a second Firebase app entry only if you decide later to use Firebase directly inside the Share Extension. The current MVP does not require that.
11. Build and run the main app once to create a user account.
12. In the simulator or on-device, enable the Share Extension in the iOS Share Sheet if it does not appear automatically under “More”.

## Share Extension behavior

- The extension accepts text, URLs, images, and whatever metadata the source app exposes through `NSItemProvider`.
- The extension shows:
  - an import review step
  - a required add-tags step
  - save into the shared App Group draft store
- The main app imports saved drafts into Firestore when the home screen loads.

## Instagram and third-party sharing limitations

- Instagram often shares only a caption snippet, a link, or a thumbnail instead of full post metadata.
- Many third-party apps do not expose Open Graph title, image, or description to extensions.
- Some websites/apps share only plain text or a URL, so title and description inference may be approximate.
- Because of those platform limits, the extension includes editable fields before save.

## MVP assumptions

- Email/password auth is sufficient for the first build.
- One active household per user is supported in the UI, even though the data model supports multiple household memberships.
- Recipes are stored under a household subcollection in Firestore.
- Ratings are 1 through 5 stars.
- Comments and reviews are separate records so households can keep lightweight discussion and rating history.
- Share imports are finalized by the main app after extension save, rather than writing directly to Firestore from the extension.

## Recommended next steps

- Add a proper invite screen showing the current household code inside the home view.
- Add HTML/Open Graph parsing for web URLs fetched inside the main app after import.
- Add offline caching and optimistic local persistence.
- Add edit/delete recipe flows and household switching.
- Add image resizing and duplicate detection for imports.
