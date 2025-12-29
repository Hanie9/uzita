import 'dart:convert';
import 'dart:convert' show utf8;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/services.dart';
import 'package:uzita/services/session_manager.dart';
import 'package:uzita/utils/http_with_session.dart' as http;
import 'package:uzita/utils/ui_scale.dart';
import 'package:uzita/providers/settings_provider.dart';

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

  // Shared list of available parts (same as technician/service)
  List<String> _availablePieces = List<String>.from(kDefaultPieceOptions);

  final List<String> _selectedPieces = <String>[];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchPieces();
  }

  Future<void> _fetchPieces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return;

      await SessionManager().onNetworkRequest();
      final response = await http.get(
        Uri.parse('$baseUrl5/listpieces/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data is List) {
          setState(() {
            _availablePieces = data
                .map((item) => item['name']?.toString() ?? '')
                .where((name) => name.isNotEmpty)
                .toList();
          });
        }
      }
    } catch (e) {
      // If API fails, keep default pieces
      if (mounted) {
        setState(() {
          _availablePieces = List<String>.from(kDefaultPieceOptions);
        });
      }
    }
  }

  @override
  void dispose() {
    _maghsadController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final localizations = AppLocalizations.of(context)!;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizations.trn_required_error)));
      return;
    }

    if (_selectedPieces.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizations.trn_required_error)));
      return;
    }

    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final body = <String, dynamic>{
        'pieces': _selectedPieces,
        'maghsad': _maghsadController.text.trim(),
        'phone': _phoneController.text.trim(),
        'description': _descriptionController.text.trim(),
      };

      await SessionManager().onNetworkRequest();
      final response = await http.post(
        Uri.parse('https://device-control.liara.run/api/transport/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

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

  Future<void> _openPiecesMenu() async {
    final localizations = AppLocalizations.of(context)!;
    final Set<String> tempSelected = Set<String>.from(_selectedPieces);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (modalContext, modalSetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              builder: (context, scrollController) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            localizations.trn_pieces,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(bottomSheetContext).pop(),
                            child: Text(localizations.trn_ok),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _availablePieces.length,
                        itemBuilder: (context, index) {
                          final piece = _availablePieces[index];
                          final bool isChecked = tempSelected.contains(piece);
                          return CheckboxListTile(
                            value: isChecked,
                            title: Text(piece),
                            onChanged: (checked) {
                              modalSetState(() {
                                if (checked == true) {
                                  tempSelected.add(piece);
                                } else {
                                  tempSelected.remove(piece);
                                }
                              });
                              setState(() {
                                _selectedPieces
                                  ..clear()
                                  ..addAll(tempSelected);
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    final screenHeight = MediaQuery.of(context).size.height;
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
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
                        Text(
                          localizations.trn_pieces,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.lapisLazuli,
                          ),
                          textDirection: Directionality.of(context),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedPieces.isEmpty
                              ? [
                                  Chip(
                                    label: Text(localizations.trd_unknown),
                                    backgroundColor: AppColors.lapisLazuli
                                        .withValues(alpha: 0.06),
                                  ),
                                ]
                              : _selectedPieces
                                    .map(
                                      (p) => Chip(
                                        label: Text(p),
                                        onDeleted: () {
                                          setState(() {
                                            _selectedPieces.remove(p);
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton.icon(
                            onPressed: _openPiecesMenu,
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.lapisLazuli,
                              size: 18,
                            ),
                            label: Text(
                              localizations.trn_add_piece,
                              style: const TextStyle(
                                color: AppColors.lapisLazuli,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: ui.scale(base: 16, min: 12, max: 20)),
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
