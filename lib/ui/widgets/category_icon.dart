import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const CategoryIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      radius: size,
      child: Icon(
        icon,
        color: color,
        size: size * 0.6,
      ),
    );
  }
}
