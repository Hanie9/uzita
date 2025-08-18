import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/main.dart';
import 'package:uzita/utils/ticket_class.dart';
import 'package:uzita/services.dart';
import 'package:provider/provider.dart';
import 'package:uzita/providers/settings_provider.dart';

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  Ticket? ticket;
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    fetchTicketDetail();
  }

  Future<void> fetchTicketDetail() async {
    setState(() {
      loading = true;
      error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() {
          error = AppLocalizations.of(context)!.tds_login_again;
          loading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('$baseUrl/listticket/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json; charset=utf-8',
        },
      );

      if (response.statusCode == 200) {
        final String responseBody = utf8.decode(response.bodyBytes);
        final data = json.decode(responseBody) as List;

        final ticketData = data.firstWhere(
          (t) => t['id'] == widget.ticketId,
          orElse: () => null,
        );

        if (ticketData != null) {
          setState(() {
            ticket = Ticket.fromJson(ticketData);
            loading = false;
          });
        } else {
          setState(() {
            error = AppLocalizations.of(context)!.tds_error_no_ticket;
            loading = false;
          });
        }
      } else {
        setState(() {
          error = AppLocalizations.of(context)!.tds_error_details;
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = AppLocalizations.of(context)!.tds_error_connecting;
        loading = false;
      });
      print('${AppLocalizations.of(context)!.tds_error_details}: $e');
    }
  }

  String convertToShamsi(String dateTime) {
    try {
      DateTime dt = DateTime.parse(dateTime);
      if (Localizations.localeOf(context).languageCode == 'en') {
        return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else {
        Jalali shamsiDate = Jalali.fromDateTime(dt);
        return '${shamsiDate.year}/${shamsiDate.month.toString().padLeft(2, '0')}/${shamsiDate.day.toString().padLeft(2, '0')} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return AppLocalizations.of(context)!.tds_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          color: theme.appBarTheme.backgroundColor,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Left side - Back button and title
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        AppLocalizations.of(context)!.tds_title,
                        style: theme.appBarTheme.titleTextStyle,
                      ),
                    ],
                  ),

                  // Right side - Logo
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Image.asset(
                          'assets/logouzita.png',
                          height: MediaQuery.of(context).size.height * 0.08,
                          width: MediaQuery.of(context).size.height * 0.08,
                        ),
                      ],
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
            Provider.of<SettingsProvider>(
                  context,
                  listen: false,
                ).selectedLanguage ==
                'en'
            ? TextDirection.ltr
            : TextDirection.rtl,
        child: loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.lapisLazuli,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.tds_loading,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontSize: 14),
                    ),
                  ],
                ),
              )
            : error.isNotEmpty
            ? _buildErrorWidget()
            : ticket == null
            ? _buildEmptyState()
            : _buildTicketDetails(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red[900]?.withValues(alpha: 0.3)
                    : Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red[300]
                    : Colors.red[400],
              ),
            ),
            SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.red[300]
                    : Colors.red[600],
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: fetchTicketDetail,
              icon: Icon(Icons.refresh, size: 18),
              label: Text(AppLocalizations.of(context)!.tds_try_again),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.lapisLazuli,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Theme.of(
              context,
            ).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
          ),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.tds_error_no_ticket,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketDetails() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTicketCard(),
          if (ticket!.replies.isNotEmpty) ...[
            SizedBox(height: 24),
            _buildRepliesSection(),
          ] else ...[
            SizedBox(height: 24),
            _buildStatusMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildTicketCard() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardTheme.color,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket!.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildStatusBadge(),
              ],
            ),
            SizedBox(height: 16),
            _buildDateRow(),
            SizedBox(height: 20),
            _buildMessageContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ticket!.reply
            ? AppColors.lapisLazuli.withValues(alpha: 0.1)
            : (Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue[900]?.withValues(alpha: 0.2)
                  : Colors.blue[50]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ticket!.reply
              ? AppColors.lapisLazuli
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[600]!
                    : Colors.blue[300]!),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ticket!.reply ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: ticket!.reply
                ? AppColors.lapisLazuli
                : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue[400]
                      : Colors.blue[700]),
          ),
          SizedBox(width: 4),
          Text(
            ticket!.reply
                ? AppLocalizations.of(context)!.tds_replied
                : AppLocalizations.of(context)!.tds_waiting_for_reply,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ticket!.reply
                  ? AppColors.lapisLazuli
                  : (Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue[400]
                        : Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            size: 16,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
          SizedBox(width: 8),
          Text(
            convertToShamsi(ticket!.createdAt),
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.tds_content_message,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[600]!
                  : Colors.grey[200]!,
            ),
          ),
          child: SelectableText(
            ticket!.description,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.titleMedium?.color,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRepliesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context)!.tds_replies} (${ticket!.replies.length})',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        SizedBox(height: 8),
        ...ticket!.replies.asMap().entries.map((entry) {
          int index = entry.key;
          TicketReply reply = entry.value;

          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[900]?.withValues(alpha: 0.2)
                    : null,
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? null
                    : LinearGradient(
                        colors: [Colors.blue[50]!, Colors.blue[100]!],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lapisLazuli,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${AppLocalizations.of(context)!.tds_reply_label} ${index + 1}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.support_agent,
                        color: AppColors.lapisLazuli,
                        size: 20,
                      ),
                      SizedBox(width: 4),
                      Text(
                        AppLocalizations.of(context)!.tds_support,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      SizedBox(width: 4),
                      Text(
                        convertToShamsi(reply.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue[600]!
                            : Colors.blue[200]!,
                      ),
                    ),
                    child: SelectableText(
                      reply.massage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.titleMedium?.color,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (ticket!.reply) ...[
          // اگر reply = true اما پاسخی موجود نیست
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[900]?.withValues(alpha: 0.2)
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue[600]!
                      : Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue[300]
                        : Colors.blue[700],
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.tds_show_soon,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.blue[200]
                            : Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          // اگر هیچ پاسخی وجود نداشت
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.blue[900]?.withValues(alpha: 0.2)
                    : Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue[600]!
                      : Colors.blue[200]!,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue[300]
                        : Colors.blue[600],
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.tds_waiting_for_reply_support,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue[300]
                                : Color(0xFF1976D2),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          AppLocalizations.of(context)!.tds_reply_soon,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.blue[200]
                                : Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
