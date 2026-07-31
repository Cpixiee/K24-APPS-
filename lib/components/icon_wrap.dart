import 'package:flutter/material.dart';

class IconWrap extends StatelessWidget {
  final Color? color;
  final double? height;
  final double? width;
  final String path;

  const IconWrap({
    super.key,
    required this.path,
    this.color,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 25,
      width: width ?? 25,
      alignment: Alignment.center,
      child: Image.asset(
        path,
        height: height ?? 25,
        width: width ?? 25,
      ),
    );
  }
}
