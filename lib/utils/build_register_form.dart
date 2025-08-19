import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/screens/login_screen.dart';
import 'package:uzita/services.dart';

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

      // Calculate responsive dimensions
      // final topPadding = screenHeight * 0.01; // 4% of screen height
      final logoHeight = screenHeight * 0.25; // 25% of screen height
      final svgHeight = logoHeight * 1.2; // 120% of logo container height
      final svgWidth = screenWidth * 0.95; // 95% of screen width
      final spacingAfterLogo = screenHeight * 0.02; // 5% of screen height

      return Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          resizeToAvoidBottomInset: true, // Make sure this is true
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
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
                                // Uzita logo in top-right
                                Image.asset(
                                  'assets/logouzita.png',
                                  height: screenHeight * 0.08,
                                  width: screenHeight * 0.08,
                                ),
                              ],
                            ),

                            // Main branding section
                            SizedBox(
                              height: logoHeight,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Main logo image at the top
                                  Positioned(
                                    top:
                                        -logoHeight *
                                        0.3, // Move up by 20% of container height
                                    child: Image.asset(
                                      'assets/biokaveh.png',
                                      height: svgHeight,
                                      width: svgWidth,
                                      fit: BoxFit.contain,
                                    ),
                                  ),

                                  // ELARRO text in gold/bronze in the middle
                                  Positioned(
                                    top:
                                        logoHeight *
                                        0.44, // 64% of logo container height (moved up)
                                    child: Text(
                                      'ELARRO',
                                      style: TextStyle(
                                        fontSize:
                                            screenWidth *
                                            0.08, // 8% of screen width
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.bronzeGold,
                                        letterSpacing: 4,
                                        fontFamily: 'Nasalization',
                                      ),
                                    ),
                                  ),

                                  // BIOKAVEH text in black at the bottom
                                  Positioned(
                                    top:
                                        logoHeight *
                                        0.6, // 80% of logo container height (moved up)
                                    child: Text(
                                      'BIOKAVEH',
                                      style: TextStyle(
                                        fontSize:
                                            screenWidth *
                                            0.045, // 4.5% of screen width
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
                                horizontal: screenWidth * 0.04,
                                vertical: screenHeight * 0.01,
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
                                      fontSize:
                                          screenWidth *
                                          0.035, // 3.5% of screen width
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(
                                    width: screenWidth * 0.02,
                                  ), // 2% of screen width
                                  Icon(
                                    isAdmin
                                        ? Icons.admin_panel_settings
                                        : Icons.person_add,
                                    size:
                                        screenHeight *
                                        0.025, // 2.5% of screen height
                                    color: AppColors.black,
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(
                              height: screenHeight * 0.035,
                            ), // 3.5% of screen height
                            // Phone field
                            Container(
                              height:
                                  screenHeight * 0.06, // 6% of screen height
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: TextField(
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
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                ), // 3.5% of screen width
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
                                        : const Color.fromARGB(255, 99, 97, 97),
                                    fontSize:
                                        screenWidth *
                                        0.04, // 4% of screen width
                                  ),
                                  hintTextDirection: TextDirection.rtl,
                                  prefixText: '+98 ',
                                  suffixIcon: Padding(
                                    padding: EdgeInsets.all(
                                      screenWidth * 0.02,
                                    ), // 2% of screen width
                                    child: SvgPicture.asset(
                                      'assets/icons/phone-plus.svg',
                                      colorFilter: ColorFilter.mode(
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? (Colors.grey[400] ?? Colors.grey)
                                            : const Color.fromARGB(
                                                255,
                                                80,
                                                77,
                                                77,
                                              ),
                                        BlendMode.srcIn,
                                      ),
                                      width:
                                          screenHeight *
                                          0.05, // 5% of screen height
                                      height:
                                          screenHeight *
                                          0.05, // 5% of screen height
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal:
                                        screenWidth *
                                        0.035, // 3.5% of screen width
                                    vertical:
                                        screenHeight *
                                        0.018, // 1.8% of screen height
                                  ),
                                ),
                              ),
                            ),

                            if (controllers['phone']!.text.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: screenHeight * 0.01,
                                  right: screenWidth * 0.04,
                                ),
                                child: Text(
                                  '${AppLocalizations.of(context)!.reg_phone_completely} ${controllers['phone']!.text}',
                                  style: TextStyle(
                                    color:
                                        controllers['phone']!.text.length == 10
                                        ? Colors.green
                                        : Colors.orange,
                                    fontSize:
                                        screenWidth *
                                        0.03, // 3% of screen width
                                  ),
                                ),
                              ),

                            if (phoneError.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: screenHeight * 0.01,
                                  right: screenWidth * 0.04,
                                ),
                                child: Text(
                                  phoneError,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.red[300]
                                        : Colors.red,
                                    fontSize:
                                        screenWidth *
                                        0.03, // 3% of screen width
                                  ),
                                ),
                              ),

                            SizedBox(
                              height: screenHeight * 0.015,
                            ), // 1.5% of screen height
                            // Username field
                            Container(
                              height:
                                  screenHeight * 0.06, // 6% of screen height
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: TextField(
                                controller: controllers['username'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                ), // 3.5% of screen width
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.of(
                                    context,
                                  )!.reg_name,
                                  hintStyle: TextStyle(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[400]
                                        : const Color.fromARGB(255, 99, 97, 97),
                                    fontSize:
                                        screenWidth *
                                        0.04, // 4% of screen width
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
                                            ? (Colors.grey[400] ?? Colors.grey)
                                            : const Color.fromARGB(
                                                255,
                                                80,
                                                77,
                                                77,
                                              ),
                                        BlendMode.srcIn,
                                      ),
                                      width:
                                          screenHeight *
                                          0.03, // 3% of screen height
                                      height:
                                          screenHeight *
                                          0.03, // 3% of screen height
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal:
                                        screenWidth *
                                        0.035, // 3.5% of screen width
                                    vertical:
                                        screenHeight *
                                        0.018, // 1.8% of screen height
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: screenHeight * 0.015,
                            ), // 1.5% of screen height
                            // Password field
                            Container(
                              height:
                                  screenHeight * 0.06, // 6% of screen height
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: TextField(
                                controller: controllers['password'],
                                obscureText: true,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                ), // 3.5% of screen width
                                decoration: InputDecoration(
                                  hintText: AppLocalizations.of(
                                    context,
                                  )!.reg_password,
                                  hintStyle: TextStyle(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[400]
                                        : const Color.fromARGB(255, 99, 97, 97),
                                    fontSize:
                                        screenWidth *
                                        0.04, // 4% of screen width
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
                                            ? (Colors.grey[400] ?? Colors.grey)
                                            : const Color.fromARGB(
                                                255,
                                                80,
                                                77,
                                                77,
                                              ),
                                        BlendMode.srcIn,
                                      ),
                                      width:
                                          screenHeight *
                                          0.035, // 3.5% of screen height
                                      height:
                                          screenHeight *
                                          0.035, // 3.5% of screen height
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal:
                                        screenWidth *
                                        0.035, // 3.5% of screen width
                                    vertical:
                                        screenHeight *
                                        0.018, // 1.8% of screen height
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: screenHeight * 0.015,
                            ), // 1.5% of screen height
                            // Organization code field
                            Container(
                              height:
                                  screenHeight * 0.06, // 6% of screen height
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[600]!
                                      : Colors.grey[300]!,
                                ),
                              ),
                              child: TextField(
                                controller: controllers['organ_code'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: screenWidth * 0.035,
                                ), // 3.5% of screen width
                                decoration: InputDecoration(
                                  hintText: isAdmin
                                      ? AppLocalizations.of(
                                          context,
                                        )!.reg_admin_code
                                      : AppLocalizations.of(
                                          context,
                                        )!.reg_org_code,
                                  hintStyle: TextStyle(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[400]
                                        : const Color.fromARGB(255, 99, 97, 97),
                                    fontSize:
                                        screenWidth *
                                        0.04, // 4% of screen width
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
                                            ? (Colors.grey[400] ?? Colors.grey)
                                            : const Color.fromARGB(
                                                255,
                                                80,
                                                77,
                                                77,
                                              ),
                                        BlendMode.srcIn,
                                      ),
                                      width:
                                          screenHeight *
                                          0.03, // 3% of screen height
                                      height:
                                          screenHeight *
                                          0.03, // 3% of screen height
                                    ),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal:
                                        screenWidth *
                                        0.035, // 3.5% of screen width
                                    vertical:
                                        screenHeight *
                                        0.018, // 1.8% of screen height
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: screenHeight * 0.03,
                            ), // 3% of screen height
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
                                height:
                                    screenHeight * 0.06, // 6% of screen height
                                child: ElevatedButton(
                                  onPressed: loading || !isFormValid
                                      ? null
                                      : onSubmit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isFormValid
                                        ? AppColors.lapisLazuli
                                        : Colors.grey,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 1,
                                  ),
                                  child: loading
                                      ? SizedBox(
                                          height:
                                              screenHeight *
                                              0.022, // 2.2% of screen height
                                          width:
                                              screenHeight *
                                              0.022, // 2.2% of screen height
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.reg_send_otp,
                                          style: TextStyle(
                                            fontSize:
                                                screenWidth *
                                                0.05, // 5% of screen width
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                ),
                              ),
                            ),

                            SizedBox(
                              height: screenHeight * 0.025,
                            ), // 2.5% of screen height
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
                                      ? Colors.red[900]?.withValues(alpha: 0.3)
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
                                              Theme.of(context).brightness ==
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
                              SizedBox(
                                height: screenHeight * 0.025,
                              ), // 2.5% of screen height
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
                                fontSize:
                                    screenWidth * 0.03, // 3% of screen width
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(
                              height: screenHeight * 0.02,
                            ), // Space before login text
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
                                          builder: (context) => LoginScreen(),
                                        ),
                                        (Route<dynamic> route) => false,
                                      );
                                    },
                                    child: Text(
                                      AppLocalizations.of(context)!.reg_login,
                                      style: TextStyle(
                                        color: AppColors.lapisLazuli,
                                        fontSize: screenWidth * 0.035,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.01),
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
                                      fontSize: screenWidth * 0.035,
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
                                      fontSize: screenWidth * 0.035,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.01),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoginScreen(),
                                        ),
                                        (Route<dynamic> route) => false,
                                      );
                                    },
                                    child: Text(
                                      AppLocalizations.of(context)!.reg_login,
                                      style: TextStyle(
                                        color: AppColors.lapisLazuli,
                                        fontSize: screenWidth * 0.035,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(
                              height: screenHeight * 0.02,
                            ), // Bottom padding
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
      );
    },
  );
}
