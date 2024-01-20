import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:smooth_app/generic_lib/design_constants.dart';
import 'package:smooth_app/helpers/app_helper.dart';

class ServiceSignInButton extends StatelessWidget {
<<<<<<< HEAD
=======
  final VoidCallback onPressed;
  final Color backgroundColor;
  final String iconPath;
  final String text;
  final Color fontColor;

>>>>>>> 82690318379da0b99038c2c2643c98b2af326ba7
  const ServiceSignInButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.iconPath,
    required this.text,
    required this.fontColor,
  });

<<<<<<< HEAD
  final VoidCallback onPressed;
  final Color backgroundColor;
  final String iconPath;
  final String text;
  final Color fontColor;

=======
>>>>>>> 82690318379da0b99038c2c2643c98b2af326ba7
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size size = MediaQuery.of(context).size;

    return ElevatedButton.icon(
<<<<<<< HEAD
      onPressed: onPressed,
=======
      onPressed: this.onPressed,
>>>>>>> 82690318379da0b99038c2c2643c98b2af326ba7
      style: ButtonStyle(
        minimumSize: MaterialStateProperty.all<Size>(
          Size(size.width * 0.8, theme.buttonTheme.height + 10),
        ),
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
<<<<<<< HEAD
          const RoundedRectangleBorder(
=======
          RoundedRectangleBorder(
>>>>>>> 82690318379da0b99038c2c2643c98b2af326ba7
            borderRadius: CIRCULAR_BORDER_RADIUS,
            side: BorderSide(color: Colors.black, width: 0.1),
          ),
        ),
        backgroundColor: MaterialStateProperty.all<Color>(
<<<<<<< HEAD
          backgroundColor,
        ),
      ),
      icon: SvgPicture.asset(
        iconPath,
=======
          this.backgroundColor,
        ),
      ),
      icon: SvgPicture.asset(
        this.iconPath,
>>>>>>> 82690318379da0b99038c2c2643c98b2af326ba7
        height: theme.buttonTheme.height - 10,
        package: AppHelper.APP_PACKAGE, // Replace with your actual package name
      ),
      label: Text(
<<<<<<< HEAD
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: fontColor,
=======
        this.text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          color: this.fontColor,
>>>>>>> 82690318379da0b99038c2c2643c98b2af326ba7
        ),
      ),
    );
  }
}
