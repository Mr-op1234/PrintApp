import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../providers/providers.dart';
import '../../widgets/common_widgets.dart';
import '../../services/storage_service.dart';
import '../../utils/helpers.dart';
import '../payment/payment_screen.dart';

class StudentDetailsScreen extends ConsumerStatefulWidget {
  const StudentDetailsScreen({super.key});

  @override
  ConsumerState<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends ConsumerState<StudentDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _idController;
  late TextEditingController _phoneController;
  late TextEditingController _additionalInfoController;
  bool _saveForLater = true;

  @override
  void initState() {
    super.initState();
    final details = ref.read(studentDetailsProvider);
    _nameController = TextEditingController(text: details.name);
    _idController = TextEditingController(text: details.studentId);
    _phoneController = TextEditingController(text: details.phone);
    _additionalInfoController = TextEditingController(text: details.additionalInfo);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    _additionalInfoController.dispose();
    super.dispose();
  }

  void _loadSavedDetails() {
    final saved = StorageService.getSavedStudentDetails();
    if (saved != null) {
      setState(() {
        _nameController.text = saved.name;
        _idController.text = saved.studentId;
        _phoneController.text = saved.phone;
        _additionalInfoController.text = saved.additionalInfo;
      });
      _updateProvider();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loaded saved details'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved details found'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _updateProvider() {
    ref.read(studentDetailsProvider.notifier).updateName(_nameController.text);
    ref.read(studentDetailsProvider.notifier).updateStudentId(_idController.text);
    ref.read(studentDetailsProvider.notifier).updatePhone(_phoneController.text);
    ref.read(studentDetailsProvider.notifier).updateAdditionalInfo(_additionalInfoController.text);
  }

  Future<void> _proceed() async {
    if (_formKey.currentState!.validate()) {
      _updateProvider();
      
      if (_saveForLater) {
        await ref.read(studentDetailsProvider.notifier).saveForLater();
      }
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaymentScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasSavedDetails = StorageService.getSavedStudentDetails() != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Details'),
        actions: [
          if (hasSavedDetails)
            TextButton.icon(
              onPressed: _loadSavedDetails,
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Load Saved'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMD),
            child: const ProgressStepper(
              currentStep: 2,
              steps: ['Files', 'Config', 'Details', 'Payment', 'Done'],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Your Information',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ).animate().fadeIn().slideX(begin: -0.05, end: 0),
                    
                    const SizedBox(height: AppTheme.spacingSM),
                    
                    Text(
                      'Please provide your details for order tracking and communication',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ).animate().fadeIn(delay: 100.ms),

                    const SizedBox(height: AppTheme.spacingLG),

                    // Name Field
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'Enter your full name',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        if (value.length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                      delay: 0,
                    ),

                    const SizedBox(height: AppTheme.spacingMD),

                    // Enrollment No. Field
                    _buildTextField(
                      controller: _idController,
                      label: 'Enrollment No.',
                      hint: 'Enter your enrollment number',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your enrollment number';
                        }
                        // Only allow numbers, max 14 digits
                        if (!RegExp(r'^\d{1,14}$').hasMatch(value)) {
                          return 'Enrollment No. must be numbers only (max 14 digits)';
                        }
                        return null;
                      },
                      delay: 50,
                    ),

                    const SizedBox(height: AppTheme.spacingMD),

                    // Phone Field
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      hint: 'Enter your phone number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!isValidPhone(value)) {
                          return 'Please enter a valid 10-digit phone number';
                        }
                        return null;
                      },
                      delay: 100,
                    ),

                    const SizedBox(height: AppTheme.spacingMD),

                    // Additional Information Field (Optional)
                    _buildTextField(
                      controller: _additionalInfoController,
                      label: 'Additional Information (Optional)',
                      hint: 'Any special instructions or notes for the print shop',
                      icon: Icons.note_outlined,
                      keyboardType: TextInputType.multiline,
                      validator: (value) => null, // Optional field, no validation
                      delay: 150,
                      maxLines: 3,
                    ),

                    const SizedBox(height: AppTheme.spacingLG),

                    // Save for later checkbox
                    GlassCard(
                      onTap: () => setState(() => _saveForLater = !_saveForLater),
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      margin: EdgeInsets.zero,
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _saveForLater
                                  ? AppTheme.primaryColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _saveForLater
                                    ? AppTheme.primaryColor
                                    : AppTheme.surfaceBorder,
                                width: 2,
                              ),
                            ),
                            child: _saveForLater
                                ? const Icon(
                                    Icons.check,
                                    size: 16,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppTheme.spacingMD),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Save details for later',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Pre-fill this form for future orders',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textMutedDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: AppTheme.spacingMD),

                    // Privacy notice
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 16,
                          color: AppTheme.textMutedDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your information is stored securely and only used for order fulfillment',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    required int delay,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: (_) => _updateProvider(),
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            alignLabelWithHint: maxLines > 1,
          ),
        ),
      ],
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideX(begin: 0.05, end: 0);
  }

  Widget _buildBottomBar(BuildContext context) {
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
        child: SizedBox(
          width: double.infinity,
          child: GradientButton(
            text: 'Proceed to Payment',
            icon: Icons.payment,
            onPressed: _proceed,
          ),
        ),
      ),
    );
  }
}
