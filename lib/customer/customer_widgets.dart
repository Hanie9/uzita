import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/customer/customer_api.dart';
import 'package:uzita/customer/customer_navigation.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/read_local_file_bytes.dart';
import 'package:uzita/utils/shared_bottom_nav.dart';
import 'package:uzita/utils/shared_drawer.dart';
import 'package:uzita/utils/transport_attachment_utils.dart';
import 'package:uzita/utils/ui_scale.dart';

const List<String> kCustomerFileExtensions = <String>[
  'pdf',
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
  'heic',
];

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.body,
    this.floatingActionButton,
  });

  final String title;
  final int selectedIndex;
  final Widget body;
  final Widget? floatingActionButton;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _username = '';
  DateTime? _lastBackPressedAt;

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _username = accountHeaderName(
        organType: 'customer',
        username: prefs.getString('username') ?? '',
        firstName: prefs.getString('first_name') ?? '',
        lastName: prefs.getString('last_name') ?? '',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        final DateTime now = DateTime.now();
        if (_lastBackPressedAt == null ||
            now.difference(_lastBackPressedAt!) > const Duration(seconds: 2)) {
          _lastBackPressedAt = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.click_again_to_exit),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: customerAppBar(
          context,
          title: widget.title,
          showMenu: true,
          onMenu: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        drawer: SharedAppDrawer(
          username: _username,
          userRoleTitle: loc.home_customer,
          userModir: false,
          userLevel: 2,
          organType: 'customer',
          refreshUserData: _loadUsername,
          logout: () => customerLogout(context),
          userActive: true,
        ),
        body: widget.body,
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: SharedBottomNavigation(
          selectedIndex: widget.selectedIndex,
          userLevel: 2,
          organType: 'customer',
          onItemTapped: (int index) => openCustomerTab(context, index),
        ),
      ),
    );
  }
}

class CustomerListView extends StatelessWidget {
  const CustomerListView({
    super.key,
    required this.loading,
    required this.error,
    required this.items,
    required this.onRefresh,
    required this.itemBuilder,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
    this.headerTitle,
    this.headerIcon,
    this.headerSubtitle,
    this.headerCountLabel,
    this.emptyTitle,
    this.onCreate,
  });

  final bool loading;
  final String error;
  final List<Map<String, dynamic>> items;
  final Future<void> Function() onRefresh;
  final Widget Function(Map<String, dynamic> item) itemBuilder;
  final bool hasMore;
  final bool loadingMore;
  final VoidCallback? onLoadMore;
  final String? headerTitle;
  final IconData? headerIcon;
  final String? headerSubtitle;
  final String? headerCountLabel;
  final String? emptyTitle;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        if (headerTitle != null && headerIcon != null)
          _CustomerListBanner(
            icon: headerIcon!,
            title: headerTitle!,
            subtitle: headerSubtitle ?? '',
            countText: (headerCountLabel ?? '').isEmpty
                ? null
                : '${items.length} $headerCountLabel',
            onCreate: onCreate,
            createLabel: loc.cust_new_request,
          ),
        Expanded(child: _buildBody(context, loc)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations loc) {
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error.isNotEmpty && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Vazir'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onRefresh,
                child: Text(
                  loc.cust_load_more,
                  style: const TextStyle(fontFamily: 'Vazir'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.lapisLazuli.withValues(alpha: 0.1),
                              AppColors.lapisLazuli.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.lapisLazuli.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          headerIcon ?? Icons.inbox_outlined,
                          size: 64,
                          color: AppColors.lapisLazuli,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        emptyTitle ?? loc.cust_empty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Vazir',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      if ((headerSubtitle ?? '').isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.blue[900]!.withValues(alpha: 0.1)
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.blue[700]!.withValues(alpha: 0.3)
                                    : Colors.blue[100]!,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: AppColors.lapisLazuli,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    headerSubtitle!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Vazir',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.lapisLazuli,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length + (hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (BuildContext context, int index) {
          if (index >= items.length) {
            return Center(
              child: loadingMore
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    )
                  : TextButton(
                      onPressed: onLoadMore,
                      child: Text(
                        loc.cust_load_more,
                        style: const TextStyle(fontFamily: 'Vazir'),
                      ),
                    ),
            );
          }
          return itemBuilder(items[index]);
        },
      ),
    );
  }
}

