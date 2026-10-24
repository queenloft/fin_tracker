class Offer {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final double discountPercentage;

  Offer({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.discountPercentage,
  });

  factory Offer.fromMap(Map<String, dynamic> map, String id) {
    return Offer(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      discountPercentage: (map['discountPercentage'] ?? 0).toDouble(),
    );
  }
}
