// ignore_for_file: non_constant_identifier_names

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  // Get the effective locale
  String get effectiveLanguageCode => locale.languageCode;

  // Helper method to get localized value with fallback
  String _getLocalizedValue(String key) {
    final currentLocale = locale.languageCode;
    // Try to get the value for the current locale
    if (_localizedValues[currentLocale]?.containsKey(key) == true) {
      final value = _localizedValues[currentLocale]![key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    // If the key is not found or empty in the current locale, and the current locale is not English,
    // fall back to English.
    if (currentLocale != 'en' &&
        _localizedValues['en']?.containsKey(key) == true) {
      final value = _localizedValues['en']![key];
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    // If the key is still not found, return the key itself as a fallback for debugging.
    print('WARNING: No translation found for key: $key');
    return '[$key]';
  }

  static AppLocalizations? of(BuildContext context) {
    print(
      'DEBUG: [AppLocalizations] Getting localizations for context: ${context.hashCode}',
    );

    final locale = Localizations.localeOf(context);
    print(
      'DEBUG: [AppLocalizations] Current locale from context: ${locale.languageCode}',
    );

    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );

    print(
      'DEBUG: [AppLocalizations] Retrieved localizations instance with locale: ${localizations?.locale.languageCode}',
    );

    if (localizations == null) {
      print(
        'DEBUG: [AppLocalizations] Warning: No localizations found for current context',
      );
    }

    return localizations;
  }

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'about_title': 'About us',
      'about_uzita_title': 'Uzita',
      'about_uzita_company': 'Smart Technologies Company',
      'about_uzita_description':
          'We at Uzita, relying on the knowledge of elite engineers and domestic specialists, work with the aim of achieving state-of-the-art technologies and national self-sufficiency in the fields of electronics, software, and mechatronics.',
      'about_uzita_introduction_title': 'Introduction',
      'about_uzita_introduction_body':
          'With more than 12 years of successful experience in the domestic market, we have been able to penetrate the heart of intelligent, automated and robotic systems, making the design and manufacture of complex and technologically advanced products possible, low-cost, durable and of high quality.',
      'about_uzita_mission_title': 'Our mission',
      'about_uzita_mission_body':
          'Design, engineering and manufacturing of motorized products for the construction industry',
      'about_uzita_auto_doors_title': 'Automatic doors',
      'about_uzita_gate_title': 'Traffic gates',
      'about_uzita_automatic_curtain_title': 'Automatic curtains',
      'about_uzita_smart_lock_title': 'Smart handles and locks',
      'about_uzita_vision_title': 'Outlook',
      'about_uzita_vision_body':
          'Becoming among the top 50 specialized companies in the country\'s construction industry within the next 5 years; with the help of divine grace and relying on domestic knowledge.',
      'about_uzita_core_values_title': 'Key values',
      'about_uzita_core_values_body':
          'We are committed to adhering to the following values in all our activities:',
      'about_uzita_core_values_bullet_1': 'Customer orientation',
      'about_uzita_core_values_bullet_2': 'Financial health',
      'about_uzita_core_values_bullet_3': 'Creativity and innovation',
      'about_uzita_core_values_bullet_4': 'Respect for the environment',
      'about_uzita_contact_title': 'Contact information',
      'about_uzita_contact_email': 'Email: info@uzita.ir',
      'about_uzita_contact_phone': 'Phone: 021_77195613',
      'about_uzita_contact_address':
          'Address: Tehran, Narmak, Shahid Jahanshahi Street (78), Shahid Asghar Hosseinali Street (39), Number 9, Second Floor, Unit 36',

      // Help screen sections (Persian-only keys for future use)
      'help_title': 'Application guide',
      'help_intro_title': 'Product introduction',
      'help_intro_body':
          'We, at the Smart Technology Yoozes Team, have designed software to control and secure your buildings. After purchasing this product, you can add different devices and users with different access rights to the application, view their performance reports, and delete or deactivate them if needed. You can also send commands to the devices to open the door, lock the door, and so on through the software.',
      'help_postpurchase_title':
          'Necessary steps after purchasing and installing the application',
      'help_postpurchase_body':
          'After purchasing and installing the application, it will bring you to the login and registration page, where you must click on the administrator registration button to enter the registration page. On this page, it will ask for your information such as username, password, phone number, and organization code. Please note that after purchasing the product, an eight-digit disposable code is written on its carton in the software specifications section, and you must enter it when registering. Please note that you do not provide this code to anyone and only the original owner of the device should use it. After entering the information, a confirmation code will be sent to the contact number by SMS. Also, pay attention to the following when registering:',
      'help_postpurchase_bullet_1': 'Your phone number should not be repeated.',
      'help_postpurchase_bullet_2':
          'Your username should be unique. Please select a name so that no one is selected in the server.',
      'help_postpurchase_bullet_3':
          'You can only use the organization\'s admin code once, and if someone else registers with the organization\'s code, it will no longer be possible to register this way.',
      'help_postpurchase_bullet_4':
          'If you do not comply with any of the above, error text will be displayed to you.',
      'help_add_device_title': 'Add device',
      'help_add_device_body':
          'After registration, you will be taken to the home page. On the home page, click on the list of devices and then click on Add device. You will need to enter the device name and serial number and then it will give you a token. Make sure to copy that token and save it somewhere because it will be used in the device configuration section.',
      'help_add_users_title': 'Adding users',
      'help_add_users_body': 'Users can be added in two ways.',
      'help_add_users_method_1':
          'First method: In this method, you send them the organization membership code and after installing the application, they click on the user registration and after entering the username, password, and contact number, you must enter the code you sent them in the membership code section and after confirming the contact number, a new inactive user will be created. The inactive user cannot perform any operations and the admin must activate it.',
      'help_add_users_method_2':
          'Second method: In this method, the admin can add a new user directly in the User List - Add User section by entering information.',
      'help_user_management_title': 'User management',
      'help_user_management_body':
          'The admin can view all users by clicking on the user list button. At the top of the page, you will see the number of users and below that there is a filter button. You can find the activation status or access level of the desired user by entering the username or contact number. By clicking on any user in the user list, you will enter the details page of that user. On this page, you can delete, deactivate or activate the user. Also, on this page, you can specify the authorized devices for that user so that the user can send commands to that device and view its status.',
      'help_device_management_title': 'Device management',
      'help_device_management_body':
          'By clicking on the Device List button, you can view all devices. By clicking on each device, you will enter the details page of that device. On this page, you can send a new command to that device, such as opening or locking the door. You can also delete or deactivate the device.',
      'help_device_config_title': 'Device configuration',
      'help_device_config_body':
          'The device needs a stable internet connection to connect to the server and record all reports and authenticate users, etc. By pressing the AP button, the device will enter hotspot mode and you will connect to the device via WiFi. After connecting to WiFi, enter the program and enter the device configuration section through the program menu. On this page, you enter the name and password of the home or work WiFi to which the device is to be connected, along with the device token (which was displayed to you during the device addition stage). After that, the device will connect to WiFi and communicate with the server via the token.',
      'help_reports_title': 'Report list',
      'help_reports_body':
          'You can view a list of all commands issued by each user on each device by clicking the Reports button. Note that regular users can only view their own reports.',
      'help_reports_bullet_1':
          'Each report includes information such as user name, device name, command type, command date and time, and usage type (sending command with app or card).',
      'help_reports_bullet_2':
          'You can filter your search based on username, device name, command type, or command registration date.',
      'help_reports_bullet_3':
          'Normal users cannot select a user in the search filter and can only view their own reports.',
      'help_user_levels_title': 'User levels',
      'help_user_levels_body':
          'In this application, users will be divided into four levels and, depending on the access level, they can use different parts of the software. Admins can determine the level of each user in the user details section.',
      'help_company_rep_title': 'Company representative',
      'help_company_rep_bullet_1': 'Add, remove, and deactivate devices',
      'help_company_rep_bullet_2': 'Add, remove, and deactivate users',
      'help_company_rep_bullet_3':
          'Set the list of authorized devices for each user',
      'help_company_rep_bullet_4': 'Configure devices',
      'help_company_rep_bullet_5':
          'Send device service requests to the company',
      'help_company_rep_bullet_6': 'Send messages to support',
      'help_company_rep_bullet_7':
          'View the status of all devices and send commands to them',
      'help_admin_title': 'Admin',
      'help_admin_bullet_1': 'Add new users',
      'help_admin_bullet_2': 'Delete and deactivate users',
      'help_admin_bullet_3': 'Set the list of authorized devices for each user',
      'help_admin_bullet_4': 'Send messages to support',
      'help_admin_bullet_5': 'Configure devices',
      'help_admin_bullet_6':
          'View the status of all devices and send commands to them',
      'help_admin_bullet_7': 'View reports for all users',
      'help_installer_title': 'Installer',
      'help_installer_bullet_1':
          'View the status of all devices and send commands to them',
      'help_installer_bullet_2': 'Send messages to support',
      'help_installer_bullet_3': 'Send device service requests to the company',
      'help_installer_bullet_4': 'Configure the device',
      'help_installer_bullet_5': 'View reports from all users',
      'help_regular_user_title': 'Regular user',
      'help_regular_user_bullet_1':
          'View the status of authorized devices and send commands to them',
      'help_regular_user_bullet_2': 'Send messages to support',
      'help_regular_user_bullet_3': 'Configure the device',
      'help_regular_user_bullet_4': 'View your list of reports',
      'help_user_settings_title': 'User settings',
      'help_user_settings_body':
          'Any user, regardless of their access level, can make settings on their application. By clicking on the Settings button on the home page:',
      'help_user_settings_bullet_1':
          'You can use the dark or light theme of the app. The app has a light theme by default, and users who find bright light bothering their eyes or who prefer a dark theme can use the dark theme in the app settings.',
      'help_user_settings_bullet_2':
          'You can make the text size large or small.',
      'help_user_settings_bullet_3':
          'You can change the application language to English or Persian. The application is pre-set on the Persian language.',
      'help_profile_title': 'Profile',
      'help_profile_body':
          'In the profile section, you can view your profile and also change some information such as your first and last name, city, and address. Please note that you cannot change your username or contact number. If necessary, send a message to support.',
      'help_support_title': 'Send a message to support',
      'help_support_body':
          'You can click on Support in the menu and view the list of messages. There is also a new message button at the bottom of the page through which you can send a new message to support and wait for the support team to respond to your message. Please note that you can have a maximum of three unanswered messages and you must first wait for the support team to respond to your previous messages. You can also click on each message in the message list to view the status and response to that message.',
      'help_service_request_title': 'Device service request',
      'help_service_request_body':
          'You can view the list of your previous service requests by clicking on Services in the menu. Also, by clicking on New Service, you can register a new request by entering the desired part, the time required for repair and other costs, and finally the total cost for the service will be displayed.',

      // WiFi screen (status and prompts)
      'wifi_title': 'Device configuration',
      'wifi_header': 'Device WiFi configuration',
      'wifi_subtitle': 'Connecting the device to WiFi',
      'wifi_steps_title': 'Connection steps',
      'wifi_enter_all_fields':
          'Please enter the WiFi name, password, and device token.',
      'wifi_step_1':
          'First, connect to the WiFi of the device (ESP_SETUP) through the phone settings.',
      'wifi_step_2':
          'Then enter the WiFi name, password, and device token and click the Send button.',
      'wifi_info_title': 'Connection information',
      'wifi_ssid_label': 'WiFi name (SSID)',
      'wifi_ssid_hint': 'Enter your WiFi network name',
      'wifi_password_label': 'WiFi password',
      'wifi_password_hint': 'Enter your WiFi network password',
      'wifi_token_label': 'Device token',
      'wifi_token_hint': 'Enter the device token',
      'wifi_send_button': 'Send information',
      'wifi_sending_button': 'Sending...',
      'wifi_sending': 'Sending information...',
      'wifi_send_success': 'Information sent successfully.',
      'wifi_send_failed': 'Sending failed. Code',
      'wifi_error_connect_prefix': 'Error connecting:',

      // Settings Screen (set_)
      'set_title': 'Settings',
      'set_notifications_title': 'Notifications',
      'set_notifications_subtitle':
          'Settings related to notifications of the application',
      'set_notifications_toggle': 'Receive notifications',
      'set_appearance_title': 'Display mode',
      'set_appearance_subtitle':
          'Settings related to the appearance of the application',
      'set_dark_mode': 'Dark mode',
      'set_text_size_title': 'Text size',
      'set_text_size_subtitle': 'Set the size of the application text',
      'set_text_small': 'Small',
      'set_text_normal': 'Normal',
      'set_text_large': 'Large',
      'set_app_language_title': 'Application language',
      'set_change_language_subtitle': 'Change the application language',

      // Shared Bottom Navigation (nav_)
      'nav_home': 'Home',
      'nav_reports': 'Reports',
      'nav_devices': 'Devices',
      'nav_profile': 'Profile',
      'nav_users': 'Users',
      'nav_services': 'Services',
      'nav_missions': 'Missions',

      // Shared Loading (loading_)
      'loading_please_wait_short': 'Please wait',

      // User List Screen (uls_)
      'uls_title': 'User list',
      'uls_users_header': 'Users',
      'uls_users_count': 'User',
      'uls_users_managers': 'Management',
      'uls_add_user': 'Add user',
      'uls_filter': 'Filter',
      'uls_loading_users': 'Loading users...',
      'uls_no_users_found': 'No users found',
      'uls_refresh_users': 'To refresh the list, pull it down',
      'uls_bad_response': 'Bad response structure',
      'uls_no_access': 'Access denied',
      'uls_error_fetching_users': 'Error fetching information',
      'uls_error_connecting': 'Error connecting to server',
      'uls_add_user_title': 'Add new user',
      'uls_username': 'Username',
      'uls_password': 'Password',
      'uls_phone': 'Phone number',
      'uls_user_code': 'User code',
      'uls_access_level': 'Access level',
      'uls_level1': 'Level 1 - Full admin',
      'uls_level2': 'Level 2 - Manager',
      'uls_level3': 'Level 3 - Regular user',
      'uls_cancel': 'Cancel',
      'uls_submit': 'Add user',
      'uls_fill_all': 'Please fill in all fields',
      'uls_phone_length': 'Phone number must be 10 digits',
      'uls_error_adding_user': 'Error adding user',
      'uls_filter_users': 'Filter users',
      'uls_phone_label': 'Phone number',
      'uls_admin': 'Admin',
      'uls_company_representative': 'Company representative',
      'uls_installer': 'Installer',
      'uls_user': 'User',
      'uls_active_status': 'Active status',
      'uls_active': 'Active',
      'uls_inactive': 'Inactive',
      'uls_clear': 'Clear',
      'uls_full_admin': 'Full admin',
      'uls_manager': 'Manager',
      'uls_regular_user': 'Regular user',
      'uls_apply': 'Apply filter',
      'uls_code': 'Code',

      // User Detail Screen (uds_)
      'uds_title': 'User details',
      'uds_disable_user': 'Disable user',
      'uds_enable_user': 'Enable user',
      'uds_processing': 'Processing...',
      'uds_confirm_status_title': 'Confirm status change',
      'uds_confirm_status_msg':
          'Are you sure you want to change the status of this user?',
      'uds_confirm': 'Confirm',
      'uds_cancle': 'Cancel',
      'uds_delete_permanent':
          'This operation is irreversible and all user information will be deleted',
      'uds_active_success': 'User activated successfully',
      'uds_inactive_success': 'User deactivated successfully',
      'uds_error_changing_status': 'Error changing user status',
      'uds_delete_success': 'User deleted successfully',
      'uds_delete_error': 'Error deleting user',
      'uds_change_level_success': 'User level changed successfully',
      'uds_change_level_error': 'Error changing user level',
      'uds_change_level_title': 'Change user level',
      'uds_current_level': 'Current level:',
      'uds_select_new_level': 'Select new level:',
      'uds_level_1': 'Level 1 - Full admin',
      'uds_level_2': 'Level 2 - Manager',
      'uds_level_3': 'Level 3 - Regular user',
      'uds_unknown': 'Unknown',
      'uds_level_1_description': 'Full access to all features',
      'uds_level_2_description': 'Limited management access',
      'uds_level_3_description': 'Regular user access',
      'uds_level_1_color': 'Red',
      'uds_confirm_level_title': 'Confirm level change',
      'uds_confirm_level_msg':
          'Are you sure you want to change the level of this user?',
      'uds_question_part_1': 'Do you want to change the user',
      'uds_question_part_2': 'level?',
      'uds_new_level': 'New level:',
      'uds_yes': 'Yes',
      'uds_no': 'No',
      'uds_loading': 'Loading...',
      'uds_user_info': 'User information',
      'uds_email': 'Email',
      'uds_phone': 'Phone',
      'uds_code': 'User code',
      'uds_address': 'Address',
      'uds_city': 'City',
      'uds_status': 'Status',
      'uds_active': 'Active',
      'uds_inactive': 'Inactive',
      'uds_change_level_access': 'Change user access level',
      'uds_change_level_access_description': 'Change user access level',
      'uds_allowed_devices': 'Allowed devices',
      'uds_manage_allowed_devices': 'Manage allowed devices',
      'uds_clear': 'Clear',
      'uds_full_admin': 'Full admin',
      'uds_manager': 'Manager',
      'uds_regular_user': 'Regular user',
      'uds_apply': 'Apply filter',
      'uds_wait': 'Please wait',
      'uds_disable_access': 'Disable user access',
      'uds_enable_access': 'Enable user access',
      'uds_disable_access_description': 'This user cannot log in to the system',
      'uds_enable_access_description': 'This user can log in to the system',
      'uds_disable_access_description2':
          'This user cannot log in to the system',
      'uds_enable_access_description2': 'This user can log in to the system',
      'uds_delete_user': 'Delete user',
      'uds_delete_user_description': 'Delete user permanently from the system',
      'uds_delete_user_title': 'Delete user',
      'uds_delete_user_message': 'Are you sure you want to delete this user?',
      'uds_delete_user_description2':
          'This operation is irreversible and all user information will be deleted',
      'uds_delete': 'Delete',
      'uds_delete_user_success': 'User deleted successfully',
      'uds_error_connecting': 'Error connecting to server',
      'uds_user': 'User',
      'uds_delete_full_user': 'Delete full user',

      // User Allowed Devices Screen (ual_)
      'ual_title': 'Allowed devices',
      'ual_add_allowed': 'Add authorized device',
      'ual_remove_allowed': 'Remove from authorized',
      'ual_save': 'Save',
      'ual_error_fetching_info': 'Error fetching information',
      'ual_error_connecting': 'Error connecting to server',
      'ual_save_success': 'Settings saved successfully',
      'ual_save_error': 'Error saving settings',
      'ual_user': 'User',
      'ual_device': 'Device',
      'ual_of': 'of',
      'ual_manager': 'Management',
      'ual_no_devices_found': 'No devices found',
      'ual_is_allowed': 'Authorized',
      'ual_is_not_allowed': 'Not authorized',
      'ual_no_save_changes': 'Changes not saved',
      'ual_saving': 'Saving...',
      'ual_save_changes': 'Save changes',

      // Device List Screen (dls_)
      'dls_title': 'Devices',
      'dls_add_device': 'Add device',
      'dls_devices_header': 'Devices',
      'dls_count_suffix': 'Device',
      'dls_manage': 'Management',
      'dls_retry': 'Retry',
      'dls_local_error': 'Enter the device name and serial number',
      'dls_error': 'Error:',
      'dls_error_connecting': 'Error connecting to server',
      'dls_name_device': 'Device name',
      'dls_name_error': 'Device name is required',
      'dls_serial_number': 'Serial number',
      'dls_serial_number_error': 'Serial number is required',
      'dls_token': 'Device token:',
      'dls_copy': 'Copy',
      'dls_copy_success': 'Token copied to clipboard',
      'dls_note_token': 'Please note this token.',
      'dls_cancel': 'Cancel',
      'dls_close': 'Close',
      'dls_submit': 'Submit device',
      'dls_submitting': 'Submitting...',
      'dls_no_access': 'Access denied',
      'dls_error_fetching_devices': 'Error fetching devices',
      'dls_unknown': 'Unknown',
      'dls_active': 'Active',
      'dls_inactive': 'Inactive',
      'dls_maintenance': 'Maintenance',
      'dls_no_devices': 'No devices found',
      'dls_no_devices_description':
          'No devices are currently registered in the system',
      'dls_user': 'User',
      'dls_company_representative': 'Company representative',
      'dls_admin': 'Admin',
      'dls_installer': 'Installer',
      'dls_regular_user': 'Regular user',
      'dls_loading_devices': 'Loading devices...',
      'dls_wait': 'Please wait',
      'dls_waiting_for_activation': 'Waiting for activation',
      'dls_waiting_for_activation_description':
          'Your account is waiting for system approval.\nAfter activation, you can manage your devices.',
      'dls_contact_admin':
          'Please contact the system administrator via phone or email.',
      'dls_contact_admin_button': 'Contact system administrator',
      'dls_scan_barcode': 'Scan barcode',
      'dls_scan': 'Scan',
      'dls_on_and_off_flash': 'On/off flash',
      'dls_switch_camera': 'Switch camera',
      'dls_scan_hint':
          'Place the barcode inside the frame or select from gallery/file',
      'dls_scan_from_gallery': 'Select from gallery',
      'dls_scan_from_file': 'Select from file',
      'dls_close_scan': 'Close',
      'dls_no_barcode_found': 'No barcode found',
      'dls_barcode_found': 'Barcode identified: ',
      'dls_use_code': 'Use code',
      'dls_scan_error_description':
          'Access to the camera was denied. To scan the barcode, enable camera access.',
      'dls_scan_settings': 'Settings',
      'dls_scan_settings_description':
          'To scan, enable camera access in settings.',
      'dls_cancle_scan': 'Cancel',

      // Device Detail Screen (dds_)
      'dds_send_command': 'Send command',
      'dds_yes': 'Yes',
      'dds_no': 'No',
      'dds_error_command': 'Error sending command.',
      'dds_error_connecting': 'Error connecting to server.',
      'dds_activate_device': 'Activate device',
      'dds_deactivate_device': 'Deactivate device',
      'dds_are_you_sure': 'Are you sure?',
      'dds_error_changing_status': 'Error changing device status.',
      'dds_delete_device': 'Delete device',
      'dds_delete_device_description':
          'Are you sure you want to delete this device?',
      'dds_delete_device_error': 'Error deleting device.',
      'dds_unknown': 'Unknown',
      'dds_active': 'Active',
      'dds_inactive': 'Inactive',
      'dds_serial_number': 'Serial number:',
      'dds_status': 'Status:',
      'dds_choose_command': 'Select the command',
      'dds_command': 'Command',
      'dds_sending': 'Sending...',
      'dds_details_device': 'Device details',
      'dds_delete_device_success': 'Device successfully removed.',

      // Command List Screen (cls_)
      'cls_user': 'User',
      'cls_company_representative': 'Company representative',
      'cls_admin': 'Admin',
      'cls_installer': 'Installer',
      'cls_regular_user': 'Regular user',
      'cls_error_fetching_commands': 'Error fetching commands',
      'cls_error_connecting': 'Error connecting to server',
      'cls_error_address': 'Invalid service address (404)',
      'cls_unexpected_error': 'Unexpected response structure',
      'cls_filtering_search': 'Filter search',
      'cls_command': 'Command',
      'cls_device': 'Device:',
      'cls_no_commands': 'No commands found',
      'cls_no_commands_description':
          'No commands are currently registered in the system',
      'cls_loading_more': 'Load more',
      'cls_loading': 'Loading...',
      'cls_filter_reports': 'Filter reports',
      'cls_name_device': 'Device name',
      'cls_username': 'Username',
      'cls_choosing_date': 'Choose date',
      'cls_choosed_date': 'Selected date:',
      'cls_clear': 'Clear',
      'cls_apply_filter': 'Apply filter',
      'cls_select_date_shamsi': 'Select date',
      'cls_cancel': 'Cancel',
      'cls_submit': 'Submit',
      'cls_title': 'Commands reports',
      'cls_commands': 'Commands',
      'cls_observe': 'Observe',
      'cls_loading_reports': 'Loading reports...',
      'cls_waiting_for_activation': 'Reports waiting for activation',
      'cls_waiting_for_activation_description':
          'Your account is waiting for system approval.\nAfter activation, you can view your reports.',
      'cls_contact_admin':
          'Please contact the system administrator via phone or email.',
      'cls_contact_admin_button': 'Contact system administrator',
      'cls_command_code': 'Command code',
      'cls_date': 'Date:',

      // Profile Screen (pro_)
      'pro_company_representative': 'Company representative',
      'pro_admin': 'Admin',
      'pro_installer': 'Installer',
      'pro_user': 'User',
      'pro_unexpected_error': 'Unexpected response structure',
      'pro_no_access': 'Access denied',
      'pro_error_fetching_profile': 'Error fetching profile',
      'pro_error_connecting': 'Error connecting to server',
      'pro_server_error': 'Server error. Please try again later.',
      'pro_server_connection_error':
          'Error connecting to server. Please check your internet connection.',
      'pro_profile_not_found': 'Profile not found.',
      'pro_update_profile_success': 'Profile updated successfully',
      'pro_update_profile_error': 'Update failed: ',
      'pro_title': 'Profile',
      'pro_edit_profile': 'Edit profile',
      'pro_name': 'Name',
      'pro_last_name': 'Last name',
      'pro_city': 'City',
      'pro_address': 'Address',
      'pro_phone': 'Phone number',
      'pro_email': 'Email',
      'pro_save_profile': 'Save profile',
      'pro_cancle': 'Cancel',
      'pro_save': 'Save',
      'pro_loading_profile': 'Loading profile...',
      'pro_account_active': 'Active account',
      'pro_account_inactive': 'Inactive account',
      'pro_info_account': 'User account information',
      'pro_name_last_name': 'Name and last name',
      'pro_username': 'Username',
      'pro_user_code': 'User\'s code',
      'pro_organ_name': 'Organization name',
      'pro_allowed_devices_count': 'Allowed devices count',
      'pro_created_at': 'Registration date',
      'pro_level_access': 'Access level',
      'pro_quick_access': 'Quick access',
      'pro_quick_access_description': 'Frequently used operations',
      'pro_change_password': 'Change password',
      'pro_notification_settings': 'Notification settings',
      'pro_help': 'Help',
      'pro_waiting_for_activation': 'Profile waiting for activation',
      'pro_waiting_for_activation_description':
          'Your account is waiting for system approval.\nAfter activation, you can use all features.',
      'pro_contact_admin':
          'Please contact the system administrator via phone or email.',
      'pro_contact_admin_button': 'Contact system administrator',

      // Ticket List Screen (tls_)
      'tls_user': 'User',
      'tls_company_representative': 'Company representative',
      'tls_admin': 'Admin',
      'tls_installer': 'Installer',
      'tls_login_again': 'Please login again',
      'tls_unexpected_error': 'Unexpected response structure',
      'tls_no_access': 'Access denied',
      'tls_error_fetching_tickets': 'Error fetching tickets:',
      'tls_error_connecting': 'Error connecting to server',
      'tls_unknown': 'Unknown',
      'tls_title': 'Support',
      'tls_new_ticket': 'New ticket',
      'tls_loading': 'Loading tickets...',
      'tls_error_loading': 'Error loading',
      'tls_try_again': 'Try again',
      'tls_no_tickets': 'You have no tickets',
      'tls_send_new_hint': 'To contact support, send a new ticket',
      'tls_waiting_for_activation': 'Tickets waiting for activation',
      'tls_waiting_for_activation_description':
          'Your account is waiting for system approval.\nAfter activation, you can view and send your tickets.',
      'tls_contact_admin':
          'Please contact the system administrator via phone or email.',
      'tls_contact_admin_button': 'Contact system administrator',

      // Ticket Detail Screen (tds_)
      'tds_login_again': 'Please login again',
      'tds_error_no_ticket': 'Ticket not found',
      'tds_error_details': 'Error fetching ticket details',
      'tds_error_connecting': 'Error connecting to server',
      'tds_unknown': 'Unknown',
      'tds_title': 'Ticket details',
      'tds_loading': 'Loading details...',
      'tds_try_again': 'Try again',
      'tds_waiting_for_reply': 'Waiting for reply',
      'tds_replied': 'Replied',
      'tds_content_message': 'Message content:',
      'tds_replies': 'Support replies',
      'tds_support': 'Support',
      'tds_reply_label': 'Reply',
      'tds_show_soon': 'The response to this ticket will be displayed soon.',
      'tds_waiting_for_reply_support': 'Waiting for support reply',
      'tds_reply_soon':
          'Your ticket is in the review queue and will be answered soon.',

      // Home Screen (home_)
      'home_access_denies': 'Access to user statistics is not allowed',
      'home_logout': 'Logout',
      'home_logout_confirm': 'Are you sure you want to log out?',
      'home_yes': 'Yes',
      'home_no': 'No',
      'home_company_representative': 'Company representative',
      'home_installer': 'Installer',
      'home_user': 'User',
      'home_admin': 'Admin',
      'home_loading': 'Loading...',
      'home_active_devices': 'Active devices',
      'home_active_users': 'Active users',
      'home_pending_missions': 'Pending missions',
      'home_device_list': 'Device list',
      'home_device_list_description': 'Manage and monitor devices',
      'home_user_list': 'User list',
      'home_user_list_description': 'Manage system users',
      'home_reports': 'View reports',
      'home_reports_description': 'System reports and analyses',
      'home_settings': 'Settings',
      'home_settings_description': 'System general settings',
      'home_account_pending': 'Account waiting for activation',
      'home_account_pending_description':
          'Your account has been created by the system administrator, but is not yet active.\nPlease wait for the system administrator to activate your account.',
      'home_contact_admin':
          'Please contact the system administrator via phone or email.',
      'home_contact_admin_button': 'Contact system administrator',

      // Login Screen (login_)
      'login_error_username':
          'The account does not match the username entered. Please try again.',
      'login_error': 'Login error',
      'login_error_connecting': 'Error connecting to server',
      'login_no_authentication':
          'Authentication is not available on this device.',
      'login_with_username_and_Password':
          'First, log in with your username and password.',
      'login_authentication': 'Authenticate with fingerprint/pattern/PIN',
      'login_account': 'Login to account',
      'login_cancle': 'Cancel',
      'login_add_finger': 'Place your fingerprint',
      'login_no_access_fingerprint': 'Fingerprint not recognized',
      'login_need_authentication': 'Authentication required',
      'login_need_lock': 'Page lock required',
      'login_active_lock': 'To use authentication, activate the page lock',
      'login_settings': 'Settings',
      'login_error_fingerprint': 'Fingerprint authentication error',
      'login_biometric': 'Login with fingerprint / PIN / pattern',
      'login_login_first': 'First, log in',
      'login_fingerprint_not_available':
          'The fingerprint sensor is not available on this device or is not supported.',
      'login_fingerprint_not_enrolled':
          'No fingerprints registered. First, register your fingerprint in the device settings.',
      'login_fingerprint_not_set':
          'The page lock is not set on the device. First, set a page lock.',
      'login_fingerprint_locked_out':
          'The sensor is temporarily locked. Please try again later.',
      'login_fingerprint_permanently_locked_out':
          'The sensor is permanently locked. Enter with PIN/pattern and try again.',
      'login_fingerprint_error': 'Fingerprint authentication error',
      'login_username': 'Username',
      'login_password': 'Password',
      'login_remember_me': 'Remember me',
      'login': 'Login',
      'login_user_register': 'User registration',
      'login_admin_register': 'Admin registration',

      // Registration Forms (reg_)
      'reg_phone_98': '+98',
      'reg_user_register': 'User registration',
      'reg_admin_register': 'Admin registration',
      'reg_org_code': 'Organization code',
      'reg_admin_code': 'Management code',
      'reg_send_otp': 'Send verification code',
      'reg_verify_code': 'Verify code',
      'reg_name': 'Username',
      'reg_password': 'Password',
      'reg_phone': '    Phone number',
      'reg_phone_completely': 'Complete phone number:',
      'reg_attention_admin':
          'Note: Get the management code from the system administrator',
      'reg_attention_org':
          'Note: Get the organization code from the relevant administrator',
      'reg_login': 'Login',
      'reg_login_before': 'Already registered?',

      // Add User Screen (adduser_)
      'adduser_error': 'Error',
      'adduser_title': 'Add new user',
      'adduser_submit': 'Add user',
      'adduser_new_info': 'New user information',
      'adduser_username': 'Username',
      'adduser_password': 'Password',
      'adduser_phone': 'Phone number',
      'adduser_code': 'User code',
      'adduser_level_access': 'Access level',
      'adduser_level': 'Level',
      'adduser_required': 'Please fill in all fields',
      'adduser_success': 'User added successfully',

      // Admin Register Screen (adminreg_)
      'adminreg_add_phone_completely':
          'Enter your phone number without zero and completely',
      'adminreg_add_phone_exist': 'This phone number is already registered',
      'adminreg_add_username_exist': 'This username is already registered',
      'adminreg_add_admin_code_exist': 'The management code entered is invalid',
      'adminreg_add_required': 'Please fill in all fields',
      'adminreg_add_error': 'Error sending verification code. Please try again',
      'adminreg_add_success': 'User added successfully',
      'adminreg_add_required_correctly': 'Please fill in all fields correctly',
      'adminreg_error_connecting': 'Error connecting to server',
      'adminreg_error_sending_otp': 'Error sending code',
      'adminreg_title': 'Admin registration',

      // User Register Screen (userreg_)
      'userreg_add_phone_completely':
          'Enter your phone number without zero and completely',
      'userreg_add_phone_exist': 'This phone number is already registered',
      'userreg_add_username_exist': 'This username is already registered',
      'userreg_add_organ_code_exist':
          'The organization code entered is invalid',
      'userreg_add_required': 'Please fill in all fields',
      'userreg_add_error': 'Error sending verification code. Please try again',
      'userreg_add_required_correctly': 'Please fill in all fields correctly',
      'userreg_error_connecting': 'Error connecting to server',
      'userreg_error_sending_otp': 'Error sending code',
      'userreg_error_register': 'Error registering:',
      'userreg_title': 'User registration',

      // Create Ticket Screen (ct_)
      'ct_waiting_response_error':
          'You can have a maximum of 3 unanswered tickets.\nPlease wait for the response to the previous tickets.',
      'ct_add_required': 'Please fill in all fields',
      'ct_try_again_error':
          'An error occurred while submitting the ticket. Please try again',
      'ct_add_required_correctly': 'Please fill in all fields correctly',
      'ct_login_again': 'Please log in again',
      'ct_submit_ticket_successfully': 'Ticket submitted successfully',
      'ct_error_add_ticket': 'Error submitting ticket',
      'ct_error_connecting': 'Error connecting to server',
      'ct_send_ticket_successfully': 'Ticket sent successfully',
      'ct_I_got_it': 'I understand',
      'ct_send_submit': 'Submit',
      'ct_are_you_sure': 'Are you sure you want to send this ticket?',
      'ct_cancle': 'Cancel',
      'ct_send': 'Send',
      'ct_send_new_ticket': 'Send new ticket',
      'ct_information': 'Information',
      'ct_information_description':
          'Please fill in the ticket subject and description completely and accurately so that the support can provide the best response.',
      'ct_title': 'Ticket title',
      'ct_title_example': 'Example: Problem logging in to the account',
      'ct_title_required': 'Ticket title is required',
      'ct_max_part_1': 'Title cannot be more than',
      'ct_max_part_2': 'characters',
      'ct_description_ticket': 'Ticket description',
      'ct_description_ticket_hint':
          'Please describe your problem or request completely...\n\nExample:\n- Steps you took\n- Error received (if any)\n- Time of occurrence of the problem',
      'ct_description_max_length': 'Description cannot be more than',
      'ct_description_max_part_2': 'characters',
      'ct_description_ticket_required': 'Ticket description is required',
      'ct_description_ticket_min_length':
          'Ticket description must be at least 10 characters',
      'ct_loading_sending': 'Sending...',
      'ct_send_ticket': 'Send ticket',
      'ct_important_notes': 'Important notes',
      'ct_important_notes_part_1':
          '• You can have a maximum of 3 unanswered tickets',
      'ct_important_notes_part_2':
          '• The response to tickets is usually provided within 24 hours',
      'ct_important_notes_part_3':
          '• Please refrain from sending duplicate tickets',

      // edit password screen (editpassword_)
      'editpassword_title': 'Change password',
      'editpassword_new_password': 'New password',
      'editpassword_confirm_password': 'Confirm password',
      'editpassword_change_password': 'Change password',
      'editpassword_note':
          'Note: After changing the password, the verification code will be sent',
      'editpassword_add_required_correctly':
          'Please fill in all fields correctly',
      'editpassword_error_no_token': 'Token not found',
      'editpassword_error_connecting': 'Error connecting to server',
      'editpassword_error_sending_request': 'Error sending request',

      // OTP Verify Pass Screen (otpverifypass_)
      'otpverifypass_success_title': 'Password change successful',
      'otpverifypass_success_content': 'Password changed successfully!',
      'otpverifypass_success_button': 'OK',
      'otpverifypass_error_not_correct': 'The code is incorrect or expired',
      'otpverifypass_error_connecting': 'Error connecting to server',
      'otpverifypass_send_new_code': 'New code sent',
      'otpverifypass_error_sending_again': 'Error sending code again',
      'otpverifypass_submit_code': 'Verify code',
      'otpverifypass_type_code': 'Enter the verification code sent',
      'otpverifypass_otp_code': 'Verification code',
      'otpverifypass_remaining_time': 'Remaining time:',
      'otpverifypass_resend_code': 'Resend code',
      'otpverifypass_submit': 'Verify',

      // OTP Verify Screen (otpverify_)
      'otpverify_error_not_correct': 'The code is incorrect or expired',
      'otpverify_error_unsuccessful_login': 'Login failed',
      'otpverify_error_connecting': 'Error connecting to server',
      'otpverify_error_submit_otp': 'Error verifying OTP:',
      'otpverify_send_new_code': 'New code sent',
      'otpverify_error_sending_again': 'Error sending code again',
      'otpverify_submit_code': 'Verify code',
      'otpverify_send_code_content_1':
          'Enter the verification code sent to the number',
      'otpverify_send_code_content_2': 'Enter the code',
      'otpverify_otp_code': 'Verification code',
      'otpverify_remaining_time': 'Remaining time:',
      'otpverify_resend_code': 'Resend code',
      'otpverify_submit': 'Verify',

      // Send Service Screen (SSS_)
      'sss_half_hour': 'Half hour',
      'sss_one_hour': 'One hour',
      'sss_two_hour': 'Two hours',
      'sss_three_hour': 'Three hours',
      'sss_four_hour': 'Four hours',
      'sss_five_hour': 'Five hours',
      'sss_six_hour': 'Six hours',
      'sss_seven_hour': 'Seven hours',
      'sss_eight_hour': 'Eight hours',
      'sss_nine_hour': 'Nine hours',
      'sss_ten_hour': 'Ten hours',
      'sss_add_required': 'Please fill in all fields',
      'sss_successfully': 'Successfully',
      'sss_submit_successfully': 'Request submitted successfully',
      'sss_total_cost': 'Total cost:',
      'sss_tooman': 'Toman',
      'sss_ok': 'OK',
      'sss_error_send_request': 'Error sending request',
      'sss_error_connecting': 'Error connecting to server',
      'sss_send_service_request': 'Send service request',
      'sss_send_service_request_form': 'Service request form',
      'sss_send_service_request_form_title': 'Request title',
      'sss_send_service_request_form_title_hint':
          'Enter the service request title',
      'sss_add_service_request_title_error': 'Please enter the title',
      'sss_send_service_request_form_description': 'Description',
      'sss_send_service_request_form_description_hint':
          'Enter the additional description of the request',
      'sss_add_service_request_description_error':
          'Please enter the description',
      'sss_add_service_request_piece': 'Required piece',
      'sss_choose_service_request_piece_hint': 'Select a piece',
      'sss_add_service_request_piece_error': 'Please select a piece',
      'sss_add_service_request_time': 'Time required for repair',
      'sss_add_service_request_time_hint': 'Select the required time',
      'sss_add_service_request_time_error': 'Please select the time required',
      'sss_other_costs': 'Other costs (Toman)',
      'sss_other_costs_hint': 'Enter the amount of other costs',
      'sss_other_costs_error': 'Please enter the amount of other costs',
      'sss_other_costs_error_number': 'Please enter a valid number',
      'sss_send_service_request_form_submit': 'Send request',
      'sss_loading_sending': 'Sending...',
      'sss_address': 'Address',
      'sss_address_hint': 'Enter the service address',
      'sss_address_error': 'Please enter the address',
      'sss_phone': 'Phone number',
      'sss_phone_hint': 'Enter your phone number',
      'sss_phone_error': 'Please enter the phone number',
      'sss_urgency': 'Urgency level',
      'sss_urgency_hint': 'Select urgency level',
      'sss_urgency_error': 'Please select urgency level',
      'sss_urgency_normal': 'Normal',
      'sss_urgency_urgent': 'Urgent',
      'sss_urgency_very_urgent': 'Very urgent',

      // Service List Screen (sls_)
      'sls_error_connecting': 'Error connecting to server',
      'sls_error_fetching_services': 'Error fetching services',
      'sls_error_fetching_services_status_code_403': 'Access denied',
      'sls_request_service': 'Service requests',
      'sls_request': 'Request',
      'sls_new': 'New',
      'sls_loading': 'Loading...',
      'sls_description': 'Description:',
      'sls_need_piece': 'Required piece',
      'sls_all_cost': 'Total cost:',
      'sls_tooman': 'Toman',
      'sls_date_register': 'Registration date:',
      'sls_no_request': 'No service requests yet',
      'sls_no_request_description': 'Click to register a new request',

      // Service Provider Services Screen (sps_)
      'sps_services': 'Services',
      'sps_pending_services': 'Pending Services',
      'sps_completed_services': 'Completed Services',
      'sps_no_pending_services': 'No pending services',
      'sps_no_pending_services_description':
          'You have no services to complete at the moment',
      'sps_no_completed_services': 'No completed services',
      'sps_no_completed_services_description':
          'You have not completed any services yet',
      'sps_status_open': 'Open',
      'sps_status_assigned': 'Assigned',
      'sps_status_confirm': 'Confirmed',
      'sps_status_done': 'Done',
      'sps_status_canceled': 'Canceled',
      'sps_technician': 'Technician',
      'sps_technician_name': 'Name',
      'sps_technician_phone': 'Phone',
      'sps_technician_grade': 'Technician Average Rating',
      'sps_service_grade': 'Admin Rating for This Service',
      'sps_ratings': 'Ratings',
      'sps_no_rating': 'No rating yet',
      'sps_service_details': 'Service Details',
      'sps_piece_code': 'Code',
      'sps_piece_price': 'Price',
      'sps_cost_info': 'Cost Information',
      'sps_piece_cost': 'Piece Cost',
      'sps_other_costs': 'Other Costs',
      'sps_time_required': 'Time Required',
      'sps_minutes': 'minutes',
      'sps_confirm_completion': 'Confirm Completion',
      'sps_rating_dialog_title': 'Rate and Comment',
      'sps_select_rating': 'Select Rating',
      'sps_comment': 'Comment',
      'sps_comment_hint': 'Enter your comment (optional)',
      'sps_confirm_button': 'Confirm',
      'sps_rating_required': 'Please select a rating',
      'sps_confirming': 'Confirming...',
      'sps_confirmation_success': 'Service confirmed successfully',
      'sps_confirmation_error': 'Error confirming service',

      // Technician Screens (tech_)
      'tech_missions': 'Missions',
      'tech_no_missions': 'No missions',
      'tech_no_missions_description':
          'You have no pending missions at the moment.',
      'tech_task_details': 'Task Details',
      'tech_price': 'Price',
      'tech_location': 'Location',
      'tech_organ_name': 'Organization',
      'tech_address': 'Address',
      'tech_city': 'City',
      'tech_phone': 'Phone',
      'tech_confirm_task': 'Confirm Task Completion',
      'tech_confirmation_success': 'Task confirmed successfully',
      'tech_confirmation_error': 'Error confirming task',
      'tech_no_completed_tasks': 'No completed tasks',
      'tech_no_completed_tasks_description':
          'You have no completed tasks at the moment.',
      'tech_first_visit_date': 'First Visit Date',
      'tech_first_visit_date_hint': 'Select first visit date',
      'tech_first_visit_date_error': 'Please select first visit date',
      'tech_set_first_visit': 'Set First Visit Date',
      'tech_first_visit_success': 'First visit date set successfully',
      'tech_check_task': 'Check Task',
      'tech_piece_name': 'Required Piece',
      'tech_piece_name_hint': 'Select piece',
      'tech_piece_name_error': 'Please select piece',
      'tech_time_required': 'Time Required (minutes)',
      'tech_time_required_hint': 'Enter time in minutes',
      'tech_time_required_error': 'Please enter time',
      'tech_other_costs': 'Other Costs',
      'tech_other_costs_hint': 'Enter other costs',
      'tech_other_costs_error': 'Please enter other costs',
      'tech_second_visit_date': 'Second Visit Date (Optional)',
      'tech_second_visit_date_hint': 'Select second visit date if needed',
      'tech_submit_check_task': 'Submit Task Check',
      'tech_check_task_success': 'Task check submitted successfully',
      'tech_check_task_error': 'Error submitting task check',
      'tech_report': 'Report',
      'tech_report_hint': 'Enter your report',
      'tech_report_error': 'Please enter report',
      'tech_submit_report': 'Submit Report and Confirm',
      'tech_urgency': 'Urgency',
      'tech_urgency_normal': 'Normal',
      'tech_urgency_urgent': 'Urgent',
      'tech_urgency_very_urgent': 'Very Urgent',

      // Splash Screen (splash_)
      'splash_authentication_login': 'Authenticate quickly for login',
      'splash_version': 'Version 1.0.0',

      // Shared Drawer (shareddrawer_)
      'shareddrawer_logout': 'Logout',
      'shareddrawer_logout_confirm': 'Are you sure you want to logout?',
      'shareddrawer_no': 'No',
      'shareddrawer_yes': 'Yes, logout',
      'shareddrawer_level_user': 'User level:',
      'shareddrawer_home': 'Home',
      'shareddrawer_refresh_data': 'Refresh data',
      'shareddrawer_change_password': 'Change password',
      'shareddrawer_help': 'Help',
      'shareddrawer_about': 'About us',
      'shareddrawer_support': 'Support',
      'shareddrawer_services': 'Services',
      'shareddrawer_wifi_config': 'Device configuration',

      // Shared loading (sharedload_)
      'sharedload_please_wait': 'Please wait',

      // ticket card (ticketcard_)
      'ticketcard_unknown': 'Unknown',
      'ticketcard_waiting_response': 'Waiting for response',
      'ticketcard_answered': 'Answered',
      'ticketcard_date_send': 'Date of sending:',
      'ticketcard_view_details': 'View details',

      // All
      'click_again_to_exit': 'Click again to exit',
    },
    'fa': {
      //About screen sections
      'about_title': 'درباره ما',
      'about_uzita_title': 'یوزیتا',
      'about_uzita_company': 'شرکت فناوری‌های هوشمند',
      'about_uzita_description':
          'ما در یوزیتا با تکیه بر دانش مهندسان نخبه و متخصصان داخلی، با هدف دستیابی به فناوری‌های روز دنیا و خودکفایی ملی در شاخه‌های الکترونیک، نرم‌افزار و مکاترونیک فعالیت می‌کنیم.',
      'about_uzita_introduction_title': 'معرفی',
      'about_uzita_introduction_body':
          'با بیش از ۱۲ سال تجربه موفق در بازار داخلی، توانسته‌ایم به قلب سیستم‌های هوشمند، خودکار و رباتیک نفوذ کنیم؛ به گونه‌ای که طراحی و ساخت محصولات پیچیده و پیشرفته فناورانه، به امری ممکن، کم‌هزینه، بادوام و با کیفیت بالا تبدیل شده است.',
      'about_uzita_mission_title': 'ماموریت ما',
      'about_uzita_mission_body':
          'طراحی، مهندسی و ساخت محصولات موتوردار صنعت ساختمان',
      'about_uzita_auto_doors_title': 'درب‌های خودکار',
      'about_uzita_gate_title': 'گیت‌های تردد',
      'about_uzita_automatic_curtain_title': 'پرده‌های اتوماتیک',
      'about_uzita_smart_lock_title': 'دستگیره‌ها و قفل‌های هوشمند',
      'about_uzita_vision_title': 'چشم‌انداز',
      'about_uzita_vision_body':
          'قرار گرفتن در بین ۵۰ شرکت برتر تخصصی صنعت ساختمان کشور طی ۵ سال آینده؛ با استعانت از الطاف الهی و تکیه بر دانش داخلی.',
      'about_uzita_core_values_title': 'ارزش‌های کلیدی',
      'about_uzita_core_values_body':
          'ما متعهد به رعایت ارزش‌های زیر در تمام فعالیت‌های خود هستیم:',
      'about_uzita_core_values_bullet_1': 'مشتری‌مداری',
      'about_uzita_core_values_bullet_2': 'سلامت مالی',
      'about_uzita_core_values_bullet_3': 'خلاقیت و نوآوری',
      'about_uzita_core_values_bullet_4': 'احترام به محیط زیست',
      'about_uzita_contact_title': 'اطلاعات تماس',
      'about_uzita_contact_email': 'ایمیل: info@uzita.ir',
      'about_uzita_contact_phone': 'شماره تماس: ۷۷۱۹۵۶۱۳_۰۲۱',
      'about_uzita_contact_address':
          'آدرس: تهران، نارمک، خیابان شهید جهانشاهی (۷۸)، خیابان شهید اصغر حسینعلی (۳۹)، پلاک ۹، طبقه ۲، واحد ۳۶',

      // Help screen sections (Persian-only keys for future use)
      'help_title': 'راهنمای اپلیکیشن',
      'help_intro_title': 'معرفی محصول',
      'help_intro_body':
          'ما در تیم یوز های فناوری هوشمند نرم افزاری برای کنترل و امنیت ساختمان های شما طراحی کردیم. شما بعد از خریداری این محصول میتوانید دستگاه های مختلف و کاربران با حق دسترسی های مختلف را به اپلیکیشن اضافه بکنید و گزارشات عملکرد آن ها را مشاهده و در صورت نیاز آن ها را حذف و یا غیر فعال بکنید. همچنین از طریق نرم افزار می توانید به دستگاه ها فرمان باز شدن در، قفل شدن در و ... را ارسال بکنید.',
      'help_postpurchase_title': 'اقدامات لازم پس از خرید و نصب اپلیکیشن',
      'help_postpurchase_body':
          'پس از خرید و نصب اپلیکیشن برای شما صفحه لاگین و ثبت نام را می آورد که شما باید روی دکمه ثبت نام مدیر بزنید تا وارد صفحه ثبت نام بشوید. در این صفحه اطلاعات شما مانند نام کاربری ، رمز عبور، شماره تلفن و کد سازمان را می خواهد. دقت کنید پس از خرید محصول بر روی کارتن آن در قسمت مشخصات نرم افزار، کدی هشت رقمی یکبار مصرف نوشته شده و شما در هنگام ثبت نام باید آن را وارد بکنید. دقت کنید این کد را در اختیار هیچ شخصی قرار ندهید و فقط مالک اصلی دستگاه باید از آن استفاده بکند. پس از وارد کردن اطلاعات، به شماره تماس کد تایید پیامک خواهد شد. همچنین در هنگام ثبت نام به موارد زیر دقت بکنید:',
      'help_postpurchase_bullet_1': 'شماره موبایل شما نباید تکراری باشد.',
      'help_postpurchase_bullet_2':
          'نام کاربری شما باید منحصر به فرد باشد. لطفا نامی را انتخاب بکنید تا افراد در سرور انتخاب نشده باشد.',
      'help_postpurchase_bullet_3':
          'از کد ادمین سازمان فقط یکبار می توانید استفاده بکنید و در صورت ثبت نام شخصی دیگر با کد سازمان، دیگر امکان ثبت نام از این طریق وجود ندارد.',
      'help_postpurchase_bullet_4':
          'در صورت رعایت نکردن هر کدام از موارد بالا، متن ارور به شما نمایش داده خواهد شد.',
      'help_add_device_title': 'اضافه کردن دستگاه',
      'help_add_device_body':
          'پس از ثبت نام شما وارد صفحه خانه خواهید شد. در صفحه خانه بر روی لیست دستگاه ها بزنید و بعد روی افزودن دستگاه بزنید. شما باید نام دستگاه و شماره سریال رو وارد بکنید و پس از آن توکنی به شما میدهد. حتما آن توکن را کپی بکنید و در جایی ذخیره بکنید زیرا در قسمت پیکربندی دستگاه استفاده خواهد شد.',
      'help_add_users_title': 'اضافه شدن کاربران',
      'help_add_users_body':
          'کاربران از دو طریق می توانند به اپلیکیشن اضافه شوند.',
      'help_add_users_method_1':
          'روش اول: در این روش کد عضویت در سازمان را برای آن ها می فرستید و آن ها پس از نصب اپلیکیشن بر روی ثبت نام کاربران می زنند و پس از وارد کردن نام کاربری، رمز عبور، شماره تماس، باید در قسمت کد عضویت، کدی که شما برای آن ها فرستاده اید را وارد بکنید و پس از تایید شماره تماس کاربر غیر فعال جدید ساخته خواهد شد. کاربر غیر فعال هیچ عملیاتی نمی تواند انجام بدهد و ادمین باید آن را فعال بکند.',
      'help_add_users_method_2':
          'روش دوم: در این روش خود ادمین به صورت مستقیم در قسمت لیست کاربران – اضافه کردن کاربر می تواند با وارد کردن اطلاعات، کاربر جدیدی را اضافه بکند.',
      'help_user_management_title': 'مدیریت کاربران',
      'help_user_management_body':
          'ادمین می تواند با زدن بر روی دکمه لیست کاربران، همه کاربران را مشاهده بکند. در بالای صفحه تعداد کاربران را مشاهده میکنید و در زیر آن دکمه فیلتر کردن وجود دارد. می توانید با وارد کردن نام کاربری یا شماره تماس، وضعیت فعال بودن و یا سطح دسترسی کاربر مورد نظر را پیدا بکنید. در لیست کاربران با کلیک بر روی هر کاربر، وارد صفحه جزییات آن کاربر خواهید شد. در این صفحه می توانید کاربر را حذف ، غیر فعال و یا فعال بکنید. همچنین در این صفحه می توانید دستگاه های مجاز برای آن کاربر را تعیین بکنید تا کاربر بتواند بر روی آن دستگاه فرمانی ارسال بکند و وضعیت آن را مشاهده بکند.',
      'help_device_management_title': 'مدیریت دستگاه',
      'help_device_management_body':
          'با کلیک بر روی دکمه لیست دستگاه ها، می توانید همه دستگاه ها را مشاهده بکنید. با کلیک بر روی هر دستگاه، وارد صفحه جزییات آن دستگاه خواهید شد. در این صفحه می توانید بر روی آن دستگاه فرمان جدیدی مانند باز شدن و یا قفل شدن در ارسال کنید. همچنین می توانید دستگاه را حذف و یا غیر فعال بکنید.',
      'help_device_config_title': 'پیکربندی دستگاه',
      'help_device_config_body':
          'دستگاه برای اتصال به سرور و ثبت تمام گزارشات و احراز هویت کاربران و ... نیاز به اتصال به اینترنت پایدار دارد. با زدن دکمه AP دستگاه وارد حالت هات اسپات خواهد شد و شما از طریق وایفای به دستگاه متصل شوید. پس از اتصال به وایفای، وارد برنامه شوید و از طریق منوی برنامه وارد قسمت پیکربندی دستگاه شوید. در این صفحه شما نام و رمز وایفای منزل و یا محل کار را که قرار هست دستگاه به آن متصل شود را به همراه توکن دستگاه (که در مرحله اضافه کردن دستگاه به شما نمایش داده شد) را وارد بکنید. پس از آن دستگاه به وایفای متصل خواهد شد و از طریق توکن با سرور ارتباط خواهد گرفت.',
      'help_reports_title': 'لیست گزارشات',
      'help_reports_body':
          'شما می توانید با کلیک بر روی دکمه گزارشات، لیست تمام فرمان هایی که هر کابر روی هر دستگاه اعمال شده را مشاهده بکنید. دقت بکنید که کاربران عادی تنها می توانند گزارشات خودشان را مشاهده بکنند.',
      'help_reports_bullet_1':
          'هر گزارش شامل اطلاعاتی مانند نام کاربر، نام دستگاه، نوع فرمان، تاریخ و ساعت فرمان و نوع استفاده ( ارسال فرمان با اپلیکیشن یا کارت) می باشد.',
      'help_reports_bullet_2':
          'میتوان بر اساس نام کاربری، نام دستگاه، نوع فرمان و یا تاریخ ثبت فرمان، جستجوی خودتان را فیلتر بکنید.',
      'help_reports_bullet_3':
          'کاربران عادی در فیلتر کردن جستجو، نمی توانند کاربری را انتخاب بکنند و فقط گزارشات خودشان را می توانند مشاهده بکنند.',
      'help_user_levels_title': 'سطح کاربران',
      'help_user_levels_body':
          'در این اپلیکیشن کاربران به چهار سطح تقسیم بندی خواهند شد و با توجه به سطح دسترسی، می توانند از قسمت های مختلف نرم افزار استفاده بکنند. ادمین ها می توانند در قسمت جزییات کاربر، سطح هر کاربر را تعیین بکنند.',
      'help_company_rep_title': 'نماینده شرکت',
      'help_company_rep_bullet_1':
          'اضافه کردن، حذف کردن و غیر فعال کردن دستگاه',
      'help_company_rep_bullet_2': 'اضافه کردن، حذف کردن و غیر فعال کردن کاربر',
      'help_company_rep_bullet_3':
          'تعیین کردن لیست دستگاه های مجاز برای هر کاربر',
      'help_company_rep_bullet_4': 'پیکربندی دستگاه',
      'help_company_rep_bullet_5': 'ارسال درخواست سرویس دستگاه به شرکت',
      'help_company_rep_bullet_6': 'ارسال پیام به پشتیبانی',
      'help_company_rep_bullet_7':
          'مشاهده وضعیت همه دستگاه ها و ارسال فرمان به آن ها',
      'help_admin_title': 'ادمین',
      'help_admin_bullet_1': 'اضافه کردن کاربر جدید',
      'help_admin_bullet_2': 'حذف و غیر فعال کردن کاربران',
      'help_admin_bullet_3': 'تعیین کردن لیست دستگاه های مجاز برای هر کاربر',
      'help_admin_bullet_4': 'ارسال پیام به پشتیبانی',
      'help_admin_bullet_5': 'پیکربندی دستگاه',
      'help_admin_bullet_6':
          'مشاهده وضعیت همه دستگاه ها و ارسال فرمان به آن ها',
      'help_admin_bullet_7': 'مشاهده گزارشات همه کاربران',
      'help_installer_title': 'نصاب',
      'help_installer_bullet_1':
          'مشاهده وضعیت همه دستگاه ها و ارسال فرمان به آن ها',
      'help_installer_bullet_2': 'ارسال پیام به پشتیباتی',
      'help_installer_bullet_3': 'ارسال درخواست سرویس دستگاه به شرکت',
      'help_installer_bullet_4': 'پیکربندی دستگاه',
      'help_installer_bullet_5': 'مشاهده گزارشات همه کاربران',
      'help_regular_user_title': 'کاربر عادی',
      'help_regular_user_bullet_1':
          'مشاهده وضعیت دستگاه های مجاز و ارسال فرمان به آن ها',
      'help_regular_user_bullet_2': 'ارسال پیام به پشتیبانی',
      'help_regular_user_bullet_3': 'پیکربندی دستگاه',
      'help_regular_user_bullet_4': 'مشاهده لیست گزارشات خود',
      'help_user_settings_title': 'تنظیمات شخصی کاربر',
      'help_user_settings_body':
          'هر کاربر با هر سطح دسترسی که دارد می تواند تنظیماتی را بر روی اپلیکیشن خود انجام دهد. با زدن بر روی دکمه تنظیمات در صفحه خانه:',
      'help_user_settings_bullet_1':
          'می توانید از تم تاریک یا روشن برنامه استفاده بکنید. برنامه به صورت پیش فرض تم روشن دارند و کاربرانی نور روشن چشم های آن ها را اذیت می کند و یا سلیقه آن ها تم تاریک را می پسندد می توانند در تنظبمات برنامه از تم تاریک استفاده بکنند.',
      'help_user_settings_bullet_2':
          'می توانید اندازه متن ها رو بزرگ یا کوچک بکنید.',
      'help_user_settings_bullet_3':
          'می توانید زبان برنامه را انگلیسی و یا فارسی بکنید. برنامه به صورت پیش فرض روی زبان فارسی هست.',
      'help_profile_title': 'پروفایل',
      'help_profile_body':
          'شما در قسمت پروفایل می توانید مشخصات خودتان را مشاهده بکنید و همچنین برخی اطلاعات مانند نام و نام خانوادگی و شهر و آدرس را تغییر بدهید. دقت بکنید شما نمی توانید نام کاربری و یا شماره تماس خود را تغییر دهید. در صورت لزوم به پشتیبانی پیام بدهید.',
      'help_support_title': 'ارسال پیام به پشتیبانی',
      'help_support_body':
          'شما می توانید در قسمت منو بر روی پشتیبانی کلیک بکنید و لیست پیام ها را مشاهده بکنید. همچنین در پایین صفحه دکمه پیام جدید وجود دارد که می توانید از طریق آن پیام جدیدی به پشتیبانی بدهید و منتظر بمانید تا تیم پشتیبانی جواب پیام شما را بدهد. دقت بکنید که شما حداکثر سه پیام بدون پاسخ می توانید داشته باشید و باید ابتدا صبر کنید تا تیم پشتیبانی به پیام های قبلی شما پاسخ بدهند. همچنین در لیست پیام ها می توانید با کلیک بر روی هر پیام وضغیت و پاسخ آن پیام را مشاهده بکنید.',
      'help_service_request_title': 'درخواست سرویس دستگاه',
      'help_service_request_body':
          'شما می توانید در قسمت منو با کلیک بر روی سرویس ها لیست درخواست های قبلی خودتان برای سرویس را مشاهده بکنید. همچنین با کلیک بر روی سرویس جدید، می توانید با وارد کردن قطعه مورد نظر، زمان نیاز برای تعمیر و سایر هزینه ها، قطعه درخواست جدیدی را ثبت بکنید و در نهایت هزینه کل برای سرویس را نمایش می دهد.',

      // WiFi screen (status and prompts)
      'wifi_title': 'پیکربندی دستگاه',
      'wifi_header': 'پیکربندی وای‌فای دستگاه',
      'wifi_subtitle': 'اتصال دستگاه به شبکه وای‌فای',
      'wifi_steps_title': 'مراحل اتصال',
      'wifi_enter_all_fields':
          'لطفاً نام وای‌فای، رمز و توکن دستگاه را وارد کنید.',
      'wifi_step_1':
          'ابتدا از طریق تنظیمات گوشی به وای‌فای دیوایس (ESP_SETUP) متصل شوید.',
      'wifi_step_2':
          'سپس نام وای‌فای منزل، رمز آن و توکن دستگاه را وارد کرده و روی دکمه ارسال بزنید.',
      'wifi_info_title': 'اطلاعات اتصال',
      'wifi_ssid_label': 'نام وای‌فای (SSID)',
      'wifi_ssid_hint': 'نام شبکه وای‌فای خود را وارد کنید',
      'wifi_password_label': 'رمز عبور وای‌فای',
      'wifi_password_hint': 'رمز عبور شبکه وای‌فای را وارد کنید',
      'wifi_token_label': 'توکن دستگاه',
      'wifi_token_hint': 'توکن دستگاه را وارد کنید',
      'wifi_send_button': 'ارسال اطلاعات',
      'wifi_sending_button': 'در حال ارسال...',
      'wifi_sending': 'در حال ارسال اطلاعات...',
      'wifi_send_success': 'اطلاعات با موفقیت ارسال شد.',
      'wifi_send_failed': 'ارسال ناموفق بود. کد',
      'wifi_error_connect_prefix': 'خطا در اتصال:',

      // Settings Screen (set_)
      'set_title': 'تنظیمات',
      'set_notifications_title': 'اعلان‌ها',
      'set_notifications_subtitle': 'تنظیمات مربوط به اعلان‌های برنامه',
      'set_notifications_toggle': 'دریافت اعلان‌ها',
      'set_appearance_title': 'حالت نمایش',
      'set_appearance_subtitle': 'تنظیمات مربوط به ظاهر برنامه',
      'set_dark_mode': 'حالت تاریک',
      'set_text_size_title': 'اندازه متن',
      'set_text_size_subtitle': 'تنظیم اندازه متن‌های برنامه',
      'set_text_small': 'کوچک',
      'set_text_normal': 'معمولی',
      'set_text_large': 'بزرگ',
      'set_app_language_title': 'زبان برنامه',
      'set_change_language_subtitle': 'تغییر زبان رابط کاربری',

      // Shared Bottom Navigation (nav_)
      'nav_home': 'خانه',
      'nav_reports': 'گزارشات',
      'nav_devices': 'دستگاه ها',
      'nav_profile': 'پروفایل',
      'nav_users': 'کاربران',
      'nav_services': 'سرویس ها',
      'nav_missions': 'ماموریت ها',

      // Shared Loading (loading_)
      'loading_please_wait_short': 'لطفاً صبر کنید',

      // User List Screen (uls_)
      'uls_title': 'لیست کاربران',
      'uls_users_header': 'کاربران',
      'uls_users_count': 'کاربر',
      'uls_users_managers': 'مدیریت',
      'uls_add_user': 'افزودن کاربر',
      'uls_filter': 'فیلتر',
      'uls_loading_users': 'در حال بارگذاری کاربران...',
      'uls_no_users_found': 'هیچ کاربری یافت نشد',
      'uls_refresh_users': 'برای تازه‌سازی لیست، آن را به پایین بکشید',
      'uls_bad_response': 'ساختار پاسخ غیرمنتظره است',
      'uls_no_access': 'دسترسی مجاز نیست',
      'uls_error_fetching_users': 'خطا در دریافت اطلاعات',
      'uls_error_connecting': 'خطا در اتصال به سرور',
      'uls_add_user_title': 'افزودن کاربر جدید',
      'uls_username': 'نام کاربری',
      'uls_password': 'رمز عبور',
      'uls_phone': 'شماره تلفن',
      'uls_user_code': 'کد کاربر',
      'uls_access_level': 'سطح دسترسی',
      'uls_level1': 'سطح 1 - مدیر کل',
      'uls_level2': 'سطح 2 - مدیر',
      'uls_level3': 'سطح 3 - کاربر عادی',
      'uls_cancel': 'انصراف',
      'uls_submit': 'افزودن کاربر',
      'uls_fill_all': 'لطفاً تمام فیلدها را پر کنید',
      'uls_phone_length': 'شماره تماس باید 10 رقم باشد',
      'uls_error_adding_user': 'خطا در افزودن کاربر',
      'uls_filter_users': 'فیلتر کاربران',
      'uls_phone_label': 'شماره تماس',
      'uls_company_representative': 'نماینده شرکت',
      'uls_admin': 'ادمین',
      'uls_installer': 'نصاب',
      'uls_user': 'کاربر',
      'uls_active_status': 'وضعیت فعال',
      'uls_active': 'فعال',
      'uls_inactive': 'غیرفعال',
      'uls_clear': 'پاک‌سازی',
      'uls_full_admin': 'مدیر کل',
      'uls_manager': 'مدیر',
      'uls_regular_user': 'کاربر عادی',
      'uls_apply': 'اعمال فیلتر',
      'uls_code': 'کد',

      // User Detail Screen (uds_)
      'uds_title': 'جزئیات کاربر',
      'uds_disable_user': 'غیرفعال کردن کاربر',
      'uds_enable_user': 'فعال کردن کاربر',
      'uds_processing': 'در حال پردازش...',
      'uds_confirm_status_title': 'تایید تغییر وضعیت',
      'uds_confirm_status_msg': 'آیا از تغییر وضعیت این کاربر مطمئن هستید؟',
      'uds_confirm': 'تأیید',
      'uds_cancle': 'انصراف',
      'uds_delete_permanent':
          'این عملیات غیرقابل بازگشت است و تمام اطلاعات کاربر حذف خواهد شد',
      'uds_error_connecting': 'خطا در اتصال به سرور',
      'uds_active_success': 'کاربر با موفقیت فعال شد',
      'uds_inactive_success': 'کاربر با موفقیت غیرفعال شد',
      'uds_error_changing_status': 'خطا در تغییر وضعیت کاربر',
      'uds_delete_success': 'کاربر با موفقیت حذف شد',
      'uds_delete_error': 'خطا در حذف کاربر',
      'uds_change_level_success': 'سطح کاربر با موفقیت تغییر کرد',
      'uds_change_level_error': 'خطا در تغییر سطح کاربر',
      'uds_change_level_title': 'تغیین سطح کاربر',
      'uds_current_level': 'سطح فعلی:',
      'uds_select_new_level': 'سطح جدید را انتخاب کنید:',
      'uds_level_1': 'سطح 1 - مدیر کل',
      'uds_level_2': 'سطح 2 - مدیر',
      'uds_level_3': 'سطح 3 - کاربر عادی',
      'uds_unknown': 'نامشخص',
      'uds_level_1_description': 'دسترسی کامل به تمام امکانات',
      'uds_level_2_description': 'دسترسی مدیریتی محدود',
      'uds_level_3_description': 'دسترسی عادی',
      'uds_level_1_color': 'قرمز',
      'uds_confirm_level_title': 'تایید تغییر سطح',
      'uds_confirm_level_msg': 'آیا از تغییر سطح این کاربر مطمئن هستید؟',
      'uds_question_part_1': 'آیا می‌خواهید سطح کاربر',
      'uds_question_part_2': 'را تغییر دهید؟',
      'uds_new_level': 'سطح جدید:',
      'uds_yes': 'بله',
      'uds_no': 'خیر',
      'uds_loading': 'در حال بارگذاری...',
      'uds_user_info': 'اطلاعات کاربر',
      'uds_email': 'ایمیل',
      'uds_phone': 'تلفن',
      'uds_code': 'کد کاربر',
      'uds_address': 'آدرس',
      'uds_city': 'شهر',
      'uds_status': 'وضعیت',
      'uds_active': 'فعال',
      'uds_inactive': 'غیرفعال',
      'uds_change_level_access': 'تغییر سطح دسترسی',
      'uds_change_level_access_description': 'تغییر سطح دسترسی کاربر',
      'uds_allowed_devices': 'دستگاه‌های مجاز',
      'uds_manage_allowed_devices': 'مدیریت دستگاه‌های مجاز',
      'uds_clear': 'پاک‌سازی',
      'uds_full_admin': 'مدیر کل',
      'uds_manager': 'مدیر',
      'uds_regular_user': 'کاربر عادی',
      'uds_apply': 'اعمال فیلتر',
      'uds_wait': 'لطفاً صبر کنید',
      'uds_disable_access': 'غیرفعال کردن دسترسی کاربر',
      'uds_enable_access': 'فعال کردن دسترسی کاربر',
      'uds_disable_access_description':
          'این کاربر دیگر نمی‌تواند وارد سیستم شود',
      'uds_enable_access_description': 'این کاربر می‌تواند وارد سیستم شود',
      'uds_disable_access_description2':
          'این کاربر دیگر نمی‌تواند وارد سیستم شود',
      'uds_enable_access_description2': 'این کاربر می‌تواند وارد سیستم شود',
      'uds_delete_user': 'حذف کاربر',
      'uds_delete_user_description': 'حذف دائمی کاربر از سیستم',
      'uds_delete_user_title': 'تایید حذف کاربر',
      'uds_delete_user_message': 'آیا از حذف دائمی این کاربر مطمئن هستید؟',
      'uds_delete_user_description2':
          'این عملیات غیرقابل بازگشت است و تمام اطلاعات کاربر حذف خواهد شد',
      'uds_delete': 'حذف',
      'uds_delete_user_success': 'کاربر با موفقیت حذف شد',
      'uds_user': 'کاربر',
      'uds_delete_full_user': 'حذف دائمی کاربر',

      // User Allowed Devices Screen (ual_)
      'ual_title': 'دیوایس‌های مجاز',
      'ual_add_allowed': 'افزودن دستگاه مجاز',
      'ual_remove_allowed': 'حذف از مجاز',
      'ual_save': 'ذخیره',
      'ual_error_fetching_info': 'خطا در دریافت اطلاعات',
      'ual_error_connecting': 'خطا در اتصال به سرور',
      'ual_save_success': 'تنظیمات با موفقیت ذخیره شد',
      'ual_save_error': 'خطا در ذخیره تنظیمات',
      'ual_user': 'کاربر',
      'ual_device': 'دستگاه',
      'ual_of': 'از',
      'ual_manager': 'مدیریت',
      'ual_no_devices_found': 'هیچ دستگاهی یافت نشد',
      'ual_is_allowed': 'مجاز',
      'ual_is_not_allowed': 'غیرمجاز',
      'ual_no_save_changes': 'تغییرات ذخیره نشده',
      'ual_saving': 'در حال ذخیره...',
      'ual_save_changes': 'ذخیره تغییرات',

      // Device List Screen (dls_)
      'dls_title': 'دستگاه‌ها',
      'dls_add_device': 'افزودن دستگاه',
      'dls_devices_header': 'دستگاه‌ها',
      'dls_count_suffix': 'دستگاه',
      'dls_manage': 'مدیریت',
      'dls_retry': 'تلاش مجدد',
      'dls_local_error': 'نام دستگاه و شماره سریال را وارد کنید',
      'dls_error': 'خطا:',
      'dls_error_connecting': 'خطا در اتصال به سرور',
      'dls_name_device': 'نام دستگاه',
      'dls_name_error': 'نام دستگاه الزامی است',
      'dls_serial_number': 'شماره سریال',
      'dls_serial_number_error': 'شماره سریال الزامی است',
      'dls_token': 'توکن دستگاه:',
      'dls_copy': 'کپی',
      'dls_copy_success': 'توکن در کلیپ بورد کپی شد',
      'dls_note_token': 'لطفاً این توکن را یادداشت کنید.',
      'dls_cancel': 'انصراف',
      'dls_close': 'بستن',
      'dls_submit': 'ثبت دستگاه',
      'dls_submitting': 'در حال ارسال...',
      'dls_no_access': 'دسترسی مجاز نیست',
      'dls_error_fetching_devices': 'خطا در دریافت دستگاه‌ها',
      'dls_unknown': 'نامشخص',
      'dls_active': 'فعال',
      'dls_inactive': 'غیرفعال',
      'dls_maintenance': 'در حال تعمیر',
      'dls_no_devices': 'هیچ دستگاهی یافت نشد',
      'dls_no_devices_description':
          'در حال حاضر هیچ دستگاهی در سیستم ثبت نشده است',
      'dls_user': 'کاربر',
      'dls_company_representative': 'نماینده شرکت',
      'dls_admin': 'ادمین',
      'dls_installer': 'نصاب',
      'dls_regular_user': 'کاربر عادی',
      'dls_loading_devices': 'در حال بارگذاری دستگاه‌ها...',
      'dls_wait': 'لطفاً صبر کنید',
      'dls_waiting_for_activation': 'در انتظار فعال‌سازی',
      'dls_waiting_for_activation_description':
          'حساب کاربری شما در انتظار تایید مدیر سیستم است.\nپس از فعال‌سازی می‌توانید دستگاه‌های خود را مدیریت کنید.',
      'dls_contact_admin':
          'لطفاً از طریق تلفن یا ایمیل با مدیر سیستم تماس بگیرید.',
      'dls_contact_admin_button': 'تماس با مدیر سیستم',
      'dls_scan_barcode': 'اسکن بارکد',
      'dls_scan': 'اسکن',
      'dls_on_and_off_flash': 'روشن/خاموش کردن فلش',
      'dls_switch_camera': 'تعویض دوربین',
      'dls_scan_hint':
          'بارکد را داخل کادر قرار دهید یا از گالری/فایل انتخاب کنید',
      'dls_scan_from_gallery': 'انتخاب از گالری',
      'dls_scan_from_file': 'انتخاب فایل',
      'dls_close_scan': 'بستن',
      'dls_no_barcode_found': 'بارکدی در تصویر یافت نشد',
      'dls_barcode_found': 'کد شناسایی شد: ',
      'dls_use_code': 'استفاده از کد',
      'dls_scan_error_description':
          'دسترسی به دوربین رد شد. برای اسکن بارکد، اجازه دوربین را فعال کنید.',
      'dls_scan_settings': 'تنظیمات',
      'dls_scan_settings_description':
          'برای اسکن، اجازه دوربین را در تنظیمات فعال کنید.',
      'dls_cancle_scan': 'لغو',

      // Device Detail Screen (dds_)
      'dds_send_command': 'ارسال فرمان',
      'dds_yes': 'بله',
      'dds_no': 'خیر',
      'dds_error_command': 'خطا در ارسال فرمان.',
      'dds_error_connecting': 'خطا در اتصال به سرور.',
      'dds_activate_device': 'فعال‌سازی دستگاه',
      'dds_deactivate_device': 'غیرفعال کردن دستگاه',
      'dds_are_you_sure': 'آیا مطمئن هستید؟',
      'dds_error_changing_status': 'خطا در تغییر وضعیت دستگاه.',
      'dds_delete_device': 'حذف دستگاه',
      'dds_delete_device_description': 'آیا از حذف این دستگاه مطمئن هستید؟',
      'dds_delete_device_error': 'خطا در حذف دستگاه.',
      'dds_unknown': 'نامشخص',
      'dds_active': 'فعال',
      'dds_inactive': 'غیرفعال',
      'dds_serial_number': 'شماره سریال:',
      'dds_status': 'وضعیت:',
      'dds_choose_command': 'فرمان مورد نظر را انتخاب کنید',
      'dds_command': 'فرمان',
      'dds_sending': 'در حال ارسال...',
      'dds_details_device': 'جزئیات دستگاه',
      'dds_delete_device_success': 'دستگاه با موفقیت حذف شد.',

      // Command List Screen (cls_)
      'cls_user': 'کاربر',
      'cls_company_representative': 'نماینده شرکت',
      'cls_admin': 'ادمین',
      'cls_installer': 'نصاب',
      'cls_regular_user': 'کاربر عادی',
      'cls_error_fetching_commands': 'خطا در دریافت فرمان‌ها',
      'cls_error_connecting': 'خطا در اتصال به سرور',
      'cls_error_address': 'آدرس سرویس گزارش نامعتبر است (404)',
      'cls_unexpected_error': 'ساختار پاسخ غیرمنتظره است',
      'cls_filtering_search': 'فیلتر کردن جستجو',
      'cls_command': 'فرمان',
      'cls_device': 'دستگاه:',
      'cls_no_commands': 'هیچ فرمانی یافت نشد',
      'cls_no_commands_description':
          'در حال حاضر هیچ فرمانی در سیستم ثبت نشده است',
      'cls_loading_more': 'بارگذاری بیشتر',
      'cls_loading': 'در حال بارگذاری...',
      'cls_filter_reports': 'فیلتر گزارشات',
      'cls_name_device': 'نام دستگاه',
      'cls_username': 'نام کاربری',
      'cls_choosing_date': 'انتخاب تاریخ',
      'cls_choosed_date': 'تاریخ انتخاب شده:',
      'cls_clear': 'پاک‌سازی',
      'cls_apply_filter': 'اعمال فیلتر',
      'cls_select_date_shamsi': 'انتخاب تاریخ شمسی',
      'cls_cancel': 'انصراف',
      'cls_submit': 'تأیید',
      'cls_title': 'گزارشات فرمان‌ها',
      'cls_commands': 'فرمان‌ها',
      'cls_observe': 'مشاهده',
      'cls_loading_reports': 'در حال بارگذاری گزارش‌ها...',
      'cls_waiting_for_activation': 'گزارشات در انتظار فعال‌سازی',
      'cls_waiting_for_activation_description':
          'حساب کاربری شما در انتظار تایید مدیر سیستم است.\nپس از فعال‌سازی می‌توانید گزارشات خود را مشاهده کنید.',
      'cls_contact_admin':
          'لطفاً از طریق تلفن یا ایمیل با مدیر سیستم تماس بگیرید.',
      'cls_contact_admin_button': 'تماس با مدیر سیستم',
      'cls_command_code': 'کد فرمان',
      'cls_date': 'تاریخ:',

      // Profile Screen (pro_)
      'pro_company_representative': 'نماینده شرکت',
      'pro_admin': 'ادمین',
      'pro_installer': 'نصاب',
      'pro_user': 'کاربر',
      'pro_unexpected_error': 'ساختار پاسخ غیرمنتظره است',
      'pro_no_access': 'دسترسی مجاز نیست',
      'pro_error_fetching_profile': 'خطا در دریافت پروفایل',
      'pro_error_connecting': 'خطا در اتصال به سرور',
      'pro_server_error': 'خطا در سرور. لطفاً بعداً تلاش کنید.',
      'pro_server_connection_error':
          'خطا در ارتباط با سرور. لطفاً اتصال اینترنت خود را بررسی کنید.',
      'pro_profile_not_found': 'پروفایل یافت نشد.',
      'pro_update_profile_success': 'پروفایل با موفقیت به‌روزرسانی شد',
      'pro_update_profile_error': 'به‌روزرسانی ناموفق: ',
      'pro_title': 'پروفایل',
      'pro_edit_profile': 'ویرایش پروفایل',
      'pro_name': 'نام',
      'pro_last_name': 'نام خانوادگی',
      'pro_city': 'شهر',
      'pro_address': 'آدرس',
      'pro_phone': 'شماره تماس',
      'pro_email': 'ایمیل',
      'pro_save_profile': 'ذخیره پروفایل',
      'pro_cancle': 'انصراف',
      'pro_save': 'ذخیره',
      'pro_loading_profile': 'در حال بارگذاری پروفایل...',
      'pro_account_active': 'حساب فعال',
      'pro_account_inactive': 'حساب غیرفعال',
      'pro_info_account': 'اطلاعات حساب کاربری',
      'pro_name_last_name': 'نام و نام خانوادگی',
      'pro_username': 'نام کاربری',
      'pro_user_code': 'کد کاربر',
      'pro_organ_name': 'نام سازمان',
      'pro_allowed_devices_count': 'تعداد دستگاه های مجاز',
      'pro_created_at': 'تاریخ ثبت',
      'pro_level_access': 'سطح دسترسی',
      'pro_quick_access': 'دسترسی سریع',
      'pro_quick_access_description': 'عملیات‌های پرکاربرد',
      'pro_change_password': 'تغییر رمز عبور',
      'pro_notification_settings': 'تنظیمات اعلان‌ها',
      'pro_help': 'راهنما',
      'pro_waiting_for_activation': 'پروفایل در انتظار فعال‌سازی',
      'pro_waiting_for_activation_description':
          'حساب کاربری شما در انتظار تایید مدیر سیستم است.\nپس از فعال‌سازی می‌توانید از تمامی امکانات استفاده کنید.',
      'pro_contact_admin':
          'لطفاً از طریق تلفن یا ایمیل با مدیر سیستم تماس بگیرید.',
      'pro_contact_admin_button': 'تماس با مدیر سیستم',

      // Ticket List Screen (tls_)
      'tls_user': 'کاربر',
      'tls_company_representative': 'نماینده شرکت',
      'tls_admin': 'ادمین',
      'tls_installer': 'نصاب',
      'tls_login_again': 'لطفاً دوباره وارد شوید',
      'tls_unexpected_error': 'ساختار پاسخ غیرمنتظره است',
      'tls_no_access': 'دسترسی مجاز نیست',
      'tls_error_fetching_tickets': 'خطا در دریافت تیکت‌ها:',
      'tls_error_connecting': 'خطا در اتصال به سرور',
      'tls_unknown': 'نامشخص',
      'tls_title': 'پشتیبانی',
      'tls_new_ticket': 'تیکت جدید',
      'tls_loading': 'در حال بارگذاری تیکت‌ها...',
      'tls_error_loading': 'خطا در بارگذاری',
      'tls_try_again': 'تلاش مجدد',
      'tls_no_tickets': 'شما تیکتی ندارید',
      'tls_send_new_hint': 'برای ارتباط با پشتیبانی، تیکت جدید ارسال کنید',
      'tls_waiting_for_activation': 'تیکت‌ها در انتظار فعال‌سازی',
      'tls_waiting_for_activation_description':
          'حساب کاربری شما در انتظار تایید مدیر سیستم است.\nپس از فعال‌سازی می‌توانید تیکت‌های خود را مشاهده و ارسال کنید.',
      'tls_contact_admin':
          'لطفاً از طریق تلفن یا ایمیل با مدیر سیستم تماس بگیرید.',
      'tls_contact_admin_button': 'تماس با مدیر سیستم',

      // Ticket Detail Screen (tds_)
      'tds_login_again': 'لطفاً دوباره وارد شوید',
      'tds_error_no_ticket': 'تیکت مورد نظر یافت نشد',
      'tds_error_details': 'خطا در دریافت جزئیات تیکت',
      'tds_error_connecting': 'خطا در اتصال به سرور',
      'tds_unknown': 'نامشخص',
      'tds_title': 'جزئیات تیکت',
      'tds_loading': 'در حال بارگذاری جزئیات...',
      'tds_try_again': 'تلاش مجدد',
      'tds_waiting_for_reply': 'در انتظار پاسخ',
      'tds_replied': 'پاسخ داده شده',
      'tds_content_message': 'محتوای پیام:',
      'tds_replies': 'پاسخ‌های پشتیبانی',
      'tds_support': 'پشتیبانی',
      'tds_reply_label': 'پاسخ',
      'tds_show_soon': 'پاسخ این تیکت به‌زودی نمایش داده خواهد شد.',
      'tds_waiting_for_reply_support': 'در انتظار پاسخ پشتیبانی',
      'tds_reply_soon':
          'تیکت شما در صف بررسی قرار دارد و به‌زودی پاسخ داده خواهد شد.',

      // Home Screen (home_)
      'home_access_denies': 'دسترسی به آمار کاربران مجاز نیست',
      'home_logout': 'خروج',
      'home_logout_confirm': 'آیا مطمئن هستید که می‌خواهید خارج شوید؟',
      'home_yes': 'بله',
      'home_no': 'خیر',
      'home_company_representative': 'نماینده شرکت',
      'home_installer': 'نصاب',
      'home_user': 'کاربر',
      'home_admin': 'ادمین',
      'home_loading': 'در حال بارگذاری...',
      'home_active_devices': 'دستگاه فعال',
      'home_active_users': 'کاربر فعال',
      'home_pending_missions': 'ماموریت در انتظار',
      'home_device_list': 'لیست دستگاه ها',
      'home_device_list_description': 'مدیریت و نظارت بر دستگاه ها',
      'home_user_list': 'لیست کاربران',
      'home_user_list_description': 'مدیریت کاربران سیستم',
      'home_reports': 'مشاهده گزارشات',
      'home_reports_description': 'گزارشات و تحلیل های سیستم',
      'home_settings': 'تنظیمات',
      'home_settings_description': 'تنظیمات عمومی سیستم',
      'home_account_pending': 'حساب کاربری در انتظار فعال‌سازی',
      'home_account_pending_description':
          'حساب کاربری شما توسط مدیر سیستم ایجاد شده اما هنوز فعال نشده است.\nلطفاً منتظر بمانید تا مدیر سیستم حساب شما را فعال کند.',
      'home_contact_admin':
          'لطفاً از طریق تلفن یا ایمیل با مدیر سیستم تماس بگیرید.',
      'home_contact_admin_button': 'تماس با مدیر سیستم',

      // Login Screen (login_)
      'login_error_username':
          'حساب کاربری برگشتی با نام کاربری وارد شده تطابق ندارد. لطفاً دوباره تلاش کنید.',
      'login_error': 'خطا در ورود',
      'login_error_connecting': 'خطا در اتصال به سرور',
      'login_no_authentication': 'احراز هویت در این دستگاه در دسترس نیست.',
      'login_with_username_and_Password':
          'ابتدا یک بار با نام کاربری و رمز عبور وارد شوید.',
      'login_authentication': 'برای ورود با اثر انگشت/الگو/پین احراز هویت کنید',
      'login_account': 'ورود به حساب',
      'login_cancle': 'انصراف',
      'login_add_finger': 'اثر انگشت خود را قرار دهید',
      'login_no_access_fingerprint': 'اثر انگشت شناسایی نشد',
      'login_need_authentication': 'نیاز به احراز هویت',
      'login_need_lock': 'نیاز به قفل صفحه',
      'login_active_lock': 'برای استفاده از احراز هویت، قفل صفحه را فعال کنید',
      'login_settings': 'تنظیمات',
      'login_error_fingerprint': 'خطا در احراز هویت اثر انگشت',
      'login_biometric': 'ورود با اثر انگشت / پین / الگو',
      'login_login_first': 'ابتدا یک بار وارد شوید',
      'login_fingerprint_not_available':
          'حسگر اثر انگشت در این دستگاه موجود نیست یا پشتیبانی نمی‌شود.',
      'login_fingerprint_not_enrolled':
          'هیچ اثرانگشتی ثبت نشده است. ابتدا در تنظیمات دستگاه اثرانگشت خود را ثبت کنید.',
      'login_fingerprint_not_set':
          'قفل صفحه روی دستگاه تنظیم نشده است. ابتدا یک قفل صفحه تنظیم کنید.',
      'login_fingerprint_locked_out':
          'حسگر به طور موقت قفل شده است. بعداً دوباره تلاش کنید.',
      'login_fingerprint_permanently_locked_out':
          'حسگر به طور دائم قفل شده است. با PIN/الگو وارد شوید و مجدد تلاش کنید.',
      'login_fingerprint_error': 'خطا در احراز هویت اثر انگشت',
      'login_username': 'نام کاربری',
      'login_password': 'رمز عبور',
      'login_remember_me': 'ذخیره نام کاربری',
      'login': 'ورود',
      'login_user_register': 'ثبت‌نام کاربر',
      'login_admin_register': 'ثبت‌نام مدیر',

      // Registration Forms (reg_)
      'reg_user_register': 'ثبت‌نام کاربر',
      'reg_admin_register': 'ثبت‌نام مدیر',
      'reg_org_code': 'کد سازمان',
      'reg_admin_code': 'کد مدیریت',
      'reg_send_otp': 'ارسال کد تأیید',
      'reg_verify_code': 'تأیید کد',
      'reg_name': 'نام کاربری',
      'reg_password': 'رمز عبور',
      'reg_phone': '     شماره تلفن',
      'reg_phone_completely': 'شماره کامل:',
      'reg_phone_98': '+98',
      'reg_attention_admin': 'توجه: کد مدیریت را از مسئول سیستم دریافت کنید',
      'reg_attention_org': 'توجه: کد سازمان را از مسئول مربوطه دریافت کنید',
      'reg_login': 'ورود',
      'reg_login_before': ' قبلا ثبت نام کردی؟ ',

      // Add User Screen (adduser_)
      'adduser_error': 'خطا',
      'adduser_title': 'افزودن کاربر جدید',
      'adduser_submit': 'افزودن کاربر',
      'adduser_new_info': 'اطلاعات کاربر جدید',
      'adduser_username': 'نام کاربری',
      'adduser_password': 'رمز عبور',
      'adduser_phone': 'شماره تلفن',
      'adduser_code': 'کد کاربر',
      'adduser_level_access': 'سطح دسترسی',
      'adduser_level': 'سطح',
      'adduser_required': 'لطفاً تمام فیلدها را پر کنید',
      'adduser_success': 'کاربر با موفقیت اضافه شد',

      // Admin Register Screen (adminreg_)
      'adminreg_add_phone_completely':
          'شماره تلفن خود را بدون صفر و کامل وارد کنید',
      'adminreg_add_phone_exist': 'این شماره تلفن قبلاً ثبت شده است',
      'adminreg_add_username_exist': 'این نام کاربری قبلاً ثبت شده است',
      'adminreg_add_admin_code_exist': 'کد مدیریت وارد شده معتبر نیست',
      'adminreg_add_required': 'لطفاً تمام فیلدها را پر کنید',
      'adminreg_add_error': 'خطا در ارسال کد تایید. دوباره تلاش کنید',
      'adminreg_add_success': 'کاربر با موفقیت اضافه شد',
      'adminreg_add_required_correctly':
          'لطفاً تمام فیلدها را به درستی پر کنید',
      'adminreg_error_connecting': 'خطا در اتصال به سرور',
      'adminreg_error_sending_otp': 'خطا در ارسال کد',
      'adminreg_title': 'ثبت‌نام مدیر',

      // User Register Screen (userreg_)
      'userreg_add_phone_completely':
          'شماره تلفن خود را بدون صفر و کامل وارد کنید',
      'userreg_add_phone_exist': 'این شماره تلفن قبلاً ثبت شده است',
      'userreg_add_username_exist': 'این نام کاربری قبلاً ثبت شده است',
      'userreg_add_organ_code_exist': 'کد سازمان وارد شده معتبر نیست',
      'userreg_add_required': 'لطفاً تمام فیلدها را پر کنید',
      'userreg_add_error': 'خطا در ارسال کد تایید. دوباره تلاش کنید',
      'userreg_add_required_correctly': 'لطفاً تمام فیلدها را به درستی پر کنید',
      'userreg_error_connecting': 'خطا در اتصال به سرور',
      'userreg_error_sending_otp': 'خطا در ارسال کد',
      'userreg_error_register': 'خطا در ثبت‌نام:',
      'userreg_title': 'ثبت‌نام کاربر',

      // Create Ticket Screen (ct_)
      'ct_waiting_response_error':
          'شما حداکثر 3 تیکت بی‌پاسخ می‌توانید داشته باشید.\nلطفاً منتظر پاسخ تیکت‌های قبلی بمانید.',
      'ct_add_required': 'لطفاً تمام فیلدها را پر کنید',
      'ct_try_again_error': 'خطایی در ثبت تیکت رخ داد. دوباره تلاش کنید',
      'ct_add_required_correctly': 'لطفاً تمام فیلدها را به درستی پر کنید',
      'ct_login_again': 'لطفاً دوباره وارد شوید',
      'ct_submit_ticket_successfully': 'تیکت شما با موفقیت ثبت شد',
      'ct_error_add_ticket': 'خطا در ثبت تیکت',
      'ct_error_connecting': 'خطا در اتصال به سرور',
      'ct_send_ticket_successfully': 'تیکت ارسال شد',
      'ct_I_got_it': 'متوجه شدم',
      'ct_send_submit': 'تأیید ارسال',
      'ct_are_you_sure': 'آیا از ارسال این تیکت اطمینان دارید؟',
      'ct_cancle': 'انصراف',
      'ct_send': 'ارسال',
      'ct_send_new_ticket': 'ارسال تیکت جدید',
      'ct_information': 'راهنمایی',
      'ct_information_description':
          'لطفاً موضوع و توضیحات تیکت خود را به‌طور کامل و دقیق وارد کنید تا پشتیبانی بتواند بهترین پاسخ را ارائه دهد.',
      'ct_title': 'عنوان تیکت',
      'ct_title_example': 'مثال: مشکل در ورود به حساب کاربری',
      'ct_title_required': 'عنوان تیکت اجباری است',
      'ct_max_part_1': 'عنوان نمی‌تواند بیش از',
      'ct_max_part_2': 'کاراکتر باشد',
      'ct_description_ticket': 'توضیحات تیکت',
      'ct_description_ticket_hint':
          'لطفاً مشکل یا درخواست خود را به‌طور کامل شرح دهید...\n\nمثال:\n- مراحلی که انجام دادید\n- خطای دریافتی (در صورت وجود)\n- زمان وقوع مشکل',
      'ct_description_max_length': 'توضیحات نمی‌تواند بیش از',
      'ct_description_max_part_2': 'کاراکتر باشد',
      'ct_description_ticket_required': 'توضیحات تیکت اجباری است',
      'ct_description_ticket_min_length':
          'توضیحات تیکت باید حداقل 10 کاراکتر باشد',
      'ct_loading_sending': 'در حال ارسال...',
      'ct_send_ticket': 'ارسال تیکت',
      'ct_important_notes': 'نکات مهم',
      'ct_important_notes_part_1':
          '• حداکثر 3 تیکت بی‌پاسخ می‌توانید داشته باشید',
      'ct_important_notes_part_2':
          '• پاسخ تیکت‌ها معمولاً ظرف 24 ساعت ارائه می‌شود',
      'ct_important_notes_part_3': '• لطفاً از ارسال تیکت تکراری خودداری کنید',

      // edit password screen (editpassword_)
      'editpassword_title': 'تغییر رمز عبور',
      'editpassword_new_password': 'رمز عبور جدید',
      'editpassword_confirm_password': 'تایید رمز عبور',
      'editpassword_change_password': 'تغییر رمز عبور',
      'editpassword_note':
          'توجه: پس از تغییر رمز عبور، کد تایید ارسال خواهد شد',
      'editpassword_add_required_correctly':
          'لطفاً تمام فیلدها را به درستی پر کنید',
      'editpassword_error_no_token': 'توکن یافت نشد',
      'editpassword_error_connecting': 'خطا در اتصال به سرور',
      'editpassword_error_sending_request': 'خطا در ارسال درخواست',

      // OTP Verify Pass Screen (otpverifypass_)
      'otpverifypass_success_title': 'تغییر رمز موفق',
      'otpverifypass_success_content': 'رمز عبور با موفقیت تغییر کرد!',
      'otpverifypass_success_button': 'باشه',
      'otpverifypass_error_not_correct': 'کد اشتباه یا منقضی شده است',
      'otpverifypass_error_connecting': 'خطا در اتصال به سرور',
      'otpverifypass_send_new_code': 'کد جدید ارسال شد',
      'otpverifypass_error_sending_again': 'خطا در ارسال مجدد کد',
      'otpverifypass_submit_code': 'تایید کد',
      'otpverifypass_type_code': 'کد تأیید ارسال‌شده را وارد کنید',
      'otpverifypass_otp_code': 'کد تایید',
      'otpverifypass_remaining_time': 'زمان باقی‌مانده:',
      'otpverifypass_resend_code': 'ارسال مجدد کد',
      'otpverifypass_submit': 'تایید',

      // OTP Verify Screen (otpverify_)
      'otpverify_error_not_correct': 'کد اشتباه یا منقضی شده است',
      'otpverify_error_unsuccessful_login': 'ورود ناموفق بود',
      'otpverify_error_connecting': 'خطا در اتصال به سرور',
      'otpverify_error_submit_otp': 'خطا در تایید OTP:',
      'otpverify_send_new_code': 'کد جدید ارسال شد',
      'otpverify_error_sending_again': 'خطا در ارسال مجدد کد',
      'otpverify_submit_code': 'تایید کد',
      'otpverify_send_code_content_1': 'کد تأیید ارسال‌شده به شماره',
      'otpverify_send_code_content_2': 'را وارد کنید',
      'otpverify_otp_code': 'کد تایید',
      'otpverify_remaining_time': 'زمان باقی‌مانده:',
      'otpverify_resend_code': 'ارسال مجدد کد',
      'otpverify_submit': 'تایید',

      // Send Service Screen (SSS_)
      'sss_half_hour': 'نیم ساعت',
      'sss_one_hour': 'یک ساعت',
      'sss_two_hour': 'دو ساعت',
      'sss_three_hour': 'سه ساعت',
      'sss_four_hour': 'چهار ساعت',
      'sss_five_hour': 'پنج ساعت',
      'sss_six_hour': 'شش ساعت',
      'sss_seven_hour': 'هفت ساعت',
      'sss_eight_hour': 'هشت ساعت',
      'sss_nine_hour': 'نه ساعت',
      'sss_ten_hour': 'ده ساعت',
      'sss_add_required': 'لطفاً تمام فیلدها را پر کنید',
      'sss_successfully': 'موفقیت آمیز',
      'sss_submit_successfully': 'درخواست شما با موفقیت ثبت شد',
      'sss_total_cost': 'هزینه کل:',
      'sss_tooman': 'تومان',
      'sss_ok': 'باشه',
      'sss_error_send_request': 'خطا در ارسال درخواست',
      'sss_error_connecting': 'خطا در اتصال به سرور',
      'sss_send_service_request': 'ارسال درخواست سرویس',
      'sss_send_service_request_form': 'فرم ارسال درخواست سرویس',
      'sss_send_service_request_form_title': 'عنوان درخواست',
      'sss_send_service_request_form_title_hint':
          'عنوان درخواست سرویس را وارد کنید',
      'sss_add_service_request_title_error': 'لطفاً عنوان را وارد کنید',
      'sss_send_service_request_form_description': 'توضیحات',
      'sss_send_service_request_form_description_hint':
          'توضیحات تکمیلی درخواست را وارد کنید',
      'sss_add_service_request_description_error': 'لطفاً توضیحات را وارد کنید',
      'sss_add_service_request_piece': 'قطعه مورد نیاز',
      'sss_choose_service_request_piece_hint': 'یک قطعه را انتخاب کنید',
      'sss_add_service_request_piece_error': 'لطفاً یک قطعه را انتخاب کنید',
      'sss_add_service_request_time': 'زمان مورد نیاز برای تعمیر',
      'sss_add_service_request_time_hint': 'زمان مورد نیاز را انتخاب کنید',
      'sss_add_service_request_time_error':
          'لطفاً زمان مورد نیاز را انتخاب کنید',
      'sss_other_costs': 'سایر هزینه‌ها (تومان)',
      'sss_other_costs_hint': 'مبلغ سایر هزینه‌ها را وارد کنید',
      'sss_other_costs_error': 'لطفاً مبلغ سایر هزینه‌ها را وارد کنید',
      'sss_other_costs_error_number': 'لطفاً عدد معتبر وارد کنید',
      'sss_send_service_request_form_submit': 'ارسال درخواست',
      'sss_loading_sending': 'در حال ارسال...',
      'sss_address': 'آدرس',
      'sss_address_hint': 'آدرس سرویس را وارد کنید',
      'sss_address_error': 'لطفاً آدرس را وارد کنید',
      'sss_phone': 'شماره تماس',
      'sss_phone_hint': 'شماره تماس خود را وارد کنید',
      'sss_phone_error': 'لطفاً شماره تماس را وارد کنید',
      'sss_urgency': 'درجه فوریت',
      'sss_urgency_hint': 'درجه فوریت را انتخاب کنید',
      'sss_urgency_error': 'لطفاً درجه فوریت را انتخاب کنید',
      'sss_urgency_normal': 'عادی',
      'sss_urgency_urgent': 'فوری',
      'sss_urgency_very_urgent': 'خیلی فوری',

      // Service List Screen (sls_)
      'sls_error_connecting': 'خطا در اتصال به سرور',
      'sls_error_fetching_services': 'خطا در دریافت اطلاعات',
      'sls_error_fetching_services_status_code_403': 'دسترسی مجاز نیست',
      'sls_request_service': 'درخواست‌های سرویس',
      'sls_request': 'درخواست',
      'sls_new': 'جدید',
      'sls_loading': 'در حال بارگذاری...',
      'sls_description': 'توضیحات:',
      'sls_need_piece': 'قطعه مورد نیاز',
      'sls_all_cost': 'هزینه کل:',
      'sls_tooman': 'تومان',
      'sls_date_register': 'تاریخ ثبت:',
      'sls_no_request': 'هنوز درخواست سرویسی ندارید',
      'sls_no_request_description': 'برای ثبت درخواست جدید کلیک کنید',

      // Service Provider Services Screen (sps_)
      'sps_services': 'سرویس ها',
      'sps_pending_services': 'سرویس های در انتظار',
      'sps_completed_services': 'سرویس های انجام شده',
      'sps_no_pending_services': 'سرویس در انتظاری وجود ندارد',
      'sps_no_pending_services_description':
          'در حال حاضر سرویسی برای انجام ندارید',
      'sps_no_completed_services': 'سرویس انجام شده‌ای وجود ندارد',
      'sps_no_completed_services_description':
          'هنوز هیچ سرویسی انجام نداده‌اید',
      'sps_status_open': 'باز',
      'sps_status_assigned': 'واگذار شده',
      'sps_status_confirm': 'تایید شده',
      'sps_status_done': 'تمام شده',
      'sps_status_canceled': 'کنسل شده',
      'sps_technician': 'تکنسین',
      'sps_technician_name': 'نام',
      'sps_technician_phone': 'تلفن',
      'sps_technician_grade': 'میانگین امتیاز تکنسین',
      'sps_service_grade': 'نمره مدیر برای این سرویس',
      'sps_ratings': 'امتیازها',
      'sps_no_rating': 'هنوز امتیازی ثبت نشده',
      'sps_service_details': 'جزئیات سرویس',
      'sps_piece_code': 'کد',
      'sps_piece_price': 'قیمت',
      'sps_cost_info': 'اطلاعات هزینه',
      'sps_piece_cost': 'هزینه قطعه',
      'sps_other_costs': 'سایر هزینه‌ها',
      'sps_time_required': 'زمان مورد نیاز',
      'sps_minutes': 'دقیقه',
      'sps_confirm_completion': 'تایید اتمام کار',
      'sps_rating_dialog_title': 'امتیازدهی و ثبت نظر',
      'sps_select_rating': 'انتخاب امتیاز',
      'sps_comment': 'نظر',
      'sps_comment_hint': 'نظر خود را وارد کنید (اختیاری)',
      'sps_confirm_button': 'تایید کردن',
      'sps_rating_required': 'لطفاً یک امتیاز انتخاب کنید',
      'sps_confirming': 'در حال تایید...',
      'sps_confirmation_success': 'سرویس با موفقیت تایید شد',
      'sps_confirmation_error': 'خطا در تایید سرویس',

      // Technician Screens (tech_)
      'tech_missions': 'ماموریت ها',
      'tech_no_missions': 'ماموریتی وجود ندارد',
      'tech_no_missions_description': 'در حال حاضر ماموریت در انتظاری ندارید.',
      'tech_task_details': 'جزئیات ماموریت',
      'tech_price': 'قیمت',
      'tech_location': 'موقعیت',
      'tech_organ_name': 'سازمان',
      'tech_address': 'آدرس',
      'tech_city': 'شهر',
      'tech_phone': 'تلفن',
      'tech_confirm_task': 'تایید اتمام کار',
      'tech_confirmation_success': 'ماموریت با موفقیت تایید شد',
      'tech_first_visit_date': 'زمان مراجعه اولیه',
      'tech_first_visit_date_hint': 'زمان مراجعه اولیه را انتخاب کنید',
      'tech_first_visit_date_error': 'لطفاً زمان مراجعه اولیه را انتخاب کنید',
      'tech_set_first_visit': 'ثبت زمان مراجعه اولیه',
      'tech_first_visit_success': 'زمان مراجعه اولیه با موفقیت ثبت شد',
      'tech_check_task': 'بررسی مأموریت',
      'tech_piece_name': 'قطعه مورد نیاز',
      'tech_piece_name_hint': 'قطعه را انتخاب کنید',
      'tech_piece_name_error': 'لطفاً قطعه را انتخاب کنید',
      'tech_time_required': 'زمان مورد نیاز (دقیقه)',
      'tech_time_required_hint': 'زمان را به دقیقه وارد کنید',
      'tech_time_required_error': 'لطفاً زمان را وارد کنید',
      'tech_other_costs': 'سایر هزینه‌ها',
      'tech_other_costs_hint': 'سایر هزینه‌ها را وارد کنید',
      'tech_other_costs_error': 'لطفاً سایر هزینه‌ها را وارد کنید',
      'tech_second_visit_date': 'زمان مراجعه مجدد (اختیاری)',
      'tech_second_visit_date_hint':
          'در صورت نیاز زمان مراجعه مجدد را انتخاب کنید',
      'tech_submit_check_task': 'ثبت بررسی مأموریت',
      'tech_check_task_success': 'بررسی مأموریت با موفقیت ثبت شد',
      'tech_check_task_error': 'خطا در ثبت بررسی مأموریت',
      'tech_report': 'گزارش',
      'tech_report_hint': 'گزارش خود را وارد کنید',
      'tech_report_error': 'لطفاً گزارش را وارد کنید',
      'tech_submit_report': 'ثبت گزارش و تایید',
      'tech_urgency': 'درجه فوریت',
      'tech_urgency_normal': 'عادی',
      'tech_urgency_urgent': 'فوری',
      'tech_urgency_very_urgent': 'خیلی فوری',
      'tech_confirmation_error': 'خطا در تایید ماموریت',
      'tech_no_completed_tasks': 'ماموریت انجام شده‌ای وجود ندارد',
      'tech_no_completed_tasks_description':
          'در حال حاضر ماموریت انجام شده‌ای ندارید.',

      // Splash Screen (splash_)
      'splash_authentication_login': 'برای ورود سریع احراز هویت کنید',
      'splash_version': 'نسخه 1.0.0',

      // Shared Drawer (shareddrawer_)
      'shareddrawer_logout': 'خروج از حساب',
      'shareddrawer_logout_confirm': 'آیا مطمئن هستید که می‌خواهید خارج شوید؟',
      'shareddrawer_no': 'خیر',
      'shareddrawer_yes': 'بله، خروج',
      'shareddrawer_level_user': 'سطح کاربری:',
      'shareddrawer_home': 'خانه',
      'shareddrawer_refresh_data': 'بروزرسانی اطلاعات',
      'shareddrawer_change_password': 'تغییر رمز عبور',
      'shareddrawer_help': 'راهنما',
      'shareddrawer_about': 'درباره ما',
      'shareddrawer_support': 'پشتیبانی',
      'shareddrawer_services': 'سرویس ها',
      'shareddrawer_wifi_config': 'پیکربندی دستگاه',

      // Shared loading (sharedload_)
      'sharedload_please_wait': 'لطفاً صبر کنید',

      // ticket card (ticketcard_)
      'ticketcard_unknown': 'نامشخص',
      'ticketcard_waiting_response': 'در انتظار پاسخ',
      'ticketcard_answered': 'پاسخ داده شده',
      'ticketcard_date_send': 'تاریخ ارسال:',
      'ticketcard_view_details': 'مشاهده جزئیات',

      // All
      'click_again_to_exit': 'برای خروج دوباره دکمه بازگشت را فشار دهید',
    },
  };

  // User Register Screen (userreg_)
  String get userreg_add_phone_completely =>
      _getLocalizedValue('userreg_add_phone_completely');
  String get userreg_add_phone_exist =>
      _getLocalizedValue('userreg_add_phone_exist');
  String get userreg_add_username_exist =>
      _getLocalizedValue('userreg_add_username_exist');
  String get userreg_add_organ_code_exist =>
      _getLocalizedValue('userreg_add_organ_code_exist');
  String get userreg_add_required => _getLocalizedValue('userreg_add_required');
  String get userreg_add_error => _getLocalizedValue('userreg_add_error');
  String get userreg_add_required_correctly =>
      _getLocalizedValue('userreg_add_required_correctly');
  String get userreg_error_connecting =>
      _getLocalizedValue('userreg_error_connecting');
  String get userreg_error_sending_otp =>
      _getLocalizedValue('userreg_error_sending_otp');
  String get userreg_error_register =>
      _getLocalizedValue('userreg_error_register');
  String get userreg_title => _getLocalizedValue('userreg_title');

  // WiFi screen getters (wifi_*)
  String get wifi_title => _getLocalizedValue('wifi_title');
  String get wifi_header => _getLocalizedValue('wifi_header');
  String get wifi_subtitle => _getLocalizedValue('wifi_subtitle');
  String get wifi_steps_title => _getLocalizedValue('wifi_steps_title');
  String get wifi_enter_all_fields =>
      _getLocalizedValue('wifi_enter_all_fields');
  String get wifi_step_1 => _getLocalizedValue('wifi_step_1');
  String get wifi_step_2 => _getLocalizedValue('wifi_step_2');
  String get wifi_info_title => _getLocalizedValue('wifi_info_title');
  String get wifi_ssid_label => _getLocalizedValue('wifi_ssid_label');
  String get wifi_ssid_hint => _getLocalizedValue('wifi_ssid_hint');
  String get wifi_password_label => _getLocalizedValue('wifi_password_label');
  String get wifi_password_hint => _getLocalizedValue('wifi_password_hint');
  String get wifi_token_label => _getLocalizedValue('wifi_token_label');
  String get wifi_token_hint => _getLocalizedValue('wifi_token_hint');
  String get wifi_send_button => _getLocalizedValue('wifi_send_button');
  String get wifi_sending_button => _getLocalizedValue('wifi_sending_button');
  String get wifi_sending => _getLocalizedValue('wifi_sending');
  String get wifi_send_success => _getLocalizedValue('wifi_send_success');
  String get wifi_send_failed => _getLocalizedValue('wifi_send_failed');
  String get wifi_error_connect_prefix =>
      _getLocalizedValue('wifi_error_connect_prefix');

  // Settings Screen getters (set_*)
  String get set_title {
    print('DEBUG: set_title getter called, locale: $effectiveLanguageCode');
    final localeData = _localizedValues[effectiveLanguageCode];
    if (localeData == null) {
      print('DEBUG: ERROR - No data for locale: $effectiveLanguageCode');
      print('DEBUG: Available locales: ${_localizedValues.keys.toList()}');
      return 'Settings'; // Fallback
    }

    final value = localeData['set_title'];
    if (value == null) {
      print(
        'DEBUG: ERROR - No set_title key for locale: $effectiveLanguageCode',
      );
      print('DEBUG: Available keys: ${localeData.keys.toList()}');
      return 'Settings'; // Fallback
    }

    print(
      'DEBUG: set_title called, locale: $effectiveLanguageCode, value: $value',
    );
    return value;
  }

  String get set_notifications_title =>
      _getLocalizedValue('set_notifications_title');
  String get set_notifications_subtitle =>
      _getLocalizedValue('set_notifications_subtitle');
  String get set_notifications_toggle =>
      _getLocalizedValue('set_notifications_toggle');
  String get set_appearance_title => _getLocalizedValue('set_appearance_title');
  String get set_appearance_subtitle =>
      _getLocalizedValue('set_appearance_subtitle');
  String get set_dark_mode => _getLocalizedValue('set_dark_mode');
  String get set_text_size_title => _getLocalizedValue('set_text_size_title');
  String get set_text_size_subtitle =>
      _getLocalizedValue('set_text_size_subtitle');
  String get set_text_small => _getLocalizedValue('set_text_small');
  String get set_text_normal => _getLocalizedValue('set_text_normal');
  String get set_text_large => _getLocalizedValue('set_text_large');
  String get set_app_language_title =>
      _getLocalizedValue('set_app_language_title');
  String get set_change_language_subtitle =>
      _getLocalizedValue('set_change_language_subtitle');

  // Navigation getters (nav_*)
  String get nav_home => _getLocalizedValue('nav_home');
  String get nav_reports => _getLocalizedValue('nav_reports');
  String get nav_devices => _getLocalizedValue('nav_devices');
  String get nav_profile => _getLocalizedValue('nav_profile');
  String get nav_users => _getLocalizedValue('nav_users');
  String get nav_services => _getLocalizedValue('nav_services');
  String get nav_missions => _getLocalizedValue('nav_missions');

  // Loading getters (loading_*)
  String get loading_please_wait_short =>
      _getLocalizedValue('loading_please_wait_short');

  // User List Screen getters (uls_*)
  String get uls_title => _getLocalizedValue('uls_title');
  String get uls_users_header => _getLocalizedValue('uls_users_header');
  String get uls_users_count => _getLocalizedValue('uls_users_count');
  String get uls_users_managers => _getLocalizedValue('uls_users_managers');
  String get uls_add_user => _getLocalizedValue('uls_add_user');
  String get uls_filter => _getLocalizedValue('uls_filter');
  String get uls_loading_users => _getLocalizedValue('uls_loading_users');
  String get uls_no_users_found => _getLocalizedValue('uls_no_users_found');
  String get uls_refresh_users => _getLocalizedValue('uls_refresh_users');
  String get uls_bad_response => _getLocalizedValue('uls_bad_response');
  String get uls_no_access => _getLocalizedValue('uls_no_access');
  String get uls_error_fetching_users =>
      _getLocalizedValue('uls_error_fetching_users');
  String get uls_error_connecting => _getLocalizedValue('uls_error_connecting');
  String get uls_add_user_title => _getLocalizedValue('uls_add_user_title');
  String get uls_username => _getLocalizedValue('uls_username');
  String get uls_password => _getLocalizedValue('uls_password');
  String get uls_phone => _getLocalizedValue('uls_phone');
  String get uls_user_code => _getLocalizedValue('uls_user_code');
  String get uls_access_level => _getLocalizedValue('uls_access_level');
  String get uls_level1 => _getLocalizedValue('uls_level1');
  String get uls_level2 => _getLocalizedValue('uls_level2');
  String get uls_level3 => _getLocalizedValue('uls_level3');
  String get uls_cancel => _getLocalizedValue('uls_cancel');
  String get uls_submit => _getLocalizedValue('uls_submit');
  String get uls_fill_all => _getLocalizedValue('uls_fill_all');
  String get uls_phone_length => _getLocalizedValue('uls_phone_length');
  String get uls_error_adding_user =>
      _getLocalizedValue('uls_error_adding_user');
  String get uls_filter_users => _getLocalizedValue('uls_filter_users');
  String get uls_phone_label => _getLocalizedValue('uls_phone_label');
  String get uls_admin => _getLocalizedValue('uls_admin');
  String get uls_company_representative =>
      _getLocalizedValue('uls_company_representative');
  String get uls_installer => _getLocalizedValue('uls_installer');
  String get uls_user => _getLocalizedValue('uls_user');
  String get uls_active_status => _getLocalizedValue('uls_active_status');
  String get uls_active => _getLocalizedValue('uls_active');
  String get uls_inactive => _getLocalizedValue('uls_inactive');
  String get uls_clear => _getLocalizedValue('uls_clear');
  String get uls_full_admin => _getLocalizedValue('uls_full_admin');
  String get uls_manager => _getLocalizedValue('uls_manager');
  String get uls_regular_user => _getLocalizedValue('uls_regular_user');
  String get uls_apply => _getLocalizedValue('uls_apply');
  String get uls_code => _getLocalizedValue('uls_code');

  // User Detail Screen getters (uds_*)
  String get uds_title => _getLocalizedValue('uds_title');
  String get uds_disable_user => _getLocalizedValue('uds_disable_user');
  String get uds_enable_user => _getLocalizedValue('uds_enable_user');
  String get uds_processing => _getLocalizedValue('uds_processing');
  String get uds_confirm_status_title =>
      _getLocalizedValue('uds_confirm_status_title');
  String get uds_confirm_status_msg =>
      _getLocalizedValue('uds_confirm_status_msg');
  String get uds_confirm => _getLocalizedValue('uds_confirm');
  String get uds_cancle => _getLocalizedValue('uds_cancle');
  String get uds_delete_permanent => _getLocalizedValue('uds_delete_permanent');
  String get uds_active_success => _getLocalizedValue('uds_active_success');
  String get uds_inactive_success => _getLocalizedValue('uds_inactive_success');
  String get uds_error_changing_status =>
      _getLocalizedValue('uds_error_changing_status');
  String get uds_delete_success => _getLocalizedValue('uds_delete_success');
  String get uds_delete_error => _getLocalizedValue('uds_delete_error');
  String get uds_change_level_success =>
      _getLocalizedValue('uds_change_level_success');
  String get uds_change_level_error =>
      _getLocalizedValue('uds_change_level_error');
  String get uds_change_level_title =>
      _getLocalizedValue('uds_change_level_title');
  String get uds_current_level => _getLocalizedValue('uds_current_level');
  String get uds_select_new_level => _getLocalizedValue('uds_select_new_level');
  String get uds_level_1 => _getLocalizedValue('uds_level_1');
  String get uds_level_2 => _getLocalizedValue('uds_level_2');
  String get uds_level_3 => _getLocalizedValue('uds_level_3');
  String get uds_unknown => _getLocalizedValue('uds_unknown');
  String get uds_level_1_description =>
      _getLocalizedValue('uds_level_1_description');
  String get uds_level_2_description =>
      _getLocalizedValue('uds_level_2_description');
  String get uds_level_3_description =>
      _getLocalizedValue('uds_level_3_description');
  String get uds_level_1_color => _getLocalizedValue('uds_level_1_color');
  String get uds_confirm_level_title =>
      _getLocalizedValue('uds_confirm_level_title');
  String get uds_confirm_level_msg =>
      _getLocalizedValue('uds_confirm_level_msg');
  String get uds_question_part_1 => _getLocalizedValue('uds_question_part_1');
  String get uds_question_part_2 => _getLocalizedValue('uds_question_part_2');
  String get uds_new_level => _getLocalizedValue('uds_new_level');
  String get uds_yes => _getLocalizedValue('uds_yes');
  String get uds_no => _getLocalizedValue('uds_no');
  String get uds_loading => _getLocalizedValue('uds_loading');
  String get uds_user_info => _getLocalizedValue('uds_user_info');
  String get uds_email => _getLocalizedValue('uds_email');
  String get uds_phone => _getLocalizedValue('uds_phone');
  String get uds_code => _getLocalizedValue('uds_code');
  String get uds_address => _getLocalizedValue('uds_address');
  String get uds_city => _getLocalizedValue('uds_city');
  String get uds_status => _getLocalizedValue('uds_status');
  String get uds_active => _getLocalizedValue('uds_active');
  String get uds_inactive => _getLocalizedValue('uds_inactive');
  String get uds_change_level_access =>
      _getLocalizedValue('uds_change_level_access');
  String get uds_change_level_access_description =>
      _getLocalizedValue('uds_change_level_access_description');
  String get uds_allowed_devices => _getLocalizedValue('uds_allowed_devices');
  String get uds_manage_allowed_devices =>
      _getLocalizedValue('uds_manage_allowed_devices');
  String get uds_clear => _getLocalizedValue('uds_clear');
  String get uds_full_admin => _getLocalizedValue('uds_full_admin');
  String get uds_manager => _getLocalizedValue('uds_manager');
  String get uds_regular_user => _getLocalizedValue('uds_regular_user');
  String get uds_apply => _getLocalizedValue('uds_apply');
  String get uds_wait => _getLocalizedValue('uds_wait');
  String get uds_disable_access => _getLocalizedValue('uds_disable_access');
  String get uds_enable_access => _getLocalizedValue('uds_enable_access');
  String get uds_disable_access_description =>
      _getLocalizedValue('uds_disable_access_description');
  String get uds_enable_access_description =>
      _getLocalizedValue('uds_enable_access_description');
  String get uds_disable_access_description2 =>
      _getLocalizedValue('uds_disable_access_description2');
  String get uds_enable_access_description2 =>
      _getLocalizedValue('uds_enable_access_description2');
  String get uds_delete_user => _getLocalizedValue('uds_delete_user');
  String get uds_delete_user_description =>
      _getLocalizedValue('uds_delete_user_description');
  String get uds_delete_user_title =>
      _getLocalizedValue('uds_delete_user_title');
  String get uds_delete_user_message =>
      _getLocalizedValue('uds_delete_user_message');
  String get uds_delete_user_description2 =>
      _getLocalizedValue('uds_delete_user_description2');
  String get uds_delete => _getLocalizedValue('uds_delete');
  String get uds_delete_user_success =>
      _getLocalizedValue('uds_delete_user_success');
  String get uds_error_connecting => _getLocalizedValue('uds_error_connecting');
  String get uds_user => _getLocalizedValue('uds_user');
  String get uds_delete_full_user => _getLocalizedValue('uds_delete_full_user');

  // User Allowed Devices Screen getters (ual_*)
  String get ual_title => _getLocalizedValue('ual_title');
  String get ual_add_allowed => _getLocalizedValue('ual_add_allowed');
  String get ual_remove_allowed => _getLocalizedValue('ual_remove_allowed');
  String get ual_save => _getLocalizedValue('ual_save');
  String get ual_error_fetching_info =>
      _getLocalizedValue('ual_error_fetching_info');
  String get ual_error_connecting => _getLocalizedValue('ual_error_connecting');
  String get ual_save_success => _getLocalizedValue('ual_save_success');
  String get ual_save_error => _getLocalizedValue('ual_save_error');
  String get ual_user => _getLocalizedValue('ual_user');
  String get ual_device => _getLocalizedValue('ual_device');
  String get ual_of => _getLocalizedValue('ual_of');
  String get ual_manager => _getLocalizedValue('ual_manager');
  String get ual_no_devices_found => _getLocalizedValue('ual_no_devices_found');
  String get ual_is_allowed => _getLocalizedValue('ual_is_allowed');
  String get ual_is_not_allowed => _getLocalizedValue('ual_is_not_allowed');
  String get ual_no_save_changes => _getLocalizedValue('ual_no_save_changes');
  String get ual_saving => _getLocalizedValue('ual_saving');
  String get ual_save_changes => _getLocalizedValue('ual_save_changes');

  // Profile Screen getters (pro_*)
  String get pro_cancle => _getLocalizedValue('pro_cancle');
  String get pro_unexpected_response =>
      _getLocalizedValue('pro_unexpected_response');
  String get pro_company_representative =>
      _getLocalizedValue('pro_company_representative');
  String get pro_admin => _getLocalizedValue('pro_admin');
  String get pro_installer => _getLocalizedValue('pro_installer');
  String get pro_user => _getLocalizedValue('pro_user');
  String get pro_unexpected_error => _getLocalizedValue('pro_unexpected_error');
  String get pro_no_access => _getLocalizedValue('pro_no_access');
  String get pro_error_fetching_profile =>
      _getLocalizedValue('pro_error_fetching_profile');
  String get pro_error_connecting => _getLocalizedValue('pro_error_connecting');
  String get pro_server_error => _getLocalizedValue('pro_server_error');
  String get pro_server_connection_error =>
      _getLocalizedValue('pro_server_connection_error');
  String get pro_profile_not_found =>
      _getLocalizedValue('pro_profile_not_found');
  String get pro_update_profile_success =>
      _getLocalizedValue('pro_update_profile_success');
  String get pro_update_profile_error =>
      _getLocalizedValue('pro_update_profile_error');
  String get pro_title => _getLocalizedValue('pro_title');
  String get pro_edit_profile => _getLocalizedValue('pro_edit_profile');
  String get pro_name => _getLocalizedValue('pro_name');
  String get pro_last_name => _getLocalizedValue('pro_last_name');
  String get pro_city => _getLocalizedValue('pro_city');
  String get pro_address => _getLocalizedValue('pro_address');
  String get pro_phone => _getLocalizedValue('pro_phone');
  String get pro_email => _getLocalizedValue('pro_email');
  String get pro_save_profile => _getLocalizedValue('pro_save_profile');
  String get pro_save => _getLocalizedValue('pro_save');
  String get pro_loading_profile => _getLocalizedValue('pro_loading_profile');
  String get pro_account_active => _getLocalizedValue('pro_account_active');
  String get pro_account_inactive => _getLocalizedValue('pro_account_inactive');
  String get pro_info_account => _getLocalizedValue('pro_info_account');
  String get pro_name_last_name => _getLocalizedValue('pro_name_last_name');
  String get pro_username => _getLocalizedValue('pro_username');
  String get pro_user_code => _getLocalizedValue('pro_user_code');
  String get pro_organ_name => _getLocalizedValue('pro_organ_name');
  String get pro_allowed_devices_count =>
      _getLocalizedValue('pro_allowed_devices_count');
  String get pro_created_at => _getLocalizedValue('pro_created_at');
  String get pro_level_access => _getLocalizedValue('pro_level_access');
  String get pro_quick_access => _getLocalizedValue('pro_quick_access');
  String get pro_quick_access_description =>
      _getLocalizedValue('pro_quick_access_description');
  String get pro_change_password => _getLocalizedValue('pro_change_password');
  String get pro_notification_settings =>
      _getLocalizedValue('pro_notification_settings');
  String get pro_help => _getLocalizedValue('pro_help');
  String get pro_waiting_for_activation =>
      _getLocalizedValue('pro_waiting_for_activation');
  String get pro_waiting_for_activation_description =>
      _getLocalizedValue('pro_waiting_for_activation_description');
  String get pro_contact_admin => _getLocalizedValue('pro_contact_admin');
  String get pro_contact_admin_button =>
      _getLocalizedValue('pro_contact_admin_button');

  // Ticket List Screen getters (tls_*)
  String get tls_user => _getLocalizedValue('tls_user');
  String get tls_company_representative =>
      _getLocalizedValue('tls_company_representative');
  String get tls_admin => _getLocalizedValue('tls_admin');
  String get tls_installer => _getLocalizedValue('tls_installer');
  String get tls_login_again => _getLocalizedValue('tls_login_again');
  String get tls_unexpected_error => _getLocalizedValue('tls_unexpected_error');
  String get tls_no_access => _getLocalizedValue('tls_no_access');
  String get tls_error_fetching_tickets =>
      _getLocalizedValue('tls_error_fetching_tickets');
  String get tls_error_connecting => _getLocalizedValue('tls_error_connecting');
  String get tls_unknown => _getLocalizedValue('tls_unknown');
  String get tls_title => _getLocalizedValue('tls_title');
  String get tls_new_ticket => _getLocalizedValue('tls_new_ticket');
  String get tls_loading => _getLocalizedValue('tls_loading');
  String get tls_error_loading => _getLocalizedValue('tls_error_loading');
  String get tls_try_again => _getLocalizedValue('tls_try_again');
  String get tls_no_tickets => _getLocalizedValue('tls_no_tickets');
  String get tls_send_new_hint => _getLocalizedValue('tls_send_new_hint');
  String get tls_waiting_for_activation =>
      _getLocalizedValue('tls_waiting_for_activation');
  String get tls_waiting_for_activation_description =>
      _getLocalizedValue('tls_waiting_for_activation_description');
  String get tls_contact_admin => _getLocalizedValue('tls_contact_admin');
  String get tls_contact_admin_button =>
      _getLocalizedValue('tls_contact_admin_button');

  // Ticket Detail Screen getters (tds_*)
  String get tds_login_again => _getLocalizedValue('tds_login_again');
  String get tds_error_no_ticket => _getLocalizedValue('tds_error_no_ticket');
  String get tds_error_details => _getLocalizedValue('tds_error_details');
  String get tds_error_connecting => _getLocalizedValue('tds_error_connecting');
  String get tds_unknown => _getLocalizedValue('tds_unknown');
  String get tds_title => _getLocalizedValue('tds_title');
  String get tds_loading => _getLocalizedValue('tds_loading');
  String get tds_try_again => _getLocalizedValue('tds_try_again');
  String get tds_waiting_for_reply =>
      _getLocalizedValue('tds_waiting_for_reply');
  String get tds_replied => _getLocalizedValue('tds_replied');
  String get tds_content_message => _getLocalizedValue('tds_content_message');
  String get tds_replies => _getLocalizedValue('tds_replies');
  String get tds_support => _getLocalizedValue('tds_support');
  String get tds_reply_label => _getLocalizedValue('tds_reply_label');
  String get tds_show_soon => _getLocalizedValue('tds_show_soon');
  String get tds_waiting_for_reply_support =>
      _getLocalizedValue('tds_waiting_for_reply_support');
  String get tds_reply_soon => _getLocalizedValue('tds_reply_soon');

  // Home Screen getters (home_*)
  String get home_access_denies => _getLocalizedValue('home_access_denies');
  String get home_logout => _getLocalizedValue('home_logout');
  String get home_logout_confirm => _getLocalizedValue('home_logout_confirm');
  String get home_yes => _getLocalizedValue('home_yes');
  String get home_no => _getLocalizedValue('home_no');
  String get home_company_representative =>
      _getLocalizedValue('home_company_representative');
  String get home_installer => _getLocalizedValue('home_installer');
  String get home_user => _getLocalizedValue('home_user');
  String get home_admin => _getLocalizedValue('home_admin');
  String get home_loading => _getLocalizedValue('home_loading');
  String get home_active_devices => _getLocalizedValue('home_active_devices');
  String get home_active_users => _getLocalizedValue('home_active_users');
  String get home_pending_missions =>
      _getLocalizedValue('home_pending_missions');
  String get home_device_list => _getLocalizedValue('home_device_list');
  String get home_device_list_description =>
      _getLocalizedValue('home_device_list_description');
  String get home_user_list => _getLocalizedValue('home_user_list');
  String get home_user_list_description =>
      _getLocalizedValue('home_user_list_description');
  String get home_reports => _getLocalizedValue('home_reports');
  String get home_reports_description =>
      _getLocalizedValue('home_reports_description');
  String get home_settings => _getLocalizedValue('home_settings');
  String get home_settings_description =>
      _getLocalizedValue('home_settings_description');
  String get home_account_pending => _getLocalizedValue('home_account_pending');
  String get home_account_pending_description =>
      _getLocalizedValue('home_account_pending_description');
  String get home_contact_admin => _getLocalizedValue('home_contact_admin');
  String get home_contact_admin_button =>
      _getLocalizedValue('home_contact_admin_button');

  // Login Screen getters (login_*)
  String get login_error_username => _getLocalizedValue('login_error_username');
  String get login_error => _getLocalizedValue('login_error');
  String get login_error_connecting =>
      _getLocalizedValue('login_error_connecting');
  String get login_no_authentication =>
      _getLocalizedValue('login_no_authentication');
  String get login_with_username_and_Password =>
      _getLocalizedValue('login_with_username_and_Password');
  String get login_authentication => _getLocalizedValue('login_authentication');
  String get login_account => _getLocalizedValue('login_account');
  String get login_cancle => _getLocalizedValue('login_cancle');
  String get login_add_finger => _getLocalizedValue('login_add_finger');
  String get login_no_access_fingerprint =>
      _getLocalizedValue('login_no_access_fingerprint');
  String get login_need_authentication =>
      _getLocalizedValue('login_need_authentication');
  String get login_need_lock => _getLocalizedValue('login_need_lock');
  String get login_active_lock => _getLocalizedValue('login_active_lock');
  String get login_settings => _getLocalizedValue('login_settings');
  String get login_error_fingerprint =>
      _getLocalizedValue('login_error_fingerprint');
  String get login_biometric => _getLocalizedValue('login_biometric');
  String get login_login_first => _getLocalizedValue('login_login_first');
  String get login_fingerprint_not_available =>
      _getLocalizedValue('login_fingerprint_not_available');
  String get login_fingerprint_not_enrolled =>
      _getLocalizedValue('login_fingerprint_not_enrolled');
  String get login_fingerprint_not_set =>
      _getLocalizedValue('login_fingerprint_not_set');
  String get login_fingerprint_locked_out =>
      _getLocalizedValue('login_fingerprint_locked_out');
  String get login_fingerprint_permanently_locked_out =>
      _getLocalizedValue('login_fingerprint_permanently_locked_out');
  String get login_fingerprint_error =>
      _getLocalizedValue('login_fingerprint_error');
  String get login_username => _getLocalizedValue('login_username');
  String get login_password => _getLocalizedValue('login_password');
  String get login_remember_me => _getLocalizedValue('login_remember_me');
  String get login => _getLocalizedValue('login');
  String get login_user_register => _getLocalizedValue('login_user_register');
  String get login_admin_register => _getLocalizedValue('login_admin_register');

  // Registration Forms getters (reg_*)
  String get reg_user_register => _getLocalizedValue('reg_user_register');
  String get reg_admin_register => _getLocalizedValue('reg_admin_register');
  String get reg_org_code => _getLocalizedValue('reg_org_code');
  String get reg_admin_code => _getLocalizedValue('reg_admin_code');
  String get reg_send_otp => _getLocalizedValue('reg_send_otp');
  String get reg_verify_code => _getLocalizedValue('reg_verify_code');
  String get reg_name => _getLocalizedValue('reg_name');
  String get reg_password => _getLocalizedValue('reg_password');
  String get reg_phone => _getLocalizedValue('reg_phone');
  String get reg_phone_completely => _getLocalizedValue('reg_phone_completely');
  String get reg_phone_98 => _getLocalizedValue('reg_phone_98');
  String get reg_attention_admin => _getLocalizedValue('reg_attention_admin');
  String get reg_attention_org => _getLocalizedValue('reg_attention_org');
  String get reg_login => _getLocalizedValue('reg_login');
  String get reg_login_before => _getLocalizedValue('reg_login_before');

  // OTP Verify Pass Screen getters (otpverifypass_*)
  String get otpverifypass_success_title =>
      _getLocalizedValue('otpverifypass_success_title');
  String get otpverifypass_success_content =>
      _getLocalizedValue('otpverifypass_success_content');
  String get otpverifypass_success_button =>
      _getLocalizedValue('otpverifypass_success_button');
  String get otpverifypass_error_not_correct =>
      _getLocalizedValue('otpverifypass_error_not_correct');
  String get otpverifypass_error_connecting =>
      _getLocalizedValue('otpverifypass_error_connecting');
  String get otpverifypass_send_new_code =>
      _getLocalizedValue('otpverifypass_send_new_code');
  String get otpverifypass_error_sending_again =>
      _getLocalizedValue('otpverifypass_error_sending_again');
  String get otpverifypass_submit_code =>
      _getLocalizedValue('otpverifypass_submit_code');
  String get otpverifypass_type_code =>
      _getLocalizedValue('otpverifypass_type_code');
  String get otpverifypass_otp_code =>
      _getLocalizedValue('otpverifypass_otp_code');
  String get otpverifypass_remaining_time =>
      _getLocalizedValue('otpverifypass_remaining_time');
  String get otpverifypass_resend_code =>
      _getLocalizedValue('otpverifypass_resend_code');
  String get otpverifypass_submit => _getLocalizedValue('otpverifypass_submit');

  // OTP Verify Screen getters (otpverify_*)
  String get otpverify_error_not_correct =>
      _getLocalizedValue('otpverify_error_not_correct');
  String get otpverify_error_unsuccessful_login =>
      _getLocalizedValue('otpverify_error_unsuccessful_login');
  String get otpverify_error_connecting =>
      _getLocalizedValue('otpverify_error_connecting');
  String get otpverify_error_submit_otp =>
      _getLocalizedValue('otpverify_error_submit_otp');
  String get otpverify_send_new_code =>
      _getLocalizedValue('otpverify_send_new_code');
  String get otpverify_error_sending_again =>
      _getLocalizedValue('otpverify_error_sending_again');
  String get otpverify_submit_code =>
      _getLocalizedValue('otpverify_submit_code');
  String get otpverify_send_code_content_1 =>
      _getLocalizedValue('otpverify_send_code_content_1');
  String get otpverify_send_code_content_2 =>
      _getLocalizedValue('otpverify_send_code_content_2');
  String get otpverify_otp_code => _getLocalizedValue('otpverify_otp_code');
  String get otpverify_remaining_time =>
      _getLocalizedValue('otpverify_remaining_time');
  String get otpverify_resend_code =>
      _getLocalizedValue('otpverify_resend_code');
  String get otpverify_submit => _getLocalizedValue('otpverify_submit');

  // Send Service Screen getters (sss_*)
  String get sss_half_hour => _getLocalizedValue('sss_half_hour');
  String get sss_one_hour => _getLocalizedValue('sss_one_hour');
  String get sss_two_hour => _getLocalizedValue('sss_two_hour');
  String get sss_three_hour => _getLocalizedValue('sss_three_hour');
  String get sss_four_hour => _getLocalizedValue('sss_four_hour');
  String get sss_five_hour => _getLocalizedValue('sss_five_hour');
  String get sss_six_hour => _getLocalizedValue('sss_six_hour');
  String get sss_seven_hour => _getLocalizedValue('sss_seven_hour');
  String get sss_eight_hour => _getLocalizedValue('sss_eight_hour');
  String get sss_nine_hour => _getLocalizedValue('sss_nine_hour');
  String get sss_ten_hour => _getLocalizedValue('sss_ten_hour');
  String get sss_add_required => _getLocalizedValue('sss_add_required');
  String get sss_successfully => _getLocalizedValue('sss_successfully');
  String get sss_submit_successfully =>
      _getLocalizedValue('sss_submit_successfully');
  String get sss_total_cost => _getLocalizedValue('sss_total_cost');
  String get sss_tooman => _getLocalizedValue('sss_tooman');
  String get sss_ok => _getLocalizedValue('sss_ok');
  String get sss_error_send_request =>
      _getLocalizedValue('sss_error_send_request');
  String get sss_error_connecting => _getLocalizedValue('sss_error_connecting');
  String get sss_send_service_request =>
      _getLocalizedValue('sss_send_service_request');
  String get sss_send_service_request_form =>
      _getLocalizedValue('sss_send_service_request_form');
  String get sss_send_service_request_form_title =>
      _getLocalizedValue('sss_send_service_request_form_title');
  String get sss_send_service_request_form_title_hint =>
      _getLocalizedValue('sss_send_service_request_form_title_hint');
  String get sss_add_service_request_title_error =>
      _getLocalizedValue('sss_add_service_request_title_error');
  String get sss_send_service_request_form_description =>
      _getLocalizedValue('sss_send_service_request_form_description');
  String get sss_send_service_request_form_description_hint =>
      _getLocalizedValue('sss_send_service_request_form_description_hint');
  String get sss_add_service_request_description_error =>
      _getLocalizedValue('sss_add_service_request_description_error');
  String get sss_add_service_request_piece =>
      _getLocalizedValue('sss_add_service_request_piece');
  String get sss_choose_service_request_piece_hint =>
      _getLocalizedValue('sss_choose_service_request_piece_hint');
  String get sss_add_service_request_piece_error =>
      _getLocalizedValue('sss_add_service_request_piece_error');
  String get sss_add_service_request_time =>
      _getLocalizedValue('sss_add_service_request_time');
  String get sss_add_service_request_time_hint =>
      _getLocalizedValue('sss_add_service_request_time_hint');
  String get sss_add_service_request_time_error =>
      _getLocalizedValue('sss_add_service_request_time_error');
  String get sss_other_costs => _getLocalizedValue('sss_other_costs');
  String get sss_other_costs_hint => _getLocalizedValue('sss_other_costs_hint');
  String get sss_other_costs_error =>
      _getLocalizedValue('sss_other_costs_error');
  String get sss_other_costs_error_number =>
      _getLocalizedValue('sss_other_costs_error_number');
  String get sss_send_service_request_form_submit =>
      _getLocalizedValue('sss_send_service_request_form_submit');
  String get sss_loading_sending => _getLocalizedValue('sss_loading_sending');
  String get sss_address => _getLocalizedValue('sss_address');
  String get sss_address_hint => _getLocalizedValue('sss_address_hint');
  String get sss_address_error => _getLocalizedValue('sss_address_error');
  String get sss_phone => _getLocalizedValue('sss_phone');
  String get sss_phone_hint => _getLocalizedValue('sss_phone_hint');
  String get sss_phone_error => _getLocalizedValue('sss_phone_error');
  String get sss_urgency => _getLocalizedValue('sss_urgency');
  String get sss_urgency_hint => _getLocalizedValue('sss_urgency_hint');
  String get sss_urgency_error => _getLocalizedValue('sss_urgency_error');
  String get sss_urgency_normal => _getLocalizedValue('sss_urgency_normal');
  String get sss_urgency_urgent => _getLocalizedValue('sss_urgency_urgent');
  String get sss_urgency_very_urgent =>
      _getLocalizedValue('sss_urgency_very_urgent');

  // Service List Screen getters (sls_*)
  String get sls_error_connecting => _getLocalizedValue('sls_error_connecting');
  String get sls_error_fetching_services =>
      _getLocalizedValue('sls_error_fetching_services');
  String get sls_error_fetching_services_status_code_403 =>
      _getLocalizedValue('sls_error_fetching_services_status_code_403');
  String get sls_request_service => _getLocalizedValue('sls_request_service');
  String get sls_request => _getLocalizedValue('sls_request');
  String get sls_new => _getLocalizedValue('sls_new');
  String get sls_loading => _getLocalizedValue('sls_loading');
  String get sls_description => _getLocalizedValue('sls_description');
  String get sls_need_piece => _getLocalizedValue('sls_need_piece');
  String get sls_all_cost => _getLocalizedValue('sls_all_cost');
  String get sls_tooman => _getLocalizedValue('sls_tooman');
  String get sls_date_register => _getLocalizedValue('sls_date_register');
  String get sls_no_request => _getLocalizedValue('sls_no_request');
  String get sls_no_request_description =>
      _getLocalizedValue('sls_no_request_description');

  // Service Provider Services Screen getters (sps_*)
  String get sps_services => _getLocalizedValue('sps_services');
  String get sps_pending_services => _getLocalizedValue('sps_pending_services');
  String get sps_completed_services =>
      _getLocalizedValue('sps_completed_services');
  String get sps_no_pending_services =>
      _getLocalizedValue('sps_no_pending_services');
  String get sps_no_pending_services_description =>
      _getLocalizedValue('sps_no_pending_services_description');
  String get sps_no_completed_services =>
      _getLocalizedValue('sps_no_completed_services');
  String get sps_no_completed_services_description =>
      _getLocalizedValue('sps_no_completed_services_description');
  String get sps_status_open => _getLocalizedValue('sps_status_open');
  String get sps_status_assigned => _getLocalizedValue('sps_status_assigned');
  String get sps_status_confirm => _getLocalizedValue('sps_status_confirm');
  String get sps_status_done => _getLocalizedValue('sps_status_done');
  String get sps_status_canceled => _getLocalizedValue('sps_status_canceled');
  String get sps_technician => _getLocalizedValue('sps_technician');
  String get sps_technician_name => _getLocalizedValue('sps_technician_name');
  String get sps_technician_phone => _getLocalizedValue('sps_technician_phone');
  String get sps_technician_grade => _getLocalizedValue('sps_technician_grade');
  String get sps_service_grade => _getLocalizedValue('sps_service_grade');
  String get sps_ratings => _getLocalizedValue('sps_ratings');
  String get sps_no_rating => _getLocalizedValue('sps_no_rating');
  String get sps_service_details => _getLocalizedValue('sps_service_details');
  String get sps_piece_code => _getLocalizedValue('sps_piece_code');
  String get sps_piece_price => _getLocalizedValue('sps_piece_price');
  String get sps_cost_info => _getLocalizedValue('sps_cost_info');
  String get sps_piece_cost => _getLocalizedValue('sps_piece_cost');
  String get sps_other_costs => _getLocalizedValue('sps_other_costs');
  String get sps_time_required => _getLocalizedValue('sps_time_required');
  String get sps_minutes => _getLocalizedValue('sps_minutes');
  String get sps_confirm_completion =>
      _getLocalizedValue('sps_confirm_completion');
  String get sps_rating_dialog_title =>
      _getLocalizedValue('sps_rating_dialog_title');
  String get sps_select_rating => _getLocalizedValue('sps_select_rating');
  String get sps_comment => _getLocalizedValue('sps_comment');
  String get sps_comment_hint => _getLocalizedValue('sps_comment_hint');
  String get sps_confirm_button => _getLocalizedValue('sps_confirm_button');
  String get sps_rating_required => _getLocalizedValue('sps_rating_required');
  String get sps_confirming => _getLocalizedValue('sps_confirming');
  String get sps_confirmation_success =>
      _getLocalizedValue('sps_confirmation_success');
  String get sps_confirmation_error =>
      _getLocalizedValue('sps_confirmation_error');

  // Technician Screen getters (tech_*)
  String get tech_missions => _getLocalizedValue('tech_missions');
  String get tech_no_missions => _getLocalizedValue('tech_no_missions');
  String get tech_no_missions_description =>
      _getLocalizedValue('tech_no_missions_description');
  String get tech_task_details => _getLocalizedValue('tech_task_details');
  String get tech_price => _getLocalizedValue('tech_price');
  String get tech_location => _getLocalizedValue('tech_location');
  String get tech_organ_name => _getLocalizedValue('tech_organ_name');
  String get tech_address => _getLocalizedValue('tech_address');
  String get tech_city => _getLocalizedValue('tech_city');
  String get tech_phone => _getLocalizedValue('tech_phone');
  String get tech_confirm_task => _getLocalizedValue('tech_confirm_task');
  String get tech_confirmation_success =>
      _getLocalizedValue('tech_confirmation_success');
  String get tech_confirmation_error =>
      _getLocalizedValue('tech_confirmation_error');
  String get tech_no_completed_tasks =>
      _getLocalizedValue('tech_no_completed_tasks');
  String get tech_no_completed_tasks_description =>
      _getLocalizedValue('tech_no_completed_tasks_description');
  String get tech_first_visit_date =>
      _getLocalizedValue('tech_first_visit_date');
  String get tech_first_visit_date_hint =>
      _getLocalizedValue('tech_first_visit_date_hint');
  String get tech_first_visit_date_error =>
      _getLocalizedValue('tech_first_visit_date_error');
  String get tech_set_first_visit => _getLocalizedValue('tech_set_first_visit');
  String get tech_first_visit_success =>
      _getLocalizedValue('tech_first_visit_success');
  String get tech_check_task => _getLocalizedValue('tech_check_task');
  String get tech_piece_name => _getLocalizedValue('tech_piece_name');
  String get tech_piece_name_hint => _getLocalizedValue('tech_piece_name_hint');
  String get tech_piece_name_error =>
      _getLocalizedValue('tech_piece_name_error');
  String get tech_time_required => _getLocalizedValue('tech_time_required');
  String get tech_time_required_hint =>
      _getLocalizedValue('tech_time_required_hint');
  String get tech_time_required_error =>
      _getLocalizedValue('tech_time_required_error');
  String get tech_other_costs => _getLocalizedValue('tech_other_costs');
  String get tech_other_costs_hint =>
      _getLocalizedValue('tech_other_costs_hint');
  String get tech_other_costs_error =>
      _getLocalizedValue('tech_other_costs_error');
  String get tech_second_visit_date =>
      _getLocalizedValue('tech_second_visit_date');
  String get tech_second_visit_date_hint =>
      _getLocalizedValue('tech_second_visit_date_hint');
  String get tech_submit_check_task =>
      _getLocalizedValue('tech_submit_check_task');
  String get tech_check_task_success =>
      _getLocalizedValue('tech_check_task_success');
  String get tech_check_task_error =>
      _getLocalizedValue('tech_check_task_error');
  String get tech_report => _getLocalizedValue('tech_report');
  String get tech_report_hint => _getLocalizedValue('tech_report_hint');
  String get tech_report_error => _getLocalizedValue('tech_report_error');
  String get tech_submit_report => _getLocalizedValue('tech_submit_report');
  String get tech_urgency => _getLocalizedValue('tech_urgency');
  String get tech_urgency_normal => _getLocalizedValue('tech_urgency_normal');
  String get tech_urgency_urgent => _getLocalizedValue('tech_urgency_urgent');
  String get tech_urgency_very_urgent =>
      _getLocalizedValue('tech_urgency_very_urgent');

  // Splash Screen getters (splash_*)
  String get splash_authentication_login =>
      _getLocalizedValue('splash_authentication_login');
  String get splash_version => _getLocalizedValue('splash_version');

  // Shared Drawer getters (shareddrawer_*)
  String get shareddrawer_logout => _getLocalizedValue('shareddrawer_logout');
  String get shareddrawer_logout_confirm =>
      _getLocalizedValue('shareddrawer_logout_confirm');
  String get shareddrawer_no => _getLocalizedValue('shareddrawer_no');
  String get shareddrawer_yes => _getLocalizedValue('shareddrawer_yes');
  String get shareddrawer_level_user =>
      _getLocalizedValue('shareddrawer_level_user');
  String get shareddrawer_home => _getLocalizedValue('shareddrawer_home');
  String get shareddrawer_refresh_data =>
      _getLocalizedValue('shareddrawer_refresh_data');
  String get shareddrawer_change_password =>
      _getLocalizedValue('shareddrawer_change_password');
  String get shareddrawer_help => _getLocalizedValue('shareddrawer_help');
  String get shareddrawer_about => _getLocalizedValue('shareddrawer_about');
  String get shareddrawer_support => _getLocalizedValue('shareddrawer_support');
  String get shareddrawer_services =>
      _getLocalizedValue('shareddrawer_services');
  String get shareddrawer_wifi_config =>
      _getLocalizedValue('shareddrawer_wifi_config');

  // Ticket Card getters (ticketcard_*)
  String get ticketcard_unknown => _getLocalizedValue('ticketcard_unknown');
  String get ticketcard_waiting_response =>
      _getLocalizedValue('ticketcard_waiting_response');
  String get ticketcard_answered => _getLocalizedValue('ticketcard_answered');
  String get ticketcard_date_send => _getLocalizedValue('ticketcard_date_send');
  String get ticketcard_view_details =>
      _getLocalizedValue('ticketcard_view_details');

  // About screen getters
  String get about_title => _getLocalizedValue('about_title');
  String get about_uzita_title => _getLocalizedValue('about_uzita_title');
  String get about_uzita_company => _getLocalizedValue('about_uzita_company');
  String get about_uzita_description =>
      _getLocalizedValue('about_uzita_description');
  String get about_uzita_introduction_title =>
      _getLocalizedValue('about_uzita_introduction_title');
  String get about_uzita_introduction_body =>
      _getLocalizedValue('about_uzita_introduction_body');
  String get about_uzita_mission_title =>
      _getLocalizedValue('about_uzita_mission_title');
  String get about_uzita_mission_body =>
      _getLocalizedValue('about_uzita_mission_body');
  String get about_uzita_auto_doors_title =>
      _getLocalizedValue('about_uzita_auto_doors_title');
  String get about_uzita_gate_title =>
      _getLocalizedValue('about_uzita_gate_title');
  String get about_uzita_automatic_curtain_title =>
      _getLocalizedValue('about_uzita_automatic_curtain_title');
  String get about_uzita_smart_lock_title =>
      _getLocalizedValue('about_uzita_smart_lock_title');
  String get about_uzita_vision_title =>
      _getLocalizedValue('about_uzita_vision_title');
  String get about_uzita_vision_body =>
      _getLocalizedValue('about_uzita_vision_body');
  String get about_uzita_core_values_title =>
      _getLocalizedValue('about_uzita_core_values_title');
  String get about_uzita_core_values_body =>
      _getLocalizedValue('about_uzita_core_values_body');
  String get about_uzita_core_values_bullet_1 =>
      _getLocalizedValue('about_uzita_core_values_bullet_1');
  String get about_uzita_core_values_bullet_2 =>
      _getLocalizedValue('about_uzita_core_values_bullet_2');
  String get about_uzita_core_values_bullet_3 =>
      _getLocalizedValue('about_uzita_core_values_bullet_3');
  String get about_uzita_core_values_bullet_4 =>
      _getLocalizedValue('about_uzita_core_values_bullet_4');
  String get about_uzita_contact_title =>
      _getLocalizedValue('about_uzita_contact_title');
  String get about_uzita_contact_phone =>
      _getLocalizedValue('about_uzita_contact_phone');
  String get about_uzita_contact_email =>
      _getLocalizedValue('about_uzita_contact_email');
  String get about_uzita_contact_address =>
      _getLocalizedValue('about_uzita_contact_address');

  // Command List Screen getters (cls_*)
  String get cls_user => _getLocalizedValue('cls_user');
  String get cls_company_representative =>
      _getLocalizedValue('cls_company_representative');
  String get cls_admin => _getLocalizedValue('cls_admin');
  String get cls_installer => _getLocalizedValue('cls_installer');
  String get cls_regular_user => _getLocalizedValue('cls_regular_user');
  String get cls_error_fetching_commands =>
      _getLocalizedValue('cls_error_fetching_commands');
  String get cls_error_connecting => _getLocalizedValue('cls_error_connecting');
  String get cls_error_address => _getLocalizedValue('cls_error_address');
  String get cls_unexpected_error => _getLocalizedValue('cls_unexpected_error');
  String get cls_filtering_search => _getLocalizedValue('cls_filtering_search');
  String get cls_command => _getLocalizedValue('cls_command');
  String get cls_device => _getLocalizedValue('cls_device');
  String get cls_no_commands => _getLocalizedValue('cls_no_commands');
  String get cls_no_commands_description =>
      _getLocalizedValue('cls_no_commands_description');
  String get cls_loading_more => _getLocalizedValue('cls_loading_more');
  String get cls_loading => _getLocalizedValue('cls_loading');
  String get cls_filter_reports => _getLocalizedValue('cls_filter_reports');
  String get cls_name_device => _getLocalizedValue('cls_name_device');
  String get cls_username => _getLocalizedValue('cls_username');
  String get cls_choosing_date => _getLocalizedValue('cls_choosing_date');
  String get cls_choosed_date => _getLocalizedValue('cls_choosed_date');
  String get cls_clear => _getLocalizedValue('cls_clear');
  String get cls_apply_filter => _getLocalizedValue('cls_apply_filter');
  String get cls_select_date_shamsi =>
      _getLocalizedValue('cls_select_date_shamsi');
  String get cls_cancel => _getLocalizedValue('cls_cancel');
  String get cls_submit => _getLocalizedValue('cls_submit');
  String get cls_title => _getLocalizedValue('cls_title');
  String get cls_commands => _getLocalizedValue('cls_commands');
  String get cls_observe => _getLocalizedValue('cls_observe');
  String get cls_loading_reports => _getLocalizedValue('cls_loading_reports');
  String get cls_waiting_for_activation =>
      _getLocalizedValue('cls_waiting_for_activation');
  String get cls_waiting_for_activation_description =>
      _getLocalizedValue('cls_waiting_for_activation_description');
  String get cls_contact_admin => _getLocalizedValue('cls_contact_admin');
  String get cls_contact_admin_button =>
      _getLocalizedValue('cls_contact_admin_button');
  String get cls_command_code => _getLocalizedValue('cls_command_code');
  String get cls_date => _getLocalizedValue('cls_date');

  // Create Ticket Screen getters (ct_*)
  String get ct_waiting_response_error =>
      _getLocalizedValue('ct_waiting_response_error');
  String get ct_add_required => _getLocalizedValue('ct_add_required');
  String get ct_try_again_error => _getLocalizedValue('ct_try_again_error');
  String get ct_add_required_correctly =>
      _getLocalizedValue('ct_add_required_correctly');
  String get ct_login_again => _getLocalizedValue('ct_login_again');
  String get ct_send_ticket_successfully =>
      _getLocalizedValue('ct_send_ticket_successfully');
  String get ct_submit_ticket_successfully =>
      _getLocalizedValue('ct_submit_ticket_successfully');
  String get ct_error_add_ticket => _getLocalizedValue('ct_error_add_ticket');
  String get ct_error_connecting => _getLocalizedValue('ct_error_connecting');
  String get ct_I_got_it => _getLocalizedValue('ct_I_got_it');
  String get ct_send_submit => _getLocalizedValue('ct_send_submit');
  String get ct_are_you_sure => _getLocalizedValue('ct_are_you_sure');
  String get ct_cancle => _getLocalizedValue('ct_cancle');
  String get ct_send => _getLocalizedValue('ct_send');
  String get ct_send_new_ticket => _getLocalizedValue('ct_send_new_ticket');
  String get ct_information => _getLocalizedValue('ct_information');
  String get ct_information_description =>
      _getLocalizedValue('ct_information_description');
  String get ct_title => _getLocalizedValue('ct_title');
  String get ct_title_example => _getLocalizedValue('ct_title_example');
  String get ct_title_required => _getLocalizedValue('ct_title_required');
  String get ct_max_part_1 => _getLocalizedValue('ct_max_part_1');
  String get ct_max_part_2 => _getLocalizedValue('ct_max_part_2');
  String get ct_description_ticket =>
      _getLocalizedValue('ct_description_ticket');
  String get ct_description_ticket_hint =>
      _getLocalizedValue('ct_description_ticket_hint');
  String get ct_description_max_length =>
      _getLocalizedValue('ct_description_max_length');
  String get ct_description_max_part_2 =>
      _getLocalizedValue('ct_description_max_part_2');
  String get ct_description_ticket_required =>
      _getLocalizedValue('ct_description_ticket_required');
  String get ct_description_ticket_min_length =>
      _getLocalizedValue('ct_description_ticket_min_length');
  String get ct_loading_sending => _getLocalizedValue('ct_loading_sending');
  String get ct_send_ticket => _getLocalizedValue('ct_send_ticket');
  String get ct_important_notes => _getLocalizedValue('ct_important_notes');
  String get ct_important_notes_part_1 =>
      _getLocalizedValue('ct_important_notes_part_1');
  String get ct_important_notes_part_2 =>
      _getLocalizedValue('ct_important_notes_part_2');
  String get ct_important_notes_part_3 =>
      _getLocalizedValue('ct_important_notes_part_3');

  // Alias getters mapping to existing keys (no text changes)
  // Device List aliases
  String get dls_device_added => _getLocalizedValue('dls_add_device');
  String get dls_camera_permission_denied =>
      _getLocalizedValue('dls_scan_error_description');
  String get dls_camera_permission_denied_description =>
      _getLocalizedValue('dls_scan_error_description');
  String get dls_settings => _getLocalizedValue('dls_scan_settings');
  String get dls_please_wait => _getLocalizedValue('dls_wait');
  String get dls_devices_awaiting_activation =>
      _getLocalizedValue('dls_waiting_for_activation');
  String get dls_devices_awaiting_activation_description =>
      _getLocalizedValue('dls_waiting_for_activation_description');

  // Help aliases
  String get help_report_title => _getLocalizedValue('help_reports_title');
  String get help_report_body => _getLocalizedValue('help_reports_body');
  String get help_report_bullet_1 =>
      _getLocalizedValue('help_reports_bullet_1');
  String get help_report_bullet_2 =>
      _getLocalizedValue('help_reports_bullet_2');
  String get help_report_bullet_3 =>
      _getLocalizedValue('help_reports_bullet_3');
  String get help_user_level_title =>
      _getLocalizedValue('help_user_levels_title');
  String get help_user_level_body =>
      _getLocalizedValue('help_user_levels_body');
  String get help_user_profile_title =>
      _getLocalizedValue('help_profile_title');
  String get help_user_profile_body => _getLocalizedValue('help_profile_body');
  String get help_device_service_title =>
      _getLocalizedValue('help_service_request_title');
  String get help_device_service_body =>
      _getLocalizedValue('help_service_request_body');
  // Map grouped bullets to existing grouped strings
  String get help_company_rep_title =>
      _getLocalizedValue('help_company_rep_title');
  String get help_company_rep_bullet_1 =>
      _getLocalizedValue('help_company_rep_bullet_1');
  String get help_company_rep_bullet_2 =>
      _getLocalizedValue('help_company_rep_bullet_2');
  String get help_company_rep_bullet_3 =>
      _getLocalizedValue('help_company_rep_bullet_3');
  String get help_company_rep_bullet_4 =>
      _getLocalizedValue('help_company_rep_bullet_4');
  String get help_company_rep_bullet_5 =>
      _getLocalizedValue('help_company_rep_bullet_5');
  String get help_company_rep_bullet_6 =>
      _getLocalizedValue('help_company_rep_bullet_6');
  String get help_company_rep_bullet_7 =>
      _getLocalizedValue('help_company_rep_bullet_7');
  String get help_company_rep_bullet_8 =>
      _getLocalizedValue('help_company_rep_bullet_8');
  String get help_user_level_title_2 => _getLocalizedValue('help_admin_title');
  String get help_admin_bullet_1 => _getLocalizedValue('help_admin_bullet_1');
  String get help_admin_bullet_2 => _getLocalizedValue('help_admin_bullet_2');
  String get help_admin_bullet_3 => _getLocalizedValue('help_admin_bullet_3');
  String get help_admin_bullet_4 => _getLocalizedValue('help_admin_bullet_4');
  String get help_admin_bullet_5 => _getLocalizedValue('help_admin_bullet_5');
  String get help_admin_bullet_6 => _getLocalizedValue('help_admin_bullet_6');
  String get help_admin_bullet_7 => _getLocalizedValue('help_admin_bullet_7');
  String get help_installer_title => _getLocalizedValue('help_installer_title');
  String get help_installer_bullet_1 =>
      _getLocalizedValue('help_installer_bullet_1');
  String get help_installer_bullet_2 =>
      _getLocalizedValue('help_installer_bullet_2');
  String get help_installer_bullet_3 =>
      _getLocalizedValue('help_installer_bullet_3');
  String get help_installer_bullet_4 =>
      _getLocalizedValue('help_installer_bullet_4');
  String get help_installer_bullet_5 =>
      _getLocalizedValue('help_installer_bullet_5');
  String get help_regular_user_title =>
      _getLocalizedValue('help_regular_user_title');
  String get help_regular_user_bullet_1 =>
      _getLocalizedValue('help_regular_user_bullet_1');
  String get help_regular_user_bullet_2 =>
      _getLocalizedValue('help_regular_user_bullet_2');
  String get help_regular_user_bullet_3 =>
      _getLocalizedValue('help_regular_user_bullet_3');
  String get help_regular_user_bullet_4 =>
      _getLocalizedValue('help_regular_user_bullet_4');
  // Device List Screen getters (dls_*)
  String get dls_title => _getLocalizedValue('dls_title');
  String get dls_add_device => _getLocalizedValue('dls_add_device');
  String get dls_devices_header => _getLocalizedValue('dls_devices_header');
  String get dls_count_suffix => _getLocalizedValue('dls_count_suffix');
  String get dls_manage => _getLocalizedValue('dls_manage');
  String get dls_retry => _getLocalizedValue('dls_retry');
  String get dls_local_error => _getLocalizedValue('dls_local_error');
  String get dls_error => _getLocalizedValue('dls_error');
  String get dls_error_connecting => _getLocalizedValue('dls_error_connecting');
  String get dls_name_device => _getLocalizedValue('dls_name_device');
  String get dls_name_error => _getLocalizedValue('dls_name_error');
  String get dls_serial_number => _getLocalizedValue('dls_serial_number');
  String get dls_serial_number_error =>
      _getLocalizedValue('dls_serial_number_error');
  String get dls_token => _getLocalizedValue('dls_token');
  String get dls_copy => _getLocalizedValue('dls_copy');
  String get dls_copy_success => _getLocalizedValue('dls_copy_success');
  String get dls_note_token => _getLocalizedValue('dls_note_token');
  String get dls_cancel => _getLocalizedValue('dls_cancel');
  String get dls_close => _getLocalizedValue('dls_close');
  String get dls_submit => _getLocalizedValue('dls_submit');
  String get dls_submitting => _getLocalizedValue('dls_submitting');
  String get dls_no_access => _getLocalizedValue('dls_no_access');
  String get dls_error_fetching_devices =>
      _getLocalizedValue('dls_error_fetching_devices');
  String get dls_unknown => _getLocalizedValue('dls_unknown');
  String get dls_active => _getLocalizedValue('dls_active');
  String get dls_inactive => _getLocalizedValue('dls_inactive');
  String get dls_maintenance => _getLocalizedValue('dls_maintenance');
  String get dls_no_devices => _getLocalizedValue('dls_no_devices');
  String get dls_no_devices_description =>
      _getLocalizedValue('dls_no_devices_description');
  String get dls_user => _getLocalizedValue('dls_user');
  String get dls_company_representative =>
      _getLocalizedValue('dls_company_representative');
  String get dls_admin => _getLocalizedValue('dls_admin');
  String get dls_installer => _getLocalizedValue('dls_installer');
  String get dls_regular_user => _getLocalizedValue('dls_regular_user');
  String get dls_loading_devices => _getLocalizedValue('dls_loading_devices');
  String get dls_wait => _getLocalizedValue('dls_wait');
  String get dls_waiting_for_activation =>
      _getLocalizedValue('dls_waiting_for_activation');
  String get dls_waiting_for_activation_description =>
      _getLocalizedValue('dls_waiting_for_activation_description');
  String get dls_contact_admin => _getLocalizedValue('dls_contact_admin');
  String get dls_contact_admin_button =>
      _getLocalizedValue('dls_contact_admin_button');
  String get dls_scan_barcode => _getLocalizedValue('dls_scan_barcode');
  String get dls_scan => _getLocalizedValue('dls_scan');
  String get dls_on_and_off_flash => _getLocalizedValue('dls_on_and_off_flash');
  String get dls_switch_camera => _getLocalizedValue('dls_switch_camera');
  String get dls_scan_hint => _getLocalizedValue('dls_scan_hint');
  String get dls_scan_from_gallery =>
      _getLocalizedValue('dls_scan_from_gallery');
  String get dls_scan_from_file => _getLocalizedValue('dls_scan_from_file');
  String get dls_close_scan => _getLocalizedValue('dls_close_scan');
  String get dls_no_barcode_found => _getLocalizedValue('dls_no_barcode_found');
  String get dls_barcode_found => _getLocalizedValue('dls_barcode_found');
  String get dls_use_code => _getLocalizedValue('dls_use_code');
  String get dls_scan_error_description =>
      _getLocalizedValue('dls_scan_error_description');
  String get dls_scan_settings => _getLocalizedValue('dls_scan_settings');
  String get dls_scan_settings_description =>
      _getLocalizedValue('dls_scan_settings_description');
  String get dls_cancle_scan => _getLocalizedValue('dls_cancle_scan');

  // Device Detail Screen getters (dds_*)
  String get dds_send_command => _getLocalizedValue('dds_send_command');
  String get dds_yes => _getLocalizedValue('dds_yes');
  String get dds_no => _getLocalizedValue('dds_no');
  String get dds_error_command => _getLocalizedValue('dds_error_command');
  String get dds_error_connecting => _getLocalizedValue('dds_error_connecting');
  String get dds_activate_device => _getLocalizedValue('dds_activate_device');
  String get dds_deactivate_device =>
      _getLocalizedValue('dds_deactivate_device');
  String get dds_are_you_sure => _getLocalizedValue('dds_are_you_sure');
  String get dds_error_changing_status =>
      _getLocalizedValue('dds_error_changing_status');
  String get dds_delete_device => _getLocalizedValue('dds_delete_device');
  String get dds_delete_device_description =>
      _getLocalizedValue('dds_delete_device_description');
  String get dds_delete_device_error =>
      _getLocalizedValue('dds_delete_device_error');
  String get dds_unknown => _getLocalizedValue('dds_unknown');
  String get dds_active => _getLocalizedValue('dds_active');
  String get dds_inactive => _getLocalizedValue('dds_inactive');
  String get dds_serial_number => _getLocalizedValue('dds_serial_number');
  String get dds_status => _getLocalizedValue('dds_status');
  String get dds_choose_command => _getLocalizedValue('dds_choose_command');
  String get dds_command => _getLocalizedValue('dds_command');
  String get dds_sending => _getLocalizedValue('dds_sending');
  String get dds_details_device => _getLocalizedValue('dds_details_device');
  String get dds_delete_device_success =>
      _getLocalizedValue('dds_delete_device_success');

  // Edit Password Screen getters (editpassword_*)
  String get editpassword_title => _getLocalizedValue('editpassword_title');
  String get editpassword_new_password =>
      _getLocalizedValue('editpassword_new_password');
  String get editpassword_confirm_password =>
      _getLocalizedValue('editpassword_confirm_password');
  String get editpassword_change_password =>
      _getLocalizedValue('editpassword_change_password');
  String get editpassword_note => _getLocalizedValue('editpassword_note');
  String get editpassword_add_required_correctly =>
      _getLocalizedValue('editpassword_add_required_correctly');
  String get editpassword_error_no_token =>
      _getLocalizedValue('editpassword_error_no_token');
  String get editpassword_error_connecting =>
      _getLocalizedValue('editpassword_error_connecting');
  String get editpassword_error_sending_request =>
      _localizedValues[locale
          .languageCode]!['editpassword_error_sending_request']!;

  // Add User Screen getters (adduser_*)
  String get adduser_error => _getLocalizedValue('adduser_error');
  String get adduser_title => _getLocalizedValue('adduser_title');
  String get adduser_submit => _getLocalizedValue('adduser_submit');
  String get adduser_new_info => _getLocalizedValue('adduser_new_info');
  String get adduser_username => _getLocalizedValue('adduser_username');
  String get adduser_password => _getLocalizedValue('adduser_password');
  String get adduser_phone => _getLocalizedValue('adduser_phone');
  String get adduser_code => _getLocalizedValue('adduser_code');
  String get adduser_level_access => _getLocalizedValue('adduser_level_access');
  String get adduser_level => _getLocalizedValue('adduser_level');
  String get adduser_required => _getLocalizedValue('adduser_required');
  String get adduser_success => _getLocalizedValue('adduser_success');

  // Admin Register Screen getters (adminreg_*)
  String get adminreg_add_phone_completely =>
      _getLocalizedValue('adminreg_add_phone_completely');
  String get adminreg_add_phone_exist =>
      _getLocalizedValue('adminreg_add_phone_exist');
  String get adminreg_add_username_exist =>
      _getLocalizedValue('adminreg_add_username_exist');
  String get adminreg_add_admin_code_exist =>
      _getLocalizedValue('adminreg_add_admin_code_exist');
  String get adminreg_add_required =>
      _getLocalizedValue('adminreg_add_required');
  String get adminreg_add_error => _getLocalizedValue('adminreg_add_error');
  String get adminreg_add_success => _getLocalizedValue('adminreg_add_success');
  String get adminreg_add_required_correctly =>
      _getLocalizedValue('adminreg_add_required_correctly');
  String get adminreg_error_connecting =>
      _getLocalizedValue('adminreg_error_connecting');
  String get adminreg_error_sending_otp =>
      _getLocalizedValue('adminreg_error_sending_otp');
  String get adminreg_title => _getLocalizedValue('adminreg_title');

  // Help Screen getters (help_*)
  String get help_title => _getLocalizedValue('help_title');
  String get help_intro_title => _getLocalizedValue('help_intro_title');
  String get help_intro_body => _getLocalizedValue('help_intro_body');
  String get help_postpurchase_title =>
      _getLocalizedValue('help_postpurchase_title');
  String get help_postpurchase_body =>
      _getLocalizedValue('help_postpurchase_body');
  String get help_postpurchase_bullet_1 =>
      _getLocalizedValue('help_postpurchase_bullet_1');
  String get help_postpurchase_bullet_2 =>
      _getLocalizedValue('help_postpurchase_bullet_2');
  String get help_postpurchase_bullet_3 =>
      _getLocalizedValue('help_postpurchase_bullet_3');
  String get help_postpurchase_bullet_4 =>
      _getLocalizedValue('help_postpurchase_bullet_4');
  String get help_add_device_title =>
      _getLocalizedValue('help_add_device_title');
  String get help_add_device_body => _getLocalizedValue('help_add_device_body');
  String get help_add_users_title => _getLocalizedValue('help_add_users_title');
  String get help_add_users_body => _getLocalizedValue('help_add_users_body');
  String get help_add_users_method_1 =>
      _getLocalizedValue('help_add_users_method_1');
  String get help_add_users_method_2 =>
      _getLocalizedValue('help_add_users_method_2');
  String get help_user_management_title =>
      _getLocalizedValue('help_user_management_title');
  String get help_user_management_body =>
      _getLocalizedValue('help_user_management_body');
  String get help_device_management_title =>
      _getLocalizedValue('help_device_management_title');
  String get help_device_management_body =>
      _getLocalizedValue('help_device_management_body');
  String get help_device_config_title =>
      _getLocalizedValue('help_device_config_title');
  String get help_device_config_body =>
      _getLocalizedValue('help_device_config_body');
  String get help_reports_title => _getLocalizedValue('help_reports_title');
  String get help_reports_body => _getLocalizedValue('help_reports_body');
  String get help_reports_bullet_1 =>
      _getLocalizedValue('help_reports_bullet_1');
  String get help_reports_bullet_2 =>
      _getLocalizedValue('help_reports_bullet_2');
  String get help_reports_bullet_3 =>
      _getLocalizedValue('help_reports_bullet_3');
  String get help_user_levels_title =>
      _getLocalizedValue('help_user_levels_title');
  String get help_user_levels_body =>
      _getLocalizedValue('help_user_levels_body');
  String get help_company_rep_bullets =>
      _getLocalizedValue('help_company_rep_bullets');
  String get help_admin_title => _getLocalizedValue('help_admin_title');
  String get help_admin_bullets => _getLocalizedValue('help_admin_bullets');
  String get help_installer_bullets =>
      _getLocalizedValue('help_installer_bullets');
  String get help_regular_user_bullets =>
      _getLocalizedValue('help_regular_user_bullets');
  String get help_user_settings_title =>
      _getLocalizedValue('help_user_settings_title');
  String get help_user_settings_body =>
      _getLocalizedValue('help_user_settings_body');
  String get help_user_settings_bullet_1 =>
      _getLocalizedValue('help_user_settings_bullet_1');
  String get help_user_settings_bullet_2 =>
      _getLocalizedValue('help_user_settings_bullet_2');
  String get help_user_settings_bullet_3 =>
      _getLocalizedValue('help_user_settings_bullet_3');
  String get help_profile_title => _getLocalizedValue('help_profile_title');
  String get help_profile_body => _getLocalizedValue('help_profile_body');
  String get help_support_title => _getLocalizedValue('help_support_title');
  String get help_support_body => _getLocalizedValue('help_support_body');
  String get help_service_request_title =>
      _getLocalizedValue('help_service_request_title');
  String get help_service_request_body =>
      _getLocalizedValue('help_service_request_body');

  // Shared loading
  String get sharedload_please_wait =>
      _getLocalizedValue('sharedload_please_wait');

  // All
  String get click_again_to_exit => _getLocalizedValue('click_again_to_exit');

  String deviceCount(int count) {
    return effectiveLanguageCode == 'en' ? '$count devices' : '$count دستگاه';
  }

  String commandsCount(int count) {
    return effectiveLanguageCode == 'en' ? '$count commands' : '$count فرمان';
  }

  String serviceRequestsCount(int count) {
    return effectiveLanguageCode == 'en' ? '$count requests' : '$count درخواست';
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fa'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    print('DEBUG: Loading localizations for ${locale.languageCode}');
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => true;
}
