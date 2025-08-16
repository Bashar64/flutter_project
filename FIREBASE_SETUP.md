# Firebase Setup Instructions

This Flutter app has been updated to use Firebase for authentication and task storage. Follow these steps to complete the Firebase setup:

## 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter your project name
4. Follow the setup wizard

## 2. Enable Authentication

1. In your Firebase project, go to **Authentication**
2. Click **Get started**
3. Go to **Sign-in method** tab
4. Enable **Email/Password** authentication

## 3. Enable Firestore Database

1. In your Firebase project, go to **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (for development)
4. Select a location for your database

## 4. Configure Firebase for Your App

### For Android:

1. In Firebase Console, click **Add app** and select Android
2. Enter package name: `com.example.flutter_project`
3. Download the `google-services.json` file
4. Replace the placeholder file at `android/app/google-services.json` with your downloaded file

### For iOS (if needed):

1. In Firebase Console, click **Add app** and select iOS
2. Enter bundle ID: `com.example.flutterProject`
3. Download the `GoogleService-Info.plist` file
4. Add it to your iOS project

### For Web (if needed):

1. In Firebase Console, click **Add app** and select Web
2. Register your app and copy the configuration
3. Update `lib/firebase_options.dart` with your actual configuration values

## 5. Update Configuration Files

Replace the placeholder values in:

- `lib/firebase_options.dart` - Update with your actual Firebase configuration
- `android/app/google-services.json` - Replace with your downloaded file

## 6. Firebase Security Rules

For development, you can use these Firestore rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/tasks/{taskId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## Features Implemented

✅ **Removed Google Maps** - No longer using Google Maps for location picking
✅ **Added Calendar View** - Interactive calendar using `table_calendar` package
✅ **Firebase Authentication** - Email/password sign-up and login
✅ **Firestore Database** - Tasks are stored per user in Firestore
✅ **Account Management** - Users can create accounts and login/logout
✅ **Task Management** - Add, edit, and delete tasks with Firebase persistence

## Usage

1. **Sign Up**: Create a new account with email and password
2. **Login**: Sign in with your credentials
3. **View Tasks**: See all your tasks in a list view
4. **Calendar View**: Click the calendar icon to view tasks in calendar format
5. **Add Tasks**: Click the + button to add new tasks
6. **Edit Tasks**: Tap on any task to edit it
7. **Delete Tasks**: Swipe left on tasks in list view or use delete button in calendar view

## Running the App

```bash
flutter pub get
flutter run
```

Note: Make sure to complete the Firebase setup before running the app, otherwise authentication and data storage will not work.