class _CustomerListBanner extends StatelessWidget {
  const _CustomerListBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.createLabel,
    this.countText,
    this.onCreate,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? countText;
  final String createLabel;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.lapisLazuli,
            AppColors.lapisLazuli.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.lapisLazuli.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Vazir',
                  ),
                ),
                if ((countText ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.list_alt,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        countText!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontFamily: 'Vazir',
                        ),
                      ),
                    ],
                  ),
                ] else if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontFamily: 'Vazir',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onCreate != null)
            GestureDetector(
              onTap: onCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      createLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Vazir',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CustomerMetaLine {
  const CustomerMetaLine(this.icon, this.text, {this.color});

  final IconData icon;
  final String text;
  final Color? color;
}

Color customerStatusColor(String status) {
  switch (status) {
    case 'done':
    case 'confirmed':
      return Colors.green;
    case 'confirm':
      return Colors.blue;
    case 'canceled':
    case 'rejected':
      return Colors.red;
    default:
      return Colors.orange;
  }
}

class CustomerRecordCard extends StatelessWidget {
  const CustomerRecordCard({
    super.key,
    required this.title,
    required this.status,
    required this.onTap,
    this.statusCode = '',
    this.lines = const <CustomerMetaLine>[],
  });

  final String title;
  final String status;
  final String statusCode;
  final List<CustomerMetaLine> lines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = customerStatusColor(statusCode);
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
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
                if (status.isNotEmpty)
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
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Vazir',
                        color: color,
                      ),
                    ),
                  ),
                if (status.isNotEmpty) const SizedBox(width: 12),
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
                      if (lines.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            for (final CustomerMetaLine line in lines)
                              if (line.text.trim().isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      line.icon,
                                      size: 14,
                                      color:
                                          line.color ?? AppColors.iranianGray,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        line.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'Vazir',
                                          color:
                                              line.color ??
                                              AppColors.iranianGray,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          ],
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
      ),
    );
  }
}

Widget customerStatusBanner(
  BuildContext context,
  String statusCode,
  String label,
) {
  if (label.trim().isEmpty) return const SizedBox.shrink();
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      color: customerStatusColor(statusCode),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.info_outline, color: Colors.white, size: 24),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Vazir',
            ),
          ),
        ),
      ],
    ),
  );
}

class CustomerInfoRow extends StatelessWidget {
  const CustomerInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon = Icons.info_outline,
    this.valueWidget,
  });

  final String label;
  final String value;
  final IconData icon;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final String shown = value.trim().isEmpty ? '---' : value.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[700]!
              : AppColors.lapisLazuli.withValues(alpha: 0.08),
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
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'Vazir',
                    color: AppColors.lapisLazuli,
                  ),
                ),
                const SizedBox(height: 4),
                valueWidget ??
                    Text(
                      shown,
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Vazir',
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

Widget customerNoteBox(BuildContext context, String title, String value) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          fontFamily: 'Vazir',
          color: AppColors.lapisLazuli,
        ),
      ),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[700]!
                : AppColors.lapisLazuli.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          value.trim().isEmpty ? '---' : value.trim(),
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            fontFamily: 'Vazir',
            color:
                Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
          ),
        ),
      ),
    ],
  );
}

class CustomerFileField extends StatelessWidget {
  const CustomerFileField({
    super.key,
    required this.label,
    required this.file,
    required this.onPick,
    required this.onClear,
    this.requiredFile = false,
  });

  final String label;
  final PickedCustomerFile? file;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final bool requiredFile;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          requiredFile ? label : '$label (${loc.cust_optional})',
          style: const TextStyle(
            fontFamily: 'Vazir',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Material(
          color: dark
              ? Colors.grey[800]
              : AppColors.lapisLazuli.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPick,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, color: AppColors.lapisLazuli),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file?.name ?? loc.cust_pick_file,
                      style: const TextStyle(fontFamily: 'Vazir'),
                    ),
                  ),
                  if (file != null)
                    IconButton(
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          loc.cust_file_formats_hint,
          style: const TextStyle(
            fontFamily: 'Vazir',
            fontSize: 12,
            height: 1.4,
            color: AppColors.iranianGray,
          ),
        ),
      ],
    );
  }
}

