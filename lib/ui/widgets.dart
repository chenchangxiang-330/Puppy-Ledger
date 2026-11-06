import 'shapes.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import 'motion.dart';

const cream = Color(0xFFFFFCF5);
const ink = Color(0xFF2D2A26);
const muted = Color(0xFF827A6E);
const line = Color(0xFFE5DED2);
const butter = Color(0xFFFFE9A5);
const coral = Color(0xFFEB8279);

class PuppyCard extends StatelessWidget {
  const PuppyCard({super.key, required this.child, this.padding, this.color});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: ShapeDecoration(
      shape: ledgerShape(24),
      shadows: const [
        BoxShadow(color: Color(0xFFECE5D7), offset: Offset(0, 3)),
      ],
    ),
    child: Material(
      animationDuration: PuppyMotion.duration(context, PuppyMotion.theme),
      color: color ?? Colors.white,
      shape: RoundedSuperellipseBorder(
        side: const BorderSide(color: ink, width: 1.25),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(20),
        child: child,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// The selected theme determines bundled artwork throughout the widget tree.
class PuppyArtworkTheme extends ThemeExtension<PuppyArtworkTheme> {
  const PuppyArtworkTheme(this.themeKey);
  final String themeKey;
  @override
  PuppyArtworkTheme copyWith({String? themeKey}) =>
      PuppyArtworkTheme(themeKey ?? this.themeKey);
  @override
  PuppyArtworkTheme lerp(covariant PuppyArtworkTheme? other, double t) =>
      other ?? this;
  @override
  bool operator ==(Object other) =>
      other is PuppyArtworkTheme && themeKey == other.themeKey;
  @override
  int get hashCode => themeKey.hashCode;
}

String puppyArtworkAsset(String themeKey) => switch (themeKey) {
  'peach' => 'assets/illustrations/puppy_peach.png',
  'sage' => 'assets/illustrations/puppy_sage.png',
  _ => 'assets/illustrations/puppy_pair.png',
};

class DogArt extends StatelessWidget {
  const DogArt({super.key, this.size = 160, this.themeKey});
  final double size;

  /// An explicit key is used by the theme-picker thumbnails.
  final String? themeKey;
  @override
  Widget build(BuildContext context) {
    final selected =
        themeKey ??
        Theme.of(context).extension<PuppyArtworkTheme>()?.themeKey ??
        'lemon';
    final asset = puppyArtworkAsset(selected);
    final description = switch (selected) {
      'peach' => '小金毛抱着白色小狗，甜甜贴贴',
      'sage' => '白色小狗和小金毛并排坐着，相互依偎',
      _ => '白色小狗和小金毛一起记账',
    };
    return Semantics(
      label: description,
      image: true,
      child: SizedBox(
        width: size,
        height: size * .84,
        child: AnimatedSwitcher(
          duration: PuppyMotion.duration(context, PuppyMotion.theme),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeIn,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [...previous, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: .97, end: 1).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(asset),
            child: selected == 'peach' || selected == 'sage'
                ? Image.asset(
                    asset,
                    gaplessPlayback: true,
                    width: size,
                    height: size * .84,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  )
                : ClipRect(
                    child: OverflowBox(
                      maxWidth: size / .60,
                      maxHeight: size / .60 * 2 / 3,
                      child: Image.asset(
                        asset,
                        gaplessPlayback: true,
                        width: size / .60,
                        height: size / .60 * 2 / 3,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The role follows the ledger assignment; the portrait always follows the dog.
class PuppyAvatar extends StatelessWidget {
  const PuppyAvatar({super.key, this.size = 48, required this.golden});
  static const goldenPortrait = ResizeImage(
    AssetImage('assets/avatars/golden_coin.jpg'),
    width: 384,
  );
  static const whitePortrait = ResizeImage(
    AssetImage('assets/avatars/white_coin.jpg'),
    width: 384,
  );
  final double size;
  final bool golden;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image(
      image: golden ? goldenPortrait : whitePortrait,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      semanticLabel: golden ? '小鸡毛抱着金币' : '小白抱着金币',
    ),
  );
}

/// Small decorative faces in headings and navigation use the theme artwork.
class PuppyFace extends StatelessWidget {
  const PuppyFace({super.key, this.size = 30, this.golden = false});
  final double size;
  final bool golden;
  @override
  Widget build(BuildContext context) {
    final x = golden ? 715.0 : 125.0;
    final y = golden ? 145.0 : 175.0;
    final scale = size / (golden ? 570 : 550);
    return Semantics(
      image: true,
      label: golden ? '小鸡毛，黄色小狗' : '小白，白色小狗',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: golden ? const Color(0xFFFFEBC3) : const Color(0xFFF2F2EA),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Stack(
            children: [
              Positioned(
                left: -x * scale,
                top: -y * scale,
                width: 1448 * scale,
                height: 1086 * scale,
                child: Image.asset(
                  puppyArtworkAsset('sage'),
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PuppyPageHeading extends StatelessWidget {
  const PuppyPageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.golden = false,
  });
  final String title, subtitle;
  final bool golden;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: muted, height: 1.6),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: ledgerSurface(
          18,
          golden ? butter : Colors.white,
          side: const BorderSide(color: ink, width: 1.25),
        ),
        child: PuppyFace(size: 38, golden: golden),
      ),
    ],
  );
}

class LedgerDog extends StatelessWidget {
  const LedgerDog({super.key, required this.controller, this.size = 120});
  final LedgerController controller;
  final double size;
  @override
  Widget build(BuildContext context) {
    final filename = controller.settings.imageFile;
    if (filename == null) return DogArt(size: size);
    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(24),
      child: Image.file(
        File('${controller.directory.path}/$filename'),
        width: size,
        height: size,
        cacheWidth: 512,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stack) => DogArt(size: size),
      ),
    );
  }
}

IconData categoryIcon(String name) => switch (name) {
  '工资' => Icons.work_outline_rounded,
  '退款' => Icons.assignment_return_outlined,
  '兼职' => Icons.auto_awesome_outlined,
  '餐饮' => Icons.restaurant_rounded,
  '交通' => Icons.directions_bus_rounded,
  '购物' => Icons.shopping_bag_outlined,
  '学习' => Icons.menu_book_rounded,
  '娱乐' => Icons.sports_esports_outlined,
  '生活用品' => Icons.chair_outlined,
  _ => Icons.grid_view_rounded,
};
String errorText(Object error) {
  if (error is FormatException) return error.message;
  if (error is StateError) return error.message;
  if (error is FileActionCancelled) return error.toString();
  if (error is PlatformException) {
    return error.message ?? '无法打开系统文件选择器，请稍后重试。';
  }
  if (error is FileSystemException) return '文件读写失败，请检查可用存储空间后重试。原有内容已保留。';
  return '操作未完成，请检查可用存储空间后重试。输入和原有内容已保留。';
}

void showFailure(BuildContext context, Object error) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(errorText(error))));
void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const PuppyFace(size: 32),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

class EmptyLedger extends StatelessWidget {
  const EmptyLedger({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DogArt(size: 142),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.6),
          ),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 18), child: action!),
        ],
      ),
    ),
  );
}

DateTime clampUiDate(DateTime value) {
  final start = DateTime(1900);
  final end = DateTime(2100, 12, 31);
  if (value.isBefore(start)) return start;
  if (value.isAfter(end)) return end;
  return value;
}
