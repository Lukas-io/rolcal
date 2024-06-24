import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;

imglib.Image convertToImage(CameraImage image) {
  try {
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _convertYUV420(image);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      return _convertBGRA8888(image);
    } else if (image.format.group == ImageFormatGroup.nv21) {
      return _convertNV21(image);
    } else {
      throw Exception('Image format not supported');
    }
  } catch (e) {
    print("ERROR:" + e.toString());
  }
  throw Exception('Image format not supported');
}

// Convert CameraImage to Image
imglib.Image _convertNV21(CameraImage image) {
  // Assuming NV21 format (U and V interleaved in a single plane)
  Plane plane = image.planes[0];

  int width = image.width;
  int height = image.height;

  // Create an Image from raw bytes
  imglib.Image img = imglib.Image(width, height);

  // NV21 format: YUV interleaved in a single plane (Y, U, Y, V, Y, U, Y, V, ...)
  int uvIndex = 0;
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      int yValue = plane.bytes[y * width + x] & 0xFF;
      int uvValue = plane.bytes[width * height + uvIndex] & 0xFF;

      // Set RGB values with a simple conversion (adjust as needed)
      int r = (yValue + 1.402 * (uvValue - 128)).toInt();
      int g = (yValue - 0.344136 * (uvValue - 128) - 0.714136 * (uvValue - 128))
          .toInt();
      int b = (yValue + 1.772 * (uvValue - 128)).toInt();

      // Clamp values to the valid range (0-255)
      r = r.clamp(0, 255).toInt();
      g = g.clamp(0, 255).toInt();
      b = b.clamp(0, 255).toInt();

      img.setPixel(x, y, imglib.getColor(r, g, b, 255));

      // Increment the UV index every second pixel
      if (x % 2 == 1) {
        uvIndex++;
      }
    }
  }

  imglib.Image rotatedImage = imglib.copyRotate(img, -90);
  return rotatedImage;
}

imglib.Image _convertBGRA8888(CameraImage image) {
  return imglib.Image.fromBytes(
    image.width,
    image.height,
    image.planes[0].bytes,
    format: imglib.Format.bgra,
  );
}

imglib.Image _convertYUV420(CameraImage image) {
  int width = image.width;
  int height = image.height;
  var img = imglib.Image(width, height);
  const int hexFF = 0xFF000000;
  final int uvyButtonStride = image.planes[1].bytesPerRow;
  final int? uvPixelStride = image.planes[1].bytesPerPixel;
  for (int x = 0; x < width; x++) {
    for (int y = 0; y < height; y++) {
      final int uvIndex =
          uvPixelStride! * (x / 2).floor() + uvyButtonStride * (y / 2).floor();
      final int index = y * width + x;
      final yp = image.planes[0].bytes[index];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];
      int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
      int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
          .round()
          .clamp(0, 255);
      int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
      img.data[index] = hexFF | (b << 16) | (g << 8) | r;
    }
  }

  return img;
}