Future<PickedCustomerFile?> pickCustomerFile(BuildContext context) async {
  final FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: kCustomerFileExtensions,
    withData: true,
    allowMultiple: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final PlatformFile file = result.files.single;
  final String name = file.name;
  final String lower = name.toLowerCase();
  final bool allowed = kCustomerFileExtensions.any(
    (String ext) => lower.endsWith('.$ext'),
  );
  if (!allowed) return null;
  Uint8List? bytes = file.bytes;
  if (bytes == null && file.path != null) {
    bytes = await readLocalFileBytes(file.path!);
  }
  if (bytes == null) return null;
  return PickedCustomerFile(name: name, bytes: bytes);
}

Future<void> downloadCustomerUrl(
  BuildContext context,
  dynamic url, {
  String name = 'attachment',
}) async {
  if (!customerHasFile(url)) return;
  await downloadTransportAttachment(
    context: context,
    data: <String, dynamic>{
      'attachment_url': url.toString(),
      'attachment_name': name,
    },
    keys: const <String>['attachment_url'],
  );
}

Future<bool> confirmCustomerDelete(BuildContext context) async {
  final AppLocalizations loc = AppLocalizations.of(context)!;
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: Text(loc.cust_delete),
      content: Text(loc.cust_delete_confirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(loc.home_no),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(loc.cust_delete),
        ),
      ],
    ),
  );
  return ok == true;
}

void showCustomerMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

PreferredSizeWidget customerAppBar(
  BuildContext context, {
  required String title,
  List<Widget> actions = const <Widget>[],
  bool showMenu = false,
  VoidCallback? onMenu,
}) {
  final ThemeData theme = Theme.of(context);
  final double logo = MediaQuery.of(context).size.height * 0.08;
  final Widget logoImage = Image.asset(
    'assets/logouzita.png',
    height: logo,
    width: logo,
    fit: BoxFit.contain,
  );
  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight),
    child: Container(
      decoration: BoxDecoration(
        color: theme.appBarTheme.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: kToolbarHeight,
            child: showMenu
                ? Row(
                    children: <Widget>[
                      IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: theme.appBarTheme.iconTheme?.color,
                        ),
                        onPressed: onMenu,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.notifications,
                          color: theme.appBarTheme.iconTheme?.color,
                        ),
                        onPressed: () {},
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.appBarTheme.titleTextStyle,
                          ),
                        ),
                      ),
                      logoImage,
                    ],
                  )
                : Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back,
                              color: theme.appBarTheme.iconTheme?.color,
                            ),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.appBarTheme.titleTextStyle,
                              ),
                            ),
                          ),
                          ...actions,
                          SizedBox(width: logo),
                        ],
                      ),
                      PositionedDirectional(end: 0, child: logoImage),
                    ],
                  ),
          ),
        ),
      ),
    ),
  );
}

InputDecoration customerFieldDecoration(
  BuildContext context,
  String label, {
  IconData? icon,
}) {
  final bool dark = Theme.of(context).brightness == Brightness.dark;
  final double radius = UiScale(context).scale(base: 14, min: 12, max: 18);
  final Color borderColor = dark ? Colors.grey[700]! : Colors.grey[300]!;
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, color: AppColors.lapisLazuli),
    labelStyle: TextStyle(
      fontFamily: 'Vazir',
      color: dark ? Colors.grey[400] : Colors.grey[700],
    ),
    filled: true,
    fillColor: dark
        ? Colors.grey[800]
        : AppColors.lapisLazuli.withValues(alpha: 0.04),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radius),
      borderSide: const BorderSide(color: AppColors.lapisLazuli, width: 2),
    ),
  );
}

