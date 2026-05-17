import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'compare_utils.dart';

class OverlayView extends StatelessWidget {
  final ui.Image uiImage1;
  final ui.Image uiImage2;
  final double sliderValue;
  final TransformationController syncTransformationController;

  const OverlayView({
    super.key,
    required this.uiImage1,
    required this.uiImage2,
    required this.sliderValue,
    required this.syncTransformationController,
  });

  @override
  Widget build(BuildContext context) {
    final leftOpacity = 1 - sliderValue;
    final rightOpacity = sliderValue;

    return InteractiveViewer(
      transformationController: syncTransformationController,
      minScale: 0.1,
      maxScale: 10.0,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: leftOpacity,
            child: Image(
              image: UiImageProvider(uiImage1),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          Opacity(
            opacity: rightOpacity,
            child: Image(
              image: UiImageProvider(uiImage2),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ],
      ),
    );
  }
}