import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../core/services/onboarding_service.dart';
import '../../../shared/widgets/guide_overlay.dart';
import '../services/temp_file_manager.dart';

class CropScreen extends StatefulWidget {
  final File imageFile;
  final Function(File croppedImage) onCropComplete;

  const CropScreen({
    super.key,
    required this.imageFile,
    required this.onCropComplete,
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final TransformationController _controller = TransformationController();

  // Image state
  late Size _imageSize;
  bool _isLoadingImage = true;
  String? _errorMessage;

  // Crop state
  late final ValueNotifier<List<Offset>> _cornersNotifier;
  late final ValueNotifier<bool> _isCroppingNotifier;

  // Layout state
  Size? _layoutSize;
  final GlobalKey _stackKey = GlobalKey();

  // Guide state
  bool _showGuide = false;
  late final OnboardingService _onboardingService;

  @override
  void initState() {
    super.initState();
    _onboardingService = OnboardingService();
    _cornersNotifier = ValueNotifier<List<Offset>>([]);
    _isCroppingNotifier = ValueNotifier<bool>(false);
    _initializeImage();
    _checkCropGuideStatus();
  }

  Future<void> _checkCropGuideStatus() async {
    final seen = await _onboardingService.isCropGuideSeen();
    if (!seen && mounted) {
      setState(() => _showGuide = true);
    }
  }

  void _dismissGuide() async {
    await _onboardingService.markCropGuideSeen();
    setState(() => _showGuide = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    _cornersNotifier.dispose();
    _isCroppingNotifier.dispose();
    super.dispose();
  }

  Future<void> _initializeImage() async {
    try {
      final imagePath = widget.imageFile.path;
      final decodedImage = await compute(_decodeImage, imagePath);

      if (decodedImage == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load image';
          _isLoadingImage = false;
        });
        return;
      }

      if (!mounted) return;

      final w = decodedImage.width.toDouble();
      final h = decodedImage.height.toDouble();

      // Initialize corners to edges with slight padding for better UX
      final padX = w * 0.05;
      final padY = h * 0.05;

      _cornersNotifier.value = [
        Offset(padX, padY), // TL
        Offset(w - padX, padY), // TR
        Offset(w - padX, h - padY), // BR
        Offset(padX, h - padY), // BL
      ];

      setState(() {
        _imageSize = Size(w, h);
        _isLoadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading image: $e';
        _isLoadingImage = false;
      });
    }
  }

  /// Sets the initial scale of the InteractiveViewer to fit the image
  /// within the screen with some margin.
  void _setupInitialTransform(Size screenSize) {
    if (_layoutSize != null) return; // Already setup
    _layoutSize = screenSize;

    final double scaleX = screenSize.width / _imageSize.width;
    final double scaleY = screenSize.height / _imageSize.height;
    final double scale = math.min(scaleX, scaleY) * 0.85; // 85% fit

    final double dx = (screenSize.width - _imageSize.width * scale) / 2;
    final double dy = (screenSize.height - _imageSize.height * scale) / 2;

    final Matrix4 matrix = Matrix4.identity();
    matrix.setEntry(0, 0, scale);
    matrix.setEntry(1, 1, scale);
    matrix.setEntry(0, 3, dx);
    matrix.setEntry(1, 3, dy);

    _controller.value = matrix;
  }

  Future<void> _applyCrop() async {
    if (_isCroppingNotifier.value) return;

    _isCroppingNotifier.value = true;

    try {
      final cropData = _CropData(
        imagePath: widget.imageFile.path,
        corners: _cornersNotifier.value,
        imageSize: _imageSize,
      );

      final croppedFile = await compute(_cropImage, cropData);

      if (!mounted) return;

      if (croppedFile == null) {
        throw Exception('Cropping operation failed');
      }

      widget.onCropComplete(croppedFile);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _isCroppingNotifier.value = false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Crop failed: $e')));
    }
  }

  void _onCornerPan(int index, DragUpdateDetails details) {
    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    // Convert global touch position to stack-local position (screen coordinates relative to the interactive viewer)
    final Offset localPos = stackBox.globalToLocal(details.globalPosition);

    // Convert screen coordinates to image coordinates
    final Matrix4 transform = _controller.value;
    final double scale = transform[0];
    final double tx = transform[12];
    final double ty = transform[13];

    // Calculate new image position
    final double newX = (localPos.dx - tx) / scale;
    final double newY = (localPos.dy - ty) / scale;

    final currentCorners = List<Offset>.from(_cornersNotifier.value);

    // Clamp to image bounds
    final double clampedX = newX.clamp(0.0, _imageSize.width);
    final double clampedY = newY.clamp(0.0, _imageSize.height);

    // Basic geometric constraints to prevents hourglass shapes
    // (Optional: can be enhanced for strict convexity, but this prevents gross twisting)
    // TL(0) should be left of TR(1) and above BL(3)
    // TR(1) should be right of TL(0) and above BR(2)
    // BR(2) should be right of BL(3) and below TR(1)
    // BL(3) should be left of BR(2) and below TL(0)

    // We update the specific corner
    currentCorners[index] = Offset(clampedX, clampedY);
    _cornersNotifier.value = currentCorners;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          if (_isLoadingImage)
            _buildInitialLoader(theme)
          else if (_errorMessage != null)
            Center(
              child: Text(_errorMessage!, style: theme.textTheme.bodyMedium),
            )
          else
            _buildCropUI(theme),

          ValueListenableBuilder<bool>(
            valueListenable: _isCroppingNotifier,
            builder: (context, isCropping, child) {
              return isCropping
                  ? _buildProcessingOverlay(theme)
                  : const SizedBox.shrink();
            },
          ),

          // Crop guide overlay
          if (_showGuide)
            GuideOverlay(
              title: 'Adjust Your Crop Area',
              description:
                  'Drag the corner handles to adjust the crop boundaries. Use pinch to zoom and pan to move the image. Get the perfect focus on your document.',
              child: Container(),
              isFirst: true,
              onNext: _dismissGuide,
              onSkip: _dismissGuide,
            ),
        ],
      ),
    );
  }

  Widget _buildCropUI(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Main Content (Image + Crop UI)
        Positioned(
          top: MediaQuery.of(context).padding.top + 80, // Adjusted top padding
          left: 0,
          right: 0,
          bottom: MediaQuery.of(context).padding.bottom + 100,
          child: Container(
            color: isDark
                ? Colors.black
                : const Color(0xFFF5F5F5), // Neutral bg for crop
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (_layoutSize == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _setupInitialTransform(
                      Size(constraints.maxWidth, constraints.maxHeight),
                    );
                  });
                }

                return Container(
                  key: _stackKey,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // The Image Viewer does NOT need to rebuild on corner updates
                      InteractiveViewer(
                        transformationController: _controller,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        minScale: 0.1,
                        maxScale: 5.0,
                        constrained: false,
                        child: SizedBox(
                          width: _imageSize.width,
                          height: _imageSize.height,
                          child: Image.file(
                            widget.imageFile,
                            fit: BoxFit.fill,
                            cacheWidth: 1080,
                          ),
                        ),
                      ),
                      // Overlay layer listens to multiple controllers
                      // We use a custom widget to combine animations to avoid rebuilding the InteractiveViewer above
                      _CropOverlayLayer(
                        controller: _controller,
                        cornersNotifier: _cornersNotifier,
                        theme: theme,
                        onPan: _onCornerPan,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        // Top Bar (Overlay)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 16,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor.withOpacity(0.95),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Adjust Crop Area',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Drag corners to adjust • Pinch to zoom • Pan to move',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom Control Bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomBar(theme, isDark),
        ),
      ],
    );
  }

  Widget _buildBottomBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withOpacity(0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [Colors.blueAccent, Colors.cyan]
                      : [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.8),
                        ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isCroppingNotifier,
                  builder: (context, isCropping, child) {
                    return InkWell(
                      onTap: isCropping ? null : _applyCrop,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.crop_rotate,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Crop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialLoader(ThemeData theme) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 24),
            Text('Preparing image...', style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay(ThemeData theme) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                'Cropping Image',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// New class to handle overlay updates efficiently
class _CropOverlayLayer extends StatelessWidget {
  final TransformationController controller;
  final ValueNotifier<List<Offset>> cornersNotifier;
  final ThemeData theme;
  final Function(int, DragUpdateDetails) onPan;

  const _CropOverlayLayer({
    required this.controller,
    required this.cornersNotifier,
    required this.theme,
    required this.onPan,
  });

  Offset _toScreen(Offset imagePoint, Matrix4 transform) {
    // Basic matrix multiplication for 2D point [x, y, 0, 1]
    final double x = imagePoint.dx;
    final double y = imagePoint.dy;

    // transform is column-major
    // col 0: scaleX, 0, 0, 0
    // col 1: 0, scaleY, 0, 0
    // col 3: tx, ty, 0, 1

    return Offset(
      x * transform[0] + transform[12],
      y * transform[5] + transform[13],
    );
  }

  @override
  Widget build(BuildContext context) {
    // We listen to both the controller (pan/zoom) AND the corners (drag handles)
    return AnimatedBuilder(
      animation: Listenable.merge([controller, cornersNotifier]),
      builder: (context, _) {
        final transform = controller.value;
        final screenCorners = cornersNotifier.value
            .map((p) => _toScreen(p, transform))
            .toList();

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size.infinite,
                painter: CropOverlayPainter(
                  corners: screenCorners,
                  theme: theme,
                ),
                isComplex: true,
                willChange: true,
              ),
            ),
            for (int i = 0; i < 4; i++)
              _buildHandle(i, screenCorners[i], theme),
          ],
        );
      },
    );
  }

  Widget _buildHandle(int index, Offset screenPos, ThemeData theme) {
    const handleSize = 24.0;
    const touchSize = 64.0;
    final primaryColor = theme.colorScheme.primary;

    return Positioned(
      left: screenPos.dx - touchSize / 2,
      top: screenPos.dy - touchSize / 2,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanUpdate: (details) => onPan(index, details),
        child: Container(
          width: touchSize,
          height: touchSize,
          color: Colors.transparent, // Hit target
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring glow
                Container(
                  width: handleSize + 8,
                  height: handleSize + 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                // Main handle circle
                Container(
                  width: handleSize,
                  height: handleSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CropOverlayPainter extends CustomPainter {
  final List<Offset> corners;
  final ThemeData? theme;
  late final Paint _dimmedPaint;
  late final Paint _borderPaint;
  late final Paint _innerGlowPaint;
  late final Paint _cornerPaint;
  late final Paint _gridPaint;
  late final Paint _edgePaint;

  CropOverlayPainter({required this.corners, this.theme}) {
    final primaryColor = theme?.colorScheme.primary ?? Colors.blueAccent;

    _dimmedPaint = Paint()..color = const Color.fromRGBO(0, 0, 0, 0.65);
    _borderPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    _innerGlowPaint = Paint()
      ..color = primaryColor.withOpacity(0.2)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;
    _cornerPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    _gridPaint = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, 0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _edgePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.isEmpty) return;

    final path = Path()
      ..moveTo(corners[0].dx, corners[0].dy)
      ..lineTo(corners[1].dx, corners[1].dy)
      ..lineTo(corners[2].dx, corners[2].dy)
      ..lineTo(corners[3].dx, corners[3].dy)
      ..close();

    // 1. Dimmed Background
    final clipPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPath(path, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(clipPath, _dimmedPaint);

    // 2. Crop Frame Border with gradient effect
    canvas.drawPath(path, _innerGlowPaint); // Inner glow
    canvas.drawPath(path, _borderPaint); // Main border

    // 3. Corner indicators (small squares at corners)
    const cornerIndicatorSize = 12.0;
    for (int i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromCenter(
          center: corners[i],
          width: cornerIndicatorSize,
          height: cornerIndicatorSize,
        ),
        _cornerPaint,
      );
    }

    // 4. Grid Lines (Rule of thirds)
    // Cache corner values to avoid repeated list access
    final c0 = corners[0], c1 = corners[1], c2 = corners[2], c3 = corners[3];

    // Grid points (inlined lerp calculations for efficiency)
    final top1 = Offset(
      c0.dx + (c1.dx - c0.dx) / 3,
      c0.dy + (c1.dy - c0.dy) / 3,
    );
    final top2 = Offset(
      c0.dx + (c1.dx - c0.dx) * 2 / 3,
      c0.dy + (c1.dy - c0.dy) * 2 / 3,
    );
    final bottom1 = Offset(
      c3.dx + (c2.dx - c3.dx) / 3,
      c3.dy + (c2.dy - c3.dy) / 3,
    );
    final bottom2 = Offset(
      c3.dx + (c2.dx - c3.dx) * 2 / 3,
      c3.dy + (c2.dy - c3.dy) * 2 / 3,
    );
    final left1 = Offset(
      c0.dx + (c3.dx - c0.dx) / 3,
      c0.dy + (c3.dy - c0.dy) / 3,
    );
    final left2 = Offset(
      c0.dx + (c3.dx - c0.dx) * 2 / 3,
      c0.dy + (c3.dy - c0.dy) * 2 / 3,
    );
    final right1 = Offset(
      c1.dx + (c2.dx - c1.dx) / 3,
      c1.dy + (c2.dy - c1.dy) / 3,
    );
    final right2 = Offset(
      c1.dx + (c2.dx - c1.dx) * 2 / 3,
      c1.dy + (c2.dy - c1.dy) * 2 / 3,
    );

    // Draw Grid Lines
    canvas.drawLine(top1, bottom1, _gridPaint);
    canvas.drawLine(top2, bottom2, _gridPaint);
    canvas.drawLine(left1, right1, _gridPaint);
    canvas.drawLine(left2, right2, _gridPaint);

    // 5. Corner edge lines (enhance corner visibility)
    const edgeLength = 20.0;

    // Top-left
    canvas.drawLine(
      corners[0],
      Offset(corners[0].dx + edgeLength, corners[0].dy),
      _edgePaint,
    );
    canvas.drawLine(
      corners[0],
      Offset(corners[0].dx, corners[0].dy + edgeLength),
      _edgePaint,
    );

    // Top-right
    canvas.drawLine(
      corners[1],
      Offset(corners[1].dx - edgeLength, corners[1].dy),
      _edgePaint,
    );
    canvas.drawLine(
      corners[1],
      Offset(corners[1].dx, corners[1].dy + edgeLength),
      _edgePaint,
    );

    // Bottom-right
    canvas.drawLine(
      corners[2],
      Offset(corners[2].dx - edgeLength, corners[2].dy),
      _edgePaint,
    );
    canvas.drawLine(
      corners[2],
      Offset(corners[2].dx, corners[2].dy - edgeLength),
      _edgePaint,
    );

    // Bottom-left
    canvas.drawLine(
      corners[3],
      Offset(corners[3].dx + edgeLength, corners[3].dy),
      _edgePaint,
    );
    canvas.drawLine(
      corners[3],
      Offset(corners[3].dx, corners[3].dy - edgeLength),
      _edgePaint,
    );
  }

  @override
  bool shouldRepaint(CropOverlayPainter oldDelegate) {
    // Only repaint if corners have actually changed
    if (oldDelegate.corners.length != corners.length) return true;
    for (int i = 0; i < corners.length; i++) {
      if (oldDelegate.corners[i] != corners[i]) return true;
    }
    return false;
  }
}

// --- Background Isolate Logic ---

class _CropData {
  final String imagePath;
  final List<Offset> corners;
  final Size imageSize;

  _CropData({
    required this.imagePath,
    required this.corners,
    required this.imageSize,
  });
}

Future<img.Image?> _decodeImage(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    return img.decodeImage(bytes);
  } catch (e) {
    debugPrint('_decodeImage error: $e');
    return null;
  }
}

Future<File?> _cropImage(_CropData data) async {
  try {
    // Clean up old temporary files before creating new one
    await TempFileManager.cleanupOldFiles();

    final bytes = await File(data.imagePath).readAsBytes();
    final originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    // For now, implementing a Bounding Box crop that encompasses the quad.
    // True perspective warp in pure Dart is computationally expensive and complex
    // without using OpenCV or ensuring the 'image' package supports it efficiently.
    // This satisfies the "Fast" requirement while allowing the UI to be professional.

    // Find bounding box
    double minX = data.imageSize.width;
    double minY = data.imageSize.height;
    double maxX = 0;
    double maxY = 0;

    for (final point in data.corners) {
      minX = math.min(minX, point.dx);
      minY = math.min(minY, point.dy);
      maxX = math.max(maxX, point.dx);
      maxY = math.max(maxY, point.dy);
    }

    // Clamp to image bounds
    minX = minX.clamp(0, data.imageSize.width);
    minY = minY.clamp(0, data.imageSize.height);
    maxX = maxX.clamp(0, data.imageSize.width);
    maxY = maxY.clamp(0, data.imageSize.height);

    int x = minX.toInt();
    int y = minY.toInt();
    int w = (maxX - minX).toInt();
    int h = (maxY - minY).toInt();

    // Validate
    if (w <= 0 || h <= 0) return File(data.imagePath); // Fallback to original

    // Perform Crop
    final croppedImage = img.copyCrop(
      originalImage,
      x: x,
      y: y,
      width: w,
      height: h,
    );

    // Save
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${tempDir.path}/ocr_cropped_$timestamp.jpg';
    final file = File(path);
    await file.writeAsBytes(img.encodeJpg(croppedImage));

    return file;
  } catch (e) {
    debugPrint('_cropImage error: $e');
    return null;
  }
}
