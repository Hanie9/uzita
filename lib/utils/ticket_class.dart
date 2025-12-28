class Ticket {
  final int id;
  final String title;
  final String description;
  final bool reply;
  final String createdAt;
  final List<TicketReply> replies;
  final String? subjectType;

  Ticket({
    required this.id,
    required this.title,
    required this.description,
    required this.reply,
    required this.createdAt,
    required this.replies,
    this.subjectType,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      reply: json['reply'] ?? false,
      createdAt: json['created_at'] ?? '',
      replies:
          (json['replies'] as List?)
              ?.map((reply) => TicketReply.fromJson(reply))
              .toList() ??
          [],
      subjectType: json['subject'] as String? ?? 
                   json['subject_type'] as String? ?? 
                   json['subjectType'] as String?,
    );
  }
}

class TicketReply {
  final int id;
  final String massage;
  final String createdAt;

  TicketReply({
    required this.id,
    required this.massage,
    required this.createdAt,
  });

  factory TicketReply.fromJson(Map<String, dynamic> json) {
    return TicketReply(
      id: json['id'] ?? 0,
      massage: json['massage'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}
