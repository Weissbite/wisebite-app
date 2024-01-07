import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smooth_app/generic_lib/design_constants.dart';
import 'package:smooth_app/helpers/app_helper.dart';

class ServiceSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color backgroundColor;
  final String iconPath;
  final String text;
  final Color fontColor;

  const ServiceSignInButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.iconPath,
    required this.text,
    required this.fontColor,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size size = MediaQuery.of(context).size;

    return ElevatedButton.icon(
      onPressed: this.onPressed,
      style: ButtonStyle(
        minimumSize: MaterialStateProperty.all<Size>(
          Size(size.width * 0.8, theme.buttonTheme.height + 10),
        ),
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: CIRCULAR_BORDER_RADIUS,
            side: BorderSide(color: Colors.black, width: 0.1),
          ),
        ),
        backgroundColor: MaterialStateProperty.all<Color>(
          this.backgroundColor,
        ),
      ),
      icon: SvgPicture.asset(
        this.iconPath,
        height: theme.buttonTheme.height - 10,
        package: AppHelper.APP_PACKAGE, // Replace with your actual package name
      ),
      label: Text(
        this.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: this.fontColor,
        ),
      ),
    );
  }
}
