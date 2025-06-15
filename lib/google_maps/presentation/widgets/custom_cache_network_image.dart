import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

class CustomNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final Widget placeholderWidget;
  final double? radius;
  final BoxFit fit;
  final bool? changeErrorWidget;
  final BorderRadiusGeometry? borderRadius;
  const CustomNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    required this.placeholderWidget,
    this.fit = BoxFit.cover,
    this.radius = 5,
    this.changeErrorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(12),
      child: CachedNetworkImage(
        fit: fit,
        imageUrl: imageUrl != ''
            ? imageUrl
            : 'https://as1.ftcdn.net/v2/jpg/05/16/27/58/1000_F_516275801_f3Fsp17x6HQK0xQgDQEELoTuERO4SsWV.jpg',
        width: width,
        height: 100,
        placeholder: (context, message) {
          return Skeletonizer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius!),
              ),
            ),
          );
        },
        errorWidget: (context, message, error) {
          return changeErrorWidget != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/images/png/no_image.png',
                  ),
                )
              : const Center(
                  child: Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                ));
        },
      ),
    );
  }
}
