import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/providers/settings_provider.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/number_format_utils.dart';
import 'package:uzita/utils/read_local_file_bytes.dart';
import 'package:uzita/utils/transport_attachment_utils.dart';
import 'package:uzita/utils/ui_scale.dart';
import 'dart:convert';

class TransportNewRequestScreen extends StatefulWidget {
  const TransportNewRequestScreen({super.key});

  @override
  State<TransportNewRequestScreen> createState() =>
      _TransportNewRequestScreenState();
}

class _TransportNewRequestScreenState extends State<TransportNewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maghsadController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _outputController = TextEditingController();
  final _customerController = TextEditingController();
  final _coordinationController = TextEditingController();
  // final _paymentController = TextEditingController();
  final _priceController = TextEditingController();

  // Shared list of available parts (loaded from API)
  // List<String> _availablePieces = [];

  String? _selectedPayment;
  PickedTransportAttachment? _attachment;

  final List<Map<String, String>> paymentTypes = [
    {
      'value': 'direct',
      'label_en': 'Direct from customer',
      'label_fa': 'مستقیم از مشتری',
    },
    {
      'value': 'invoice',
      'label_en': 'Additional to the invoice',
      'label_fa': 'اضافه بر فاکتور',
    },
  ];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // _fetchPieces();
  }

  // Future<void> _fetchPieces() async {
  //   try {
  //     final prefs = await SharedPreferences.getInstance();
  //     final token = prefs.getString('token');

  //     if (token == null) return;

  //     await SessionManager().onNetworkRequest();
  //     final response = await http.get(
  //       Uri.parse('$baseUrl5/listpieces'),
  //       headers: {
  //         'Authorization': 'Bearer $token',
  //         'Content-Type': 'application/json',
  //       },
  //     );

  //     if (!mounted) return;

  //     if (response.statusCode == 200) {
  //       final data = json.decode(utf8.decode(response.bodyBytes));
  //       if (data is List) {
  //         setState(() {
  //           _availablePieces = data
  //               .map((item) => item['name']?.toString() ?? '')
  //               .where((name) => name.isNotEmpty)
  //               .toList();
  //         });
  //       }
  //     }
  //   } catch (e) {
  //     // If API fails, keep empty list - pieces will be loaded from API only
  //     if (mounted) {
  //       setState(() {
  //         _availablePieces = [];
  //       });
  //     }
  //   }
  // }

  @override
  void dispose() {
    _maghsadController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _productDescriptionController.dispose();
    _outputController.dispose();
    _customerController.dispose();
    _coordinationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  bool _isAllowedAttachmentName(String name) {
    return isAllowedTransportAttachmentName(name);
  }

  Future<void> _pickAttachment() async {
    final localizations = AppLocalizations.of(context)!;
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kTransportAttachmentExtensions,
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.single;
      final String name = file.name;
      if (!_isAllowedAttachmentName(name)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.trn_attachment_invalid)),
        );
        return;
      }

      Uint8List? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await readLocalFileBytes(file.path!);
      }

      if (bytes == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.trn_attachment_invalid)),
        );
        return;
      }

      setState(() {
        _attachment = PickedTransportAttachment(
          name: name,
          bytes: bytes!,
          path: file.path,
        );
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.trn_attachment_invalid)),
      );
    }
  }

  String _getpaymentLabel(String value) {
    final localizations = AppLocalizations.of(context)!;

    switch (value) {
      case 'direct':
        return localizations.trn_direct;
      case 'invoice':
        return localizations.trn_invoice;
      default:
        return '';
    }
  }

  Future<void> _submit() async {
    final localizations = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizations.trn_required_error)));
      return;
    }

    // if (_selectedPayment) {
    //   ScaffoldMessenger.of(
    //     context,
    //   ).showSnackBar(SnackBar(content: Text(localizations.trn_required_error)));
    //   return;
    // }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      await SessionManager().onNetworkRequest();

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl5/transport/request'),
      );
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['product_description'] = _productDescriptionController.text
          .trim();
      request.fields['output_number'] = _outputController.text.trim();
      request.fields['maghsad'] = _maghsadController.text.trim();
      request.fields['phone'] = _phoneController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();
      request.fields['customer'] = _customerController.text.trim();
      request.fields['coordination_person'] = _coordinationController.text
          .trim();
      request.fields['payment_type'] = _selectedPayment.toString();
      request.fields['price_transport'] =
          (parseGroupedInt(_priceController.text) ?? 0).toString();

      if (_attachment != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'attachment',
            _attachment!.bytes,
            filename: _attachment!.name,
          ),
        );
      }

      final streamed = await request.send();
      await SessionManager().onNetworkRequest();
      final response = await http.Response.fromStream(streamed);

      if (!mounted) return;

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        String successMessage = localizations.trn_success_message;
        try {
          final data = json.decode(utf8.decode(response.bodyBytes));
          if (data is Map && data['message'] != null) {
            successMessage = data['message'].toString();
          }
        } catch (_) {}

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.lapisLazuli,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  localizations.trn_success_title,
                  style: const TextStyle(
                    color: AppColors.lapisLazuli,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: Text(
              successMessage,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
                },
                child: Text(
                  localizations.trn_ok,
                  style: const TextStyle(
                    color: AppColors.lapisLazuli,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        String errorMessage = localizations.trn_error_send_request;
        try {
          final data = json.decode(utf8.decode(response.bodyBytes));
          if (data is Map && data['error'] != null) {
            errorMessage = data['error'].toString();
          }
        } catch (_) {}

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.trn_error_connecting)),
      );
    }
  }

  // Future<void> _openPiecesMenu() async {
  //   final localizations = AppLocalizations.of(context)!;
  //   final Set<String> tempSelected = Set<String>.from(_selectedPieces);
  //   final TextEditingController searchController = TextEditingController();

  //   await showModalBottomSheet<void>(
  //     context: context,
  //     isScrollControlled: true,
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //     ),
  //     builder: (bottomSheetContext) {
  //       return StatefulBuilder(
  //         builder: (modalContext, modalSetState) {
  //           final String searchQuery = searchController.text;
  //           final List<String> filteredPieces = _availablePieces.where((piece) {
  //             if (searchQuery.trim().isEmpty) return true;
  //             final query = searchQuery.toLowerCase();
  //             return piece.toLowerCase().contains(query);
  //           }).toList();

  //           return DraggableScrollableSheet(
  //             expand: false,
  //             initialChildSize: 0.6,
  //             minChildSize: 0.4,
  //             maxChildSize: 0.9,
  //             builder: (context, scrollController) {
  //               return Column(
  //                 mainAxisSize: MainAxisSize.min,
  //                 children: [
  //                   Padding(
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 16,
  //                       vertical: 12,
  //                     ),
  //                     child: Row(
  //                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                       children: [
  //                         Text(
  //                           localizations.trn_pieces,
  //                           style: const TextStyle(
  //                             fontSize: 16,
  //                             fontWeight: FontWeight.w600,
  //                           ),
  //                         ),
  //                         TextButton(
  //                           onPressed: () =>
  //                               Navigator.of(bottomSheetContext).pop(),
  //                           child: Text(localizations.trn_ok),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   const Divider(height: 1),
  //                   Padding(
  //                     padding: const EdgeInsets.symmetric(
  //                       horizontal: 16,
  //                       vertical: 8,
  //                     ),
  //                     child: Column(
  //                       crossAxisAlignment: CrossAxisAlignment.start,
  //                       children: [
  //                         Row(
  //                           children: [
  //                             const Icon(
  //                               Icons.format_list_numbered,
  //                               size: 18,
  //                               color: AppColors.lapisLazuli,
  //                             ),
  //                             const SizedBox(width: 6),
  //                             Text(
  //                               '${filteredPieces.length} / ${_availablePieces.length}',
  //                               style: const TextStyle(
  //                                 fontSize: 14,
  //                                 fontWeight: FontWeight.w700,
  //                                 color: AppColors.lapisLazuli,
  //                               ),
  //                             ),
  //                             const SizedBox(width: 6),
  //                             Text(
  //                               localizations.trn_pieces,
  //                               style: const TextStyle(
  //                                 fontSize: 13,
  //                                 fontWeight: FontWeight.w500,
  //                                 color: AppColors.iranianGray,
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                         const SizedBox(height: 8),
  //                         TextField(
  //                           controller: searchController,
  //                           decoration: InputDecoration(
  //                             hintText: localizations.trn_piece_hint,
  //                             prefixIcon: const Icon(
  //                               Icons.search,
  //                               size: 20,
  //                               color: AppColors.lapisLazuli,
  //                             ),
  //                             isDense: true,
  //                             contentPadding: const EdgeInsets.symmetric(
  //                               horizontal: 12,
  //                               vertical: 10,
  //                             ),
  //                             border: OutlineInputBorder(
  //                               borderRadius: BorderRadius.circular(12),
  //                             ),
  //                           ),
  //                           onChanged: (_) => modalSetState(() {}),
  //                         ),
  //                       ],
  //                     ),
  //                   ),
  //                   Expanded(
  //                     child: ListView.builder(
  //                       controller: scrollController,
  //                       itemCount: filteredPieces.length,
  //                       itemBuilder: (context, index) {
  //                         final piece = filteredPieces[index];
  //                         final bool isChecked = tempSelected.contains(piece);
  //                         return CheckboxListTile(
  //                           value: isChecked,
  //                           title: Text(
  //                             piece,
  //                             style: const TextStyle(fontSize: 18),
  //                           ),
  //                           onChanged: (checked) {
  //                             modalSetState(() {
  //                               if (checked == true) {
  //                                 tempSelected.add(piece);
  //                               } else {
  //                                 tempSelected.remove(piece);
  //                               }
  //                             });
  //                             setState(() {
  //                               _selectedPieces
  //                                 ..clear()
  //                                 ..addAll(tempSelected);
  //                             });
  //                           },
  //                         );
  //                       },
  //                     ),
  //                   ),
  //                 ],
  //               );
  //             },
  //           );
  //         },
  //       );
  //     },
  //   );
  //   searchController.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final localizations = AppLocalizations.of(context)!;

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
                        localizations.trn_title,
                        style: Theme.of(context).appBarTheme.titleTextStyle
                            ?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Image.asset(
                    'assets/logouzita.png',
                    height: MediaQuery.of(context).size.height * 0.08,
                    width: MediaQuery.of(context).size.height * 0.08,
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(
                  bottom: ui.scale(base: 16, min: 12, max: 20),
                  top: ui.scale(base: 8, min: 6, max: 12),
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.lapisLazuli,
                      AppColors.lapisLazuli.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(
                      ui.scale(base: 20, min: 16, max: 24),
                    ),
                    bottomRight: Radius.circular(
                      ui.scale(base: 20, min: 16, max: 24),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lapisLazuli.withValues(alpha: 0.10),
                      blurRadius: ui.scale(base: 12, min: 8, max: 16),
                      offset: Offset(0, ui.scale(base: 4, min: 3, max: 6)),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),
                    Container(
                      padding: EdgeInsets.all(
                        ui.scale(base: 12, min: 10, max: 16),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.local_shipping_outlined,
                        size: ui.scale(base: 32, min: 24, max: 40),
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: ui.scale(base: 6, min: 4, max: 8)),
                    Text(
                      localizations.trn_form_title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: ui.scale(base: 16, min: 14, max: 18),
                      ),
                      textDirection: Directionality.of(context),
                    ),
                    SizedBox(height: ui.scale(base: 6, min: 4, max: 8)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  ui.scale(base: 24, min: 16, max: 28),
                  ui.scale(base: 24, min: 16, max: 28),
                  ui.scale(base: 24, min: 16, max: 28),
                  ui.scale(base: 24, min: 16, max: 28) +
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(
                        ui.scale(base: 20, min: 12, max: 24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.3)
                              : AppColors.lapisLazuli.withValues(alpha: 0.06),
                          blurRadius: ui.scale(base: 12, min: 8, max: 16),
                          offset: Offset(0, ui.scale(base: 4, min: 3, max: 6)),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(
                      ui.scale(base: 20, min: 14, max: 24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   localizations.trn_pieces,
                        //   style: const TextStyle(
                        //     fontSize: 16,
                        //     fontWeight: FontWeight.w600,
                        //     color: AppColors.lapisLazuli,
                        //   ),
                        //   textDirection: Directionality.of(context),
                        // ),
                        // const SizedBox(height: 8),
                        // Wrap(
                        //   spacing: 8,
                        //   runSpacing: 8,
                        //   children: _selectedPieces.isEmpty
                        //       ? [
                        //           Chip(
                        //             label: Text(localizations.trd_unknown),
                        //             backgroundColor: AppColors.lapisLazuli
                        //                 .withValues(alpha: 0.06),
                        //           ),
                        //         ]
                        //       : _selectedPieces
                        //             .map(
                        //               (p) => Chip(
                        //                 label: Text(
                        //                   p,
                        //                   style: TextStyle(fontSize: 16),
                        //                 ),
                        //                 labelPadding: EdgeInsets.symmetric(
                        //                   horizontal: 12,
                        //                   vertical: 8,
                        //                 ),
                        //                 onDeleted: () {
                        //                   setState(() {
                        //                     _selectedPieces.remove(p);
                        //                   });
                        //                 },
                        //               ),
                        //             )
                        //             .toList(),
                        // ),
                        // Align(
                        //   alignment: AlignmentDirectional.centerEnd,
                        //   child: TextButton.icon(
                        //     onPressed: _openPiecesMenu,
                        //     icon: const Icon(
                        //       Icons.add,
                        //       color: AppColors.lapisLazuli,
                        //       size: 18,
                        //     ),
                        //     label: Text(
                        //       localizations.trn_add_piece,
                        //       style: const TextStyle(
                        //         color: AppColors.lapisLazuli,
                        //         fontWeight: FontWeight.w500,
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        Text(
                          localizations.trn_maghsad,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _maghsadController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: InputDecoration(
                            hintText: localizations.trn_maghsad_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.location_on,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations.trn_maghsad_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_phone,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: localizations.trn_phone_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.phone,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations.trn_phone_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_description,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: localizations.trn_description_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.description,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations.trn_description_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_product_description,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _productDescriptionController,
                          maxLines: 3,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: InputDecoration(
                            hintText:
                                localizations.trn_product_description_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.edit_document,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_output_number,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _outputController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: localizations.trn_output_number_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.numbers,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations.trn_output_number_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_customer,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _customerController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: InputDecoration(
                            hintText: localizations.trn_customer_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations.trn_customer_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_coordination_person,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _coordinationController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          decoration: InputDecoration(
                            hintText:
                                localizations.trn_coordination_person_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.person,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations
                                  .trn_coordination_person_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_payment_type,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final double fieldRadius = UiScale(
                              context,
                            ).scale(base: 12, min: 8, max: 16);
                            final BorderRadius menuRadius =
                                BorderRadius.circular(fieldRadius);
                            final Color menuColor =
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]!
                                : Colors.grey[50]!;
                            final Color borderColor =
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[600]!
                                : Colors.grey[300]!;
                            final EdgeInsets fieldPadding =
                                EdgeInsets.symmetric(
                                  horizontal: UiScale(
                                    context,
                                  ).scale(base: 16, min: 12, max: 20),
                                  vertical: UiScale(
                                    context,
                                  ).scale(base: 14, min: 12, max: 16),
                                );

                            return FormField<String>(
                              initialValue: _selectedPayment,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return AppLocalizations.of(
                                    context,
                                  )!.trn_payment_type_error;
                                }
                                return null;
                              },
                              builder: (field) {
                                final String? selected = field.value;
                                final bool hasValue = selected != null;
                                final String hintText = AppLocalizations.of(
                                  context,
                                )!.trn_payment_type_hint;

                                return MenuAnchor(
                                  consumeOutsideTap: true,
                                  alignmentOffset: const Offset(0, 4),
                                  style: MenuStyle(
                                    backgroundColor: WidgetStatePropertyAll(
                                      menuColor,
                                    ),
                                    elevation: const WidgetStatePropertyAll(4),
                                    shadowColor: WidgetStatePropertyAll(
                                      Colors.black.withValues(alpha: 0.12),
                                    ),
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                        borderRadius: menuRadius,
                                        side: BorderSide(color: borderColor),
                                      ),
                                    ),
                                    minimumSize: WidgetStatePropertyAll(
                                      Size(constraints.maxWidth, 0),
                                    ),
                                    maximumSize: WidgetStatePropertyAll(
                                      Size(constraints.maxWidth, 240),
                                    ),
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(vertical: 4),
                                    ),
                                  ),
                                  menuChildren: paymentTypes.map((subject) {
                                    final String value = subject['value']!;
                                    final bool isSelected = selected == value;
                                    return MenuItemButton(
                                      onPressed: () {
                                        field.didChange(value);
                                        setState(() {
                                          _selectedPayment = value;
                                        });
                                      },
                                      style: ButtonStyle(
                                        backgroundColor:
                                            WidgetStateProperty.resolveWith((
                                              states,
                                            ) {
                                              if (isSelected) {
                                                return AppColors.lapisLazuli
                                                    .withValues(alpha: 0.18);
                                              }
                                              return Colors.transparent;
                                            }),
                                      ),
                                      child: SizedBox(
                                        width: constraints.maxWidth - 24,
                                        child: Text(
                                          _getpaymentLabel(value),
                                          style: TextStyle(
                                            fontFamily: 'Vazir',
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                            color: isSelected
                                                ? AppColors.lapisLazuli
                                                : (Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.white
                                                      : const Color(
                                                          0xFF1A1A1A,
                                                        )),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  builder: (context, controller, child) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: menuRadius,
                                            onTap: () {
                                              if (controller.isOpen) {
                                                controller.close();
                                              } else {
                                                FocusScope.of(
                                                  context,
                                                ).unfocus();
                                                controller.open();
                                              }
                                            },
                                            child: InputDecorator(
                                              isEmpty: !hasValue,
                                              decoration: InputDecoration(
                                                hintText: hintText,
                                                hintStyle: TextStyle(
                                                  fontFamily: 'Vazir',
                                                  fontSize: 16,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                                errorText: field.errorText,
                                                border: OutlineInputBorder(
                                                  borderRadius: menuRadius,
                                                  borderSide: BorderSide(
                                                    color: borderColor,
                                                  ),
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius: menuRadius,
                                                      borderSide: BorderSide(
                                                        color: borderColor,
                                                      ),
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius: menuRadius,
                                                      borderSide:
                                                          const BorderSide(
                                                            color: AppColors
                                                                .lapisLazuli,
                                                            width: 2,
                                                          ),
                                                    ),
                                                errorBorder: OutlineInputBorder(
                                                  borderRadius: menuRadius,
                                                  borderSide: const BorderSide(
                                                    color: Colors.red,
                                                    width: 2,
                                                  ),
                                                ),
                                                focusedErrorBorder:
                                                    OutlineInputBorder(
                                                      borderRadius: menuRadius,
                                                      borderSide:
                                                          const BorderSide(
                                                            color: Colors.red,
                                                            width: 2,
                                                          ),
                                                    ),
                                                filled: true,
                                                fillColor: menuColor,
                                                contentPadding: fieldPadding,
                                                isDense: true,
                                                suffixIcon: Icon(
                                                  controller.isOpen
                                                      ? Icons.arrow_drop_up
                                                      : Icons.arrow_drop_down,
                                                  color: AppColors.lapisLazuli,
                                                ),
                                                suffixIconConstraints:
                                                    const BoxConstraints(
                                                      minWidth: 40,
                                                      minHeight: 40,
                                                    ),
                                              ),
                                              child: Align(
                                                alignment: AlignmentDirectional
                                                    .centerStart,
                                                child: Text(
                                                  hasValue
                                                      ? _getpaymentLabel(
                                                          selected,
                                                        )
                                                      : ' ',
                                                  style: TextStyle(
                                                    fontFamily: 'Vazir',
                                                    fontSize: 16,
                                                    height: 1.25,
                                                    fontWeight: hasValue
                                                        ? FontWeight.w700
                                                        : FontWeight.w400,
                                                    color: hasValue
                                                        ? (Theme.of(
                                                                    context,
                                                                  ).brightness ==
                                                                  Brightness
                                                                      .dark
                                                              ? Colors.white
                                                              : const Color(
                                                                  0xFF111111,
                                                                ))
                                                        : Colors.transparent,
                                                  ),
                                                  textAlign:
                                                      Directionality.of(
                                                            context,
                                                          ) ==
                                                          TextDirection.rtl
                                                      ? TextAlign.right
                                                      : TextAlign.left,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_price_transport,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _priceController,
                          textDirection: Directionality.of(context),
                          textAlign:
                              Directionality.of(context) == TextDirection.rtl
                              ? TextAlign.right
                              : TextAlign.left,
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            ThousandSeparatorInputFormatter(),
                          ],
                          decoration: InputDecoration(
                            hintText: localizations.trn_price_transport_hint,
                            hintStyle: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                ui.scale(base: 14, min: 12, max: 18),
                              ),
                              borderSide: const BorderSide(
                                color: AppColors.lapisLazuli,
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.attach_money,
                              color: AppColors.lapisLazuli,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return localizations.trn_price_transport_error;
                            }
                            if (parseGroupedInt(value) == null) {
                              return localizations.trn_price_transport_error;
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
                        Text(
                          localizations.trn_attachment,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[800]
                                : AppColors.lapisLazuli.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(
                              ui.scale(base: 14, min: 12, max: 18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_attachment != null) ...[
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.insert_drive_file,
                                      color: AppColors.lapisLazuli,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _attachment!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip:
                                          localizations.trn_attachment_remove,
                                      onPressed: () {
                                        setState(() => _attachment = null);
                                      },
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                              OutlinedButton.icon(
                                onPressed: isLoading ? null : _pickAttachment,
                                icon: const Icon(
                                  Icons.attach_file,
                                  color: AppColors.lapisLazuli,
                                ),
                                label: Text(
                                  _attachment == null
                                      ? localizations.trn_attach_file
                                      : localizations.trn_attach_file,
                                  style: const TextStyle(
                                    color: AppColors.lapisLazuli,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.lapisLazuli,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                localizations.trn_attachment_hint,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: ui.scale(base: 32, min: 20, max: 36)),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.lapisLazuli,
                              padding: EdgeInsets.symmetric(
                                vertical: ui.scale(base: 18, min: 14, max: 22),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  ui.scale(base: 14, min: 12, max: 18),
                                ),
                              ),
                              elevation: 4,
                            ),
                            icon: isLoading
                                ? SizedBox(
                                    width: ui.scale(base: 24, min: 18, max: 28),
                                    height: ui.scale(
                                      base: 24,
                                      min: 18,
                                      max: 28,
                                    ),
                                    child: CircularProgressIndicator(
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                      strokeWidth: ui.scale(
                                        base: 2.5,
                                        min: 2.0,
                                        max: 3.0,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.send,
                                    color: Colors.white,
                                    size: ui.scale(base: 20, min: 16, max: 24),
                                  ),
                            label: Text(
                              isLoading
                                  ? localizations.trn_loading_sending
                                  : localizations.trn_submit,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: ui.scale(base: 16, min: 14, max: 18),
                                fontWeight: FontWeight.bold,
                              ),
                              textDirection: Directionality.of(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
