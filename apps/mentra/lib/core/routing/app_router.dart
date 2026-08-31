import 'package:flutter/material.dart';
import 'app_route.dart';

class NavigationController extends ChangeNotifier {
  AppRoute _currentRoute = AppRoute.home;

  AppRoute get currentRoute => _currentRoute;

  void setRoute(AppRoute route) {
    if (_currentRoute != route) {
      _currentRoute = route;
      notifyListeners();
    }
  }
}

class NavigationScope extends InheritedNotifier<NavigationController> {
  const NavigationScope({
    super.key,
    required NavigationController controller,
    required super.child,
  }) : super(notifier: controller);

  static NavigationController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<NavigationScope>();
    assert(scope != null, 'No NavigationScope found in context');
    return scope!.notifier!;
  }
}
