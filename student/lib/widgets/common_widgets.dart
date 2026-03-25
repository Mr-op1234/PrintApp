import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/theme.dart';

/// Glassmorphic card with blur effect and gradient border
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool isSelected;
  final Gradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.onTap,
    this.isSelected = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: gradient ?? (isDark ? AppTheme.cardGradient : null),
        color: isDark ? null : AppTheme.surfaceCardLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        border: Border.all(
          color: isSelected 
              ? AppTheme.primaryColor 
              : (isDark ? AppTheme.surfaceBorder : AppTheme.surfaceBorderLight),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected ? AppTheme.glowShadow : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AppTheme.spacingMD),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Primary gradient button
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final Gradient? gradient;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 56,
      decoration: BoxDecoration(
        gradient: onPressed != null 
            ? (gradient ?? AppTheme.primaryGradient)
            : LinearGradient(
                colors: [Colors.grey[600]!, Colors.grey[700]!],
              ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        boxShadow: onPressed != null ? AppTheme.glowShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    ).animate(target: onPressed != null ? 1 : 0)
        .scale(duration: 200.ms, curve: Curves.easeOut);
  }
}

/// Status indicator with icon and pulse animation
class StatusIndicator extends StatelessWidget {
  final bool isOnline;
  final String label;
  final bool showPulse;

  const StatusIndicator({
    super.key,
    required this.isOnline,
    required this.label,
    this.showPulse = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOnline ? AppTheme.successColor : AppTheme.errorColor,
            boxShadow: isOnline && showPulse
                ? [
                    BoxShadow(
                      color: AppTheme.successColor.withOpacity(0.5),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
        ).animate(
          onPlay: (controller) => controller.repeat(),
          target: isOnline && showPulse ? 1 : 0,
        ).scale(
          begin: const Offset(1, 1),
          end: const Offset(1.3, 1.3),
          duration: 1000.ms,
          curve: Curves.easeInOut,
        ).then().scale(
          begin: const Offset(1.3, 1.3),
          end: const Offset(1, 1),
          duration: 1000.ms,
          curve: Curves.easeInOut,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isOnline ? AppTheme.successColor : AppTheme.errorColor,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

/// Section header with title and optional action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMD),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Option chip for selection
class SelectionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? selectedColor;

  const SelectionChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onTap,
    this.icon,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppTheme.primaryColor;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMD,
          vertical: AppTheme.spacingSM,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(
            color: isSelected ? color : AppTheme.surfaceBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 18,
                color: isSelected ? color : AppTheme.textMutedDark,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppTheme.textSecondaryDark,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Price display with currency formatting
class PriceDisplay extends StatelessWidget {
  final double amount;
  final String? label;
  final bool large;

  const PriceDisplay({
    super.key,
    required this.amount,
    this.label,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMutedDark,
            ),
          ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: large ? 32 : 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.successColor,
          ),
        ).animate().shimmer(
          duration: 2000.ms,
          color: AppTheme.successColor.withOpacity(0.3),
        ),
      ],
    );
  }
}

/// Loading overlay
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final String? message;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    this.message,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: GlassCard(
                padding: const EdgeInsets.all(AppTheme.spacingLG),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (message != null) ...[
                      const SizedBox(height: AppTheme.spacingMD),
                      Text(
                        message!,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 200.ms),
      ],
    );
  }
}

/// Empty state widget
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppTheme.textMutedDark,
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: AppTheme.spacingMD),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: AppTheme.spacingSM),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spacingLG),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Progress stepper
class ProgressStepper extends StatelessWidget {
  final int currentStep;
  final List<String> steps;

  const ProgressStepper({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          return Expanded(
            child: Container(
              height: 2,
              color: stepIndex < currentStep
                  ? AppTheme.primaryColor
                  : AppTheme.surfaceBorder,
            ),
          );
        }
        
        final stepIndex = index ~/ 2;
        final isCompleted = stepIndex < currentStep;
        final isCurrent = stepIndex == currentStep;
        
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isCurrent
                ? AppTheme.primaryColor
                : AppTheme.surfaceCard,
            border: Border.all(
              color: isCompleted || isCurrent
                  ? AppTheme.primaryColor
                  : AppTheme.surfaceBorder,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : AppTheme.textMutedDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ).animate(target: isCurrent ? 1 : 0)
            .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1));
      }),
    );
  }
}

/// File card for displaying selected PDF
class FileCard extends StatelessWidget {
  final String name;
  final int pageCount;
  final String size;
  final VoidCallback? onRemove;
  final int? index;

  const FileCard({
    super.key,
    required this.name,
    required this.pageCount,
    required this.size,
    this.onRemove,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: const Icon(
              Icons.picture_as_pdf,
              color: AppTheme.primaryColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spacingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$pageCount pages • $size',
                  style: TextStyle(
                    color: AppTheme.textMutedDark,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onRemove,
              color: AppTheme.errorColor,
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
  }
}
