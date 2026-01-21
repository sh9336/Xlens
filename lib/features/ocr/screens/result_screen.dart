import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import 'package:clipboard/clipboard.dart';
import 'dart:developer' as developer;
import '../../../../core/utils/snackbar_utils.dart';
import '../bloc/ocr_bloc.dart';
import '../bloc/ocr_state.dart';
import '../bloc/ocr_event.dart';
import '../services/file_service.dart';
import 'widgets/text_output.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSavingTxt = false;
  bool _isSavingPdf = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Scan Results'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.read<OcrBloc>().add(OcrClearEvent());
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to Clipboard',
            onPressed: () {
              final state = context.read<OcrBloc>().state;
              if (state.result != null) {
                developer.log('Copying text to clipboard');
                FlutterClipboard.copy(state.result!.text).then((value) {
                  if (context.mounted) {
                    SnackbarUtils.showSnackBar(
                      context,
                      'Text copied to clipboard',
                    );
                  }
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () {
              final state = context.read<OcrBloc>().state;
              if (state.result != null) {
                developer.log('Sharing text');
                Share.share(state.result!.text);
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<OcrBloc, OcrState>(
        builder: (context, state) {
          if (state.status == OcrStatus.success && state.result != null) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cropped Image Display
                  if (state.croppedImage != null)
                    Container(
                      height: 200,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? theme.cardColor,
                        border: Border.all(
                          color: theme.dividerColor.withOpacity(0.1),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          state.croppedImage!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  // Character count info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${state.result!.characters} characters detected',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: TextOutput(text: state.result!.text),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Center(
              child: Text(
                'No result available.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }
        },
      ),
      bottomNavigationBar: BlocBuilder<OcrBloc, OcrState>(
        builder: (context, state) {
          if (state.status == OcrStatus.success && state.result != null) {
            return Container(
              padding: const EdgeInsets.all(
                16,
              ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.description),
                      label: _isSavingTxt
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Save TXT'),
                      onPressed: _isSavingTxt
                          ? null
                          : () => _saveTextFile(state.result!.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf),
                      label: _isSavingPdf
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text('Save PDF'),
                      onPressed: _isSavingPdf
                          ? null
                          : () => _savePdfFile(state.result!.text),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _saveTextFile(String text) async {
    setState(() => _isSavingTxt = true);
    try {
      developer.log('Starting text file save');
      final path = await FileService().saveTextFile(text);
      if (mounted) {
        SnackbarUtils.showSnackBar(context, 'Saved to Downloads/OCR folder');
        developer.log('Text file saved: $path');
      }
    } catch (e) {
      if (mounted) {
        developer.log('Error saving text file: $e', error: e);
        SnackbarUtils.showSnackBar(
          context,
          'Failed to save: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingTxt = false);
      }
    }
  }

  Future<void> _savePdfFile(String text) async {
    setState(() => _isSavingPdf = true);
    try {
      developer.log('Starting PDF file save');
      final path = await FileService().savePdfFile(text);
      if (mounted) {
        SnackbarUtils.showSnackBar(context, 'Saved to Downloads/OCR folder');
        developer.log('PDF file saved: $path');
      }
    } catch (e) {
      if (mounted) {
        developer.log('Error saving PDF file: $e', error: e);
        SnackbarUtils.showSnackBar(
          context,
          'Failed to save: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPdf = false);
      }
    }
  }
}