Widget customerRequestBody(
  BuildContext context, {
  required String title,
  required String description,
  required List<Widget> children,
  IconData? bannerIcon,
}) {
  final UiScale ui = UiScale(context);
  final bool dark = Theme.of(context).brightness == Brightness.dark;
  final double radius = ui.scale(base: 16, min: 12, max: 20);
  final Widget formCard = Container(
    width: double.infinity,
    padding: EdgeInsets.all(ui.scale(base: 20, min: 16, max: 24)),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: dark ? Colors.grey[700]! : Colors.grey[200]!),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  if (bannerIcon != null) {
    return Directionality(
      textDirection: Localizations.localeOf(context).languageCode == 'en'
          ? TextDirection.ltr
          : TextDirection.rtl,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          ui.scale(base: 20, min: 16, max: 24),
          ui.scale(base: 28, min: 20, max: 36),
          ui.scale(base: 20, min: 16, max: 24),
          ui.scale(base: 20, min: 16, max: 24) +
              MediaQuery.of(context).padding.bottom,
        ),
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(ui.scale(base: 18, min: 14, max: 22)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.lapisLazuli,
                  AppColors.lapisLazuli.withValues(alpha: 0.82),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lapisLazuli.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(bannerIcon, color: Colors.white, size: 26),
                ),
                SizedBox(width: ui.scale(base: 14, min: 10, max: 16)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Vazir',
                          fontSize: ui.scale(base: 16, min: 14, max: 18),
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontFamily: 'Vazir',
                            height: 1.35,
                            fontSize: ui.scale(base: 13, min: 11, max: 15),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
          formCard,
        ],
      ),
    );
  }
  return Directionality(
    textDirection: Localizations.localeOf(context).languageCode == 'en'
        ? TextDirection.ltr
        : TextDirection.rtl,
    child: ListView(
      padding: EdgeInsets.fromLTRB(
        ui.scale(base: 20, min: 16, max: 24),
        ui.scale(base: 20, min: 16, max: 24),
        ui.scale(base: 20, min: 16, max: 24),
        ui.scale(base: 20, min: 16, max: 24) +
            MediaQuery.of(context).padding.bottom,
      ),
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(ui.scale(base: 20, min: 16, max: 24)),
          decoration: BoxDecoration(
            color: dark
                ? Colors.blue[900]?.withValues(alpha: 0.2)
                : const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: dark
                  ? (Colors.blue[700] ?? Colors.blue).withValues(alpha: 0.5)
                  : const Color(0xFF2196F3).withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(ui.scale(base: 8, min: 6, max: 10)),
                decoration: BoxDecoration(
                  color: dark ? Colors.blue[700] : const Color(0xFF2196F3),
                  borderRadius: BorderRadius.circular(
                    ui.scale(base: 8, min: 6, max: 10),
                  ),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: ui.scale(base: 20, min: 16, max: 24),
                ),
              ),
              SizedBox(width: ui.scale(base: 16, min: 12, max: 20)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Vazir',
                        color: dark
                            ? Colors.blue[300]
                            : const Color(0xFF1976D2),
                        fontSize: ui.scale(base: 16, min: 14, max: 18),
                      ),
                    ),
                    SizedBox(height: ui.scale(base: 4, min: 2, max: 6)),
                    Text(
                      description,
                      style: TextStyle(
                        fontFamily: 'Vazir',
                        height: 1.4,
                        color: dark
                            ? Colors.blue[200]
                            : const Color(0xFF1976D2),
                        fontSize: ui.scale(base: 13, min: 11, max: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: ui.scale(base: 20, min: 16, max: 28)),
        formCard,
      ],
    ),
  );
}

