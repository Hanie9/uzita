import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/utils/ticket_class.dart';
import 'package:uzita/utils/ui_scale.dart';

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;

  const TicketCard({super.key, required this.ticket, required this.onTap});

  String convertToShamsi(BuildContext context, String dateTime) {
    try {
      DateTime dt = DateTime.parse(dateTime);
      if (Localizations.localeOf(context).languageCode == 'en') {
        return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
      } else {
        Jalali shamsiDate = Jalali.fromDateTime(dt);
        return '${shamsiDate.year}/${shamsiDate.month.toString().padLeft(2, '0')}/${shamsiDate.day.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return AppLocalizations.of(context)!.ticketcard_unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = UiScale(context);
    return Card(
      margin: EdgeInsets.only(bottom: ui.scale(base: 12, min: 8, max: 16)),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ui.scale(base: 12, min: 10, max: 14),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          ui.scale(base: 12, min: 10, max: 14),
        ),
        child: Padding(
          padding: EdgeInsets.all(ui.scale(base: 16, min: 12, max: 20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ردیف اول: تیتر و وضعیت
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.title,
                      style: TextStyle(
                        fontSize: ui.scale(base: 16, min: 14, max: 18),
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.grey[800],
                        fontFamily: 'Vazir',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: ui.scale(base: 8, min: 6, max: 10)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: ui.scale(base: 8, min: 6, max: 10),
                      vertical: ui.scale(base: 4, min: 3, max: 6),
                    ),
                    decoration: BoxDecoration(
                      color: ticket.reply ? Colors.blue[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(
                        ui.scale(base: 8, min: 6, max: 10),
                      ),
                      border: Border.all(
                        color: Colors.blue[300]!,
                        width: ui.scale(base: 1, min: 1, max: 1.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ticket.reply
                              ? Icons.check_circle_outline
                              : Icons.schedule,
                          size: ui.scale(base: 14, min: 12, max: 16),
                          color: Colors.blue[700],
                        ),
                        SizedBox(width: ui.scale(base: 4, min: 3, max: 6)),
                        Text(
                          ticket.reply
                              ? AppLocalizations.of(
                                  context,
                                )!.ticketcard_answered
                              : AppLocalizations.of(
                                  context,
                                )!.ticketcard_waiting_response,
                          style: TextStyle(
                            fontSize: ui.scale(base: 12, min: 11, max: 14),
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                            fontFamily: 'Vazir',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: ui.scale(base: 12, min: 8, max: 16)),

              // ردیف دوم: تاریخ و آیکون مشاهده
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: ui.scale(base: 16, min: 14, max: 18),
                    color: Colors.grey[600],
                  ),
                  SizedBox(width: ui.scale(base: 6, min: 4, max: 8)),
                  Text(
                    '${AppLocalizations.of(context)!.ticketcard_date_send} ${convertToShamsi(context, ticket.createdAt)}',
                    style: TextStyle(
                      fontSize: ui.scale(base: 13, min: 12, max: 15),
                      color: Colors.grey[600],
                      fontFamily: 'Vazir',
                    ),
                  ),
                  Spacer(),
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.ticketcard_view_details,
                        style: TextStyle(
                          fontSize: ui.scale(base: 13, min: 12, max: 15),
                          color: Colors.blue[600],
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Vazir',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
