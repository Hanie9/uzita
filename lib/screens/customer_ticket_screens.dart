import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/customer/customer_api.dart';
import 'package:uzita/customer/customer_widgets.dart';
import 'package:uzita/services.dart';

class CustomerTicketListScreen extends StatefulWidget {
  const CustomerTicketListScreen({super.key});

  @override
  State<CustomerTicketListScreen> createState() =>
      _CustomerTicketListScreenState();
}

class _CustomerTicketListScreenState extends State<CustomerTicketListScreen> {
  final List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  bool _loading = true;
  bool _loadingMore = false;
  String _error = '';
  int _page = 1;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load(reset: true);
    });
  }

  Future<void> _load({required bool reset}) async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    if (reset) {
      setState(() {
        _loading = true;
        _error = '';
        _page = 1;
      });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final CustomerPage page = await customerList(
        '/customer/tickets/',
        page: reset ? 1 : _page + 1,
        fallback: loc.cust_load_failed,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.results);
        _page = page.currentPage;
        _hasMore = page.hasNext;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = customerFailure(error, loc);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    return CustomerShell(
      title: loc.cust_ticket_title,
      selectedIndex: 3,
      body: CustomerListView(
        loading: _loading,
        error: _error,
        items: _items,
        hasMore: _hasMore,
        loadingMore: _loadingMore,
        headerTitle: loc.cust_ticket_title,
        headerSubtitle: loc.tls_send_new_hint,
        headerCountLabel: loc.tls_ticket_count,
        emptyTitle: loc.tls_no_tickets,
        headerIcon: Icons.confirmation_number_outlined,
        onCreate: () async {
          final bool? saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CustomerTicketFormScreen()),
          );
          if (saved == true) _load(reset: true);
        },
        onRefresh: () => _load(reset: true),
        onLoadMore: () => _load(reset: false),
        itemBuilder: (Map<String, dynamic> item) {
          final bool replied = customerFlag(item['reply']);
          return CustomerRecordCard(
            title:
                customerText(item['subject_display']) ??
                customerText(item['title']) ??
                loc.cust_ticket_title,
            status: replied
                ? loc.ticketcard_answered
                : loc.ticketcard_waiting_response,
            statusCode: replied ? 'done' : 'open',
            lines: <CustomerMetaLine>[
              CustomerMetaLine(Icons.title, customerText(item['title']) ?? ''),
              CustomerMetaLine(
                Icons.calendar_today,
                '${loc.ticketcard_date_send} ${customerText(item['created_jalali']) ?? ''}',
              ),
            ],
            onTap: () async {
              final bool? changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerTicketDetailScreen(
                    id: int.parse('${item['id']}'),
                  ),
                ),
              );
              if (changed == true) _load(reset: true);
            },
          );
        },
      ),
    );
  }
}

class CustomerTicketFormScreen extends StatefulWidget {
  const CustomerTicketFormScreen({super.key});

  @override
  State<CustomerTicketFormScreen> createState() =>
      _CustomerTicketFormScreenState();
}

