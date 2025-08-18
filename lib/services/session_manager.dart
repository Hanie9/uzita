import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager {
  // Only enforce background timeout (15 minutes outside the app)
  static const Duration _backgroundTimeout = Duration(minutes: 15);

  DateTime? _lastActivityTime;
  bool _isSessionActive = false;

  // Singleton pattern
  static final SessionManager _instance = SessionManager._internal();
  factory SessionManager() => _instance;
  SessionManager._internal();

  // Stream to notify about session state changes
  final StreamController<bool> _sessionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get sessionStateStream => _sessionStateController.stream;

  // Getters
  bool get isSessionActive => _isSessionActive;
  DateTime? get lastActivityTime => _lastActivityTime;

  /// Initialize session manager
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // Do NOT reset stored timestamps on cold start.
    // Only reflect current active state based on token presence.
    _isSessionActive = token != null;
  }

  /// Start a new session
  Future<void> startSession() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    // Mark session state; clear any stale background marker
    await prefs.setInt('session_start_time', now.millisecondsSinceEpoch);
    await prefs.setInt('last_foreground_time', now.millisecondsSinceEpoch);
    await prefs.remove('last_background_time');

    _lastActivityTime = now;
    _isSessionActive = true;

    _sessionStateController.add(true);
  }

  /// Update last activity time and reset inactivity timer
  void updateActivity() {
    if (!_isSessionActive) return;

    _lastActivityTime = DateTime.now();
    _updateLastForegroundTime();
  }

  /// End the current session
  Future<void> endSession({bool clearBiometric = false}) async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage();

    // Clear session data
    await prefs.remove('token');
    await prefs.remove('session_start_time');
    await prefs.remove('last_activity_time');
    await prefs.remove('last_background_time');
    await prefs.remove('last_foreground_time');
    await prefs.remove('login_at_epoch_ms');

    // Clear biometric credentials only if requested (manual logout)
    if (clearBiometric) {
      await secureStorage.delete(key: 'bio_username');
      await secureStorage.delete(key: 'bio_password');
    }

    _isSessionActive = false;
    _lastActivityTime = null;

    _sessionStateController.add(false);
  }

  /// Check if session is expired
  Future<bool> isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final lastBackgroundTime = prefs.getInt('last_background_time');
    final lastForegroundTime = prefs.getInt('last_foreground_time');
    final lastRequestTime = prefs.getInt('last_request_time');

    // If there is no background timestamp, do not expire the session here
    final now = DateTime.now().millisecondsSinceEpoch;
    if (lastBackgroundTime != null) {
      final backgroundDuration = now - lastBackgroundTime;
      return backgroundDuration >= _backgroundTimeout.inMilliseconds;
    }

    // Cold start case: if it's been >= timeout since the app was last in foreground
    if (lastForegroundTime != null) {
      final awayDuration = now - lastForegroundTime;
      return awayDuration >= _backgroundTimeout.inMilliseconds;
    }

    // Fallback: if we have a last request timestamp and it is older than timeout, expire
    if (lastRequestTime != null) {
      final awayDuration = now - lastRequestTime;
      return awayDuration >= _backgroundTimeout.inMilliseconds;
    }

    return false;
  }

  /// Call this before performing any network request to enforce 15-min away rule.
  Future<void> onNetworkRequest() async {
    if (!_isSessionActive) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'last_request_time',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Handle app lifecycle changes
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _onAppPaused();
        break;
      case AppLifecycleState.inactive:
        // Don't do anything for inactive state
        break;
      case AppLifecycleState.hidden:
        _onAppHidden();
        break;
    }
  }

  /// Handle app resumed event
  void _onAppResumed() {
    if (!_isSessionActive) return;

    // Check if session expired while app was in background
    _checkSessionExpiration();
    updateActivity();
    _clearBackgroundMarker();
  }

  /// Handle app paused event
  void _onAppPaused() {
    _markBackgroundedNow();
  }

  /// Handle app hidden event
  void _onAppHidden() {
    _markBackgroundedNow();
  }

  /// Check if session has expired
  Future<void> _checkSessionExpiration() async {
    if (await isSessionExpired()) {
      await endSession();
    }
  }

  /// Mark the time when the app goes to background
  Future<void> _markBackgroundedNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'last_background_time',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Clear the background timestamp once app is active again
  Future<void> _clearBackgroundMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_background_time');
  }

  /// Persist the last time user interacted while foregrounded
  Future<void> _updateLastForegroundTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'last_foreground_time',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Dispose resources
  void dispose() {
    _sessionStateController.close();
  }
}
