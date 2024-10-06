import 'package:easy_chat/theme/easy_chat_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class SendMsgBtn extends StatelessWidget {
  final bool isLoading;
  final bool isDisabled;
  final void Function()? onTap;
  final double size;
  const SendMsgBtn({
    super.key,
    this.onTap,
    this.isDisabled = false,
    this.isLoading = false,
    this.size = 32,
  });
  @override
  Widget build(BuildContext context) {
    Widget view;
    if (isLoading) {
      view = CircularProgressIndicator(
        color: context.coloredTheme.primary,
      );
    } else if (isDisabled) {
      view = SvgPicture.asset(
        'assets/svg/input/send_disabled.svg',
        package: 'easy_chat',
        width: size,
        height: size,
      );
    } else {
      view = SvgPicture.asset(
        'assets/svg/input/send.svg',
        package: 'easy_chat',
        width: size,
        height: size,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: view,
    );
  }
}