class _CustomerTicketFormScreenState extends State<CustomerTicketFormScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  String _subject = 'service';
  PickedCustomerFile? _attachment;
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String _subjectLabel(AppLocalizations loc, String value) {
    return switch (value) {
      'warranty' => loc.cust_subject_warranty,
      'bar' => loc.cust_subject_bar,
      'feedback' => loc.cust_subject_feedback,
      'other' => loc.cust_subject_other,
      _ => loc.cust_subject_service,
    };
  }

  Future<void> _submit() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = loc.cust_required);
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      await customerMultipart(
        method: 'POST',
        path: '/customer/tickets/create/',
        fields: <String, String>{
          'subject': _subject,
          'title': _title.text.trim(),
          'description': _description.text.trim(),
        },
        files: _attachment == null
            ? const <String, PickedCustomerFile>{}
            : <String, PickedCustomerFile>{'attachment': _attachment!},
        fallback: loc.cust_connecting,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = customerFailure(error, loc);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    const List<String> subjects = <String>[
      'service',
      'warranty',
      'bar',
      'feedback',
      'other',
    ];
    return Scaffold(
      appBar: customerAppBar(context, title: loc.cust_ticket_title),
      body: customerRequestBody(
        context,
        title: loc.cust_ticket_title,
        description: loc.cust_ticket_subtitle,
        bannerIcon: Icons.confirmation_number_outlined,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _subject,
            decoration: customerFieldDecoration(
              context,
              loc.cust_subject,
              icon: Icons.category,
            ),
            items: subjects
                .map(
                  (String value) => DropdownMenuItem<String>(
                    value: value,
                    child: Text(_subjectLabel(loc, value)),
                  ),
                )
                .toList(),
            onChanged: (String? value) {
              if (value != null) setState(() => _subject = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 100,
            decoration: customerFieldDecoration(
              context,
              loc.cust_title,
              icon: Icons.title,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 300,
            minLines: 4,
            maxLines: 6,
            decoration: customerFieldDecoration(
              context,
              loc.cust_description,
              icon: Icons.notes,
            ),
          ),
          const SizedBox(height: 12),
          CustomerFileField(
            label: loc.cust_attachment,
            file: _attachment,
            onPick: () async {
              final PickedCustomerFile? file = await pickCustomerFile(context);
              if (file != null) setState(() => _attachment = file);
            },
            onClear: () => setState(() => _attachment = null),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          CustomerPrimaryButton(
            onPressed: _saving ? null : _submit,
            label: _saving ? loc.home_loading : loc.cust_save,
          ),
        ],
      ),
    );
  }
}

class CustomerTicketDetailScreen extends StatefulWidget {
  const CustomerTicketDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<CustomerTicketDetailScreen> createState() =>
      _CustomerTicketDetailScreenState();
}

class _CustomerTicketDetailScreenState
    extends State<CustomerTicketDetailScreen> {
  Map<String, dynamic>? _item;
  bool _loading = true;
  bool _sending = false;
  bool _changed = false;
  String _error = '';
  final TextEditingController _reply = TextEditingController();
  PickedCustomerFile? _attachment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final dynamic data = await customerGet(
        '/customer/tickets/${widget.id}/',
        fallback: loc.cust_load_failed,
      );
      if (!mounted) return;
      setState(() {
        _item = customerObject(data);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = customerFailure(error, loc);
        _loading = false;
      });
    }
  }

  Future<void> _sendReply() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    if (_reply.text.trim().isEmpty) {
      showCustomerMessage(context, loc.cust_required);
      return;
    }
    setState(() => _sending = true);
    try {
      await customerMultipart(
        method: 'POST',
        path: '/customer/tickets/${widget.id}/reply/',
        fields: <String, String>{'massage': _reply.text.trim()},
        files: _attachment == null
            ? const <String, PickedCustomerFile>{}
            : <String, PickedCustomerFile>{'attachment': _attachment!},
        fallback: loc.cust_connecting,
      );
      _reply.clear();
      if (mounted) {
        setState(() {
          _attachment = null;
          _sending = false;
          _changed = true;
        });
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCustomerMessage(context, customerFailure(error, loc));
      setState(() => _sending = false);
    }
  }

  bool _replyHasContent(Map<String, dynamic> reply) {
    return customerText(reply['user_full_name']) != null ||
        customerText(reply['massage']) != null ||
        customerText(reply['created_jalali']) != null ||
        customerText(reply['created_at']) != null ||
        customerHasFile(reply['attachment_url']);
  }

  void _leave() {
    Navigator.pop(context, _changed);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final Map<String, dynamic>? item = _item;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _leave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: customerAppBar(context, title: loc.tds_title),
        body: _loading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.lapisLazuli,
                    ),
                    const SizedBox(height: 16),
                    Text(loc.tds_loading),
                  ],
                ),
              )
            : _error.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(loc.tds_try_again),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lapisLazuli,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _buildDetails(loc, item),
      ),
    );
  }

  Widget _buildDetails(AppLocalizations loc, Map<String, dynamic>? item) {
    final bool hasReplyFlag = item != null && item.containsKey('reply');
    final bool replied = hasReplyFlag && customerFlag(item['reply']);
    final String? subject =
        customerText(item?['subject_display']) ??
        _subjectLabel(loc, customerText(item?['subject']));
    final String? title = customerText(item?['title']);
    final String? description = customerText(item?['description']);
    final String? created =
        customerText(item?['created_jalali']) ??
        customerText(item?['created_at']);
    final List<Map<String, dynamic>> replies =
        item != null && item.containsKey('replies')
        ? customerReplies(item['replies']).where(_replyHasContent).toList()
        : const <Map<String, dynamic>>[];
    final bool canReply = item != null && customerFlag(item['can_reply']);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        _ticketCard(
          loc: loc,
          subject: subject,
          title: title,
          description: description,
          created: created,
          hasReplyFlag: hasReplyFlag,
          replied: replied,
          attachmentUrl: item?['attachment_url'],
        ),
        const SizedBox(height: 24),
        if (replies.isNotEmpty)
          _repliesSection(loc, replies)
        else if (hasReplyFlag)
          _waitingCard(loc, replied: replied),
        if (canReply) ...[const SizedBox(height: 16), _composeCard(loc)],
      ],
    );
  }

  String? _subjectLabel(AppLocalizations loc, String? value) {
    return switch (value) {
      'service' => loc.cust_subject_service,
      'warranty' => loc.cust_subject_warranty,
      'bar' => loc.cust_subject_bar,
      'feedback' => loc.cust_subject_feedback,
      'other' => loc.cust_subject_other,
      null => null,
      _ => value,
    };
  }

  Widget _ticketCard({
    required AppLocalizations loc,
    required String? subject,
    required String? title,
    required String? description,
    required String? created,
    required bool hasReplyFlag,
    required bool replied,
    required dynamic attachmentUrl,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subject != null)
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: 20,
                          color: AppColors.lapisLazuli,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            subject,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.lapisLazuli,
                                ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                if (hasReplyFlag) ...[
                  const SizedBox(width: 12),
                  _statusBadge(loc, replied),
                ],
              ],
            ),
            if (title != null) ...[
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.lapisLazuli,
                ),
              ),
            ],
            if (created != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: dark ? Colors.grey[800] : Colors.grey[100],
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
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        created,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (description != null) ...[
              const SizedBox(height: 20),
              Text(
                loc.tds_content_message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lapisLazuli,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dark ? Colors.grey[800] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: dark ? Colors.grey[600]! : Colors.grey[200]!,
                  ),
                ),
                child: SelectableText(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
              ),
            ],
            if (customerHasFile(attachmentUrl)) ...[
              const SizedBox(height: 12),
              _attachmentTile(
                label: loc.cust_attachment,
                url: attachmentUrl,
                downloadName: 'ticket',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composeCard(AppLocalizations loc) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final PickedCustomerFile? file = _attachment;
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).cardTheme.color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.cust_your_reply,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.lapisLazuli,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reply,
              minLines: 4,
              maxLines: 6,
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                hintText: loc.cust_reply_hint,
                filled: true,
                fillColor: dark
                    ? Colors.grey[800]
                    : AppColors.lapisLazuli.withValues(alpha: 0.04),
                contentPadding: const EdgeInsets.all(14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.lapisLazuli,
                    width: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Material(
              color: dark
                  ? Colors.grey[800]
                  : AppColors.lapisLazuli.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final PickedCustomerFile? picked = await pickCustomerFile(
                    context,
                  );
                  if (picked != null) setState(() => _attachment = picked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file,
                        color: AppColors.lapisLazuli,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${loc.cust_attachment} (${loc.cust_optional})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.iranianGray,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              file?.name ?? loc.cust_pick_file,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (file != null)
                        IconButton(
                          onPressed: () => setState(() => _attachment = null),
                          icon: const Icon(Icons.close),
                          color: AppColors.iranianGray,
                        )
                      else
                        const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.lapisLazuli,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CustomerPrimaryButton(
              onPressed: _sending ? null : _sendReply,
              label: _sending ? loc.home_loading : loc.cust_reply,
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentTile({
    required String label,
    required dynamic url,
    required String downloadName,
  }) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark
          ? Colors.grey[800]
          : AppColors.lapisLazuli.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => downloadCustomerUrl(context, url, name: downloadName),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lapisLazuli.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.lapisLazuli,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.lapisLazuli,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fileName(url),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.download, color: AppColors.lapisLazuli),
            ],
          ),
        ),
      ),
    );
  }

  String _fileName(dynamic url) {
    final String? text = customerText(url);
    if (text == null) return '';
    final String leaf = text
        .split('?')
        .first
        .split('/')
        .where((String part) => part.isNotEmpty)
        .last;
    return Uri.decodeComponent(leaf);
  }

  Widget _statusBadge(AppLocalizations loc, bool replied) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final Color color = replied
        ? AppColors.lapisLazuli
        : (dark ? Colors.blue[400]! : Colors.blue[700]!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: replied
            ? AppColors.lapisLazuli.withValues(alpha: 0.1)
            : (dark
                  ? Colors.blue[900]?.withValues(alpha: 0.2)
                  : Colors.blue[50]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: replied
              ? AppColors.lapisLazuli
              : (dark ? Colors.blue[600]! : Colors.blue[300]!),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            replied ? Icons.check_circle : Icons.schedule,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            replied ? loc.tds_replied : loc.tds_waiting_for_reply,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _repliesSection(
    AppLocalizations loc,
    List<Map<String, dynamic>> replies,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${loc.tds_replies} (${replies.length})',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.lapisLazuli,
          ),
        ),
        const SizedBox(height: 8),
        for (int index = 0; index < replies.length; index++)
          _replyCard(loc, replies[index], index),
      ],
    );
  }

  Widget _replyCard(
    AppLocalizations loc,
    Map<String, dynamic> reply,
    int index,
  ) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool fromCustomer =
        reply.containsKey('is_customer') && customerFlag(reply['is_customer']);
    final String? name = customerText(reply['user_full_name']);
    final String? message = customerText(reply['massage']);
    final String? created =
        customerText(reply['created_jalali']) ??
        customerText(reply['created_at']);
    final String author = fromCustomer
        ? (name ?? loc.home_customer)
        : (name ?? loc.tds_support);
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: dark
          ? Colors.blue[900]?.withValues(alpha: 0.2)
          : (fromCustomer
                ? Theme.of(context).cardTheme.color
                : Colors.blue[50]),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  Icon(
                    fromCustomer ? Icons.person : Icons.support_agent,
                    color: AppColors.lapisLazuli,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      author,
                      textAlign: TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lapisLazuli,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.lapisLazuli,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${loc.tds_reply_label} ${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (created != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      created,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (message != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dark ? Colors.blue[600]! : Colors.blue[200]!,
                  ),
                ),
                child: SelectableText(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
              ),
            ],
            if (customerHasFile(reply['attachment_url'])) ...[
              const SizedBox(height: 12),
              _attachmentTile(
                label: loc.cust_attachment,
                url: reply['attachment_url'],
                downloadName: 'reply',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _waitingCard(AppLocalizations loc, {required bool replied}) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark
              ? Colors.blue[900]?.withValues(alpha: 0.2)
              : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: dark ? Colors.blue[600]! : Colors.blue[200]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              replied ? Icons.info_outline : Icons.schedule,
              color: dark ? Colors.blue[300] : Colors.blue[700],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: replied
                  ? Text(
                      loc.tds_show_soon,
                      style: TextStyle(
                        fontSize: 14,
                        color: dark ? Colors.blue[200] : Colors.blue[800],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.tds_waiting_for_reply_support,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lapisLazuli,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.tds_reply_soon,
                          style: TextStyle(
                            fontSize: 12,
                            color: dark
                                ? Colors.blue[200]
                                : const Color(0xFF1976D2),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
