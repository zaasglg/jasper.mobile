import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.height = 28});

  static const String assetPath = 'assets/images/logo.svg';

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Jospar Bee',
      child: ExcludeSemantics(
        child: SvgPicture.asset(
          assetPath,
          key: const Key('app-logo'),
          height: height,
          fit: BoxFit.contain,
          alignment: Alignment.centerLeft,
        ),
      ),
    );
  }
}
