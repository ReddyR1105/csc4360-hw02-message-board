# Common Room

CSC 4360 Homework 02 · The Message Board Vault Hunt

Common Room is an Android message board built with Flutter Material 3, Firebase Authentication, and Cloud Firestore. Members register, sign in, and read a live reverse-chronological board. Only an author can edit or delete their posts.

## Build and install

Requires Flutter 3.47.4 with the Android SDK, Android SDK platform tools and an emulator or device. Commands run from the repository root.

```sh
flutter doctor -v
flutter devices
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

The default Android build uses the generated Android configuration for `csc4360-hw02-common-room-rr`. The two Firebase configuration files carry public client identifiers. The app uses the FlutterFire-generated `DefaultFirebaseOptions.currentPlatform` during splash initialization. To bind a different project, enable Email/Password in Firebase Authentication, create a Standard default Firestore database in locked mode, and run the following commands with the Firebase CLI on PATH.

```sh
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project YOUR_PROJECT_ID --platforms android --android-package-name edu.gsu.csc4360.message_board
firebase deploy --only firestore:rules --project YOUR_PROJECT_ID
```

The submitted APK is signed using a dedicated local key. To sign independently, create an Android upload key and create `android/key.properties` with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. A local release-mode build without those properties uses Flutter's Android debug key. Android requires the same signing certificate for an in-place update. Uninstalling clears local app state.

## Code map

| Location | Responsibility |
| --- | --- |
| `lib/main.dart`, `screens/splash_screen.dart` | Firebase startup, Material theme, splash state and retry |
| `lib/services/auth_service.dart`, `screens/auth_gate.dart`, `screens/entry_form.dart` | Email/password, one auth-state stream, routing and missing-profile recovery |
| `lib/services/user_record_service.dart` | Profile read and create-once transaction |
| `lib/models/board_models.dart`, `lib/services/board_service.dart` | Typed records, live query, owner mutations, durable post retries |
| `lib/screens/board_screen.dart`, `lib/validation.dart` | Composer, message cards, CRUD prompts and client validation |
| `firestore.rules`, `firebase.json`, `firebase/` | Access policy, emulator wiring, isolated fixtures and tests |
| `test/widget_test.dart` | Widget and validation tests |

## Authentication and live data

The splash stores one initialization future and starts another when Retry is tapped. The auth gate subscribes to `authStateChanges()` once. A signed-out user sees the sign-in and registration forms. After account creation, a transaction creates the profile if missing. If profile saving fails, the account remains valid and the profile gate allows recovery under the same UID. The app opens the board after a profile exists. Firebase Auth manages Android session persistence.

The board uses a single stream from `messages.orderBy('createdAt', descending: true).snapshots()`. It shows loading, empty and error states and unsubscribes when the widget leaves the tree. Edit updates text and edit time. Delete removes the selected message after confirmation. Other clients receive these changes through their own streams.

## Firestore schema

| Path and field | Type | Writer and purpose |
| --- | --- | --- |
| `users/{uid}.uid` | String | Member creates own UID, which must match the document ID |
| `firstName`, `lastName` | String | Profile creator supplies names, each up to 40 characters |
| `role` | String | Fixed `member` on creation, with no authorization effect |
| `registrationDateTime` | Timestamp | Firestore server time at profile creation |
| `messages/{id}.text` | String | Owner posts or edits nonblank text up to 500 characters |
| `authorUid` | String | Authenticated UID at creation, immutable |
| `authorName` | String | Profile first and last names checked by Rules, immutable |
| `createdAt` | Timestamp | Firestore server time at creation, immutable, orders the board |
| `editedAt` | Null or timestamp | Initially null, then server time when the owner edits |
| `users/{uid}/postReceipts/{id}.createdAt` | Timestamp | Created atomically with the same-ID post, preserves evidence of that logical submission |

An authenticated member can read messages and individually get their own profile or receipt. Profiles and receipts are create-once. Message create requires the posting account, its profile name and a matching receipt created in the same transaction. Only the owner can update allowed fields or delete a message. The UI also hides the author menu from other members.

A post stores a generated document ID and its original text in Android preferences before attempting the transaction. The transaction checks the receipt and writes the message and receipt together. Retry after a failure or process death uses the saved ID. Concurrent attempts converge on one receipt, and a late retry after deletion sees the receipt without recreating the post. Post transactions need a network connection. If one fails offline, use Retry post after reconnecting. Ordinary Firestore reads may use the SDK cache and edits/deletes can wait for synchronization. Each successful unique post costs one extra document and write for the receipt. The app keeps one pending post per account and project. The saved text stays on the device until acknowledgment or app data removal.

## Emulator Explorer and automated verification

Use Node 24, pnpm 11 and Java 21 or newer. All fixtures use the no-cloud project `demo-message-board`.

```sh
pnpm install --frozen-lockfile
pnpm exec firebase emulators:exec --project demo-message-board --only auth,firestore "node --test --test-concurrency=1 firebase/integration-tests/board.test.mjs firebase/rules-tests/ownership.test.mjs"
pnpm exec firebase emulators:start --project demo-message-board --only auth,firestore
```

With the emulators running, set a disposable `DEMO_PASSWORD` of at least eight characters in your local environment and run `pnpm seed`. Sign in as `maya@example.test` or `jordan@example.test` with the chosen fixture password. The dashboard runs at `http://127.0.0.1:4000`, Auth at port 9099, and Firestore at port 8180. Tests clear Firestore fixtures, so use a fresh demo suite before seeding. Android Studio emulators connect to the host via `10.0.2.2`.

```sh
flutter run -d emulator-5554 --dart-define=USE_EMULATORS=true
```

The rules suite tests allowed CRUD, signed-out reads, cross-user denial, forged ownership, profile privacy, role restrictions, schema validation, and receipt pairing. The integration suite signs in two clients using Auth, observes live CRUD and ordering, and repeats one post concurrently. The release test matrix and screenshot evidence accompany the APK.

## Manual release gate

On two independent Android devices or AVDs, install the same release APK. Open the app, register distinct accounts, and confirm each UID's five-field document in Firestore. Leave both boards open while A creates, changes and deletes a message. Verify B sees those changes automatically and cannot see A's owner controls. Double-tap Post; count the resulting document by its ID. Attempt to send in airplane mode, force-stop and reopen, reconnect and retry. Sign out and sign back in. Restart the app and verify Firebase restores the session. Use the isolated test suite to reproduce security denials independently of UI visibility.

## Limits and repository

The app targets Android and uses one board stream for this assignment. A large deployment should paginate older messages and bound the live query. The assignment build has no email verification, account management, rate limiting or moderation. Build and test fixtures contain no signing secrets or cloud accounts.

[GitHub source repository](https://github.com/ReddyR1105/csc4360-hw02-message-board)
