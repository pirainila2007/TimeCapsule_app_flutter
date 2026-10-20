import 'package:flutter/material.dart';

class AppColors {
  static const purple = Color(0xFFAB82FF);
  static const background = Color(0xFF0A0812);
  static const surface = Color(0xFF171321);
}

String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}