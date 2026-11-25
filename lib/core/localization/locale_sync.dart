import 'dart:async';
import 'package:flutter/widgets.dart';
import 'locale_cubit.dart';

class LocaleSync extends StatefulWidget {
  const LocaleSync({super.key, required this.cubit, required this.child});
  final LocaleCubit cubit;
  final Widget child;
  @override
  State<LocaleSync> createState() => _LocaleSyncState();
}

class _LocaleSyncState extends State<LocaleSync> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.cubit.refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(widget.cubit.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
