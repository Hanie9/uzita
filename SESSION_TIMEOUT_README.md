# Automatic Session Timeout Implementation

This implementation provides automatic logout functionality that logs users out after 15 minutes of inactivity when they're outside the app.

## Features

- **15-minute session timeout**: Users are automatically logged out after 15 minutes of inactivity
- **App lifecycle awareness**: Tracks when the app goes to background/foreground
- **Activity tracking**: Monitors user interactions to reset the timeout
- **Direct logout**: Users are logged out immediately after 15 minutes of inactivity
- **Session persistence**: Maintains session state across app restarts
- **Secure cleanup**: Clears all authentication data on logout

## How It Works

### 1. Session Manager (`lib/services/session_manager.dart`)

The `SessionManager` class is a singleton that handles all session-related functionality:

- **Session tracking**: Monitors session start time and last activity
- **Timer management**: Manages session timeout and inactivity timers
- **App lifecycle handling**: Responds to app state changes
- **Direct logout**: Handles automatic logout without warnings

### 2. Main App Integration (`lib/main.dart`)

The `SessionTimeoutWrapper` wraps the entire app and:

- Initializes the session manager
- Listens to session state changes
- Handles app lifecycle events
- Tracks user interactions (touch, mouse, etc.)

### 3. Login Integration (`lib/screens/login_screen.dart`)

When a user successfully logs in:

```dart
// Start session management
await SessionManager().startSession();
```

### 4. Logout Integration (`lib/screens/home_screen.dart`)

When a user manually logs out:

```dart
// End session using session manager
await SessionManager().endSession();
```

## Usage

### Basic Implementation

The system is automatically active once integrated. Users will be:

1. **Logged out after 15 minutes** of inactivity
2. **Redirected to login screen** when session expires

### Customizing Timeouts

To modify the timeout durations, edit `lib/services/session_manager.dart`:

```dart
class SessionManager {
  static const Duration _sessionTimeout = Duration(minutes: 15);      // Total session time
  static const Duration _inactivityTimeout = Duration(minutes: 15);   // Inactivity timeout
}
```

### Adding Activity Tracking to Screens

Use the `ActivityTracker` mixin in your screens:

```dart
class MyScreen extends StatefulWidget {
  @override
  State<MyScreen> createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with ActivityTracker {
  @override
  void onUserActivity() {
    super.onUserActivity();
    // Track specific user actions
    trackUserActivity();
  }
}
```

### Manual Activity Tracking

Call `trackUserActivity()` whenever the user performs an important action:

```dart
void onButtonPressed() {
  SessionManager().updateActivity();
  // Your button logic here
}
```

## Session States

### Active Session
- User is logged in
- Timers are running
- Activity is being tracked



### Expired Session
- Session has timed out
- User is logged out
- All data is cleared

## App Lifecycle Handling

The system handles different app states:

- **Resumed**: App comes to foreground, checks session expiration
- **Paused**: App goes to background, stores current activity time
- **Detached**: App is terminated, session data persists
- **Hidden**: App is hidden, stores current activity time

## Security Features

- **Secure storage**: Biometric credentials are stored securely
- **Complete cleanup**: All authentication data is cleared on logout
- **Token removal**: API tokens are removed from storage
- **Session validation**: Checks session expiration on app resume

## Testing

To test the implementation:

1. **Login to the app**
2. **Leave the app in background** for 15+ minutes
3. **Return to the app** - you should be logged out
4. **Use the app actively** - session should not expire

## Troubleshooting

### Session not expiring
- Check if activity tracking is working
- Verify timer durations are correct
- Ensure app lifecycle events are being handled



### Login issues after logout
- Verify all authentication data is cleared
- Check token removal from storage
- Ensure proper navigation to login screen

## Files Modified

1. `lib/services/session_manager.dart` - New session management service
2. `lib/main.dart` - Updated SessionTimeoutWrapper
3. `lib/screens/login_screen.dart` - Added session start on login
4. `lib/screens/home_screen.dart` - Added session end on logout
5. `lib/screens/splash_screen.dart` - Updated session validation
6. `lib/utils/activity_tracker.dart` - New activity tracking mixin


## Dependencies

The implementation uses these Flutter packages:
- `shared_preferences` - For storing session data
- `flutter_secure_storage` - For secure credential storage
- `dart:async` - For timer management
- `flutter/material.dart` - For UI components 