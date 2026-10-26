import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/customer/customer_api.dart';
import 'package:uzita/customer/customer_widgets.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/number_format_utils.dart';
import 'package:uzita/utils/transport_attachment_utils.dart';
import 'package:uzita/widgets/tappable_phone.dart';

class CustomerBarListScreen extends StatefulWidget {
  const CustomerBarListScreen({super.key});

  @override
  State<CustomerBarListScreen> createState() => _CustomerBarListScreenState();
}

class _CustomerBarListScreenState extends State<CustomerBarListScreen> {
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
        '/customer/bars/',
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
      title: loc.cust_bar_title,
      selectedIndex: 2,
      body: CustomerListView(
        loading: _loading,
        error: _error,
        items: _items,
        hasMore: _hasMore,
        loadingMore: _loadingMore,
        headerTitle: loc.cust_bar_title,
        headerSubtitle: loc.trr_no_requests_description,
        headerCountLabel: loc.trr_count_label,
        emptyTitle: loc.trr_no_requests,
        headerIcon: Icons.local_shipping_outlined,
        onCreate: () async {
          final bool? saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CustomerBarFormScreen()),
          );
          if (saved == true) _load(reset: true);
        },
        onRefresh: () => _load(reset: true),
        onLoadMore: () => _load(reset: false),
        itemBuilder: (Map<String, dynamic> item) {
          return _CustomerBarCard(
            item: item,
            onTap: () async {
              final bool? changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerBarDetailScreen(id: int.parse('${item['id']}')),
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

class _CustomerBarCard extends StatelessWidget {
  const _CustomerBarCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final String status = '${item['status'] ?? 'open'}';
    final String mabda = customerText(item['mabda']) ?? '---';
    final String maghsad = customerText(item['maghsad']) ?? '---';
    final String customerName =
        customerText(item['customer_full_name']) ??
        customerText(item['customer']) ??
        '---';
    final String phone = customerText(item['phone']) ?? '---';
    final String payment = customerBarPayment(
      item['payment_type_display'],
      item['payment_type'],
      loc,
    );
    final String created =
        customerText(item['created_jalali']) ??
        customerText(item['created_at']) ??
        '';
    final String? description = customerText(item['description']);
    final Color statusColor = customerBarStatusColor(status);
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    const TextStyle metaStyle = TextStyle(
      fontSize: 12,
      fontFamily: 'Vazir',
      color: AppColors.iranianGray,
    );

    Widget metaRow(IconData icon, Widget child) {
      return Row(
        children: [
          Icon(icon, size: 14, color: AppColors.iranianGray),
          const SizedBox(width: 4),
          Expanded(child: child),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.2)
                  : AppColors.lapisLazuli.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]!
                : AppColors.lapisLazuli.withValues(alpha: 0.08),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  customerBarStatusText(status, loc, item['status_display']),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Vazir',
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_city,
                          size: 14,
                          color: AppColors.iranianGray,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            mabda,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Vazir',
                              color: AppColors.iranianGray,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: AppColors.iranianGray,
                          textDirection: rtl
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.lapisLazuli,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            maghsad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Vazir',
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Vazir',
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    metaRow(
                      Icons.person_outline,
                      Text(
                        '${loc.trn_customer}: $customerName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    metaRow(
                      Icons.phone,
                      TappablePhone(
                        phone: phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    metaRow(
                      Icons.payments_outlined,
                      Text(
                        payment.isEmpty ? '---' : payment,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: metaStyle,
                      ),
                    ),
                    if (item.containsKey('price_transport') &&
                        item['price_transport'] != null) ...[
                      const SizedBox(height: 4),
                      metaRow(
                        Icons.attach_money,
                        Text(
                          customerBarMoney(item['price_transport'], loc),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                      ),
                    ],
                    if (created.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      metaRow(
                        Icons.calendar_today,
                        Text(
                          created,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: metaStyle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left,
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withValues(alpha: 0.5),
                textDirection: rtl ? TextDirection.ltr : TextDirection.rtl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerBarFormScreen extends StatefulWidget {
  const CustomerBarFormScreen({super.key});

  @override
  State<CustomerBarFormScreen> createState() => _CustomerBarFormScreenState();
}

class _CustomerBarFormScreenState extends State<CustomerBarFormScreen> {
  final TextEditingController _description = TextEditingController();
  final TextEditingController _origin = TextEditingController();
  final TextEditingController _destination = TextEditingController();
  PickedCustomerFile? _attachment;
  bool _saving = false;
  String _error = '';

  @override
  void dispose() {
    _description.dispose();
    _origin.dispose();
    _destination.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    if (_description.text.trim().isEmpty ||
        _origin.text.trim().isEmpty ||
        _destination.text.trim().isEmpty) {
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
        path: '/customer/bars/create/',
        fields: <String, String>{
          'description': _description.text.trim(),
          'mabda': _origin.text.trim(),
          'maghsad': _destination.text.trim(),
        },
        files: _attachment == null
            ? const <String, PickedCustomerFile>{}
            : <String, PickedCustomerFile>{'attachment_file': _attachment!},
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
    return Scaffold(
      appBar: customerAppBar(context, title: loc.cust_bar_title),
      body: customerRequestBody(
        context,
        title: loc.cust_bar_title,
        description: loc.cust_bar_subtitle,
        bannerIcon: Icons.local_shipping_outlined,
        children: [
          TextField(
            controller: _origin,
            maxLength: 300,
            decoration: customerFieldDecoration(
              context,
              loc.driver_mabda,
              icon: Icons.location_city,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _destination,
            maxLength: 300,
            decoration: customerFieldDecoration(
              context,
              loc.trn_maghsad,
              icon: Icons.location_on,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLength: 200,
            minLines: 3,
            maxLines: 5,
            decoration: customerFieldDecoration(
              context,
              loc.trn_description,
              icon: Icons.notes,
            ),
          ),
          const SizedBox(height: 12),
          CustomerFileField(
            label: loc.trn_attachment,
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

class CustomerBarDetailScreen extends StatefulWidget {
  const CustomerBarDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<CustomerBarDetailScreen> createState() =>
      _CustomerBarDetailScreenState();
}

class _CustomerBarDetailScreenState extends State<CustomerBarDetailScreen> {
  Map<String, dynamic>? _item;
  bool _loading = true;
  String _error = '';
  int? _grade;
  final TextEditingController _comment = TextEditingController();
  bool _confirming = false;
  bool _downloadingAttachment = false;
  bool _downloadingFinal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _comment.dispose();
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
        '/customer/bars/${widget.id}/',
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

  Future<void> _confirm() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    setState(() => _confirming = true);
    try {
      await customerSendJson(
        'POST',
        '/customer/bars/${widget.id}/confirm/',
        <String, dynamic>{
          if (_grade != null) 'grade': _grade,
          if (_comment.text.trim().isNotEmpty) 'comment': _comment.text.trim(),
        },
        fallback: loc.cust_connecting,
      );
      if (!mounted) return;
      showCustomerMessage(context, loc.cust_saved);
      await _load();
    } catch (error) {
      if (!mounted) return;
      showCustomerMessage(context, customerFailure(error, loc));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _downloadFile(dynamic url, {bool finalFile = false}) async {
    if (!customerHasFile(url)) return;
    setState(() {
      if (finalFile) {
        _downloadingFinal = true;
      } else {
        _downloadingAttachment = true;
      }
    });
    try {
      if (!mounted) return;
      await downloadCustomerUrl(
        context,
        url,
        name: finalFile ? 'driver-file' : 'attachment',
      );
    } finally {
      if (mounted) {
        setState(() {
          if (finalFile) {
            _downloadingFinal = false;
          } else {
            _downloadingAttachment = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final Map<String, dynamic>? item = _item;
    final String? statusCode = customerText(item?['status']);
    final String? statusLabel = statusCode == null
        ? customerText(item?['status_display'])
        : customerBarStatusText(statusCode, loc, item?['status_display']);
    final String? phone = customerText(item?['phone']);
    final String? mabda = customerText(item?['mabda']);
    final String? maghsad = customerText(item?['maghsad']);
    final String? product = customerText(item?['product_description']);
    final String? output = customerText(item?['output_number']);
    final String? coordination = customerText(item?['coordination_person']);
    final String? customerName =
        customerText(item?['customer_full_name']) ??
        customerText(item?['customer']);
    final String? assignment = customerText(item?['assignment']);
    final String? managerNote = customerText(item?['manager_note']);
    final String? description = customerText(item?['description']);
    final String? created =
        customerText(item?['created_jalali']) ??
        customerText(item?['created_at']);
    final String? payment = _returnedPayment(item, loc);
    final String? price = _returnedMoney(item?['price_transport'], loc);
    final String? fee = _returnedMoney(item?['fee_received'], loc);
    final String? weight = item == null || item['vazn'] == null
        ? null
        : '${item['vazn']}';
    final bool hasAttachment =
        item != null && customerHasFile(item['attachment_url']);
    final bool hasFinal =
        item != null && customerHasFile(item['driver_final_attachment_url']);
    return Scaffold(
      appBar: customerAppBar(context, title: loc.trd_title),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text(_error))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                if (statusLabel != null && statusLabel.isNotEmpty)
                  customerStatusBanner(
                    context,
                    statusCode ?? '',
                    statusLabel,
                  ),
                if (mabda != null)
                  CustomerInfoRow(
                    icon: Icons.location_city,
                    label: loc.driver_mabda,
                    value: mabda,
                  ),
                if (maghsad != null)
                  CustomerInfoRow(
                    icon: Icons.location_on,
                    label: loc.driver_maghsad,
                    value: maghsad,
                  ),
                if (phone != null)
                  CustomerInfoRow(
                    icon: Icons.phone,
                    label: loc.driver_phone,
                    value: phone,
                    valueWidget: TappablePhone(
                      phone: phone,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Vazir',
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                if (price != null)
                  CustomerInfoRow(
                    icon: Icons.attach_money,
                    label: loc.driver_price_transport,
                    value: price,
                  ),
                if (fee != null)
                  CustomerInfoRow(
                    icon: Icons.payments,
                    label: loc.driver_fee_received,
                    value: fee,
                  ),
                if (hasAttachment) ...[
                  buildTransportAttachmentSection(
                    context: context,
                    data: item,
                    isDownloading: _downloadingAttachment,
                    onDownload: () => _downloadFile(item['attachment_url']),
                    titleColor: AppColors.lapisLazuli,
                  ),
                  const SizedBox(height: 16),
                ],
                if (hasFinal) ...[
                  buildDriverFinalAttachmentSection(
                    context: context,
                    data: item,
                    isDownloading: _downloadingFinal,
                    onDownload: () => _downloadFile(
                      item['driver_final_attachment_url'],
                      finalFile: true,
                    ),
                    titleColor: AppColors.lapisLazuli,
                  ),
                  const SizedBox(height: 16),
                ],
                if (product != null)
                  CustomerInfoRow(
                    icon: Icons.edit_document,
                    label: loc.trn_product_description,
                    value: product,
                  ),
                if (output != null)
                  CustomerInfoRow(
                    icon: Icons.numbers,
                    label: loc.trn_output_number,
                    value: output,
                  ),
                if (coordination != null)
                  CustomerInfoRow(
                    icon: Icons.person,
                    label: loc.trn_coordination_person,
                    value: coordination,
                  ),
                if (weight != null)
                  CustomerInfoRow(
                    icon: Icons.scale,
                    label: loc.driver_weight,
                    value: weight,
                  ),
                if (item != null && item['bime'] != null)
                  CustomerInfoRow(
                    icon: Icons.verified_user,
                    label: loc.driver_insurance,
                    value: customerFlag(item['bime'])
                        ? loc.driver_yes
                        : loc.driver_no,
                  ),
                if (payment != null)
                  CustomerInfoRow(
                    icon: Icons.payments_outlined,
                    label: loc.trn_payment_type,
                    value: payment,
                  ),
                if (customerName != null)
                  CustomerInfoRow(
                    icon: Icons.person,
                    label: loc.trn_customer,
                    value: customerName,
                  ),
                if (assignment != null)
                  CustomerInfoRow(
                    icon: Icons.local_shipping_outlined,
                    label: loc.trd_driver,
                    value: assignment,
                  ),
                if (managerNote != null)
                  CustomerInfoRow(
                    icon: Icons.notes,
                    label: loc.cust_admin_note,
                    value: managerNote,
                  ),
                if (description != null)
                  customerNoteBox(
                    context,
                    loc.driver_description,
                    description,
                  ),
                if (created != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                        Flexible(
                          child: Text(
                            '${loc.driver_created_at} $created',
                            style: const TextStyle(
                              fontSize: 14,
                              fontFamily: 'Vazir',
                              color: AppColors.iranianGray,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (customerFlag(item?['can_confirm'])) ...[
                  const SizedBox(height: 16),
                  Text(
                    loc.cust_grade,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.lapisLazuli,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List<Widget>.generate(5, (int index) {
                      final int value = index + 1;
                      return ChoiceChip(
                        label: Text('$value'),
                        selected: _grade == value,
                        onSelected: (_) => setState(() => _grade = value),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _comment,
                    maxLength: 300,
                    minLines: 2,
                    maxLines: 4,
                    decoration: customerFieldDecoration(
                      context,
                      loc.cust_comment,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CustomerPrimaryButton(
                    onPressed: _confirming ? null : _confirm,
                    label: loc.cust_confirm_delivery,
                  ),
                ],
              ],
            ),
    );
  }
}

String customerBarStatusText(
  String status,
  AppLocalizations loc,
  dynamic display,
) {
  switch (status) {
    case 'open':
      return loc.sps_status_open;
    case 'draft':
      return loc.sps_status_draft;
    case 'assigned':
      return loc.sps_status_assigned;
    case 'confirm':
      return loc.sps_status_confirm;
    case 'done':
      return loc.sps_status_done;
    case 'canceled':
      return loc.sps_status_canceled;
    case 'suspended':
      return loc.sps_status_suspended;
    case 'public':
      return loc.sps_status_public;
    default:
      return customerText(display) ?? status;
  }
}

Color customerBarStatusColor(String status) => customerStatusColor(status);

String customerBarPayment(
  dynamic display,
  dynamic code,
  AppLocalizations loc,
) {
  final String? shown = customerText(display);
  if (shown != null) return shown;
  switch ('${code ?? ''}') {
    case 'direct':
      return loc.trn_direct;
    case 'invoice':
      return loc.trn_invoice;
    default:
      return '---';
  }
}

String customerBarMoney(dynamic value, AppLocalizations loc) {
  final String grouped = formatGroupedNumber(value);
  if (grouped == '---') return grouped;
  return '$grouped ${loc.sls_tooman}';
}

String? _returnedMoney(dynamic value, AppLocalizations loc) {
  if (value == null) return null;
  final String grouped = formatGroupedNumber(value);
  if (grouped == '---') return null;
  return '$grouped ${loc.sls_tooman}';
}

String? _returnedPayment(Map<String, dynamic>? item, AppLocalizations loc) {
  if (item == null) return null;
  if (!item.containsKey('payment_type') &&
      !item.containsKey('payment_type_display')) {
    return null;
  }
  final String? shown = customerText(item['payment_type_display']);
  if (shown != null) return shown;
  final String? code = customerText(item['payment_type']);
  if (code == null) return null;
  final String label = customerBarPayment(null, code, loc);
  return label == '---' ? null : label;
}
