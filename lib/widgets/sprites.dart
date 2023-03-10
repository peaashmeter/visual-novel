import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:visual_novel/core/director.dart';
import 'package:visual_novel/widgets/painting/spritepainter.dart';

class SpriteLayer extends StatefulWidget {
  final ValueNotifier<Offset> mousePosNotifier;
  const SpriteLayer({super.key, required this.mousePosNotifier});

  @override
  State<SpriteLayer> createState() => _SpriteLayerState();
}

class _SpriteLayerState extends State<SpriteLayer> {
  //Отношение перемещения фона к перемещению мыши
  final parallaxFactor = 0.005;

  late Future<Map<Offset, Image>> imagesFuture;

  @override
  Widget build(BuildContext context) {
    final center = MediaQuery.of(context).size / 2;

    return ValueListenableBuilder(
      valueListenable: Director().sprites,
      builder: (context, sprites, child) {
        imagesFuture = loadImages(sprites ?? {});
        return FutureBuilder(
            future: imagesFuture,
            builder: (context, snapshot) {
              final images = snapshot.data?.values.toList() ?? [];
              final offsets = snapshot.data?.keys.toList() ?? [];

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ValueListenableBuilder(
                      valueListenable: widget.mousePosNotifier,
                      builder: (context, mousePos, _) {
                        return Transform.translate(
                          offset: _calculateParallax(mousePos, center),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                child: CustomPaint(
                  key: ValueKey(Director().currentSceneId.value),
                  painter: SpritePainter(images, offsets),
                  child: Container(),
                ),
              );
            });
      },
    );
  }

  Future<Map<Offset, Image>> loadImages(Map<String, String> sprites) async {
    final offsets = <Offset>[];
    final images = <Image>[];

    final root = Director().preferences.spritesRoot;

    for (var k in sprites.keys) {
      final offset = Director().preferences.spritePositions[k];
      assert(offset != null);
      offsets.add(offset!);
    }
    for (var v in sprites.values) {
      try {
        final bytes = await rootBundle.load('$root$v');
        final image = await decodeImageFromList(Uint8List.view(bytes.buffer));
        images.add(image);
      } catch (e) {
        if (kDebugMode) {
          print(e);
        }
        return {};
      }
    }

    return Map.fromIterables(offsets, images);
  }

  Offset _calculateParallax(Offset mousePos, Size center) {
    //Рассматриваем это как вектор с измерениями вдвое меньше размеров экрана
    //(x, y) = (width, heigth)
    final center = MediaQuery.of(context).size / 2;

    final offsetX = (center.width - mousePos.dx) * parallaxFactor;
    final offsetY = (center.height - mousePos.dy) * parallaxFactor;

    return Offset(offsetX, offsetY);
  }
}
