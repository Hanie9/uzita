import 'package:flutter/material.dart';

/// Neshan-style pill button shown when the user pans away from follow mode.
class NeshanReturnToRouteButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final double bottom;

  const NeshanReturnToRouteButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.bottom = 88,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      bottom: bottom,
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF4B5FD6),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.navigation,
                    color: Color(0xFF3344AA),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
