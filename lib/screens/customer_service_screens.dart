import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/customer/customer_api.dart';
import 'package:uzita/customer/customer_widgets.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/number_format_utils.dart';
import 'package:uzita/widgets/tappable_phone.dart';

class CustomerServiceListScreen extends StatefulWidget {
  const CustomerServiceListScreen({super.key});

  @override
  State<CustomerServiceListScreen> createState() =>
      _CustomerServiceListScreenState();
}

class _CustomerServiceListScreenState extends State<CustomerServiceListScreen> {
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
        '/customer/services/',
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

  Future<void> _openCreate() async {
    final bool? saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CustomerServiceFormScreen()),
    );
    if (saved == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    return CustomerShell(
      title: loc.cust_service_title,
      selectedIndex: 1,
      body: CustomerListView(
        loading: _loading,
        error: _error,
        items: _items,
        hasMore: _hasMore,
        loadingMore: _loadingMore,
        headerTitle: loc.cust_service_title,
        headerSubtitle: loc.cust_service_subtitle,
        headerCountLabel: loc.cust_service_count,
        headerIcon: Icons.home_repair_service_outlined,
        onCreate: _openCreate,
        onRefresh: () => _load(reset: true),
        onLoadMore: () => _load(reset: false),
        itemBuilder: (Map<String, dynamic> item) {
          return _CustomerServiceCard(
            item: item,
            onTap: () async {
              final bool? changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerServiceDetailScreen(
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

class _CustomerServiceCard extends StatelessWidget {
  const _CustomerServiceCard({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final String status = '${item['status'] ?? ''}';
    final String? statusLabel = status.isEmpty
        ? customerText(item['status_display'])
        : _serviceStatusText(status, loc, item['status_display']);
    final Color color = customerStatusColor(status);
    final String title = customerText(item['title']) ?? loc.cust_service_title;
    final String? description = customerText(item['description']);
    final String? subjects = _subjectNames(item['subjects']);
    final String? organ = customerText(item['organ_name']);
    final String? serial = customerText(item['serial_number']);
    final String? created =
        customerText(item['created_jalali']) ??
        customerText(item['created_at']);
    final String? cost = _serviceMoney(item['hazine'], loc);
    final bool warranty =
        item.containsKey('warranty') &&
        item['warranty'] != null &&
        customerFlag(item['warranty']);
    final List<(IconData, String, String, Color?)> fields =
        <(IconData, String, String, Color?)>[
          if (subjects != null)
            (Icons.category, loc.cust_subjects, subjects, null),
          if (organ != null)
            (Icons.apartment_outlined, loc.tech_organ_name, organ, null),
          if (serial != null) (Icons.numbers, loc.cust_serial, serial, null),
          if (cost != null)
            (Icons.attach_money, loc.cust_cost, cost, AppColors.lapisLazuli),
          if (warranty)
            (
              Icons.verified_user,
              loc.cust_warranty_title,
              loc.driver_yes,
              AppColors.lapisLazuli,
            ),
          if (created != null)
            (Icons.calendar_today, loc.cust_created, created, null),
        ];

    const TextStyle metaStyle = TextStyle(
      fontSize: 12,
      fontFamily: 'Vazir',
      color: AppColors.iranianGray,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
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
                if (statusLabel != null && statusLabel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Vazir',
                        color: color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Vazir',
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                      if (description != null && description != title) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'Vazir',
                            color: AppColors.iranianGray,
                          ),
                        ),
                      ],
                      for (final (
                            IconData icon,
                            String label,
                            String value,
                            Color? valueColor,
                          )
                          in fields)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(
                                icon,
                                size: 14,
                                color: valueColor ?? AppColors.iranianGray,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$label: $value',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: valueColor == null
                                      ? metaStyle
                                      : metaStyle.copyWith(
                                          color: valueColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
      ),
    );
  }
}

class CustomerServiceFormScreen extends StatefulWidget {
  const CustomerServiceFormScreen({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<CustomerServiceFormScreen> createState() =>
      _CustomerServiceFormScreenState();
}

class _CustomerServiceFormScreenState extends State<CustomerServiceFormScreen> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _serial = TextEditingController();
  List<Map<String, dynamic>> _subjects = <Map<String, dynamic>>[];
  final Set<int> _selected = <int>{};
  PickedCustomerFile? _invoice;
  bool _loading = true;
  bool _saving = false;
  String _error = '';

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Map<String, dynamic>? existing = widget.existing;
    if (existing != null) {
      _title.text = customerText(existing['title']) ?? '';
      _description.text = customerText(existing['description']) ?? '';
      _address.text = customerText(existing['address']) ?? '';
      _serial.text = customerText(existing['serial_number']) ?? '';
      if (existing['subjects'] is List) {
        for (final dynamic subject in existing['subjects'] as List) {
          if (subject is Map && subject['id'] != null) {
            _selected.add(int.parse('${subject['id']}'));
          }
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadSubjects();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _address.dispose();
    _serial.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    try {
      final dynamic data = await customerGet(
        '/customer/services/subjects/',
        fallback: loc.cust_load_failed,
      );
      if (!mounted) return;
      setState(() {
        _subjects = data is List
            ? data
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : <Map<String, dynamic>>[];
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

  Future<void> _submit() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    if (_title.text.trim().isEmpty || _description.text.trim().isEmpty) {
      setState(() => _error = loc.cust_required);
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = loc.cust_subjects_required);
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final Map<String, String> fields = <String, String>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
      };
      if (_address.text.trim().isNotEmpty) {
        fields['address'] = _address.text.trim();
      }
      if (_serial.text.trim().isNotEmpty) {
        fields['serial_number'] = _serial.text.trim();
      }
      final Map<String, PickedCustomerFile> files =
          <String, PickedCustomerFile>{};
      if (_invoice != null) files['invoice_file'] = _invoice!;
      final String path = _editing
          ? '/customer/services/${widget.existing!['id']}/update/'
          : '/customer/services/create/';
      await customerMultipart(
        method: _editing ? 'PUT' : 'POST',
        path: path,
        fields: fields,
        repeatedFields: <String, List<String>>{
          'subject_ids': _selected.map((int id) => '$id').toList(),
        },
        files: files,
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
      appBar: customerAppBar(
        context,
        title: _editing ? loc.cust_edit : loc.cust_service_title,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : customerRequestBody(
              context,
              title: loc.cust_service_title,
              description: loc.cust_service_subtitle,
              bannerIcon: Icons.build_outlined,
              children: [
                TextField(
                  controller: _title,
                  maxLength: 100,
                  decoration: customerFieldDecoration(context, loc.cust_title),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  maxLength: 300,
                  minLines: 3,
                  maxLines: 5,
                  decoration: customerFieldDecoration(
                    context,
                    loc.cust_description,
                  ),
                ),
                const SizedBox(height: 12),
                Text(loc.cust_subjects),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _subjects.map((Map<String, dynamic> subject) {
                    final int id = int.parse('${subject['id']}');
                    final bool selected = _selected.contains(id);
                    return FilterChip(
                      label: Text(customerText(subject['name']) ?? '$id'),
                      selected: selected,
                      onSelected: (bool value) {
                        setState(() {
                          if (value) {
                            _selected.add(id);
                          } else {
                            _selected.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  maxLength: 200,
                  decoration: customerFieldDecoration(
                    context,
                    '${loc.cust_address} (${loc.cust_optional})',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serial,
                  maxLength: 30,
                  decoration: customerFieldDecoration(
                    context,
                    '${loc.cust_serial} (${loc.cust_optional})',
                  ),
                ),
                const SizedBox(height: 12),
                CustomerFileField(
                  label: loc.cust_invoice_file,
                  file: _invoice,
                  onPick: () async {
                    final PickedCustomerFile? file = await pickCustomerFile(
                      context,
                    );
                    if (file != null) setState(() => _invoice = file);
                  },
                  onClear: () => setState(() => _invoice = null),
                ),
                if (_error.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
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

class CustomerServiceDetailScreen extends StatefulWidget {
  const CustomerServiceDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<CustomerServiceDetailScreen> createState() =>
      _CustomerServiceDetailScreenState();
}

class _CustomerServiceDetailScreenState
    extends State<CustomerServiceDetailScreen> {
  Map<String, dynamic>? _item;
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final dynamic data = await customerGet(
        '/customer/services/${widget.id}/',
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: customerAppBar(context, title: loc.sps_service_details),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text(_error))
          : _serviceDetails(loc, _item),
    );
  }

  Widget _serviceDetails(AppLocalizations loc, Map<String, dynamic>? item) {
    final String status = '${item?['status'] ?? ''}';
    final String? statusLabel = status.isEmpty
        ? customerText(item?['status_display'])
        : _serviceStatusText(status, loc, item?['status_display']);
    final String? title = customerText(item?['title']);
    final String? description = customerText(item?['description']);
    final String? serviceId = item?['id'] == null ? null : '${item!['id']}';
    final String? subjects = _subjectNames(item?['subjects']);
    final String? address = customerText(item?['address']);
    final String? serial = customerText(item?['serial_number']);
    final String? customerPhone = customerText(item?['customer_phone']);
    final String? customerName = customerText(item?['customer_full_name']);
    final String? organ = customerText(item?['organ_name']);
    final Map<String, dynamic>? technician = _technicianMap(item);
    final String? note = customerText(item?['admin_note']);
    final String? created =
        customerText(item?['created_jalali']) ??
        customerText(item?['created_at']);
    final String? piecesPrice = _serviceMoney(item?['pieces_price'], loc);
    final String? tariffsPrice = _serviceMoney(item?['tariffs_price'], loc);
    final String? otherCost = _serviceMoney(item?['sayer_hazine'], loc);
    final String? totalCost = _serviceMoney(item?['hazine'], loc);
    final String? warranty = _yesNo(item?['warranty'], loc);
    final String? warrantyConfirm = _yesNo(item?['warranty_confirm'], loc);
    final String? canConfirm = _yesNo(item?['can_confirm'], loc);
    final bool warrantyActive = customerFlag(item?['warranty']);
    final dynamic invoice = item?['invoice_file_url'] ?? item?['invoice_file'];
    final List<Map<String, dynamic>> pieces = _itemMaps(item?['pieces_items']);
    final List<Map<String, dynamic>> tariffs = _itemMaps(
      item?['tariffs_items'],
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      children: [
        if (statusLabel != null && statusLabel.isNotEmpty)
          customerStatusBanner(context, status, statusLabel),
        if (title != null)
          _detailPanel(
            child: Row(
              children: [
                const Icon(
                  Icons.build_circle,
                  color: AppColors.lapisLazuli,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.lapisLazuli,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (description != null)
          _detailPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.cust_description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lapisLazuli,
                  ),
                ),
                const SizedBox(height: 8),
                Text(description, style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
        if (serviceId != null)
          CustomerInfoRow(
            icon: Icons.tag,
            label: loc.tech_service_id,
            value: serviceId,
          ),
        if (subjects != null)
          CustomerInfoRow(
            icon: Icons.category,
            label: loc.cust_subjects,
            value: subjects,
          ),
        if (address != null)
          CustomerInfoRow(
            icon: Icons.location_on,
            label: loc.cust_address,
            value: address,
          ),
        if (serial != null)
          CustomerInfoRow(
            icon: Icons.numbers,
            label: loc.cust_serial,
            value: serial,
          ),
        if (customerPhone != null)
          _phoneRow(loc.cust_customer_phone, customerPhone),
        if (customerName != null)
          CustomerInfoRow(
            icon: Icons.person,
            label: loc.tech_customer_name,
            value: customerName,
          ),
        if (organ != null)
          CustomerInfoRow(
            icon: Icons.apartment_outlined,
            label: loc.tech_organ_name,
            value: organ,
          ),
        if (technician != null) _technicianPanel(loc, technician),
        if (note != null)
          CustomerInfoRow(
            icon: Icons.notes,
            label: loc.cust_admin_note,
            value: note,
          ),
        if (warranty != null)
          CustomerInfoRow(
            icon: Icons.verified_user,
            label: loc.cust_warranty_title,
            value: warranty,
          ),
        if (warrantyConfirm != null)
          CustomerInfoRow(
            icon: Icons.verified_outlined,
            label: loc.cust_warranty_confirm,
            value: warrantyConfirm,
          ),
        if (canConfirm != null)
          CustomerInfoRow(
            icon: Icons.fact_check_outlined,
            label: loc.cust_can_confirm,
            value: canConfirm,
          ),
        if (item != null && item['time'] != null)
          CustomerInfoRow(
            icon: Icons.timer_outlined,
            label: loc.sps_time_required,
            value: '${item['time']} ${loc.sps_minutes}',
          ),
        if (item != null && item['grade'] != null)
          CustomerInfoRow(
            icon: Icons.star_outline,
            label: loc.sps_service_grade,
            value: '${item['grade']}',
          ),
        if (piecesPrice != null ||
            tariffsPrice != null ||
            otherCost != null ||
            totalCost != null ||
            warrantyActive)
          _detailPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.attach_money,
                      color: AppColors.lapisLazuli,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      loc.sps_cost_info,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lapisLazuli,
                      ),
                    ),
                  ],
                ),
                if (piecesPrice != null)
                  CustomerInfoRow(
                    icon: Icons.settings,
                    label: loc.sps_piece_cost,
                    value: piecesPrice,
                  ),
                if (tariffsPrice != null)
                  CustomerInfoRow(
                    icon: Icons.payments_outlined,
                    label: loc.cust_tariffs,
                    value: tariffsPrice,
                  ),
                if (otherCost != null)
                  CustomerInfoRow(
                    icon: Icons.more_horiz,
                    label: loc.sps_other_costs,
                    value: otherCost,
                  ),
                if (totalCost != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.sls_all_cost,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                      Text(
                        totalCost,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                    ],
                  ),
                ],
                if (warrantyActive) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user,
                        color: AppColors.lapisLazuli,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        loc.sls_payable_zero,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        if (pieces.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              loc.cust_pieces,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.lapisLazuli,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final Map<String, dynamic> piece in pieces)
            _lineItemPanel(
              icon: Icons.settings,
              title: customerText(piece['piece_name']) ?? loc.cust_pieces,
              rows: _objectRows(loc, piece, skip: const <String>{'piece_name'}),
            ),
        ],
        if (tariffs.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              loc.cust_tariffs,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.lapisLazuli,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final Map<String, dynamic> tariff in tariffs)
            _lineItemPanel(
              icon: Icons.payments_outlined,
              title: customerText(tariff['tariff_name']) ?? loc.cust_tariffs,
              rows: _objectRows(
                loc,
                tariff,
                skip: const <String>{'tariff_name'},
              ),
            ),
        ],
        if (customerHasFile(invoice)) _invoiceTile(loc, invoice),
        ..._extraServiceRows(loc, item),
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
      ],
    );
  }

  List<Widget> _objectRows(
    AppLocalizations loc,
    Map<String, dynamic> data, {
    Set<String> skip = const <String>{},
  }) {
    final List<Widget> rows = <Widget>[];
    for (final MapEntry<String, dynamic> entry in data.entries) {
      if (skip.contains(entry.key)) continue;
      final String? text = _serviceFieldText(entry.key, entry.value, loc);
      if (text == null) continue;
      rows.add(_plainRow(_serviceFieldLabel(entry.key, loc), text));
    }
    return rows;
  }

  List<Widget> _extraServiceRows(
    AppLocalizations loc,
    Map<String, dynamic>? item,
  ) {
    if (item == null) return const <Widget>[];
    const Set<String> shown = <String>{
      'id',
      'title',
      'description',
      'subjects',
      'subject',
      'serial_number',
      'address',
      'phone',
      'status',
      'status_display',
      'warranty',
      'warranty_confirm',
      'admin_note',
      'organ_name',
      'customer_full_name',
      'customer_phone',
      'pieces_price',
      'tariffs_price',
      'sayer_hazine',
      'hazine',
      'pieces_items',
      'tariffs_items',
      'can_confirm',
      'assignment',
      'technician',
      'created_jalali',
      'created_at',
      'invoice_file',
      'invoice_file_url',
      'time',
      'grade',
    };
    final List<Widget> rows = <Widget>[];
    for (final MapEntry<String, dynamic> entry in item.entries) {
      if (shown.contains(entry.key)) continue;
      if (entry.value is Map) {
        final Map<String, dynamic> nested = Map<String, dynamic>.from(
          entry.value as Map,
        );
        for (final MapEntry<String, dynamic> sub in nested.entries) {
          final String? text = _serviceFieldText(sub.key, sub.value, loc);
          if (text == null) continue;
          rows.add(
            CustomerInfoRow(
              label: _serviceFieldLabel(sub.key, loc),
              value: text,
            ),
          );
        }
        continue;
      }
      if (customerHasFile(entry.value) &&
          (entry.key.contains('file') || entry.key.endsWith('_url'))) {
        rows.add(
          _invoiceTile(
            loc,
            entry.value,
            label: _serviceFieldLabel(entry.key, loc),
          ),
        );
        continue;
      }
      final String? text = _serviceFieldText(entry.key, entry.value, loc);
      if (text == null) continue;
      rows.add(
        CustomerInfoRow(label: _serviceFieldLabel(entry.key, loc), value: text),
      );
    }
    return rows;
  }

  Widget _technicianPanel(
    AppLocalizations loc,
    Map<String, dynamic> technician,
  ) {
    final String? name = _technicianName(technician);
    final String? phone =
        customerText(technician['technician_phone']) ??
        customerText(technician['phone']);
    final String? organ =
        customerText(technician['technician_organ_name']) ??
        customerText(technician['organ_name']);
    final String? firstVisit = customerText(technician['first_visit_jalali']);
    final String? secondVisit = customerText(technician['second_visit_jalali']);
    final String? comment = customerText(technician['comment']);
    final String? report = customerText(technician['report']);
    final String? grade = customerText(technician['grade']);
    final String? customerConfirm = technician['customer_confirm'] == null
        ? null
        : _withDate(
            _yesNo(technician['customer_confirm'], loc),
            technician['customer_confirm_date'],
          );
    final String? technicianConfirm = technician['technician_confirm'] == null
        ? null
        : _withDate(
            _yesNo(technician['technician_confirm'], loc),
            technician['technician_confirm_date'],
          );
    if (name == null &&
        phone == null &&
        organ == null &&
        firstVisit == null &&
        secondVisit == null &&
        comment == null &&
        report == null &&
        grade == null &&
        customerConfirm == null &&
        technicianConfirm == null) {
      return const SizedBox.shrink();
    }
    return _detailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.engineering_outlined,
                color: AppColors.lapisLazuli,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                loc.sps_technician,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lapisLazuli,
                ),
              ),
            ],
          ),
          if (name != null)
            CustomerInfoRow(
              icon: Icons.person_outline,
              label: loc.sps_technician_name,
              value: name,
            ),
          if (phone != null) _phoneRow(loc.sps_technician_phone, phone),
          if (organ != null)
            CustomerInfoRow(
              icon: Icons.apartment_outlined,
              label: loc.tech_organ_name,
              value: organ,
            ),
          if (firstVisit != null)
            CustomerInfoRow(
              icon: Icons.event_outlined,
              label: loc.tech_first_visit_date,
              value: firstVisit,
            ),
          if (secondVisit != null)
            CustomerInfoRow(
              icon: Icons.event_repeat_outlined,
              label: loc.tech_second_visit_date,
              value: secondVisit,
            ),
          if (grade != null)
            CustomerInfoRow(
              icon: Icons.star_outline,
              label: loc.sps_technician_grade,
              value: grade,
            ),
          if (comment != null)
            CustomerInfoRow(
              icon: Icons.notes,
              label: loc.sps_comment,
              value: comment,
            ),
          if (report != null)
            CustomerInfoRow(
              icon: Icons.description_outlined,
              label: loc.tech_report,
              value: report,
            ),
          if (customerConfirm != null)
            CustomerInfoRow(
              icon: Icons.fact_check_outlined,
              label: loc.driver_customer_confirm,
              value: customerConfirm,
            ),
          if (technicianConfirm != null)
            CustomerInfoRow(
              icon: Icons.verified_outlined,
              label: loc.cust_technician_confirm,
              value: technicianConfirm,
            ),
          ..._objectRows(
            loc,
            technician,
            skip: const <String>{
              'id',
              'first_name',
              'last_name',
              'full_name',
              'name',
              'username',
              'phone',
              'technician_name',
              'technician_phone',
              'technician_organ_name',
              'organ_name',
              'first_visit_jalali',
              'second_visit_jalali',
              'grade',
              'comment',
              'report',
              'customer_confirm',
              'technician_confirm',
              'customer_confirm_date',
              'technician_confirm_date',
            },
          ),
        ],
      ),
    );
  }

  Widget _phoneRow(String label, String phone) {
    return CustomerInfoRow(
      icon: Icons.phone,
      label: label,
      value: phone,
      valueWidget: TappablePhone(
        phone: phone,
        style: TextStyle(
          fontSize: 14,
          fontFamily: 'Vazir',
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _plainRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'Vazir',
                color: AppColors.lapisLazuli,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Vazir',
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineItemPanel({
    required IconData icon,
    required String title,
    required List<Widget> rows,
  }) {
    return _detailPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.lapisLazuli, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.lapisLazuli,
                  ),
                ),
              ),
            ],
          ),
          ...rows,
        ],
      ),
    );
  }

  Widget _detailPanel({required Widget child}) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dark
              ? Colors.grey[700]!
              : AppColors.lapisLazuli.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: dark
                ? Colors.black.withValues(alpha: 0.2)
                : AppColors.lapisLazuli.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _invoiceTile(AppLocalizations loc, dynamic url, {String? label}) {
    final String? name = customerText(url);
    final String leaf = name == null
        ? loc.cust_invoice_file
        : Uri.decodeComponent(
            name
                .split('?')
                .first
                .split('/')
                .where((String p) => p.isNotEmpty)
                .last,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: AppColors.lapisLazuli.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => downloadCustomerUrl(context, url, name: 'invoice'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.lapisLazuli,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label ?? loc.cust_invoice_file,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                      Text(
                        leaf,
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
      ),
    );
  }
}

const Set<String> _moneyKeys = <String>{
  'pieces_price',
  'tariffs_price',
  'sayer_hazine',
  'hazine',
  'unit_price',
  'total_price',
  'price',
  'cost',
};

const Set<String> _flagKeys = <String>{
  'warranty',
  'warranty_confirm',
  'can_confirm',
  'is_const_price',
  'customer_confirm',
  'technician_confirm',
  'bime',
};

String? _serviceFieldText(String key, dynamic value, AppLocalizations loc) {
  if (value == null) return null;
  if (value is bool || _flagKeys.contains(key)) return _yesNo(value, loc);
  if (key == 'time') {
    final String? text = customerText(value);
    if (text == null) return null;
    return '$text ${loc.sps_minutes}';
  }
  if (_moneyKeys.contains(key)) return _serviceMoney(value, loc);
  if (value is List) {
    if (value.isEmpty) return null;
    final String? names = _subjectNames(value);
    return names ?? customerText(value);
  }
  if (value is Map) {
    if (value.isEmpty) return null;
    return customerText(value);
  }
  return customerText(value);
}

String _serviceFieldLabel(String key, AppLocalizations loc) {
  switch (key) {
    case 'id':
      return loc.cust_field_id;
    case 'piece':
      return loc.cust_pieces;
    case 'tariff':
    case 'tariff_name':
    case 'tariffs_price':
      return loc.cust_tariffs;
    case 'piece_name':
      return loc.tech_piece_name;
    case 'count':
      return loc.tech_count;
    case 'unit_price':
    case 'price':
      return loc.sps_piece_price;
    case 'total_price':
    case 'hazine':
    case 'cost':
      return loc.sls_all_cost;
    case 'pieces_price':
      return loc.sps_piece_cost;
    case 'sayer_hazine':
      return loc.sps_other_costs;
    case 'is_const_price':
      return loc.cust_fixed_price;
    case 'phone':
      return loc.driver_phone;
    case 'customer_phone':
      return loc.cust_customer_phone;
    case 'time':
      return loc.sps_time_required;
    case 'grade':
      return loc.sps_service_grade;
    case 'technician':
    case 'assignment':
      return loc.sps_technician;
    case 'name':
    case 'full_name':
    case 'username':
      return loc.sps_technician_name;
    case 'address':
      return loc.cust_address;
    case 'serial_number':
      return loc.cust_serial;
    case 'admin_note':
    case 'note':
      return loc.cust_admin_note;
    case 'organ_name':
      return loc.tech_organ_name;
    case 'warranty':
      return loc.cust_warranty_title;
    case 'warranty_confirm':
      return loc.cust_warranty_confirm;
    case 'can_confirm':
      return loc.cust_can_confirm;
    case 'customer_full_name':
      return loc.tech_customer_name;
    case 'subjects':
    case 'subject':
      return loc.cust_subjects;
    case 'description':
      return loc.cust_description;
    case 'title':
      return loc.cust_title;
    case 'created_jalali':
    case 'created_at':
      return loc.cust_created;
    default:
      return key.replaceAll('_', ' ');
  }
}

String? _yesNo(dynamic value, AppLocalizations loc) {
  if (value == null) return null;
  if (value is bool) return value ? loc.driver_yes : loc.driver_no;
  if (value is num) return value != 0 ? loc.driver_yes : loc.driver_no;
  final String text = value.toString().trim().toLowerCase();
  if (text.isEmpty || text == 'null' || text == 'none') return null;
  if (text == 'true' || text == '1' || text == 'yes') return loc.driver_yes;
  if (text == 'false' || text == '0' || text == 'no') return loc.driver_no;
  return customerText(value);
}

String? _subjectNames(dynamic raw) {
  if (raw is! List || raw.isEmpty) return null;
  final List<String> names = raw
      .map(
        (dynamic subject) =>
            customerText(subject is Map ? subject['name'] : subject),
      )
      .whereType<String>()
      .toList();
  if (names.isEmpty) return null;
  return names.join('، ');
}

String _serviceStatusText(
  String status,
  AppLocalizations loc,
  dynamic display,
) {
  switch (status) {
    case 'open':
      return loc.sps_status_open;
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
    default:
      return customerText(display) ?? status;
  }
}

String? _serviceMoney(dynamic value, AppLocalizations loc) {
  if (value == null) return null;
  final String grouped = formatGroupedNumber(value);
  if (grouped == '---') return null;
  return '$grouped ${loc.sls_tooman}';
}

List<Map<String, dynamic>> _itemMaps(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((Map item) => Map<String, dynamic>.from(item))
      .toList();
}

Map<String, dynamic>? _technicianMap(Map<String, dynamic>? item) {
  if (item == null) return null;
  final dynamic technician = item['technician'];
  if (technician is Map && technician.isNotEmpty) {
    return Map<String, dynamic>.from(technician);
  }
  final dynamic assignment = item['assignment'];
  if (assignment is Map && assignment.isNotEmpty) {
    return Map<String, dynamic>.from(assignment);
  }
  final String? name =
      customerText(technician is Map ? null : technician) ??
      customerText(assignment is Map ? null : assignment);
  if (name == null) return null;
  return <String, dynamic>{'full_name': name};
}

String? _withDate(String? value, dynamic date) {
  final String? when = customerText(date);
  if (value == null) return when;
  if (when == null) return value;
  return '$value - $when';
}

String? _technicianName(Map<String, dynamic> technician) {
  final String? assigned = customerText(technician['technician_name']);
  if (assigned != null) return assigned;
  final String? full = customerText(technician['full_name']);
  if (full != null) return full;
  final String? named = customerText(technician['name']);
  if (named != null) return named;
  final String joined =
      '${customerText(technician['first_name']) ?? ''} ${customerText(technician['last_name']) ?? ''}'
          .trim();
  if (joined.isNotEmpty) return joined;
  return customerText(technician['username']);
}