class CustomerPrimaryButton extends StatelessWidget {
  const CustomerPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: onPressed == null
              ? Colors.grey
              : AppColors.lapisLazuli,
          foregroundColor: Colors.white,
          elevation: onPressed == null ? 0 : 2,
          shadowColor: AppColors.lapisLazuli.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Vazir',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

String customerFailure(Object error, AppLocalizations loc) {
  if (error is! CustomerCallException) return loc.cust_connecting;
  if (error.message == 'auth') return loc.cust_login_again;
  final String? text = _customerErrorText(error.data, loc);
  if (text != null && text.isNotEmpty) return text;
  if (error.data == null &&
      error.message.isNotEmpty &&
      error.statusCode == null) {
    return _translateCustomerMessage(error.message, loc) ?? error.message;
  }
  switch (error.statusCode) {
    case 401:
      return loc.cust_login_again;
    case 403:
      return loc.cust_err_forbidden;
    case 404:
      return loc.cust_err_not_found;
    case 413:
      return loc.cust_err_file_too_large;
    default:
      if ((error.statusCode ?? 0) >= 500) return loc.cust_err_server;
      return loc.cust_err_invalid;
  }
}

String? _customerErrorText(dynamic data, AppLocalizations loc) {
  final List<String> lines = <String>[];
  void add(String? text) {
    final String value = text?.trim() ?? '';
    if (value.isNotEmpty && !lines.contains(value)) lines.add(value);
  }

  if (data is Map) {
    final dynamic detail = data['detail'];
    if (detail is String || detail is List) {
      add(_translateCustomerValue(detail, loc));
    } else {
      for (final MapEntry<dynamic, dynamic> entry in data.entries) {
        final String key = entry.key.toString();
        if (key == 'data') continue;
        if (key == 'message' && data['data'] != null) continue;
        final String? field =
            key == 'error' || key == 'message' || key == 'non_field_errors'
            ? null
            : key;
        add(_translateCustomerValue(entry.value, loc, field: field));
      }
    }
  } else {
    add(_translateCustomerValue(data, loc));
  }
  if (lines.isEmpty) return null;
  return lines.join('\n');
}

String? _translateCustomerValue(
  dynamic value,
  AppLocalizations loc, {
  String? field,
}) {
  if (value is List) {
    final List<String> lines = <String>[];
    for (final dynamic item in value) {
      final String? text = _translateCustomerValue(item, loc, field: field);
      if (text != null && text.isNotEmpty && !lines.contains(text)) {
        lines.add(text);
      }
    }
    if (lines.isEmpty) return null;
    return lines.join('\n');
  }
  if (value == null) return null;
  return _translateCustomerMessage(value.toString(), loc, field: field);
}

String? _translateCustomerMessage(
  String raw,
  AppLocalizations loc, {
  String? field,
}) {
  final String text = raw.trim();
  if (text.isEmpty || text == 'null' || text == 'auth') return null;
  final String lower = text.toLowerCase();
  final bool persian = RegExp(r'[\u0600-\u06FF]').hasMatch(text);

  if (text.contains('فرمت فایل مجاز نیست') ||
      (lower.contains('file') && lower.contains('not allowed'))) {
    return loc.cust_err_file_format;
  }
  if (text.contains('شماره') && text.contains('قبلاً')) {
    return loc.cust_err_phone_exists;
  }
  if (text.contains('یکسان نیستند')) return loc.cust_passwords_mismatch;
  if (text.contains('طول شماره تماس')) return loc.cust_phone_invalid;
  if (text.contains('موضوع') && text.contains('نامعتبر')) {
    return loc.cust_err_invalid_subjects;
  }
  if (text.contains('سرویس') && text.contains('قابل حذف')) {
    return loc.cust_err_service_delete_status;
  }
  if (text.contains('سرویس') && text.contains('قابل ویرایش')) {
    return loc.cust_err_service_edit_status;
  }
  if (text.contains('گارانتی') && text.contains('قابل حذف')) {
    return loc.cust_err_warranty_delete_status;
  }
  if (text.contains('گارانتی') && text.contains('قابل ویرایش')) {
    return loc.cust_err_warranty_edit_status;
  }
  if (text.contains('بار') && text.contains('قابل تایید')) {
    return loc.cust_err_bar_confirm_status;
  }
  if (text.contains('تیکت') &&
      text.contains('پاسخ') &&
      (text.contains('۳') || text.contains('3'))) {
    return loc.cust_err_ticket_reply_limit;
  }

  final RegExpMatch? missing = RegExp(
    r'^no (\w+) matches the given query\.?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (missing != null) {
    switch (missing.group(1)!.toLowerCase()) {
      case 'service':
        return loc.cust_err_not_found_service;
      case 'bar':
        return loc.cust_err_not_found_bar;
      case 'ticket':
        return loc.cust_err_not_found_ticket;
      case 'warranty':
        return loc.cust_err_not_found_warranty;
      default:
        return loc.cust_err_not_found;
    }
  }
  if (lower.contains('not found') || text.contains('یافت نشد')) {
    if (lower.contains('file') || text.contains('فایل')) {
      return loc.cust_err_not_found_file;
    }
    return loc.cust_err_not_found;
  }
  if (lower.contains('authentication credentials') ||
      lower.contains('not authenticated')) {
    return loc.cust_login_again;
  }
  if (lower.contains('no active account') ||
      lower.contains('invalid credentials') ||
      lower.contains('unable to log in')) {
    return loc.cust_err_bad_credentials;
  }
  if (lower.contains('permission') ||
      lower.contains('not allowed') ||
      text.contains('دسترسی')) {
    return loc.cust_err_forbidden;
  }
  if (lower.contains('unsupported media type')) return loc.cust_err_invalid;

  final String label = _customerFieldLabel(field, loc);
  if (lower == 'this field is required.') {
    return loc.cust_err_required_field.replaceAll('{field}', label);
  }
  if (lower == 'this field may not be blank.') {
    return loc.cust_err_blank_field.replaceAll('{field}', label);
  }
  final RegExpMatch? maxLength = RegExp(
    r'no more than (\d+) characters',
  ).firstMatch(lower);
  if (maxLength != null) {
    return loc.cust_err_max_length
        .replaceAll('{field}', label)
        .replaceAll('{count}', _customerDigits(maxLength.group(1)!, loc));
  }
  final RegExpMatch? minLength = RegExp(
    r'at least (\d+) characters',
  ).firstMatch(lower);
  if (minLength != null) {
    return loc.cust_err_min_length
        .replaceAll('{field}', label)
        .replaceAll('{count}', _customerDigits(minLength.group(1)!, loc));
  }
  if (lower.contains('is not a valid choice')) {
    return loc.cust_err_invalid_choice.replaceAll('{field}', label);
  }
  if (lower.contains('no file was submitted') ||
      lower.contains('submitted data was not a file') ||
      lower.contains('empty file')) {
    return loc.cust_err_file_missing.replaceAll('{field}', label);
  }
  if (field == 'grade' &&
      (lower.contains('less than or equal') ||
          lower.contains('greater than or equal') ||
          lower.contains('valid integer'))) {
    return loc.cust_err_grade;
  }
  if (lower.contains('too large') ||
      lower.contains('file size') ||
      lower.contains('request body exceeded') ||
      text.contains('مگابایت') ||
      text.contains('حجم فایل')) {
    return loc.cust_err_file_too_large;
  }

  if (persian && loc.locale.languageCode == 'fa') return text;
  if (!persian &&
      loc.locale.languageCode == 'en' &&
      text.length < 180 &&
      !text.startsWith('{') &&
      !text.startsWith('<') &&
      !lower.startsWith('this field') &&
      !lower.startsWith('ensure this')) {
    return text;
  }
  return null;
}

String _customerFieldLabel(String? field, AppLocalizations loc) {
  switch (field) {
    case 'title':
      return loc.cust_title;
    case 'description':
      return loc.cust_description;
    case 'subject':
      return loc.cust_subject;
    case 'subject_ids':
      return loc.cust_subjects;
    case 'address':
      return loc.cust_address;
    case 'serial_number':
      return loc.cust_serial;
    case 'invoice_file':
      return loc.cust_invoice_file;
    case 'warranty_file':
      return loc.cust_warranty_file;
    case 'attachment':
    case 'attachment_file':
      return loc.cust_attachment;
    case 'mabda':
      return loc.cust_origin;
    case 'maghsad':
      return loc.cust_destination;
    case 'grade':
      return loc.cust_grade;
    case 'comment':
      return loc.cust_comment;
    case 'massage':
      return loc.cust_reply;
    case 'phone':
      return loc.pro_phone;
    case 'password':
      return loc.login_password;
    case 'password_confirm':
      return loc.cust_password_confirm;
    case 'first_name':
      return loc.cust_first_name;
    case 'last_name':
      return loc.cust_last_name;
    default:
      return loc.cust_err_this_field;
  }
}

String _customerDigits(String value, AppLocalizations loc) {
  if (loc.locale.languageCode != 'fa') return value;
  const String english = '0123456789';
  const String persian = '۰۱۲۳۴۵۶۷۸۹';
  final StringBuffer buffer = StringBuffer();
  for (final int code in value.codeUnits) {
    final int index = english.indexOf(String.fromCharCode(code));
    buffer.write(index < 0 ? String.fromCharCode(code) : persian[index]);
  }
  return buffer.toString();
}
