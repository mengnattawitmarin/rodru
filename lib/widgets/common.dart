import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  const SectionTitle(this.title, {super.key, this.trailing, this.onTrailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 8),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          if (trailing != null)
            InkWell(
              onTap: onTrailing,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(trailing!, style: const TextStyle(color: blue, fontSize: 12)),
              ),
            ),
        ]),
      );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderColor,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 10),
  });
  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: Material(
          color: color ?? panel,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor ?? Colors.white10),
              ),
              child: child,
            ),
          ),
        ),
      );
}

class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = blue,
    this.onTap,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: color, size: 27),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
          ),
          if (trailing != null) trailing! else if (onTap != null) const Icon(Icons.chevron_right, color: Colors.white38),
        ]),
      );
}

class ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool highlight;
  const ActionTile({super.key, required this.icon, required this.title, required this.color, required this.onTap, this.highlight = false});
  @override
  Widget build(BuildContext context) => Material(
        color: panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: highlight ? color : Colors.white10, width: highlight ? 1.5 : 1),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 29, color: color),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, {super.key, this.color = blue});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: .18), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const LegendDot({super.key, required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]);
}

class Disclaimer extends StatelessWidget {
  final String text;
  const Disclaimer(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 14, color: amber),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: amber, fontSize: 11, height: 1.35))),
        ]),
      );
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader(this.title, {super.key, this.subtitle, this.actions = const []});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              if (subtitle != null) Text(subtitle!, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ]),
          ),
          ...actions,
        ]),
      );
}

// ---------- launchers ----------
Future<void> callNumber(BuildContext context, String number) async {
  final ok = await launchUrl(Uri(scheme: 'tel', path: number.replaceAll(RegExp(r'[^0-9+]'), '')));
  if (!ok && context.mounted) toast(context, 'เปิดแอปโทรศัพท์ไม่ได้ — โทร $number ด้วยตนเอง');
}

Future<void> openWeb(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'เปิดลิงก์ไม่ได้');
}

Future<void> openDirections(BuildContext context, double lat, double lon) async {
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$lat,$lon',
    'travelmode': 'driving',
  });
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) toast(context, 'เปิดแอปแผนที่ไม่ได้');
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirmCall(BuildContext context, String number, String name) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: panel,
      title: Text('โทร $number?'),
      content: Text(name),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
        FilledButton.icon(
          onPressed: () => Navigator.pop(ctx, true),
          icon: const Icon(Icons.call),
          label: const Text('โทร'),
          style: FilledButton.styleFrom(backgroundColor: red),
        ),
      ],
    ),
  );
  return r == true;
}
