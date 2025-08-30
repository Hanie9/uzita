import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/services.dart';
import 'package:uzita/utils/ui_scale.dart';

Widget buildRegisterForm({
  required String title,
  required Map<String, TextEditingController> controllers,
  required Function() onSubmit,
  required String error,
  required String phoneError,
  required bool loading,
  required bool isFormValid,
  bool isAdmin = false,
}) {
  return Builder(
    builder: (context) {
      final screenHeight = MediaQuery.of(context).size.height;
      final screenWidth = MediaQuery.of(context).size.width;
      final ui = UiScale(context);

      // Adaptive sizing based on screen size - more aggressive for small screens
      final double horizontalPadding = ui.scale(
        base: screenWidth * 0.06,
        min: 10.0,
        max: 24.0,
      );

      // Logo sizing to match login page
      final double logoHeight = ui.scale(
        base: screenHeight * 0.22, // Same as login page
        min: 100.0, // Same as login page
        max: 200.0, // Same as login page
      );
      final double svgHeight = ui.scale(
        base: logoHeight * 1.2, // Same as login page
        min: 120.0, // Same as login page
        max: 280.0, // Same as login page
      );
      final double svgWidth = ui.scale(
        base: screenWidth * 0.9, // Same as login page
        min: 220.0, // Same as login page
        max: 480.0, // Same as login page
      );

      // Adaptive spacing that gets tighter on small screens
      final double spacingAfterLogo = ui.scale(
        base: screenHeight * 0.02, // Same as login page
        min: 8.0, // Same as login page
        max: 20.0, // Same as login page
      );
      final double fieldHeight = ui.scale(
        base: screenHeight * 0.055, // Reduced from 0.06
        min: 36.0, // Reduced from 40.0
        max: 48.0, // Reduced from 52.0
      );
      final double fieldFontSize = ui.scale(
        base: screenWidth * 0.035,
        min: 12.0,
        max: 16.0,
      );
      final double hintFontSize = ui.scale(
        base: screenWidth * 0.04,
        min: 13.0,
        max: 17.0,
      );
      final double buttonHeight = ui.scale(
        base: fieldHeight,
        min: 40.0,
        max: 52.0,
      );
      final double buttonFontSize = ui.scale(
        base: screenWidth * 0.05,
        min: 14.0,
        max: 18.0,
      );

      // Adaptive spacing between elements - ultra-tight for small screens
      final double smallSpacing = ui.scale(
        base: screenHeight * 0.012, // Reduced from 0.015
        min: 3.0, // Reduced from 6.0
        max: 12.0, // Reduced from 16.0
      );
      final double mediumSpacing = ui.scale(
        base: screenHeight * 0.016, // Reduced from 0.02
        min: 4.0, // Reduced from 8.0
        max: 16.0, // Reduced from 20.0
      );
      final double largeSpacing = ui.scale(
        base: screenHeight * 0.025, // Reduced from 0.03
        min: 6.0, // Reduced from 12.0
        max: 20.0, // Reduced from 24.0
      );
      final double extraLargeSpacing = ui.scale(
        base: screenHeight * 0.03, // Reduced from 0.035
        min: 8.0, // Reduced from 14.0
        max: 24.0, // Reduced from 28.0
      );
      // final double fingerprintSize = (screenWidth * 0.18).clamp(56.0, 88.0);

      return Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          resizeToAvoidBottomInset: true, // Make sure this is true
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      bottom: ui.scale(
                        base: screenHeight * 0.04, // Reduced from 0.06
                        min: 16.0,
                        max: 32.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Column(
                              children: [
                                // SizedBox(height: topPadding),
                                // Header with Register text
                                Row(
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

                                // Main branding section
                                SizedBox(
                                  height: logoHeight + 20, // Same as login page
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Main logo image at the top
                                      Positioned(
                                        top: -logoHeight * 0.3,
                                        child: Image.asset(
                                          'assets/biokaveh.png',
                                          height: svgHeight,
                                          width: svgWidth,
                                          fit: BoxFit.contain,
                                        ),
                                      ),

                                      // ELARRO text in gold/bronze in the middle
                                      Positioned(
                                        top: logoHeight * 0.44,
                                        child: Builder(
                                          builder: (_) {
                                            final double elarroFontSize =
                                                (screenWidth * 0.08)
                                                    .clamp(22.0, 32.0)
                                                    .toDouble();
                                            return Text(
                                              'ELARRO',
                                              style: TextStyle(
                                                fontSize: elarroFontSize,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.lapisLazuli,
                                                letterSpacing: 4,
                                                fontFamily: 'Nasalization',
                                              ),
                                            );
                                          },
                                        ),
                                      ),

                                      // BIOKAVEH text in black at the bottom
                                      Positioned(
                                        top:
                                            (logoHeight * 0.38) +
                                            ((screenWidth * 0.08)
                                                    .clamp(22.0, 32.0)
                                                    .toDouble() *
                                                1.25) +
                                            6,
                                        child: Text(
                                          'BIOKAVEH',
                                          style: TextStyle(
                                            fontSize: (screenWidth * 0.045)
                                                .clamp(16.0, 22.0)
                                                .toDouble(),
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 2,
                                            fontFamily: 'Nasalization',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: spacingAfterLogo),

                                // Registration type indicator
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: ui.scale(
                                      base: screenWidth * 0.04,
                                      min: 8.0,
                                      max: 16.0,
                                    ),
                                    vertical: ui.scale(
                                      base:
                                          screenHeight *
                                          0.008, // Reduced from 0.01
                                      min: 2.0,
                                      max: 8.0,
                                    ),
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.bronzeGold.withValues(
                                      alpha: 0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.bronzeGold,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        isAdmin
                                            ? AppLocalizations.of(
                                                context,
                                              )!.reg_admin_register
                                            : AppLocalizations.of(
                                                context,
                                              )!.reg_user_register,
                                        style: TextStyle(
                                          fontSize: ui.scale(
                                            base: screenWidth * 0.035,
                                            min: 12.0,
                                            max: 16.0,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black,
                                        ),
                                      ),
                                      SizedBox(
                                        width: ui.scale(
                                          base: screenWidth * 0.02,
                                          min: 4.0,
                                          max: 12.0,
                                        ),
                                      ),
                                      Icon(
                                        isAdmin
                                            ? Icons.admin_panel_settings
                                            : Icons.person_add,
                                        size: ui.scale(
                                          base: screenHeight * 0.025,
                                          min: 16.0,
                                          max: 22.0,
                                        ),
                                        color: AppColors.black,
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: extraLargeSpacing),
                                // Phone field
                                TextField(
                                  controller: controllers['phone'],
                                  keyboardType: TextInputType.number,
                                  textDirection:
                                      Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'en'
                                      ? TextDirection.ltr
                                      : TextDirection.rtl,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: fieldFontSize),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(
                                      context,
                                    )!.reg_phone,
                                    hintStyle: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[400]
                                          : const Color.fromARGB(
                                              255,
                                              99,
                                              97,
                                              97,
                                            ),
                                      fontSize: hintFontSize,
                                    ),
                                    hintTextDirection: TextDirection.rtl,
                                    prefixText:
                                        '${AppLocalizations.of(context)!.reg_phone_98} ',
                                    suffixIcon: Padding(
                                      padding: EdgeInsets.all(
                                        screenWidth * 0.02,
                                      ), // 2% of screen width
                                      child: SvgPicture.asset(
                                        'assets/icons/phone-plus.svg',
                                        colorFilter: ColorFilter.mode(
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? (Colors.grey[400] ??
                                                    Colors.grey)
                                              : const Color.fromARGB(
                                                  255,
                                                  80,
                                                  77,
                                                  77,
                                                ),
                                          BlendMode.srcIn,
                                        ),
                                        width: ui.scale(
                                          base: screenHeight * 0.05,
                                          min: 20.0,
                                          max: 30.0,
                                        ),
                                        height: ui.scale(
                                          base: screenHeight * 0.05,
                                          min: 20.0,
                                          max: 30.0,
                                        ),
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: (screenWidth * 0.035).clamp(
                                        12.0,
                                        16.0,
                                      ),
                                      vertical: (screenHeight * 0.018).clamp(
                                        10.0,
                                        14.0,
                                      ),
                                    ),
                                  ),
                                ),

                                if (controllers['phone']!.text.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: ui.scale(
                                        base: screenHeight * 0.01,
                                        min: 4.0,
                                        max: 8.0,
                                      ),
                                      right: ui.scale(
                                        base: screenWidth * 0.04,
                                        min: 8.0,
                                        max: 16.0,
                                      ),
                                    ),
                                    child: Text(
                                      '${AppLocalizations.of(context)!.reg_phone_98} ${AppLocalizations.of(context)!.reg_phone_completely} ${controllers['phone']!.text}',
                                      style: TextStyle(
                                        color:
                                            controllers['phone']!.text.length ==
                                                10
                                            ? Colors.green
                                            : Colors.orange,
                                        fontSize: ui.scale(
                                          base: screenWidth * 0.03,
                                          min: 10.0,
                                          max: 14.0,
                                        ),
                                      ),
                                    ),
                                  ),

                                if (phoneError.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: ui.scale(
                                        base: screenHeight * 0.01,
                                        min: 4.0,
                                        max: 8.0,
                                      ),
                                      right: ui.scale(
                                        base: screenWidth * 0.04,
                                        min: 8.0,
                                        max: 16.0,
                                      ),
                                    ),
                                    child: Text(
                                      phoneError,
                                      style: TextStyle(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.red[300]
                                            : Colors.red,
                                        fontSize: ui.scale(
                                          base: screenWidth * 0.03,
                                          min: 10.0,
                                          max: 14.0,
                                        ),
                                      ),
                                    ),
                                  ),

                                SizedBox(height: smallSpacing),
                                // Username field
                                TextField(
                                  controller: controllers['username'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: fieldFontSize),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(
                                      context,
                                    )!.reg_name,
                                    hintMaxLines: 2,
                                    hintStyle: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[400]
                                          : const Color.fromARGB(
                                              255,
                                              99,
                                              97,
                                              97,
                                            ),
                                      fontSize: hintFontSize,
                                    ),
                                    hintTextDirection: TextDirection.rtl,
                                    suffixIcon: Padding(
                                      padding: EdgeInsets.all(
                                        screenWidth * 0.02,
                                      ), // 2% of screen width
                                      child: SvgPicture.asset(
                                        'assets/icons/user.svg',
                                        colorFilter: ColorFilter.mode(
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? (Colors.grey[400] ??
                                                    Colors.grey)
                                              : const Color.fromARGB(
                                                  255,
                                                  80,
                                                  77,
                                                  77,
                                                ),
                                          BlendMode.srcIn,
                                        ),
                                        width: ui.scale(
                                          base: screenHeight * 0.03,
                                          min: 16.0,
                                          max: 24.0,
                                        ),
                                        height: ui.scale(
                                          base: screenHeight * 0.03,
                                          min: 16.0,
                                          max: 24.0,
                                        ),
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: (screenWidth * 0.035).clamp(
                                        12.0,
                                        16.0,
                                      ),
                                      vertical: (screenHeight * 0.018).clamp(
                                        10.0,
                                        14.0,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: smallSpacing),
                                // Password field
                                TextField(
                                  controller: controllers['password'],
                                  obscureText: true,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: fieldFontSize),
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(
                                      context,
                                    )!.reg_password,
                                    hintMaxLines: 2,
                                    hintStyle: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[400]
                                          : const Color.fromARGB(
                                              255,
                                              99,
                                              97,
                                              97,
                                            ),
                                      fontSize: hintFontSize,
                                    ),
                                    hintTextDirection: TextDirection.rtl,
                                    suffixIcon: Padding(
                                      padding: EdgeInsets.all(
                                        screenWidth * 0.02,
                                      ), // 2% of screen width
                                      child: SvgPicture.asset(
                                        'assets/icons/key.svg',
                                        colorFilter: ColorFilter.mode(
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? (Colors.grey[400] ??
                                                    Colors.grey)
                                              : const Color.fromARGB(
                                                  255,
                                                  80,
                                                  77,
                                                  77,
                                                ),
                                          BlendMode.srcIn,
                                        ),
                                        width: ui.scale(
                                          base: screenHeight * 0.035,
                                          min: 16.0,
                                          max: 26.0,
                                        ),
                                        height: ui.scale(
                                          base: screenHeight * 0.035,
                                          min: 16.0,
                                          max: 26.0,
                                        ),
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: (screenWidth * 0.035).clamp(
                                        12.0,
                                        16.0,
                                      ),
                                      vertical: (screenHeight * 0.018).clamp(
                                        10.0,
                                        14.0,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: smallSpacing),
                                // Organization code field
                                TextField(
                                  controller: controllers['organ_code'],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: fieldFontSize),
                                  decoration: InputDecoration(
                                    hintText: isAdmin
                                        ? AppLocalizations.of(
                                            context,
                                          )!.reg_admin_code
                                        : AppLocalizations.of(
                                            context,
                                          )!.reg_org_code,
                                    hintMaxLines: 2,
                                    hintStyle: TextStyle(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.grey[400]
                                          : const Color.fromARGB(
                                              255,
                                              99,
                                              97,
                                              97,
                                            ),
                                      fontSize: hintFontSize,
                                    ),
                                    hintTextDirection: TextDirection.rtl,
                                    suffixIcon: Padding(
                                      padding: EdgeInsets.all(
                                        screenWidth * 0.02,
                                      ), // 2% of screen width
                                      child: SvgPicture.asset(
                                        isAdmin
                                            ? 'assets/icons/admin.svg'
                                            : 'assets/icons/office.svg',
                                        colorFilter: ColorFilter.mode(
                                          Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? (Colors.grey[400] ??
                                                    Colors.grey)
                                              : const Color.fromARGB(
                                                  255,
                                                  80,
                                                  77,
                                                  77,
                                                ),
                                          BlendMode.srcIn,
                                        ),
                                        width: ui.scale(
                                          base: screenHeight * 0.03,
                                          min: 16.0,
                                          max: 24.0,
                                        ),
                                        height: ui.scale(
                                          base: screenHeight * 0.03,
                                          min: 16.0,
                                          max: 24.0,
                                        ),
                                      ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: (screenWidth * 0.035).clamp(
                                        12.0,
                                        16.0,
                                      ),
                                      vertical: (screenHeight * 0.018).clamp(
                                        10.0,
                                        14.0,
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: largeSpacing),
                                // Submit button
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isFormValid
                                            ? AppColors.lapisLazuli.withValues(
                                                alpha: 0.5,
                                              )
                                            : AppColors.black.withValues(
                                                alpha: 0.2,
                                              ),
                                        spreadRadius: 1,
                                        blurRadius: 10,
                                        offset: Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: buttonHeight,
                                    child: AbsorbPointer(
                                      absorbing: loading,
                                      child: ElevatedButton(
                                        onPressed: isFormValid
                                            ? onSubmit
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isFormValid
                                              ? AppColors.lapisLazuli
                                              : Colors.grey,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          elevation: 1,
                                        ),
                                        child: loading
                                            ? SizedBox(
                                                height: ui.scale(
                                                  base: screenHeight * 0.022,
                                                  min: 16.0,
                                                  max: 24.0,
                                                ),
                                                width: ui.scale(
                                                  base: screenHeight * 0.022,
                                                  min: 16.0,
                                                  max: 24.0,
                                                ),
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  AppLocalizations.of(
                                                    context,
                                                  )!.reg_send_otp,
                                                  style: TextStyle(
                                                    fontSize: buttonFontSize,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: mediumSpacing),
                                // Error display
                                if (error.isNotEmpty) ...[
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(
                                      screenWidth * 0.03,
                                    ), // 3% of screen width
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).brightness ==
                                              Brightness.dark
                                          ? Colors.red[900]?.withValues(
                                              alpha: 0.3,
                                            )
                                          : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.red[600]!
                                            : Colors.red.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.red[300]
                                              : Colors.red,
                                          size:
                                              screenHeight *
                                              0.025, // 2.5% of screen height
                                        ),
                                        SizedBox(
                                          width: screenWidth * 0.02,
                                        ), // 2% of screen width
                                        Expanded(
                                          child: Text(
                                            error,
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? Colors.red[300]
                                                  : Colors.red.shade700,
                                              fontSize:
                                                  screenWidth *
                                                  0.035, // 3.5% of screen width
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(height: mediumSpacing),
                                ],

                                // Note text
                                Text(
                                  isAdmin
                                      ? AppLocalizations.of(
                                          context,
                                        )!.reg_attention_admin
                                      : AppLocalizations.of(
                                          context,
                                        )!.reg_attention_org,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: ui.scale(
                                      base: screenWidth * 0.03,
                                      min: 10.0,
                                      max: 14.0,
                                    ),
                                  ),
                                  textAlign: TextAlign.center,
                                ),

                                SizedBox(
                                  height: ui.scale(
                                    base: screenHeight * 0.007,
                                    min: 4.0,
                                    max: 8.0,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (Localizations.localeOf(
                                          context,
                                        ).languageCode ==
                                        'fa') ...[
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  LoginScreen(),
                                            ),
                                            (Route<dynamic> route) => false,
                                          );
                                        },
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.reg_login,
                                          style: TextStyle(
                                            color: AppColors.lapisLazuli,
                                            fontSize: ui.scale(
                                              base: screenWidth * 0.035,
                                              min: 12.0,
                                              max: 16.0,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: ui.scale(
                                          base: screenWidth * 0.01,
                                          min: 2.0,
                                          max: 8.0,
                                        ),
                                      ),
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.reg_login_before,
                                        style: TextStyle(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontSize: ui.scale(
                                            base: screenWidth * 0.035,
                                            min: 12.0,
                                            max: 16.0,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        AppLocalizations.of(
                                          context,
                                        )!.reg_login_before,
                                        style: TextStyle(
                                          color:
                                              Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.grey[400]
                                              : Colors.grey[600],
                                          fontSize: ui.scale(
                                            base: screenWidth * 0.035,
                                            min: 12.0,
                                            max: 16.0,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: ui.scale(
                                          base: screenWidth * 0.01,
                                          min: 2.0,
                                          max: 8.0,
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.pushAndRemoveUntil(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  LoginScreen(),
                                            ),
                                            (Route<dynamic> route) => false,
                                          );
                                        },
                                        child: Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.reg_login,
                                          style: TextStyle(
                                            color: AppColors.lapisLazuli,
                                            fontSize: ui.scale(
                                              base: screenWidth * 0.035,
                                              min: 12.0,
                                              max: 16.0,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                SizedBox(height: largeSpacing),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
