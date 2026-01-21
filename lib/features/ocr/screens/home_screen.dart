import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../core/services/theme_service.dart';
import '../../../main.dart';
import '../bloc/ocr_bloc.dart';
import '../bloc/ocr_event.dart';
import '../bloc/ocr_state.dart';
import '../services/image_service.dart';
import '../services/permission_service.dart';
import 'result_screen.dart';
import 'crop_screen.dart';
import 'widgets/empty_state.dart';
import 'widgets/image_preview.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/error_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isNavigating = false;
  late final OnboardingService _onboardingService;
  late final ThemeService _themeService;

  @override
  void initState() {
    super.initState();
    _onboardingService = OnboardingService();
    _onboardingService.initialize();
    _themeService = ThemeService();
    _themeService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: theme.brightness == Brightness.dark
                  ? [
                      Colors.blueAccent.shade700,
                      Colors.cyan.shade700,
                    ] // Richer deep gradient for dark mode
                  : [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ], // Brand gradient for light mode
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Xlens OCR',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: Colors.white, // White text for contrast against gradient
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        centerTitle: false,
        actions: [
          // Theme Switcher
          PopupMenuButton<AppThemeMode>(
            icon: const Icon(Icons.palette_outlined, size: 22),
            tooltip: 'Theme Settings',
            onSelected: (AppThemeMode mode) async {
              themeNotifier.value = mode;
              await _themeService.setThemeMode(mode);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    behavior: SnackBarBehavior.floating,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    backgroundColor: Colors.green,
                    content: Text(
                      'Theme changed to ${mode.name.replaceFirst(mode.name[0], mode.name[0].toUpperCase())}',
                    ),
                    duration: const Duration(milliseconds: 1200),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<AppThemeMode>(
                value: AppThemeMode.system,
                child: Row(
                  children: [
                    Icon(Icons.brightness_auto, size: 20),
                    SizedBox(width: 12),
                    Text('System'),
                  ],
                ),
              ),
              const PopupMenuItem<AppThemeMode>(
                value: AppThemeMode.light,
                child: Row(
                  children: [
                    Icon(Icons.brightness_7, size: 20),
                    SizedBox(width: 12),
                    Text('Light'),
                  ],
                ),
              ),
              const PopupMenuItem<AppThemeMode>(
                value: AppThemeMode.dark,
                child: Row(
                  children: [
                    Icon(Icons.brightness_4, size: 20),
                    SizedBox(width: 12),
                    Text('Dark'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Reset Guides Button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Tooltip(
                message: 'Reset Guides',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await _onboardingService.resetAllGuides();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            backgroundColor: Colors.green,
                            duration: Duration(milliseconds: 1500),
                            content: Text(
                              'Guides reset! They will show on next action.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Icon(Icons.info_outline, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: BlocConsumer<OcrBloc, OcrState>(
        listener: (context, state) {
          // Prevent multiple simultaneous navigations
          if (_isNavigating) return;

          if (state.status == OcrStatus.imageReady) {
            _isNavigating = true;
            // Navigate to crop screen when image is ready
            Navigator.of(context)
                .push(
                  MaterialPageRoute(
                    builder: (_) => CropScreen(
                      imageFile: state.image!,
                      onCropComplete: (croppedFile) {
                        context.read<OcrBloc>().add(
                          OcrCroppedImageEvent(croppedFile),
                        );
                      },
                    ),
                  ),
                )
                .then((_) {
                  // Reset state if user cancelled crop (back button)
                  // If they cropped, the event inside CropScreen would have changed state to cropReady already
                  // so clearEvent here might override it?
                  // Wait! If they cropped, state changes to cropReady.
                  // If they cancel, state stays imageReady.
                  // We should check state?
                  // Actually, if crop was successful, we are already in cropReady.
                  // If we fire ClearEvent here, we will lose the cropped image!

                  // BETTER APPROACH: Only clear if state is still imageReady (meaning cancelled)
                  final currentState = context.read<OcrBloc>().state;
                  if (currentState.status == OcrStatus.imageReady) {
                    context.read<OcrBloc>().add(OcrClearEvent());
                  }

                  _isNavigating = false;
                });
          } else if (state.status == OcrStatus.success) {
            _isNavigating = true;
            Navigator.of(context)
                .push(
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        const ResultScreen(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          );
                        },
                  ),
                )
                .then((_) {
                  // Reset state to initial so FAB reappears and we don't get stuck
                  context.read<OcrBloc>().add(OcrClearEvent());
                  _isNavigating = false;
                });
          } else if (state.status == OcrStatus.failure) {
            // Handled by UI builder or snackbar
          }
        },
        builder: (context, state) {
          if (state.status == OcrStatus.processing) {
            return const LoadingIndicator(message: 'Processing image...');
          }

          if (state.status == OcrStatus.failure) {
            return ErrorDisplayWidget(
              message: state.errorMessage ?? 'Unknown error',
              onRetry: () {
                context.read<OcrBloc>().add(OcrClearEvent());
              },
            );
          }

          if (state.status == OcrStatus.cropReady) {
            return Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: ImagePreview(file: state.croppedImage!),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    border: Border(
                      top: BorderSide(color: theme.dividerColor, width: 1),
                    ),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              context.read<OcrBloc>().add(OcrClearEvent());
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color:
                                    theme.outlinedButtonTheme.style?.side
                                        ?.resolve({MaterialState.pressed})
                                        ?.color ??
                                    theme.primaryColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text(
                              'Retake Photo',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              context.read<OcrBloc>().add(
                                OcrProcessImageEvent(),
                              );
                            },
                            icon: const Icon(Icons.search, size: 20),
                            label: const Text(
                              'Extract Text',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return EmptyState(onScan: () => _showImageSourceModal(context));
        },
      ),
      floatingActionButton: BlocBuilder<OcrBloc, OcrState>(
        builder: (context, state) {
          if (state.status == OcrStatus.initial) {
            return FloatingActionButton(
              onPressed: () async {
                final permission = await PermissionService()
                    .requestCameraPermission();
                if (permission && context.mounted) {
                  final file = await ImageService().pickImageFromCamera();
                  if (file != null && context.mounted) {
                    context.read<OcrBloc>().add(OcrImagePickedEvent(file));
                  }
                }
              },
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.camera_alt),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showImageSourceModal(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          top: 32,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Select Image Source',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 32),

            // Camera option
            _buildSourceCard(
              context: ctx,
              parentContext: context,
              icon: Icons.camera_alt_rounded,
              title: 'Take Photo',
              description: 'Capture a new image using camera',
              onTap: () async {
                Navigator.pop(ctx);
                final permission = await PermissionService()
                    .requestCameraPermission();
                if (permission && context.mounted) {
                  final file = await ImageService().pickImageFromCamera();
                  if (file != null && context.mounted) {
                    context.read<OcrBloc>().add(OcrImagePickedEvent(file));
                  }
                }
              },
            ),
            const SizedBox(height: 16),

            // Gallery option
            _buildSourceCard(
              context: ctx,
              parentContext: context,
              icon: Icons.image_rounded,
              title: 'Choose from Gallery',
              description: 'Select an existing image from storage',
              onTap: () async {
                Navigator.pop(ctx);
                // Gallery access usually doesn't need explicit runtime permission on newer Android for picker
                final file = await ImageService().pickImageFromGallery();
                if (file != null && context.mounted) {
                  context.read<OcrBloc>().add(OcrImagePickedEvent(file));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard({
    required BuildContext context,
    required BuildContext parentContext,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            border: Border.all(
              color: primaryColor.withOpacity(0.2),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(child: Icon(icon, size: 28, color: primaryColor)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
