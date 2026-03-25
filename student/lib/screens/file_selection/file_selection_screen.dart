import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../config/theme.dart';
import '../../config/app_config.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../services/pdf_service.dart';
import '../../utils/helpers.dart';
import '../configure/configure_screen.dart';

class FileSelectionScreen extends ConsumerStatefulWidget {
  const FileSelectionScreen({super.key});

  @override
  ConsumerState<FileSelectionScreen> createState() => _FileSelectionScreenState();
}

class _FileSelectionScreenState extends ConsumerState<FileSelectionScreen> {
  bool _isLoading = false;
  String? _error;

  Future<void> _pickFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.bytes != null) {
            // Validate file
            final validationError = _validateFile(file);
            if (validationError != null) {
              setState(() => _error = validationError);
              continue;
            }

            // Check if valid PDF
            if (!PdfService.isValidPdf(file.bytes!)) {
              setState(() => _error = '${file.name} is not a valid PDF file');
              continue;
            }

            await ref.read(selectedFilesProvider.notifier).addFile(
              file.name,
              file.path ?? '',
              file.bytes!,
            );
          }
        }
      }
    } catch (e) {
      setState(() => _error = 'Error picking files: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _validateFile(PlatformFile file) {
    // Check file size
    final sizeInMB = (file.size / (1024 * 1024));
    if (sizeInMB > AppConfig.maxFileSizeMB) {
      return '${file.name} exceeds ${AppConfig.maxFileSizeMB}MB limit';
    }

    // Check total files count
    final currentCount = ref.read(selectedFilesProvider).length;
    if (currentCount >= AppConfig.maxFilesCount) {
      return 'Maximum ${AppConfig.maxFilesCount} files allowed';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(selectedFilesProvider);
    final totalPages = files.fold(0, (sum, f) => sum + f.pageCount);
    final totalSize = files.fold(0, (sum, f) => sum + f.sizeBytes);
    final canProceed = files.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Documents'),
        actions: [
          if (files.isNotEmpty)
            TextButton.icon(
              onPressed: () => ref.read(selectedFilesProvider.notifier).clearFiles(),
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: const ProgressStepper(
              currentStep: 0,
              steps: ['Files', 'Config', 'Details', 'Payment', 'Done'],
            ),
          ),

          Expanded(
            child: files.isEmpty
                ? _buildEmptyState()
                : _buildFilesList(files),
          ),

          // Summary and Actions
          _buildBottomBar(context, files, totalPages, totalSize, canProceed),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.upload_file,
                size: 60,
                color: AppTheme.primaryColor.withOpacity(0.7),
              ),
            ).animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut)
                .then()
                .shake(hz: 2, offset: const Offset(2, 0)),
            
            const SizedBox(height: AppTheme.spacingLG),
            
            Text(
              'No Documents Selected',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            
            const SizedBox(height: AppTheme.spacingSM),
            
            Text(
              'Select PDF files to print. You can choose multiple files at once.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            
            const SizedBox(height: AppTheme.spacingLG),
            
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMD),
                margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorColor),
                    const SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn().shake(),
            
            GradientButton(
              text: 'Select PDF Files',
              icon: Icons.folder_open,
              isLoading: _isLoading,
              onPressed: _pickFiles,
            ),
            
            const SizedBox(height: AppTheme.spacingMD),
            
            Text(
              'Max ${AppConfig.maxFileSizeMB}MB per file • Max ${AppConfig.maxFilesCount} files',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMutedDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilesList(List files) {
    return Column(
      children: [
        // Add More Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
          child: GlassCard(
            onTap: _isLoading ? null : _pickFiles,
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.add, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingSM),
                Text(
                  _isLoading ? 'Processing...' : 'Add More Files',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: AppTheme.errorColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _error = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),

        // Files List
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMD),
            itemCount: files.length,
            onReorder: (oldIndex, newIndex) {
              ref.read(selectedFilesProvider.notifier).reorderFiles(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final file = files[index];
              return Padding(
                key: ValueKey(file.path + index.toString()),
                padding: const EdgeInsets.only(bottom: AppTheme.spacingSM),
                child: FileCard(
                  name: file.name,
                  pageCount: file.pageCount,
                  size: file.formattedSize,
                  index: index + 1,
                  onRemove: () {
                    ref.read(selectedFilesProvider.notifier).removeFile(index);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    List files,
    int totalPages,
    int totalSize,
    bool canProceed,
  ) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (files.isNotEmpty) ...[
              // Summary Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem(
                    Icons.description,
                    '${files.length} File${files.length > 1 ? 's' : ''}',
                  ),
                  _buildSummaryItem(
                    Icons.layers,
                    '$totalPages Pages',
                  ),
                  _buildSummaryItem(
                    Icons.storage,
                    formatFileSize(totalSize),
                  ),
                ],
              ).animate().fadeIn(duration: 300.ms),
              const SizedBox(height: AppTheme.spacingMD),
            ],
            
            // Action Button
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: canProceed ? 'Configure Print Settings' : 'Select Files to Continue',
                icon: canProceed ? Icons.arrow_forward : Icons.upload_file,
                onPressed: canProceed
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ConfigureScreen()),
                        )
                    : _pickFiles,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
