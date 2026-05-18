import 'package:flutter_test/flutter_test.dart';
import 'package:uzita/api_config.dart';
import 'package:uzita/utils/technician_task_utils.dart';

void main() {
  final Map<String, dynamic> sampleTask = <String, dynamic>{
    'id': 17,
    'created_at': '2026-05-18T19:57:17.180174+03:30',
    'technician_confirm': false,
    'customer_confirm': false,
    'hazine': '0',
    'time': '0',
    'technician': null,
    'subjects': <String>['مفقودی کلید', 'password'],
    'status': 'assigned',
    'title': 'tess',
    'description': 'test',
    'address': 'ccfc',
    'phone': '9121234444',
    'urgency': null,
    'first_visit_date': null,
    'second_visit_date': null,
    'warranty': 'False',
    'pieces': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 3,
        'name': 'mkin',
        'code': '848',
        'price': 40000,
        'display': '40,000 تومان',
      },
    ],
    'tariffs': <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 2,
        'name': 'تعویض قفل صندوق های سبک',
        'price': 500000,
        'display': '500,000 تومان',
      },
    ],
    'attachment':
        '/media/service_attachments/2026/05/18/Screenshot_2026-05-13_at_11-12-36_%D9%84%DB%8C%D8%B3%D8%AA_%D8%B3%D8%B1%D9%88%DB%8C%D8%B3_%D9%87%D8%A7_-_%D9%BE%D9%86%D9%84_%D9%85%D8%AF%DB%8C%D8%B1%DB%8C%D8%AA.png',
    'attachment_name':
        'Screenshot_2026-05-13_at_11-12-36_لیست_سرویس_ها_-_پنل_مدیریت.png',
  };

  test('sample organ task JSON exposes attachment', () {
    final Map<String, dynamic> task = normalizeTechnicianTask(sampleTask);

    expect(taskHasAttachment(task), isTrue);
    expect(
      taskAttachmentPath(task),
      startsWith('/media/service_attachments/'),
    );
    expect(
      taskAttachmentDisplayName(task),
      'Screenshot_2026-05-13_at_11-12-36_لیست_سرویس_ها_-_پنل_مدیریت.png',
    );
    expect(
      taskAttachmentDownloadUrl(task),
      'https://device-control.liara.run/media/service_attachments/2026/05/18/Screenshot_2026-05-13_at_11-12-36_%D9%84%DB%8C%D8%B3%D8%AA_%D8%B3%D8%B1%D9%88%DB%8C%D8%B3_%D9%87%D8%A7_-_%D9%BE%D9%86%D9%84_%D9%85%D8%AF%DB%8C%D8%B1%DB%8C%D8%AA.png',
    );
  });

  test('findTechnicianTaskInPayload reads list wrapper', () {
    final Map<String, dynamic>? found = findTechnicianTaskInPayload(
      <Map<String, dynamic>>[sampleTask],
      '17',
    );

    expect(found, isNotNull);
    expect(taskHasAttachment(found!), isTrue);
  });

  test('resolveTaskAttachmentUrl uses site origin not /api', () {
    expect(
      resolveTaskAttachmentUrl(
        '/media/service_attachments/2026/05/18/file.png',
      ),
      '${apiOrigin}/media/service_attachments/2026/05/18/file.png',
    );
  });
}
