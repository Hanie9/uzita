import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/ui_scale.dart';

class TransportRequestDetailScreen extends StatelessWidget {
  final Map<String, dynamic> request;

  const TransportRequestDetailScreen({super.key, required this.request});

  String _formatDate(BuildContext context, String dateString) {
    try {
      final date = DateTime.parse(dateString);
      if (Localizations.localeOf(context).languageCode == 'en') {
        return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      } else {
        final j = Jalali.fromDateTime(date);
        return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
      }
    } catch (_) {
      return dateString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'done':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color _getStatusBackgroundColor(String status) {
    // Same colors as list/status badge but used as solid banner background
    return _getStatusColor(status);
  }

  String _getStatusText(String status, AppLocalizations localizations) {
    switch (status) {
      case 'open':
        return localizations.sps_status_open;
      case 'assigned':
        return localizations.sps_status_assigned;
      case 'confirm':
        return localizations.sps_status_confirm;
      case 'done':
        return localizations.sps_status_done;
      case 'canceled':
        return localizations.sps_status_canceled;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;
    final screenHeight = MediaQuery.of(context).size.height;

    final List<dynamic> pieces = (request['pieces'] as List?) ?? [];
    final String maghsad = (request['maghsad'] ?? '---').toString();
    final String phone = (request['phone'] ?? '---').toString();
    final String description = (request['description'] ?? '---').toString();
    final String status = (request['status'] ?? 'open').toString();
    final String createdAt = (request['created_at'] ?? '').toString();
    final String driver = request['driver'] == null
        ? localizations.trd_unknown
        : request['driver'].toString();
    final String comment = (request['comment'] ?? '---').toString();
    final String grade = (request['grade'] ?? '---').toString();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ui.scale(base: 16, min: 12, max: 20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: Theme.of(context).appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        localizations.trd_title,
                        style: Theme.of(context).appBarTheme.titleTextStyle
                            ?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  Image.asset(
                    'assets/logouzita.png',
                    height: ui.scale(
                      base: screenHeight * 0.08,
                      min: 28,
                      max: 56,
                    ),
                    width: ui.scale(
                      base: screenHeight * 0.08,
                      min: 28,
                      max: 56,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Directionality(
        textDirection:
            AppLocalizations.of(context)!.effectiveLanguageCode == 'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            ui.scale(base: 20, min: 16, max: 24),
            ui.scale(base: 20, min: 16, max: 24),
            ui.scale(base: 20, min: 16, max: 24),
            ui.scale(base: 20, min: 16, max: 24) +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status banner (same style as service details)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: _getStatusBackgroundColor(status),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _getStatusText(status, localizations),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              Text(
                localizations.trd_pieces,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pieces.isEmpty
                    ? [
                        Chip(
                          label: Text(localizations.trd_unknown),
                          backgroundColor: AppColors.lapisLazuli.withValues(
                            alpha: 0.06,
                          ),
                        ),
                      ]
                    : pieces
                          .map(
                            (p) => Chip(
                              label: Text(p.toString()),
                              backgroundColor: AppColors.lapisLazuli.withValues(
                                alpha: 0.06,
                              ),
                            ),
                          )
                          .toList(),
              ),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              _buildInfoItem(
                context,
                icon: Icons.location_on,
                title: localizations.trd_maghsad,
                value: maghsad,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.phone,
                title: localizations.trd_phone,
                value: phone,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.person,
                title: localizations.trd_driver,
                value: driver,
              ),
              SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
              _buildInfoItem(
                context,
                icon: Icons.star_border,
                title: localizations.trd_grade,
                value: grade,
              ),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              Text(
                localizations.trd_description,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : AppColors.lapisLazuli.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              Text(
                localizations.trd_comment,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[700]!
                        : AppColors.lapisLazuli.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Text(
                  comment,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.black87,
                  ),
                ),
              ),
              SizedBox(height: ui.scale(base: 20, min: 16, max: 24)),
              if (createdAt.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.iranianGray.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: AppColors.iranianGray,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${localizations.trd_created_at} ${_formatDate(context, createdAt)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.iranianGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : AppColors.lapisLazuli.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.lapisLazuli),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.iranianGray,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
