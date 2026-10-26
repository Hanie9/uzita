import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/customer/customer_api.dart';
import 'package:uzita/customer/customer_widgets.dart';
import 'package:uzita/services.dart';

class CustomerWarrantyListScreen extends StatefulWidget {
  const CustomerWarrantyListScreen({super.key});

  @override
  State<CustomerWarrantyListScreen> createState() =>
      _CustomerWarrantyListScreenState();
}

class _CustomerWarrantyListScreenState
    extends State<CustomerWarrantyListScreen> {
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
        '/customer/warranties/',
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
    return Scaffold(
      appBar: customerAppBar(context, title: loc.cust_warranty_title),
      body: CustomerListView(
        loading: _loading,
        error: _error,
        items: _items,
        hasMore: _hasMore,
        loadingMore: _loadingMore,
        headerTitle: loc.cust_warranty_title,
        headerSubtitle: loc.cust_warranty_subtitle,
        headerCountLabel: loc.cust_warranty_count,
        headerIcon: Icons.verified_user_outlined,
        onCreate: () async {
          final bool? saved = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => const CustomerWarrantyFormScreen(),
            ),
          );
          if (saved == true) _load(reset: true);
        },
        onRefresh: () => _load(reset: true),
        onLoadMore: () => _load(reset: false),
        itemBuilder: (Map<String, dynamic> item) {
          return CustomerRecordCard(
            title: customerText(item['serial_number']) ?? loc.cust_serial,
            status: customerText(item['status_display']) ?? '',
            statusCode: '${item['status'] ?? ''}',
            lines: <CustomerMetaLine>[
              CustomerMetaLine(
                Icons.calendar_today,
                customerText(item['created_jalali']) ?? '',
              ),
            ],
            onTap: () async {
              final bool? changed = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerWarrantyDetailScreen(
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

class CustomerWarrantyFormScreen extends StatefulWidget {
  const CustomerWarrantyFormScreen({super.key, this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<CustomerWarrantyFormScreen> createState() =>
      _CustomerWarrantyFormScreenState();
}

class _CustomerWarrantyFormScreenState
    extends State<CustomerWarrantyFormScreen> {
  final TextEditingController _serial = TextEditingController();
  PickedCustomerFile? _invoice;
  PickedCustomerFile? _warrantyFile;
  bool _saving = false;
  String _error = '';

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _serial.text = customerText(widget.existing?['serial_number']) ?? '';
  }

  @override
  void dispose() {
    _serial.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final String serial = _serial.text.trim();
    if (serial.length < 6 || serial.length > 30) {
      setState(() => _error = loc.cust_serial_invalid);
      return;
    }
    if (!_editing && _invoice == null) {
      setState(() => _error = loc.cust_file_required);
      return;
    }
    setState(() {
      _saving = true;
      _error = '';
    });
    try {
      final Map<String, PickedCustomerFile> files =
          <String, PickedCustomerFile>{};
      if (_invoice != null) files['invoice_file'] = _invoice!;
      if (_warrantyFile != null) files['warranty_file'] = _warrantyFile!;
      await customerMultipart(
        method: _editing ? 'PUT' : 'POST',
        path: _editing
            ? '/customer/warranties/${widget.existing!['id']}/update/'
            : '/customer/warranties/create/',
        fields: <String, String>{'serial_number': serial},
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
        title: _editing ? loc.cust_edit : loc.cust_warranty_title,
      ),
      body: customerRequestBody(
        context,
        title: loc.cust_warranty_title,
        description: loc.cust_warranty_subtitle,
        bannerIcon: Icons.verified_outlined,
        children: [
          TextField(
            controller: _serial,
            maxLength: 30,
            buildCounter:
                (
                  BuildContext context, {
                  required int currentLength,
                  required bool isFocused,
                  required int? maxLength,
                }) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '$currentLength/$maxLength',
                      style: const TextStyle(
                        fontFamily: 'Vazir',
                        fontSize: 12,
                        height: 1.2,
                        color: AppColors.iranianGray,
                      ),
                    ),
                  );
                },
            decoration: customerFieldDecoration(context, loc.cust_serial),
          ),
          const SizedBox(height: 16),
          CustomerFileField(
            label: loc.cust_invoice_file,
            requiredFile: !_editing,
            file: _invoice,
            onPick: () async {
              final PickedCustomerFile? file = await pickCustomerFile(context);
              if (file != null) setState(() => _invoice = file);
            },
            onClear: () => setState(() => _invoice = null),
          ),
          const SizedBox(height: 16),
          CustomerFileField(
            label: loc.cust_warranty_file,
            file: _warrantyFile,
            onPick: () async {
              final PickedCustomerFile? file = await pickCustomerFile(context);
              if (file != null) setState(() => _warrantyFile = file);
            },
            onClear: () => setState(() => _warrantyFile = null),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          CustomerPrimaryButton(
            onPressed: _saving ? null : _submit,
            label: _saving ? loc.home_loading : loc.cust_save,
          ),
        ],
      ),
    );
  }
}

class CustomerWarrantyDetailScreen extends StatefulWidget {
  const CustomerWarrantyDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<CustomerWarrantyDetailScreen> createState() =>
      _CustomerWarrantyDetailScreenState();
}

class _CustomerWarrantyDetailScreenState
    extends State<CustomerWarrantyDetailScreen> {
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
        '/customer/warranties/${widget.id}/',
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

  Future<void> _delete() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    if (!await confirmCustomerDelete(context)) return;
    if (!mounted) return;
    try {
      await customerDelete(
        '/customer/warranties/${widget.id}/delete/',
        fallback: loc.cust_connecting,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      showCustomerMessage(context, customerFailure(error, loc));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final Map<String, dynamic>? item = _item;
    final bool canEdit =
        item != null && '${item['status']}' == 'pending_confirm';
    return Scaffold(
      appBar: customerAppBar(
        context,
        title: loc.cust_warranty_title,
        actions: [
          if (canEdit)
            IconButton(
              onPressed: () async {
                final bool? saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerWarrantyFormScreen(existing: item),
                  ),
                );
                if (saved == true) _load();
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (canEdit)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
          ? Center(child: Text(_error))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                customerStatusBanner(
                  context,
                  '${item?['status'] ?? ''}',
                  customerText(item?['status_display']) ?? '',
                ),
                CustomerInfoRow(
                  icon: Icons.numbers,
                  label: loc.cust_serial,
                  value: customerText(item?['serial_number']) ?? '',
                ),
                CustomerInfoRow(
                  icon: Icons.notes,
                  label: loc.cust_rejection,
                  value: customerText(item?['rejection_description']) ?? '',
                ),
                CustomerInfoRow(
                  icon: Icons.calendar_today,
                  label: loc.cust_created,
                  value: customerText(item?['created_jalali']) ?? '',
                ),
                CustomerInfoRow(
                  icon: Icons.event_available,
                  label: loc.cust_confirmed_at,
                  value: customerText(item?['confirm_jalali']) ?? '',
                ),
                CustomerInfoRow(
                  icon: Icons.event,
                  label: loc.cust_warranty_until,
                  value: customerText(item?['end_jalali']) ?? '',
                ),
                if (customerFlag(item?['has_warranty']))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(loc.cust_has_warranty),
                  ),
                if (customerHasFile(item?['invoice_file_url']))
                  TextButton(
                    onPressed: () => downloadCustomerUrl(
                      context,
                      item?['invoice_file_url'],
                      name: 'invoice',
                    ),
                    child: Text(loc.cust_invoice_file),
                  ),
                if (customerHasFile(item?['warranty_file_url']))
                  TextButton(
                    onPressed: () => downloadCustomerUrl(
                      context,
                      item?['warranty_file_url'],
                      name: 'warranty',
                    ),
                    child: Text(loc.cust_warranty_file),
                  ),
              ],
            ),
    );
  }
}
