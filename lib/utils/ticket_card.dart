import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:uzita/app_localizations.dart';
import 'package:uzita/utils/ticket_class.dart';

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
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                        fontFamily: 'Vazir',
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ticket.reply ? Colors.blue[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[300]!, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ticket.reply
                              ? Icons.check_circle_outline
                              : Icons.schedule,
                          size: 14,
                          color: Colors.blue[700],
                        ),
                        SizedBox(width: 4),
                        Text(
                          ticket.reply
                              ? AppLocalizations.of(
                                  context,
                                )!.ticketcard_answered
                              : AppLocalizations.of(
                                  context,
                                )!.ticketcard_waiting_response,
                          style: TextStyle(
                            fontSize: 12,
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

              SizedBox(height: 12),

              // ردیف دوم: تاریخ و آیکون مشاهده
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Text(
                    '${AppLocalizations.of(context)!.ticketcard_date_send} ${convertToShamsi(context, ticket.createdAt)}',
                    style: TextStyle(
                      fontSize: 13,
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
                          fontSize: 13,
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
