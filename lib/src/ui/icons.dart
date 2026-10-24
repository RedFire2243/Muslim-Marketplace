import 'package:flutter/material.dart';

import '../domain/taxonomy.dart';

IconData typeIcon(ListingType t) => switch (t) {
  ListingType.service => Icons.handyman_outlined,
  ListingType.job => Icons.work_outline,
  ListingType.internship => Icons.school_outlined,
  ListingType.mentorship => Icons.diversity_3_outlined,
  ListingType.collaboration => Icons.handshake_outlined,
  ListingType.volunteer => Icons.volunteer_activism_outlined,
  ListingType.business => Icons.storefront_outlined,
};

IconData categoryIcon(ListingCategory c) => switch (c) {
  ListingCategory.education => Icons.menu_book_outlined,
  ListingCategory.technology => Icons.computer_outlined,
  ListingCategory.engineering => Icons.precision_manufacturing_outlined,
  ListingCategory.business => Icons.account_balance_outlined,
  ListingCategory.careers => Icons.trending_up,
  ListingCategory.creative => Icons.palette_outlined,
  ListingCategory.health => Icons.favorite_outline,
  ListingCategory.home => Icons.home_repair_service_outlined,
  ListingCategory.food => Icons.restaurant_outlined,
  ListingCategory.community => Icons.groups_outlined,
  ListingCategory.other => Icons.category_outlined,
};
