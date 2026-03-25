import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../status/status_screen.dart';

class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final List<String> _logs = [];
  final ScrollController _logScrollController = ScrollController();
  bool _showLogs = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Defer processing to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startProcessing();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _logScrollController.dispose();
    super.dispose();
  }
  
  void _addLog(String message) {
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now().toString().substring(11, 19);
        _logs.add('[$timestamp] $message');
      });
      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.animateTo(
            _logScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }
  
  void _copyLogs() {
    final logText = _logs.join('\n');
    Clipboard.setData(ClipboardData(text: logText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _startProcessing() async {
    _addLog('Starting order processing...');
    final order = await ref.read(orderProcessingProvider.notifier).processOrder(
      onLog: _addLog,
    );
    
    _addLog('Processing complete. Order: ${order?.orderId ?? "null"}');
    
    if (mounted && order != null) {
      // Defer navigation to next frame to avoid provider modification during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => StatusScreen(order: order),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final processingState = ref.watch(orderProcessingProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            children: [
              // Processing Animation (smaller)
              const SizedBox(height: AppTheme.spacingMD),
              SizedBox(
                height: 80,
                child: _buildProcessingAnimation(processingState),
              ),

              const SizedBox(height: AppTheme.spacingMD),

              // Status Text
              Text(
                processingState.currentStep ?? 'Initializing...',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spacingSM),

              // Progress Bar
              _buildProgressBar(processingState.progress),

              const SizedBox(height: AppTheme.spacingSM),

              Text(
                '${(processingState.progress * 100).toInt()}% Complete',
                style: const TextStyle(
                  color: AppTheme.textMutedDark,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),

              const SizedBox(height: AppTheme.spacingMD),

              // Live Debug Log Panel (only in debug mode)
              if (kDebugMode) _buildLogPanel(),

              const SizedBox(height: AppTheme.spacingMD),

              // Steps Indicator (compact)
              _buildStepsIndicator(processingState),

              const SizedBox(height: AppTheme.spacingMD),

              // Error State
              if (processingState.error != null)
                _buildErrorCard(processingState.error!),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogPanel() {
    return Expanded(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.deepPurple,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusSM),
                  topRight: Radius.circular(AppTheme.radiusSM),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Live Debug Log (${_logs.length} entries)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  // Copy button
                  InkWell(
                    onTap: _copyLogs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Toggle button
                  InkWell(
                    onTap: () => setState(() => _showLogs = !_showLogs),
                    child: Icon(
                      _showLogs ? Icons.visibility_off : Icons.visibility,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (_showLogs)
              Expanded(
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Waiting for logs...',
                          style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                        ),
                      )
                    : ListView.builder(
                        controller: _logScrollController,
                        padding: const EdgeInsets.all(8),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final isError = log.contains('ERROR') || log.contains('TIMEOUT') || log.contains('Exception');
                          final isSuccess = log.contains('SUCCESS') || log.contains('✓') || log.contains('complete');
                          final isWarning = log.contains('WARNING');
                          return Text(
                            log,
                            style: TextStyle(
                              color: isError
                                  ? Colors.red[400]
                                  : isSuccess
                                      ? Colors.green[400]
                                      : isWarning
                                          ? Colors.orange[400]
                                          : Colors.green[200],
                              fontFamily: 'monospace',
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
              )
            else
              const Expanded(
                child: Center(
                  child: Text(
                    'Logs hidden',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingAnimation(ProcessingState state) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer pulse rings
        ...List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final progress = (_pulseController.value + (index * 0.3)) % 1.0;
              return Container(
                width: 120 + (progress * 80),
                height: 120 + (progress * 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.3 * (1 - progress)),
                    width: 2,
                  ),
                ),
              );
            },
          );
        }),
        
        // Inner circle with icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppTheme.glowShadow,
          ),
          child: Icon(
            _getStepIcon(state.currentStep),
            color: Colors.white,
            size: 40,
          ),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
      ],
    );
  }

  IconData _getStepIcon(String? step) {
    if (step == null) return Icons.hourglass_empty;
    if (step.contains('front page')) return Icons.article;
    if (step.contains('Merging')) return Icons.merge_type;
    if (step.contains('Uploading')) return Icons.cloud_upload;
    if (step.contains('Queuing')) return Icons.queue;
    if (step.contains('submitted')) return Icons.check_circle;
    return Icons.sync;
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: MediaQuery.of(context).size.width * progress * 0.9,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
              ),
            ),
            // Shimmer effect
            Positioned.fill(
              child: Container()
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(duration: 1500.ms, color: Colors.white24),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsIndicator(ProcessingState state) {
    final steps = [
      {'text': 'Preparing Order', 'threshold': 0.1},
      {'text': 'Generating Front Page', 'threshold': 0.3},
      {'text': 'Merging PDFs', 'threshold': 0.5},
      {'text': 'Uploading', 'threshold': 0.7},
      {'text': 'Complete', 'threshold': 1.0},
    ];

    return GlassCard(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          final isCompleted = state.progress >= (step['threshold'] as double);
          final isCurrent = state.progress < (step['threshold'] as double) &&
              (index == 0 || state.progress >= (steps[index - 1]['threshold'] as double));

          return Padding(
            padding: EdgeInsets.only(bottom: index < steps.length - 1 ? 12 : 0),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppTheme.successColor
                        : isCurrent
                            ? AppTheme.primaryColor
                            : AppTheme.surfaceBorder,
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check
                        : isCurrent
                            ? Icons.sync
                            : Icons.circle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step['text'] as String,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted || isCurrent
                          ? null
                          : AppTheme.textMutedDark,
                    ),
                  ),
                ),
                if (isCurrent)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return GlassCard(
      gradient: LinearGradient(
        colors: [
          AppTheme.errorColor.withOpacity(0.2),
          AppTheme.errorColor.withOpacity(0.1),
        ],
      ),
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.errorColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: AppTheme.errorColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMD),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
              ),
              child: const Text('Go Back'),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().shake();
  }
}
