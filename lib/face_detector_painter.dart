import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'coordinates_translator.dart';

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(
      this.faces, this.imageSize, this.rotation, this.cameraLensDirection,
      {this.name, required this.faceMatched});

  final String? name;
  final bool faceMatched;
  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final identifiedName = faceMatched ? name : 'Unknown';

    final Paint paint1 = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = faceMatched ? Colors.green : Colors.red;
    final Paint paint2 = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 1.0
      ..color = Colors.green;

    for (final Face face in faces) {
      TextSpan span = TextSpan(
        text: identifiedName,
        style: TextStyle(
          color: faceMatched ? Colors.green : Colors.red,
          fontSize: 16.0,
        ),
      );

      TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
      );

      tp.layout();
      final left = translateX(
        face.boundingBox.left,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final top = translateY(
        face.boundingBox.top,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final right = translateX(
        face.boundingBox.right,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );
      final bottom = translateY(
        face.boundingBox.bottom,
        size,
        imageSize,
        rotation,
        cameraLensDirection,
      );

      canvas.drawRect(
        Rect.fromLTRB(left, top, right, bottom),
        paint1,
      );
      tp.paint(canvas, Offset(right, top));
      void paintContour(FaceContourType type) {
        final contour = face.contours[type];
        if (contour?.points != null) {
          for (final Point point in contour!.points) {
            canvas.drawCircle(
                Offset(
                  translateX(
                    point.x.toDouble(),
                    size,
                    imageSize,
                    rotation,
                    cameraLensDirection,
                  ),
                  translateY(
                    point.y.toDouble(),
                    size,
                    imageSize,
                    rotation,
                    cameraLensDirection,
                  ),
                ),
                1,
                paint1);
          }
        }
      }
      //
      // void paintLandmark(FaceLandmarkType type) {
      //   final landmark = face.landmarks[type];
      //   if (landmark?.position != null) {
      //     canvas.drawCircle(
      //         Offset(
      //           translateX(
      //             landmark!.position.x.toDouble(),
      //             size,
      //             imageSize,
      //             rotation,
      //             cameraLensDirection,
      //           ),
      //           translateY(
      //             landmark.position.y.toDouble(),
      //             size,
      //             imageSize,
      //             rotation,
      //             cameraLensDirection,
      //           ),
      //         ),
      //         2,
      //         paint2);
      //   }
      // }
      //
      // for (final type in FaceContourType.values) {
      //   paintContour(type);
      // }
      //
      // for (final type in FaceLandmarkType.values) {
      //   paintLandmark(type);
      // }
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.faces != faces;
  }
}
