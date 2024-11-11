import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonCard extends StatelessWidget {
  static const double fixedCardWidth = 250.0;
  static const double fixedCardHeight = 454.0;
  static const double imageHeight = 370.0; // Match image height in CardWidget

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Color.fromARGB(255, 124, 124, 124),
      highlightColor: Color.fromARGB(255, 143, 143, 143),
      child: SizedBox(
        width: fixedCardWidth,
        height: fixedCardHeight,
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: imageHeight,
                width: double.infinity,
                color: Colors.grey[300],
              ),
              Divider(
                height: 2.0,
                color: Color.fromARGB(255, 37, 37, 37),
                thickness: 2.0,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 20,
                      width: 100,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 16,
                      width: 60,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
