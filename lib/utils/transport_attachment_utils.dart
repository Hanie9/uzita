import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/file_download_utils.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/task_attachment_download.dart';

const List<String> kTransportAttachmentExtensions = <String>[
  'pdf',
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'heic',
];

bool isAllowedTransportAttachmentName(String name) {
  final String lower = name.toLowerCase();
  return kTransportAttachmentExtensions.any(
    (String ext) => lower.endsWith('.$ext'),
  );
}

String? _pathFromFieldValue(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  if (value is Map) {
    final dynamic nested =
        value['url'] ?? value['path'] ?? value['file'] ?? value['attachment'];
    if (nested != null && nested.toString().trim().isNotEmpty) {
      return nested.toString().trim();
    }
  }
  return null;
}

String? transportAttachmentPath(
  Map<String, dynamic>? data, {
  List<String> keys = const <String>['attachment', 'attachment_url', 'file'],
}) {
  if (data == null) return null;
  for (final String key in keys) {
    final String? path = _pathFromFieldValue(data[key]);
    if (path != null) return path;
  }
  return null;
}

String? driverFinalAttachmentPath(Map<String, dynamic>? data) {
  return transportAttachmentPath(
    data,
    keys: const <String>[
      'driver_final_attachment',
      'driver_final_attachment_url',
    ],
  );
}

String transportAttachmentDisplayName(
  Map<String, dynamic>? data, {
  List<String> keys = const <String>['attachment', 'attachment_url', 'file'],
  String nameKey = 'attachment_name',
}) {
  if (data == null) return 'attachment';
  final String? named = data[nameKey]?.toString().trim();
  if (named != null && named.isNotEmpty) return named;

  final String? path = transportAttachmentPath(data, keys: keys);
  if (path == null || path.isEmpty) return 'attachment';

  final String cleaned = path.split('?').first;
  final String leaf = cleaned.split('/').where((s) => s.isNotEmpty).last;
  return leaf.isNotEmpty ? leaf : 'attachment';
}

String driverFinalAttachmentDisplayName(Map<String, dynamic>? data) {
  return transportAttachmentDisplayName(
    data,
    keys: const <String>[
      'driver_final_attachment',
      'driver_final_attachment_url',
    ],
    nameKey: 'driver_final_attachment_name',
  );
}

bool hasTransportAttachment(Map? data) {
  if (data == null) return false;
  return transportAttachmentPath(Map<String, dynamic>.from(data)) != null;
}

bool hasDriverFinalAttachment(Map? data) {
  if (data == null) return false;
  return driverFinalAttachmentPath(Map<String, dynamic>.from(data)) != null;
}

Future<void> downloadTransportAttachment({
  required BuildContext context,
  required Map<String, dynamic> data,
  List<String> keys = const <String>['attachment', 'attachment_url', 'file'],
  String nameKey = 'attachment_name',
}) async {
  final AppLocalizations loc = AppLocalizations.of(context)!;
  final String? path = transportAttachmentPath(data, keys: keys);
  if (path == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.tech_attachment_download_failed)),
    );
    return;
  }

  final String fileName = transportAttachmentDisplayName(
    data,
    keys: keys,
    nameKey: nameKey,
  );
  final String url = resolveTaskAttachmentUrl(path);

  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('token');
    await SessionManager().onNetworkRequest();

    final http.Response response = await http.get(
      Uri.parse(url),
      headers: <String, String>{
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
        'Accept': '*/*',
      },
    );

    if (!context.mounted) return;

    if (response.statusCode != 200 ||
        response.bodyBytes.isEmpty ||
        looksLikeDownloadErrorBody(response.bodyBytes)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.tech_attachment_download_failed)),
      );
      return;
    }

    await saveTaskAttachmentFile(
      bytes: response.bodyBytes,
      fileName: fileName,
      contentType: contentTypeFromHeaders(response.headers),
    );

    if (!context.mounted) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.tech_attachment_opened_in_browser)),
      );
    }
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.tech_attachment_download_failed)),
    );
  }
}

Future<void> downloadDriverFinalAttachment({
  required BuildContext context,
  required Map<String, dynamic> data,
}) {
  return downloadTransportAttachment(
    context: context,
    data: data,
    keys: const <String>[
      'driver_final_attachment',
      'driver_final_attachment_url',
    ],
    nameKey: 'driver_final_attachment_name',
  );
}

Widget buildTransportAttachmentSection({
  required BuildContext context,
  required Map<String, dynamic> data,
  required bool isDownloading,
  required VoidCallback onDownload,
  String? title,
  List<String> keys = const <String>['attachment', 'attachment_url', 'file'],
  String nameKey = 'attachment_name',
}) {
  final AppLocalizations localizations = AppLocalizations.of(context)!;
  final String? path = transportAttachmentPath(data, keys: keys);
  if (path == null) return const SizedBox.shrink();

  final String fileName = transportAttachmentDisplayName(
    data,
    keys: keys,
    nameKey: nameKey,
  );

  return Container(
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.attach_file,
              color: AppColors.lapisLazuli,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title ?? localizations.trn_attachment,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          fileName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.lapisLazuli,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isDownloading ? null : onDownload,
          icon: isDownloading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download, color: AppColors.lapisLazuli),
          label: Text(
            localizations.tech_download_attachment,
            style: const TextStyle(
              color: AppColors.lapisLazuli,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.lapisLazuli),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    ),
  );
}

Widget buildDriverFinalAttachmentSection({
  required BuildContext context,
  required Map<String, dynamic> data,
  required bool isDownloading,
  required VoidCallback onDownload,
}) {
  final AppLocalizations localizations = AppLocalizations.of(context)!;
  return buildTransportAttachmentSection(
    context: context,
    data: data,
    isDownloading: isDownloading,
    onDownload: onDownload,
    title: localizations.driver_final_attachment,
    keys: const <String>[
      'driver_final_attachment',
      'driver_final_attachment_url',
    ],
    nameKey: 'driver_final_attachment_name',
  );
}

class PickedTransportAttachment {
  PickedTransportAttachment({
    required this.name,
    required this.bytes,
    this.path,
  });

  final String name;
  final Uint8List bytes;
  final String? path;
}
