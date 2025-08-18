import 'package:flutter/material.dart';
import 'package:uzita/services/session_manager.dart';

mixin ActivityTracker<T extends StatefulWidget> on State<T> {
  final SessionManager _sessionManager = SessionManager();

  @override
  void initState() {
    super.initState();
    _setupActivityTracking();
  }

  void _setupActivityTracking() {
    // Track activity on various user interactions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _trackActivity();
      }
    });
  }

  void _trackActivity() {
    // Update session activity
    _sessionManager.updateActivity();
  }

  // Call this method whenever user performs an action
  void trackUserActivity() {
    _sessionManager.updateActivity();
  }

  // Override this method in screens to track specific activities
  void onUserActivity() {
    trackUserActivity();
  }
}
