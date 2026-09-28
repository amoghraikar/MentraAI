import 'package:flutter/material.dart';

enum AppRoute {
  home(
    path: '/home',
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    group: NavGroup.workspace,
  ),
  study(
    path: '/study',
    label: 'Study',
    icon: Icons.auto_stories_outlined,
    activeIcon: Icons.auto_stories_rounded,
    group: NavGroup.workspace,
  ),
  subjects(
    path: '/subjects',
    label: 'Subjects',
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder_rounded,
    group: NavGroup.workspace,
  ),
  notes(
    path: '/notes',
    label: 'Notes',
    icon: Icons.description_outlined,
    activeIcon: Icons.description_rounded,
    group: NavGroup.workspace,
  ),
  goals(
    path: '/goals',
    label: 'Goals',
    icon: Icons.flag_outlined,
    activeIcon: Icons.flag_rounded,
    group: NavGroup.workspace,
  ),
  aiCoach(
    path: '/ai-coach',
    label: 'Mentra AI',
    icon: Icons.psychology_outlined,
    activeIcon: Icons.psychology_rounded,
    group: NavGroup.insights,
  ),
  focus(
    path: '/focus',
    label: 'Focus',
    icon: Icons.center_focus_strong_outlined,
    activeIcon: Icons.center_focus_strong_rounded,
    group: NavGroup.insights,
  ),
  analytics(
    path: '/analytics',
    label: 'Analytics',
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights_rounded,
    group: NavGroup.insights,
  ),
  settings(
    path: '/settings',
    label: 'Settings',
    icon: Icons.tune_outlined,
    activeIcon: Icons.tune_rounded,
    group: NavGroup.system,
  );

  const AppRoute({
    required this.path,
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.group,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final NavGroup group;
}

enum NavGroup {
  workspace(label: 'WORKSPACE'),
  insights(label: 'INSIGHTS'),
  system(label: 'SYSTEM');

  const NavGroup({required this.label});
  final String label;
}
