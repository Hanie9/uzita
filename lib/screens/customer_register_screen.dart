import 'package:flutter/material.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/customer/customer_api.dart';
import 'package:uzita/utils/build_register_form.dart';

class CustomerRegisterScreen extends StatefulWidget {
  const CustomerRegisterScreen({super.key});

  @override
  State<CustomerRegisterScreen> createState() => _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState extends State<CustomerRegisterScreen> {
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();

  bool _loading = false;
  String _error = '';
  String _phoneError = '';

  @override
  void initState() {
    super.initState();
    _phone.addListener(_onFieldChanged);
    _firstName.addListener(_onFieldChanged);
    _lastName.addListener(_onFieldChanged);
    _password.addListener(_onFieldChanged);
    _passwordConfirm.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _phone.removeListener(_onFieldChanged);
    _firstName.removeListener(_onFieldChanged);
    _lastName.removeListener(_onFieldChanged);
    _password.removeListener(_onFieldChanged);
    _passwordConfirm.removeListener(_onFieldChanged);
    _phone.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    String phoneText = _phone.text;
    if (phoneText.startsWith('0') && phoneText.length > 1) {
      phoneText = phoneText.substring(1);
      _phone.value = TextEditingValue(
        text: phoneText,
        selection: TextSelection.collapsed(offset: phoneText.length),
      );
    }
    if (phoneText.length > 10) {
      phoneText = phoneText.substring(0, 10);
      _phone.value = TextEditingValue(
        text: phoneText,
        selection: TextSelection.collapsed(offset: phoneText.length),
      );
    }

    setState(() {
      if (phoneText.isNotEmpty && phoneText.length < 10) {
        _phoneError = AppLocalizations.of(
          context,
        )!.userreg_add_phone_completely;
      } else {
        _phoneError = '';
      }
    });
  }

  bool _isValidForm() {
    return _phone.text.length == 10 &&
        _firstName.text.trim().isNotEmpty &&
        _lastName.text.trim().isNotEmpty &&
        _password.text.isNotEmpty &&
        _password.text == _passwordConfirm.text;
  }

  Future<void> _submit() async {
    final AppLocalizations loc = AppLocalizations.of(context)!;
    final String? phone = normalizeCustomerPhone(_phone.text);
    if (!_isValidForm() || phone == null) {
      setState(() {
        _error = _password.text != _passwordConfirm.text
            ? loc.cust_passwords_mismatch
            : loc.cust_required;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await registerCustomer(
        phone: phone,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        password: _password.text,
        passwordConfirm: _passwordConfirm.text,
        fallback: loc.cust_connecting,
      );
      await signInCustomer(
        phone: phone,
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        fallback: loc.cust_connecting,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on CustomerCallException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = loc.cust_connecting);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return buildRegisterForm(
      title: AppLocalizations.of(context)!.cust_register_title,
      controllers: {
        'phone': _phone,
        'first_name': _firstName,
        'last_name': _lastName,
        'password': _password,
        'password_confirm': _passwordConfirm,
      },
      onSubmit: _submit,
      error: _error,
      phoneError: _phoneError,
      loading: _loading,
      isFormValid: _isValidForm(),
      isCustomer: true,
    );
  }
}
