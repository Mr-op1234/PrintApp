import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../models/print_order.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../utils/helpers.dart';
import '../student_details/student_details_screen.dart';

class ConfigureScreen extends ConsumerWidget {
  const ConfigureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(printConfigProvider);
    final files = ref.watch(selectedFilesProvider);
    final totalPrice = ref.watch(totalPriceProvider);
    final totalPages = files.fold(0, (sum, f) => sum + f.pageCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Configuration'),
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: const ProgressStepper(
              currentStep: 1,
              steps: ['Files', 'Config', 'Details', 'Payment', 'Done'],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Paper Size Section
                  _buildSection(
                    context,
                    'Paper Size',
                    'Select the paper size for printing',
                    _buildPaperSizeOptions(context, ref, config),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Print Type Section
                  _buildSection(
                    context,
                    'Print Type',
                    'Choose color or black & white',
                    _buildPrintTypeOptions(context, ref, config),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Print Side Section
                  _buildSection(
                    context,
                    'Print Sides',
                    'Single or double-sided printing',
                    _buildPrintSideOptions(context, ref, config),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Copies Section
                  _buildSection(
                    context,
                    'Number of Copies',
                    'How many copies do you need?',
                    _buildCopiesSelector(context, ref, config),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Binding Section
                  _buildSection(
                    context,
                    'Binding (Optional)',
                    'Add binding to your document',
                    _buildBindingOptions(context, ref, config),
                  ),

                  const SizedBox(height: AppTheme.spacingLG),

                  // Price Summary
                  _buildPriceSummary(context, config, totalPages, totalPrice),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomBar(context, totalPrice),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String subtitle, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, subtitle: subtitle),
        content,
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildPaperSizeOptions(BuildContext context, WidgetRef ref, PrintConfig config) {
    final sizes = [
      {'value': 'A4', 'label': 'A4', 'desc': '210 × 297 mm'},
      {'value': 'A3', 'label': 'A3', 'desc': '297 × 420 mm'},
    ];

    return Row(
      children: sizes.map((size) {
        final isSelected = config.paperSize == size['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: size != sizes.last ? AppTheme.spacingSM : 0,
            ),
            child: GlassCard(
              isSelected: isSelected,
              onTap: () => ref.read(printConfigProvider.notifier).setPaperSize(size['value']!),
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  Icon(
                    Icons.description,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textMutedDark,
                    size: 28,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    size['label']!,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    size['desc']!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrintTypeOptions(BuildContext context, WidgetRef ref, PrintConfig config) {
    final types = [
      {
        'value': 'BW',
        'label': 'Black & White',
        'icon': Icons.invert_colors_off,
        'color': Colors.grey,
      },
      {
        'value': 'COLOR',
        'label': 'Color',
        'icon': Icons.palette,
        'color': AppTheme.accentTeal,
      },
    ];

    return Row(
      children: types.map((type) {
        final isSelected = config.printType == type['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: type != types.last ? AppTheme.spacingMD : 0,
            ),
            child: GlassCard(
              isSelected: isSelected,
              onTap: () => ref.read(printConfigProvider.notifier).setPrintType(type['value'] as String),
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              margin: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (type['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      type['icon'] as IconData,
                      color: isSelected ? type['color'] as Color : AppTheme.textMutedDark,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingMD),
                  Flexible(
                    child: Text(
                      type['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? type['color'] as Color : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrintSideOptions(BuildContext context, WidgetRef ref, PrintConfig config) {
    final sides = [
      {
        'value': 'SINGLE',
        'label': 'Single Sided',
        'icon': Icons.note,
        'desc': 'Print on one side',
      },
      {
        'value': 'DOUBLE',
        'label': 'Double Sided',
        'icon': Icons.library_books,
        'desc': 'Print on both sides',
      },
    ];

    return Row(
      children: sides.map((side) {
        final isSelected = config.printSide == side['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: side != sides.last ? AppTheme.spacingMD : 0,
            ),
            child: GlassCard(
              isSelected: isSelected,
              onTap: () => ref.read(printConfigProvider.notifier).setPrintSide(side['value'] as String),
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  Icon(
                    side['icon'] as IconData,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textMutedDark,
                    size: 32,
                  ),
                  const SizedBox(height: AppTheme.spacingSM),
                  Text(
                    side['label'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppTheme.primaryColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    side['desc'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMutedDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCopiesSelector(BuildContext context, WidgetRef ref, PrintConfig config) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMD,
        vertical: AppTheme.spacingSM,
      ),
      margin: EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: config.copies > 1
                ? () => ref.read(printConfigProvider.notifier).setCopies(config.copies - 1)
                : null,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: config.copies > 1
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : AppTheme.surfaceBorder,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Icon(
                Icons.remove,
                color: config.copies > 1 ? AppTheme.primaryColor : AppTheme.textMutedDark,
              ),
            ),
          ),
          Column(
            children: [
              Text(
                '${config.copies}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ).animate(target: 1).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 150.ms,
              ),
              const Text(
                'copies',
                style: TextStyle(
                  color: AppTheme.textMutedDark,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: config.copies < 100
                ? () => ref.read(printConfigProvider.notifier).setCopies(config.copies + 1)
                : null,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: const Icon(
                Icons.add,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBindingOptions(BuildContext context, WidgetRef ref, PrintConfig config) {
    final bindingTypes = [
      {
        'value': 'NONE',
        'label': 'None',
        'icon': Icons.close,
        'color': Colors.grey,
        'price': '',
      },
      {
        'value': 'SPIRAL',
        'label': 'Spiral',
        'icon': Icons.loop,
        'color': AppTheme.accentAmber,
        'price': '+₹25',
      },
      {
        'value': 'SOFT',
        'label': 'Soft',
        'icon': Icons.menu_book,
        'color': AppTheme.accentPink,
        'price': '+₹100',
      },
    ];

    return Row(
      children: bindingTypes.map((binding) {
        final isSelected = config.bindingType == binding['value'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: binding != bindingTypes.last ? AppTheme.spacingSM : 0,
            ),
            child: GlassCard(
              isSelected: isSelected,
              onTap: () => ref.read(printConfigProvider.notifier).setBindingType(binding['value'] as String),
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              margin: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (binding['color'] as Color).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      binding['icon'] as IconData,
                      color: isSelected ? binding['color'] as Color : AppTheme.textMutedDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    binding['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? binding['color'] as Color : null,
                    ),
                  ),
                  if ((binding['price'] as String).isNotEmpty)
                    Text(
                      binding['price'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? AppTheme.successColor : AppTheme.textMutedDark,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPriceSummary(BuildContext context, PrintConfig config, int totalPages, double totalPrice) {
    final pricePerUnit = config.getPricePerUnit();
    final topSheetPrice = config.getTopSheetPrice();
    final bindingPrice = config.getBindingPrice();
    final billableUnits = config.calculateBillableUnits(totalPages, includeFrontPage: false);
    final unitLabel = config.printSide == 'DOUBLE' ? 'sheets' : 'pages';
    final documentCost = billableUnits * pricePerUnit * config.copies;
    final topSheetFree = config.isTopSheetFree(totalPages);
    final topSheetCost = topSheetFree ? 0.0 : topSheetPrice; // Only 1 per order, not per copy
    
    return GlassCard(
      gradient: AppTheme.cardGradient,
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppTheme.primaryColor),
              const SizedBox(width: AppTheme.spacingSM),
              const Text(
                'Price Summary',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          const Divider(color: AppTheme.surfaceBorder),
          const SizedBox(height: AppTheme.spacingSM),
          
          // Document cost
          _buildPriceRow('Document ($billableUnits $unitLabel × ₹${pricePerUnit.toStringAsFixed(0)} × ${config.copies})', formatCurrency(documentCost)),
          const SizedBox(height: 4),
          
          // Top sheet cost - 1 per order, free for 50+ pages
          if (topSheetFree)
            _buildPriceRow('Top sheet (FREE - 50+ pages)', '₹0')
          else
            _buildPriceRow('Top sheet (1 per order)', formatCurrency(topSheetCost)),
          const SizedBox(height: 4),
          
          // Binding cost (if any)
          if (bindingPrice > 0) ...[
            _buildPriceRow(
              '${config.bindingType == 'SPIRAL' ? 'Spiral' : 'Soft'} Binding',
              formatCurrency(bindingPrice),
            ),
            const SizedBox(height: 4),
          ],
          
          const SizedBox(height: AppTheme.spacingSM),
          const Divider(color: AppTheme.surfaceBorder),
          const SizedBox(height: AppTheme.spacingXS),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              PriceDisplay(amount: totalPrice),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildPriceRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isBold ? null : AppTheme.textMutedDark,
            fontWeight: isBold ? FontWeight.w600 : null,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, double totalPrice) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
          top: BorderSide(color: AppTheme.surfaceBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      color: AppTheme.textMutedDark,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    formatCurrency(totalPrice),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.successColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: GradientButton(
                text: 'Continue',
                icon: Icons.arrow_forward,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentDetailsScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
