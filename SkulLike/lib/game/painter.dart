import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'types.dart';
import 'entities.dart';
import 'world.dart';
import 'skulls.dart';

class GamePainter extends CustomPainter {
  final GameWorld world;
  GamePainter(this.world);

  Paint _pixelPaint(Color color) => Paint()..color = color..isAntiAlias = false;

  // Deep-floor "reinforced" look: as stats ramp, foes & bosses steep toward a
  // darkening blood-crimson so the power creep reads visually.
  static const Color _crimson = Color(0xFF5A0A0A);
  double get _reinforce => world.reinforce;
  // shift a base sprite colour toward deepening crimson by the reinforce factor
  Color _reinforced(Color base) {
    final k = _reinforce;
    if (k <= 0) return base;
    final crimsoned = Color.lerp(base, _crimson, k * 0.7)!;
    return Color.lerp(crimsoned, Colors.black, k * 0.22)!;
  }

  void _pixelRect(Canvas canvas, Rect rect, Color color) {
    canvas.drawRect(rect, _pixelPaint(color));
  }

  // soft blurred glow — the cheap workhorse behind the "화려함" pass
  void _glow(Canvas canvas, Offset c, double r, Color color,
      [double sigma = 8]) {
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma));
  }

  // base→[shadow, mid, light] ramp for consistent 3-step pixel shading
  (Color, Color, Color) _ramp(Color base) => (
        Color.lerp(base, const Color(0xFF000000), 0.4)!,
        base,
        Color.lerp(base, const Color(0xFFFFFFFF), 0.32)!,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Render the whole scene into a low-resolution framebuffer, then upscale it
    // nearest-neighbor. This pixelates everything uniformly (true pixel-art look)
    // regardless of how each sprite is drawn.
    final lowW = (kViewW / kPixelScale).round();
    final lowH = (kViewH / kPixelScale).round();
    final recorder = ui.PictureRecorder();
    final lowCanvas = Canvas(recorder);
    lowCanvas.scale(1 / kPixelScale);
    _paintScene(lowCanvas);
    final pic = recorder.endRecording();
    final img = pic.toImageSync(lowW, lowH);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, lowW.toDouble(), lowH.toDouble()),
      const Rect.fromLTWH(0, 0, kViewW, kViewH),
      Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false,
    );
    img.dispose();
    pic.dispose();
  }

  void _paintScene(Canvas canvas) {
    final w = world;
    _background(canvas);

    canvas.save();
    final s = w.shakeOffset;
    // screen-space shake, then zoom, then world camera offset
    canvas.translate(s.dx, s.dy);
    canvas.scale(kZoom, kZoom);
    canvas.translate(-w.camX, -w.camY);

    // carnivorous plants lurk BEHIND the terrain — drawn before the ground so
    // the buried body stays hidden and only the emerged head pops above it.
    for (final e in w.enemies) {
      if (e.kind == EnemyKind.plant) _enemy(canvas, e);
    }

    for (final seg in w.groundSegments) {
      _ground(canvas, seg);
    }
    for (final r in w.platforms) {
      _oneWay(canvas, r);
    }
    _props(canvas, w.props);
    if (w.shieldCrystal != null) _shieldCrystal(canvas, w.shieldCrystal!);

    if (w.town) {
      _blacksmith(canvas, w.blacksmithRect);
      _traitShrine(canvas, w.traitsRect);
      _graveyard(canvas, w.graveyardRect);
      _portal(canvas, w.departRect, '모험 시작 (E)');
    } else {
      for (final d in w.doors) {
        _door(canvas, d, w.roomCleared);
      }
      for (final it in w.shopItems) {
        _shopItem(canvas, it, w.gold);
      }
      if (w.chest != null) _chest(canvas, w.chest!);
      for (final tr in w.traps) {
        _trap(canvas, tr);
      }
      for (final m in w.mines) {
        _mine(canvas, m);
      }
      for (final d in w.skullDrops) {
        _skullOffer(canvas, d.type, d.x, d.near);
      }
      if (w.exitPortal != null) _portal(canvas, w.exitPortal!, '다음 층 (E)');
    }

    for (final pr in w.projectiles) {
      _projectile(canvas, pr);
    }
    for (final e in w.enemies) {
      if (e.kind == EnemyKind.plant) continue; // already drawn behind terrain
      _enemy(canvas, e);
    }
    for (final a in w.allies) {
      _ally(canvas, a);
    }
    if (w.boss != null) _boss(canvas, w.boss!);
    if (w.paladinSwordTimer > 0) _paladinSword(canvas);
    _player(canvas, w.player);

    for (final c in w.storms) {
      _stormCloud(canvas, c);
    }

    for (final pa in w.particles) {
      _particle(canvas, pa);
    }
    for (final fx in w.skillFx) {
      _skillFx(canvas, fx);
    }
    // bushes drawn on top so they occlude (hide) the player
    for (final b in w.bushes) {
      _bush(canvas, b, w.player.hidden && w.player.rect.overlaps(b.rect));
    }
    if (w.enterPrompt != null) _prompt(canvas, w.enterPrompt!);
    if (w.townPrompt != null && w.townPromptPos != null) {
      _label(canvas, w.townPrompt!, w.townPromptPos!);
    }
    canvas.restore();
  }

  // 성기사 천공의 대검: the planted greatsword standing in the ground. Brightens
  // and rings the ground while the paladin is close enough to be empowered.
  void _paladinSword(Canvas canvas) {
    final w = world;
    final x = w.paladinSwordX;
    final gy = w.paladinSwordY;
    final buff = w.paladinSwordBuff;
    final fade = w.paladinSwordTimer.clamp(0.0, 1.0); // fade out in last second
    const steel = Color(0xFFE3F2FD);
    const gold = Color(0xFFFFD166);
    _glow(canvas, Offset(x, gy - 30), buff ? 46 : 30,
        gold.withOpacity((buff ? 0.34 : 0.18) * fade), buff ? 20 : 14);
    if (buff) {
      canvas.drawCircle(
          Offset(x, gy),
          120,
          Paint()
            ..color = gold.withOpacity(0.22 * fade)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
    final blade = Path()
      ..moveTo(x, gy + 6)
      ..lineTo(x - 7, gy - 56)
      ..lineTo(x - 7, gy - 64)
      ..lineTo(x + 7, gy - 64)
      ..lineTo(x + 7, gy - 56)
      ..close();
    canvas.drawPath(blade, Paint()..color = steel.withOpacity(fade));
    canvas.drawPath(
        Path()
          ..moveTo(x, gy + 4)
          ..lineTo(x, gy - 60),
        Paint()
          ..color = const Color(0xFF90A4AE).withOpacity(0.8 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    _pixelRect(canvas, Rect.fromLTWH(x - 16, gy - 70, 32, 6),
        gold.withOpacity(fade));
    _pixelRect(canvas, Rect.fromLTWH(x - 3, gy - 84, 6, 16),
        const Color(0xFF8D6E63).withOpacity(fade));
    _pixelRect(canvas, Rect.fromLTWH(x - 4, gy - 86, 8, 4),
        gold.withOpacity(fade));
  }

  // ----------------------------------------------------------------
  void _background(Canvas canvas) {
    final b = world.biome;
    final rect = const Rect.fromLTWH(0, 0, kViewW, kViewH);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [b.skyTop, b.skyBottom],
          ).createShader(rect));
    // moon / orb with soft halo
    _glow(canvas, const Offset(kViewW * 0.82, 130), 70,
        b.accent.withOpacity(0.22), 24);
    canvas.drawCircle(const Offset(kViewW * 0.82, 130), 54,
        Paint()..color = b.accent.withOpacity(0.2));
    canvas.drawCircle(const Offset(kViewW * 0.82 - 12, 118), 40,
        Paint()..color = b.skyTop.withOpacity(0.25));
    // far parallax hills (darker, slower) for depth
    final farOff = (world.camX * 0.12) % 360;
    final farHill = _pixelPaint(Color.lerp(b.hill, b.skyBottom, 0.55)!);
    for (double hx = -farOff - 480; hx < kViewW + 480; hx += 300) {
      final path = Path()..moveTo(hx, kViewH);
      final h0 = kViewH - 200;
      final peaks = [0, 70, 40, 92, 54, 78, 30];
      for (int i = 0; i < peaks.length; i++) {
        path.lineTo(hx + i * 52, h0 - peaks[i]);
      }
      path.lineTo(hx + peaks.length * 52, kViewH);
      path.close();
      canvas.drawPath(path, farHill);
    }
    // parallax hills
    final off = (world.camX * 0.26) % 320;
    final hill = _pixelPaint(b.hill);
    for (double hx = -off - 440; hx < kViewW + 440; hx += 220) {
      final path = Path()..moveTo(hx, kViewH);
      final h0 = kViewH - 140;
      final peaks = [0, 44, 20, 56, 30, 52, 14, 38, 22];
      for (int i = 0; i < peaks.length; i++) {
        path.lineTo(hx + i * 40, h0 - peaks[i]);
      }
      path.lineTo(hx + peaks.length * 40, kViewH);
      path.close();
      canvas.drawPath(path, hill);
      for (int i = 0; i < peaks.length; i++) {
        final px = hx + i * 40;
        final py = h0 - peaks[i];
        _pixelRect(canvas, Rect.fromLTWH(px - 6, py - 10, 12, 10), b.hill.withOpacity(0.8));
      }
    }
    final star = _pixelPaint(Colors.white.withOpacity(0.35));
    for (int i = 0; i < 40; i++) {
      final x = (i * 137.0) % kViewW;
      final y = (i * 53.0) % 300;
      final tw = 0.2 + 0.8 * (0.5 + 0.5 * sin(world.clock * 2 + i));
      canvas.drawRect(Rect.fromLTWH(x, y, 2, 2),
          _pixelPaint(Colors.white.withOpacity(0.35 * tw)));
      canvas.drawRect(Rect.fromLTWH(x + 4, y + 3, 2, 2), star);
    }
    // ambient biome motes drifting up (embers/snow/spores/ash)
    final t = world.clock;
    for (int i = 0; i < 26; i++) {
      final seed = i * 71.0;
      final bx = (seed * 13 + t * (12 + i % 7) * 1.0) % kViewW;
      final by = kViewH - ((seed * 7 + t * (18 + i % 5) * 1.0) % kViewH);
      final sway = sin(t * 1.2 + i) * 8;
      final sz = 1.5 + (i % 3);
      canvas.drawRect(Rect.fromLTWH(bx + sway, by, sz, sz),
          _pixelPaint(b.accent.withOpacity(0.16 + 0.12 * (i % 3))));
    }
    // subtle edge vignette for depth
    canvas.drawRect(
        const Rect.fromLTWH(0, 0, kViewW, kViewH),
        Paint()
          ..shader = RadialGradient(
            center: Alignment.center,
            radius: 0.9,
            colors: [Colors.transparent, Colors.black.withOpacity(0.28)],
            stops: const [0.62, 1.0],
          ).createShader(const Rect.fromLTWH(0, 0, kViewW, kViewH)));
  }

  void _ground(Canvas canvas, Rect r) {
    final b = world.biome;
    _pixelRect(canvas, r, b.ground);
    for (double dx = r.left; dx < r.right; dx += 24) {
      _pixelRect(canvas, Rect.fromLTWH(dx, r.top, 16, 8), b.platform);
    }
    final edge = _pixelPaint(b.platform.withOpacity(0.9));
    for (double dx = r.left + 8; dx < r.right - 6; dx += 32) {
      canvas.drawRect(Rect.fromLTWH(dx, r.top + 8, 6, 6), edge);
    }
    for (double dx = r.left + 18; dx < r.right - 12; dx += 64) {
      final gy = r.top + 18 + ((dx / 64).floor().isEven ? 2 : 0);
      _pixelRect(canvas, Rect.fromLTWH(dx, gy, 14, 6), b.ground.withOpacity(0.72));
      _pixelRect(canvas, Rect.fromLTWH(dx + 24, gy + 4, 10, 4), b.ground.withOpacity(0.68));
    }
  }

  void _props(Canvas canvas, List<RoomProp> props) {
    for (final prop in props) {
      _prop(canvas, prop);
    }
  }

  void _prop(Canvas canvas, RoomProp prop) {
    final r = prop.rect;
    switch (prop.kind) {
      case 'crate':
        canvas.drawRect(r, Paint()..color = prop.color);
        canvas.drawRect(Rect.fromLTWH(r.left + 4, r.top + 4, 6, r.height - 8),
            Paint()..color = Colors.black.withOpacity(0.2));
        canvas.drawRect(Rect.fromLTWH(r.left + 4, r.top + 4, r.width - 8, 6),
            Paint()..color = Colors.black.withOpacity(0.2));
        break;
      case 'barrel':
        canvas.drawRect(r.deflate(4), Paint()..color = prop.color);
        canvas.drawRect(Rect.fromLTWH(r.left + 4, r.top + 8, r.width - 8, 4),
            Paint()..color = Colors.black.withOpacity(0.25));
        canvas.drawRect(Rect.fromLTWH(r.left + 4, r.bottom - 14, r.width - 8, 4),
            Paint()..color = Colors.black.withOpacity(0.25));
        canvas.drawRect(Rect.fromLTWH(r.left + r.width / 2 - 2, r.top + 6, 4, 6),
            Paint()..color = const Color(0xFFBCAAA4));
        break;
      case 'torch':
        final post = Rect.fromLTWH(r.center.dx - 4, r.bottom - 18, 8, 18);
        canvas.drawRect(post, Paint()..color = const Color(0xFF6D4C41));
        canvas.drawRect(
            Rect.fromLTWH(r.center.dx - 8, r.bottom - 26, 16, 10),
            Paint()..color = const Color(0xFF8D6E63));
        final flame = Offset(r.center.dx, r.top + 12);
        canvas.drawRect(Rect.fromLTWH(flame.dx - 4, flame.dy - 12, 8, 12),
            Paint()..color = const Color(0xFFFFD54F));
        canvas.drawRect(Rect.fromLTWH(flame.dx - 2, flame.dy - 16, 4, 6),
            Paint()..color = const Color(0xFFFF6F00));
        break;
      case 'skull':
        final head = Rect.fromCenter(center: r.center, width: r.width, height: r.height);
        canvas.drawRect(head, Paint()..color = prop.color);
        canvas.drawRect(Rect.fromLTWH(head.left + 6, head.top + 8, 4, 4),
            Paint()..color = Colors.black);
        canvas.drawRect(Rect.fromLTWH(head.right - 10, head.top + 8, 4, 4),
            Paint()..color = Colors.black);
        canvas.drawRect(Rect.fromLTWH(head.center.dx - 4, head.bottom - 10, 8, 4),
            Paint()..color = Colors.black);
        break;
      case 'mushroom':
        final cap = Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.6);
        final stem = Rect.fromLTWH(r.center.dx - 6, r.top + r.height * 0.4, 12,
            r.height * 0.55);
        _pixelRect(canvas, stem, const Color(0xFFE0E0E0));
        _pixelRect(canvas, cap, prop.color);
        _pixelRect(canvas, Rect.fromLTWH(cap.left + 6, cap.top + 4, 6, 4), Colors.white);
        _pixelRect(canvas, Rect.fromLTWH(cap.right - 12, cap.top + 4, 6, 4), Colors.white);
        break;
      case 'stone':
        _pixelRect(canvas, Rect.fromLTWH(r.left, r.top + r.height * 0.2, r.width, r.height * 0.8), prop.color);
        _pixelRect(canvas, Rect.fromLTWH(r.left + 4, r.top + 10, 10, 10), Colors.black.withOpacity(0.2));
        _pixelRect(canvas, Rect.fromLTWH(r.right - 14, r.top + 24, 8, 8), Colors.black.withOpacity(0.2));
        break;
      case 'banner':
        final post = Rect.fromLTWH(r.center.dx - 2, r.top + 12, 4, r.height - 12);
        _pixelRect(canvas, post, const Color(0xFF6D4C41));
        final board = Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.36);
        _pixelRect(canvas, board, prop.color);
        _pixelRect(canvas, Rect.fromLTWH(board.left + 4, board.top + 4, 6, 6), Colors.black.withOpacity(0.3));
        _pixelRect(canvas, Rect.fromLTWH(board.right - 10, board.top + 4, 6, 6), Colors.black.withOpacity(0.3));
        break;
      case 'pillar':
        final col = _pixelPaint(prop.color);
        for (double y = r.top; y < r.bottom; y += 12) {
          canvas.drawRect(Rect.fromLTWH(r.left, y, r.width, 10), col);
        }
        _pixelRect(canvas, Rect.fromLTWH(r.left + 4, r.top + 4, 6, 6), Colors.black.withOpacity(0.18));
        break;
      case 'root':
        _pixelRect(canvas, Rect.fromLTWH(r.left + 6, r.top, 8, r.height), prop.color);
        _pixelRect(canvas, Rect.fromLTWH(r.left, r.top + r.height * 0.4, 8, 10), prop.color);
        _pixelRect(canvas, Rect.fromLTWH(r.left + r.width - 8, r.top + r.height * 0.55, 8, 10), prop.color);
        _pixelRect(canvas, Rect.fromLTWH(r.left + 10, r.top + r.height * 0.75, 12, 8), const Color(0xFF3E2723));
        break;
      case 'stalactite':
        final stem = Rect.fromLTWH(r.center.dx - 4, r.top, 8, r.height * 0.6);
        _pixelRect(canvas, stem, prop.color);
        _pixelRect(canvas, Rect.fromLTWH(r.left, r.top + r.height * 0.55, 10, 10), prop.color.withOpacity(0.9));
        _pixelRect(canvas, Rect.fromLTWH(r.right - 10, r.top + r.height * 0.55, 10, 10), prop.color.withOpacity(0.9));
        break;
      case 'rune':
        _pixelRect(canvas, Rect.fromLTWH(r.left, r.top, r.width, r.height), prop.color.withOpacity(0.2));
        _pixelRect(canvas, Rect.fromLTWH(r.center.dx - 6, r.center.dy - 14, 12, 28), prop.color);
        _pixelRect(canvas, Rect.fromLTWH(r.center.dx - 14, r.center.dy - 6, 28, 12), prop.color);
        _pixelRect(canvas, Rect.fromLTWH(r.center.dx - 4, r.center.dy - 4, 8, 8), Colors.white);
        break;
      case 'crystal':
        // vertical faceted crystal cluster
        final cx = r.center.dx;
        final top = r.top + 4;
        _pixelRect(canvas, Rect.fromLTWH(cx - 6, top + 6, 12, r.height - 12), prop.color.withOpacity(0.9));
        _pixelRect(canvas, Rect.fromLTWH(cx - 10, top + 18, 8, r.height - 28), prop.color.withOpacity(0.65));
        _pixelRect(canvas, Rect.fromLTWH(cx + 2, top + 18, 8, r.height - 28), prop.color.withOpacity(0.65));
        _pixelRect(canvas, Rect.fromLTWH(cx - 4, top + 8, 8, 6), Colors.white.withOpacity(0.9));
        break;
      case 'sign':
      default:
        final post = Rect.fromLTWH(r.center.dx - 4, r.center.dy - 4, 8, r.height);
        _pixelRect(canvas, post, const Color(0xFF6D4C41));
        final board = Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.5);
        _pixelRect(canvas, board, prop.color);
        _pixelRect(canvas, Rect.fromLTWH(board.left + 4, board.top + 4, 6, 6), Colors.black.withOpacity(0.3));
        _pixelRect(canvas, Rect.fromLTWH(board.right - 10, board.top + 4, 6, 6), Colors.black.withOpacity(0.3));
        break;
    }
  }

  void _oneWay(Canvas canvas, Rect r) {
    final b = world.biome;
    final top = b.platform.withOpacity(0.96);
    final body = b.platform.withOpacity(0.88);
    for (double x = r.left; x < r.right; x += 16) {
      _pixelRect(canvas, Rect.fromLTWH(x, r.top, min(16, r.right - x), 20), body);
    }
    for (double x = r.left; x < r.right; x += 12) {
      _pixelRect(canvas, Rect.fromLTWH(x, r.top, min(12, r.right - x), 5), top);
    }
    final post = b.ground.withOpacity(0.7);
    _pixelRect(canvas, Rect.fromLTWH(r.left + 6, r.bottom, 6, 10), post);
    _pixelRect(canvas, Rect.fromLTWH(r.right - 14, r.bottom, 6, 10), post);
  }

  void _door(Canvas canvas, Door d, bool open) {
    final r = d.rect;
    final meta = _roomMeta(d.targetType);
    final glow = open ? meta.$2 : const Color(0xFF555555);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(10)),
        Paint()..color = const Color(0xFF241B33));
    final inner = r.deflate(8);
    if (open) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(inner.inflate(6), const Radius.circular(8)),
          Paint()
            ..color = glow.withOpacity(0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawRRect(
          RRect.fromRectAndRadius(inner, const Radius.circular(8)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [glow.withOpacity(0.85), const Color(0xFF0B0716)],
            ).createShader(inner));
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(inner, const Radius.circular(8)),
          Paint()..color = const Color(0xFF0B0716));
      final bar = Paint()..color = const Color(0xFF7A2E2E);
      for (int i = 0; i < 3; i++) {
        final y = inner.top + 14 + i * (inner.height - 24) / 2;
        canvas.drawRect(Rect.fromLTWH(inner.left, y - 4, inner.width, 8), bar);
      }
    }
    _text(canvas, meta.$1, Offset(r.center.dx, r.top - 16), 17,
        open ? meta.$2 : Colors.white54);
  }

  void _shopItem(Canvas canvas, ShopItem it, int gold) {
    final r = it.pedestal;
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()..color = const Color(0xFF4E342E));
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 6),
        Paint()..color = const Color(0xFF6D4C41));
    if (it.bought) {
      _text(canvas, 'SOLD', Offset(r.center.dx, r.top - 18), 18,
          Colors.white38);
      return;
    }
    final bob = sin(world.clock * 3 + r.left) * 4;
    final gem = Offset(r.center.dx, r.top - 26 + bob);
    final col = _itemColor(it.kind);
    canvas.drawCircle(
        gem,
        14,
        Paint()
          ..color = col.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    canvas.drawCircle(gem, 9, Paint()..color = col);
    canvas.drawCircle(gem - const Offset(3, 3), 3,
        Paint()..color = Colors.white.withOpacity(0.8));
    _text(canvas, it.name, Offset(r.center.dx, r.top - 54), 15, Colors.white);
    final afford = gold >= it.cost;
    _text(canvas, '${it.cost} G', Offset(r.center.dx, r.top - 38), 15,
        afford ? const Color(0xFFFFD166) : const Color(0xFFE57373));
  }

  void _chest(Canvas canvas, Chest c) {
    final r = c.rect;
    if (!c.opened) {
      // glow + sparkle to read as treasure
      canvas.drawRRect(
          RRect.fromRectAndRadius(r.inflate(6), const Radius.circular(8)),
          Paint()
            ..color = const Color(0xFFFFD166).withOpacity(0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    // body
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)),
        Paint()..color = const Color(0xFF6D4C2E));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left, r.center.dy, r.width, r.height / 2),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFF5A3D24));
    // gold trim
    final trim = Paint()..color = const Color(0xFFE6B33E);
    canvas.drawRect(
        Rect.fromLTWH(r.left, r.center.dy - 3, r.width, 6), trim);
    if (c.opened) {
      // open lid (tilted up) + empty inside
      canvas.save();
      canvas.translate(r.left, r.top);
      canvas.rotate(-0.5);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(0, -14, r.width, 16), const Radius.circular(6)),
          Paint()..color = const Color(0xFF7A552F));
      canvas.restore();
      canvas.drawRect(Rect.fromLTWH(r.left + 6, r.top + 4, r.width - 12, 10),
          Paint()..color = Colors.black.withOpacity(0.5));
    } else {
      // closed lid
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(r.left, r.top - 10, r.width, 18),
              const Radius.circular(6)),
          Paint()..color = const Color(0xFF7A552F));
      canvas.drawRect(
          Rect.fromLTWH(r.center.dx - 5, r.top - 2, 10, 10), trim); // lock
      final s = (sin(c.t * 5) * 0.5 + 0.5);
      canvas.drawCircle(Offset(r.center.dx, r.top - 18), 2 + s * 1.5,
          Paint()..color = const Color(0xFFFFF59D));
    }
  }

  void _skullOffer(Canvas canvas, SkullType t, double x, bool near) {
    final bob = sin(world.clock * 3) * 5;
    final c = Offset(x, kGroundY - 70 + bob);
    final col = _skullColor(t);
    canvas.drawCircle(
        c,
        near ? 24 : 18,
        Paint()
          ..color = col.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    // pixel skull head matching the player's
    const bone = Color(0xFFECEFF1);
    _pixelRect(canvas, Rect.fromLTWH(c.dx - 11, c.dy - 10, 22, 18), bone);
    _pixelRect(canvas, Rect.fromLTWH(c.dx - 8, c.dy + 8, 16, 6), bone);
    _pixelRect(canvas, Rect.fromLTWH(c.dx - 11, c.dy - 10, 22, 4),
        Colors.white.withOpacity(0.85));
    _pixelRect(canvas, Rect.fromLTWH(c.dx - 6, c.dy - 4, 4, 4), col);
    _pixelRect(canvas, Rect.fromLTWH(c.dx + 2, c.dy - 4, 4, 4), col);
    _pixelRect(canvas, Rect.fromLTWH(c.dx - 2, c.dy + 2, 4, 4), Colors.black26);
    final sp = skull(t);
    _text(canvas, '[${tierLabel(sp.tier)}] ${sp.name}',
        Offset(x, kGroundY - 98), 15, tierColor(sp.tier));
    if (near) {
      _text(canvas, '1: 슬롯1   2: 슬롯2', Offset(x, kGroundY - 80), 13,
          Colors.white);
    }
  }

  // Trapper-deployed explosive trap: a small spiked plate with a warning light
  // that blinks faster as it nears detonation/expiry.
  void _mine(Canvas canvas, Mine m) {
    final cxp = m.x;
    final base = m.y - 4;
    final arming = m.arm > 0;
    // pulsing warning light — pace from the mine's own timers
    final phase = m.triggered
        ? 1.0
        : (arming ? (0.5 + 0.5 * sin(m.arm * 30)) : (0.5 + 0.5 * sin(m.life * 8)));
    // base plate
    _pixelRect(canvas, Rect.fromCenter(center: Offset(cxp, base), width: 34, height: 8),
        const Color(0xFF455A64));
    _pixelRect(canvas, Rect.fromCenter(center: Offset(cxp, base - 5), width: 22, height: 6),
        const Color(0xFF37474F));
    // trigger plate / dome
    _pixelRect(canvas, Rect.fromCenter(center: Offset(cxp, base - 9), width: 12, height: 6),
        const Color(0xFF263238));
    // little prongs
    for (final s in [-1, 1]) {
      _pixelRect(canvas, Rect.fromLTWH(cxp + s * 13 - 2, base - 8, 3, 6),
          const Color(0xFF90A4AE));
    }
    // warning light
    final lightColor = Color.lerp(
        const Color(0xFF7E0000), const Color(0xFFFF5252), phase)!;
    canvas.drawCircle(Offset(cxp, base - 11), 3.2 + phase * 1.4,
        Paint()..color = lightColor.withOpacity(0.5 + 0.5 * phase));
    canvas.drawCircle(Offset(cxp, base - 11), 1.6, Paint()..color = Colors.white);
  }

  void _trap(Canvas canvas, Trap tr) {
    final r = tr.rect;
    switch (tr.kind) {
      case 'spike':
        canvas.drawRect(Rect.fromLTWH(r.left, r.bottom - 5, r.width, 5),
            Paint()..color = const Color(0xFF455A64));
        final spike = Paint()..color = const Color(0xFFB0BEC5);
        const sw = 12.0;
        for (double sx = r.left; sx < r.right - 2; sx += sw) {
          canvas.drawPath(
              Path()
                ..moveTo(sx, r.bottom - 4)
                ..lineTo(sx + sw / 2, r.top)
                ..lineTo(sx + sw, r.bottom - 4)
                ..close(),
              spike);
        }
        break;
      case 'saw':
        final c = r.center;
        final rad = r.width / 2;
        final blade = Paint()..color = const Color(0xFFB0BEC5);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(tr.t * 14);
        for (int i = 0; i < 8; i++) {
          final a = i / 8 * pi * 2;
          canvas.drawPath(
              Path()
                ..moveTo(cos(a) * rad, sin(a) * rad)
                ..lineTo(cos(a + 0.3) * (rad + 6), sin(a + 0.3) * (rad + 6))
                ..lineTo(cos(a + 0.6) * rad, sin(a + 0.6) * rad)
                ..close(),
              blade);
        }
        canvas.drawCircle(Offset.zero, rad * 0.6, blade);
        canvas.drawCircle(
            Offset.zero, rad * 0.25, Paint()..color = const Color(0xFF546E7A));
        canvas.restore();
        break;
      case 'arrow':
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(4)),
            Paint()..color = const Color(0xFF4E342E));
        final ready = tr.t < 0.5;
        canvas.drawCircle(
            Offset(r.center.dx, r.center.dy),
            5,
            Paint()
              ..color = ready
                  ? const Color(0xFFFF5252)
                  : const Color(0xFF8D6E63));
        break;
      case 'flame':
        // metal vent grate always; flame column erupts during the active window
        _pixelRect(canvas, r, const Color(0xFF455A64));
        _pixelRect(canvas, Rect.fromLTWH(r.left, r.top, r.width, 4),
            const Color(0xFF263238));
        for (double gx = r.left + 4; gx < r.right - 2; gx += 8) {
          _pixelRect(canvas, Rect.fromLTWH(gx, r.top + 1, 3, 3),
              const Color(0xFF1A1A1A));
        }
        final cycle = tr.t % 2.4;
        if (cycle > 1.4) {
          final f = ((cycle - 1.4) / 1.0).clamp(0.0, 1.0);
          final hgt = 96 * (f < 0.4 ? f / 0.4 : 1.0);
          final base = r.top;
          canvas.drawRect(
              Rect.fromLTWH(r.left + 2, base - hgt, r.width - 4, hgt),
              Paint()
                ..color = const Color(0xFFFF7043).withOpacity(0.9)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
          canvas.drawRect(Rect.fromLTWH(r.left + 6, base - hgt + 6, r.width - 12,
              hgt - 6), Paint()..color = const Color(0xFFFFCA28).withOpacity(0.95));
          canvas.drawRect(
              Rect.fromLTWH(r.left + r.width / 2 - 3, base - hgt + 10, 6,
                  (hgt - 12).clamp(0.0, hgt)),
              Paint()..color = const Color(0xFFFFF59D));
        }
        break;
    }
  }

  void _bush(Canvas canvas, Bush b, bool hiding) {
    final r = b.rect;
    final base = Paint()
      ..color = hiding ? const Color(0xFF356B3C) : const Color(0xFF274D2C);
    for (int i = 0; i < 5; i++) {
      final cx = r.left + r.width * (0.14 + i * 0.18);
      final cy = r.bottom - 14 - (i.isOdd ? 8 : 0);
      canvas.drawCircle(Offset(cx, cy), 19, base);
    }
    final top = Paint()
      ..color = (hiding ? const Color(0xFF4C9A52) : const Color(0xFF3F7D44))
          .withOpacity(hiding ? 0.7 : 0.95);
    for (int i = 0; i < 4; i++) {
      final cx = r.left + r.width * (0.24 + i * 0.18);
      canvas.drawCircle(Offset(cx, r.bottom - 24), 14, top);
    }
    if (hiding) {
      _text(canvas, '숨는 중', Offset(r.center.dx, r.top - 8), 12,
          Colors.white70);
    }
  }

  void _blacksmith(Canvas canvas, Rect r) {
    // anvil
    final ax = r.center.dx;
    final ay = r.bottom;
    canvas.drawRect(Rect.fromLTWH(ax - 22, ay - 18, 44, 14),
        Paint()..color = const Color(0xFF455A64));
    canvas.drawRect(Rect.fromLTWH(ax - 10, ay - 30, 20, 14),
        Paint()..color = const Color(0xFF546E7A));
    canvas.drawRect(Rect.fromLTWH(ax - 14, ay - 8, 28, 8),
        Paint()..color = const Color(0xFF37474F));
    // NPC (dwarf smith)
    final nx = ax - 44;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(nx - 12, ay - 40, 24, 32), const Radius.circular(8)),
        Paint()..color = const Color(0xFF8D6E63));
    canvas.drawCircle(Offset(nx, ay - 46), 9,
        Paint()..color = const Color(0xFFE0B188));
    // beard
    canvas.drawPath(
        Path()
          ..moveTo(nx - 8, ay - 44)
          ..lineTo(nx, ay - 30)
          ..lineTo(nx + 8, ay - 44)
          ..close(),
        Paint()..color = const Color(0xFFECEFF1));
    _text(canvas, '⚒ 대장장이', Offset(ax, r.top - 14), 16,
        const Color(0xFFFFD166));
  }

  void _traitShrine(Canvas canvas, Rect r) {
    // glowing soul obelisk (skill-tree shrine)
    canvas.drawCircle(
        Offset(r.center.dx, r.center.dy),
        58,
        Paint()
          ..color = const Color(0xFFFFD166).withOpacity(0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    // stepped stone base
    _pixelRect(canvas, Rect.fromLTWH(r.left - 6, r.bottom - 14, r.width + 12, 14),
        const Color(0xFF4A4055));
    _pixelRect(canvas, Rect.fromLTWH(r.left + 2, r.bottom - 24, r.width - 4, 12),
        const Color(0xFF5C5168));
    // obelisk body (tapered)
    final cx = r.center.dx;
    for (int i = 0; i < 5; i++) {
      final wHalf = 22.0 - i * 3.0;
      final y = r.top + 6 + i * ((r.height - 30) / 5);
      _pixelRect(canvas, Rect.fromLTWH(cx - wHalf, y, wHalf * 2,
          (r.height - 30) / 5 + 1), const Color(0xFF6A5B7A));
    }
    // tip
    _pixelRect(canvas, Rect.fromLTWH(cx - 6, r.top - 4, 12, 12),
        const Color(0xFF7A6A8A));
    // glowing runes climbing the shaft
    for (int i = 0; i < 4; i++) {
      final pulse = 0.5 + 0.5 * sin(world.clock * 3 + i);
      _pixelRect(canvas, Rect.fromLTWH(cx - 4, r.top + 14 + i * 22.0, 8, 8),
          const Color(0xFFFFD166).withOpacity(0.4 + 0.5 * pulse));
    }
    // floating sparks
    for (int i = 0; i < 3; i++) {
      final a = world.clock * 1.4 + i * 2.1;
      canvas.drawCircle(
          Offset(cx + cos(a) * 30, r.center.dy + sin(a) * 24), 2.4,
          Paint()..color = const Color(0xFFFFE9A8));
    }
    _text(canvas, '✦ 영혼의 비석', Offset(cx, r.top - 18), 16,
        const Color(0xFFFFD166));
  }

  void _graveyard(Canvas canvas, Rect r) {
    // mystic glow
    canvas.drawCircle(
        r.center,
        70,
        Paint()
          ..color = const Color(0xFF9D7BFF).withOpacity(0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    // tombstones
    final stone = Paint()..color = const Color(0xFF6A5B7A);
    for (int i = 0; i < 3; i++) {
      final sx = r.left + 20 + i * 45.0;
      final sh = 60.0 + (i.isEven ? 12 : 0);
      final top = r.bottom - sh;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(sx, top, 30, sh), const Radius.circular(12)),
          stone);
      canvas.drawRect(Rect.fromLTWH(sx + 13, top + 12, 4, 22),
          Paint()..color = const Color(0xFF4A4055));
      canvas.drawRect(Rect.fromLTWH(sx + 6, top + 18, 18, 4),
          Paint()..color = const Color(0xFF4A4055));
    }
    // wisps
    for (int i = 0; i < 4; i++) {
      final a = world.clock * 1.5 + i * 1.6;
      canvas.drawCircle(
          Offset(r.center.dx + cos(a) * 40, r.center.dy - 10 + sin(a) * 22),
          2.5,
          Paint()..color = const Color(0xFFB388FF));
    }
    _text(canvas, '🪦 무덤가', Offset(r.center.dx, r.top - 16), 16,
        const Color(0xFFB388FF));
  }

  void _label(Canvas canvas, String s, Offset pos) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: const TextStyle(
              fontSize: 15,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromCenter(
        center: pos, width: tp.width + 20, height: tp.height + 12);
    canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(8)),
        Paint()..color = Colors.black.withOpacity(0.6));
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  void _prompt(Canvas canvas, Offset pos) {
    final pulse = 0.6 + 0.4 * sin(world.clock * 6);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: pos, width: 30, height: 26),
            const Radius.circular(5)),
        Paint()..color = Colors.black.withOpacity(0.6 * pulse + 0.2));
    _text(canvas, 'E', pos, 18, Colors.white);
  }

  void _portal(Canvas canvas, Rect r, String label) {
    final t = world.clock;
    canvas.drawOval(
        r.inflate(14),
        Paint()
          ..color = const Color(0xFF64FFDA).withOpacity(0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawOval(
        r,
        Paint()
          ..shader = SweepGradient(
            colors: const [
              Color(0xFF64FFDA),
              Color(0xFF1DE9B6),
              Color(0xFF18FFFF),
              Color(0xFF64FFDA),
            ],
            transform: GradientRotation(t * 2),
          ).createShader(r));
    canvas.drawOval(r.deflate(9), Paint()..color = const Color(0xFF05131A));
    for (int i = 0; i < 6; i++) {
      final a = t * 3 + i * pi / 3;
      final rr = r.deflate(14);
      canvas.drawCircle(
          Offset(rr.center.dx + cos(a) * rr.width * 0.32,
              rr.center.dy + sin(a) * rr.height * 0.32),
          2.6,
          Paint()..color = const Color(0xFF9DFFF0));
    }
    _text(canvas, label, Offset(r.center.dx, r.top - 16), 18,
        const Color(0xFF9DFFF0));
  }

  void _projectile(Canvas canvas, Projectile pr) {
    switch (pr.shape) {
      case 'bolt':
        // sniper rail slug: glowing energy streak with a motion trail
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.scale(pr.vx >= 0 ? 1 : -1, 1);
        canvas.drawRect(
            const Rect.fromLTWH(-26, -2, 30, 4),
            Paint()
              ..color = pr.color.withOpacity(0.4)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        _pixelRect(canvas, const Rect.fromLTWH(-22, -1, 26, 2),
            pr.color.withOpacity(0.85)); // trail
        _pixelRect(canvas, Rect.fromLTWH(2, -pr.r * 0.5, pr.r + 6, pr.r),
            pr.color); // slug
        _pixelRect(canvas, Rect.fromLTWH(4, -1.5, pr.r + 2, 3), Colors.white);
        canvas.restore();
        break;
      case 'arrow':
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.scale(pr.vx >= 0 ? 1 : -1, 1);
        _pixelRect(canvas, const Rect.fromLTWH(-15, -1.5, 22, 3),
            const Color(0xFF8D6E63)); // shaft
        // arrowhead
        canvas.drawPath(
            Path()
              ..moveTo(7, -5)
              ..lineTo(18, 0)
              ..lineTo(7, 5)
              ..close(),
            Paint()..color = const Color(0xFFCFD8DC));
        // fletching (class-tinted)
        _pixelRect(canvas, Rect.fromLTWH(-15, -4, 5, 3),
            pr.color.withOpacity(0.9));
        _pixelRect(canvas, Rect.fromLTWH(-15, 1, 5, 3),
            pr.color.withOpacity(0.9));
        canvas.restore();
        break;
      case 'icicle':
        // sharp ice shard pointing in travel direction
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.scale(pr.vx >= 0 ? 1 : -1, 1);
        canvas.drawPath(
            Path()
              ..moveTo(pr.r + 8, 0)
              ..lineTo(-pr.r, -pr.r * 0.8)
              ..lineTo(-pr.r - 4, 0)
              ..lineTo(-pr.r, pr.r * 0.8)
              ..close(),
            Paint()..color = pr.color);
        canvas.drawPath(
            Path()
              ..moveTo(pr.r + 8, 0)
              ..lineTo(-pr.r * 0.4, -pr.r * 0.35)
              ..lineTo(-pr.r * 0.4, pr.r * 0.35)
              ..close(),
            Paint()..color = Colors.white.withOpacity(0.85));
        canvas.restore();
        break;
      case 'orb':
        canvas.drawCircle(
            Offset(pr.x, pr.y),
            pr.r + 4,
            Paint()
              ..color = pr.color.withOpacity(0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawCircle(Offset(pr.x, pr.y), pr.r, Paint()..color = pr.color);
        canvas.drawCircle(
            Offset(pr.x - pr.r * 0.3, pr.y - pr.r * 0.3),
            pr.r * 0.42,
            Paint()..color = Colors.white.withOpacity(0.85));
        break;
      case 'darkhand':
        // a clutching skeletal hand of shadow reaching in the travel direction
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.scale(pr.vx >= 0 ? 1 : -1, 1);
        canvas.drawCircle(
            Offset.zero,
            pr.r,
            Paint()
              ..color = const Color(0xFF7E57C2).withOpacity(0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
        const palm = Color(0xFF311B92);
        const claw = Color(0xFFB388FF);
        // palm
        _pixelRect(canvas, Rect.fromLTWH(-pr.r * 0.5, -pr.r * 0.5, pr.r, pr.r),
            palm);
        // three reaching claws
        for (int f = -1; f <= 1; f++) {
          _pixelRect(
              canvas,
              Rect.fromLTWH(pr.r * 0.4, f * pr.r * 0.42 - 1.5, pr.r * 0.9, 3),
              claw);
        }
        // shadowy wrist trail
        _pixelRect(canvas, Rect.fromLTWH(-pr.r * 1.4, -2, pr.r, 4),
            const Color(0xFF7E57C2).withOpacity(0.7));
        canvas.restore();
        break;
      case 'fireball':
        // roiling ball of flame: soft outer glow, hot core, white-yellow center
        canvas.drawCircle(
            Offset(pr.x, pr.y),
            pr.r + 9,
            Paint()
              ..color = const Color(0xFFFF7043).withOpacity(0.35)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
        canvas.drawCircle(
            Offset(pr.x, pr.y), pr.r, Paint()..color = const Color(0xFFFF7043));
        canvas.drawCircle(Offset(pr.x, pr.y), pr.r * 0.66,
            Paint()..color = const Color(0xFFFFB300));
        canvas.drawCircle(Offset(pr.x - pr.r * 0.22, pr.y - pr.r * 0.22),
            pr.r * 0.34, Paint()..color = const Color(0xFFFFF59D));
        break;
      case 'swordwave':
        // crescent blade of sword energy bowing in the travel direction
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.scale(pr.vx >= 0 ? 1 : -1, 1);
        final wavePath = Path()
          ..moveTo(-pr.r * 0.5, -pr.r)
          ..quadraticBezierTo(pr.r * 0.95, 0, -pr.r * 0.5, pr.r);
        canvas.drawPath(
            wavePath,
            Paint()
              ..color = pr.color.withOpacity(0.4)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 11
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
        canvas.drawPath(
            wavePath,
            Paint()
              ..color = pr.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeCap = StrokeCap.round);
        canvas.drawPath(
            wavePath,
            Paint()
              ..color = Colors.white.withOpacity(0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..strokeCap = StrokeCap.round);
        canvas.restore();
        break;
      case 'swordfall':
        // giant greatsword plunging point-down from the sky
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.drawCircle(
            Offset.zero,
            pr.r,
            Paint()
              ..color = pr.color.withOpacity(0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        final blade = Path()
          ..moveTo(0, pr.r * 2.0)
          ..lineTo(-pr.r * 0.42, pr.r * 0.3)
          ..lineTo(-pr.r * 0.42, -pr.r * 1.4)
          ..lineTo(pr.r * 0.42, -pr.r * 1.4)
          ..lineTo(pr.r * 0.42, pr.r * 0.3)
          ..close();
        canvas.drawPath(blade, Paint()..color = const Color(0xFFE3F2FD));
        canvas.drawPath(
            Path()
              ..moveTo(0, pr.r * 2.0)
              ..lineTo(0, -pr.r * 1.2),
            Paint()
              ..color = pr.color.withOpacity(0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        _pixelRect(
            canvas,
            Rect.fromCenter(
                center: Offset(0, -pr.r * 1.4),
                width: pr.r * 1.9,
                height: pr.r * 0.5),
            const Color(0xFFFFD166)); // crossguard
        _pixelRect(
            canvas,
            Rect.fromCenter(
                center: Offset(0, -pr.r * 1.95),
                width: pr.r * 0.42,
                height: pr.r * 0.8),
            const Color(0xFF8D6E63)); // hilt
        canvas.restore();
        break;
      case 'potion':
        // thrown flask: glass body + liquid + neck + cork
        canvas.drawCircle(Offset(pr.x, pr.y + 2), pr.r,
            Paint()..color = const Color(0xFFB0BEC5).withOpacity(0.35));
        canvas.drawCircle(
            Offset(pr.x, pr.y + 2), pr.r - 2, Paint()..color = pr.color);
        canvas.drawCircle(Offset(pr.x - pr.r * 0.3, pr.y), pr.r * 0.3,
            Paint()..color = Colors.white.withOpacity(0.7));
        _pixelRect(canvas, Rect.fromLTWH(pr.x - 3, pr.y - pr.r - 2, 6, 6),
            const Color(0xFFCFD8DC)); // neck
        _pixelRect(canvas, Rect.fromLTWH(pr.x - 2, pr.y - pr.r - 6, 4, 4),
            const Color(0xFF8D6E63)); // cork
        break;
      case 'bomb':
        canvas.drawCircle(
            Offset(pr.x, pr.y), pr.r, Paint()..color = const Color(0xFF263238));
        canvas.drawCircle(Offset(pr.x - pr.r * 0.3, pr.y - pr.r * 0.3),
            pr.r * 0.3, Paint()..color = Colors.white24);
        _pixelRect(canvas, Rect.fromLTWH(pr.x - 1, pr.y - pr.r - 5, 3, 6),
            const Color(0xFF8D6E63)); // fuse
        _glow(canvas, Offset(pr.x + 1, pr.y - pr.r - 6), 4,
            const Color(0xFFFFB300), 3); // spark
        break;
      case 'rock':
        // chunky ore nugget
        _pixelRect(canvas,
            Rect.fromLTWH(pr.x - pr.r, pr.y - pr.r * 0.8, pr.r * 2, pr.r * 1.6),
            const Color(0xFF8D6E63));
        _pixelRect(canvas, Rect.fromLTWH(pr.x - pr.r * 0.6, pr.y - pr.r * 0.8,
            pr.r * 1.2, pr.r * 0.5), const Color(0xFFA1887F));
        _pixelRect(canvas, Rect.fromLTWH(pr.x - pr.r * 0.2, pr.y, pr.r * 0.5,
            pr.r * 0.5), pr.color); // ore vein
        break;
      case 'net':
        // woven mesh square
        final mesh = Paint()
          ..color = pr.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final box =
            Rect.fromCenter(center: Offset(pr.x, pr.y), width: pr.r * 2.4, height: pr.r * 2.4);
        canvas.drawRect(box, mesh);
        for (int i = 1; i < 3; i++) {
          final t = i / 3.0;
          canvas.drawLine(Offset(box.left + box.width * t, box.top),
              Offset(box.left + box.width * t, box.bottom), mesh);
          canvas.drawLine(Offset(box.left, box.top + box.height * t),
              Offset(box.right, box.top + box.height * t), mesh);
        }
        break;
      case 'feather':
        // a razor flight-feather, pointing along its travel direction
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.rotate(atan2(pr.vy, pr.vx));
        final quill = Path()
          ..moveTo(pr.r + 6, 0)
          ..lineTo(-pr.r, -pr.r * 0.7)
          ..lineTo(-pr.r - 5, 0)
          ..lineTo(-pr.r, pr.r * 0.7)
          ..close();
        canvas.drawPath(quill, Paint()..color = pr.color);
        canvas.drawPath(
            quill,
            Paint()
              ..color = Colors.white.withOpacity(0.5)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2);
        // central shaft
        canvas.drawLine(Offset(pr.r + 6, 0), Offset(-pr.r - 5, 0),
            Paint()..color = Colors.white.withOpacity(0.85)..strokeWidth = 1.4);
        canvas.restore();
        break;
      case 'apple':
        // a plump red apple with a stalk + leaf, tumbling as it arcs
        canvas.save();
        canvas.translate(pr.x, pr.y);
        canvas.rotate(pr.x * 0.05); // tumble (no time field; use position)
        canvas.drawCircle(Offset(-pr.r * 0.32, 0), pr.r * 0.8,
            Paint()..color = pr.color);
        canvas.drawCircle(Offset(pr.r * 0.32, 0), pr.r * 0.8,
            Paint()..color = pr.color);
        canvas.drawCircle(Offset(-pr.r * 0.3, -pr.r * 0.3), pr.r * 0.3,
            Paint()..color = Colors.white.withOpacity(0.5));
        _pixelRect(canvas, Rect.fromLTWH(-1.5, -pr.r - 4, 3, 6),
            const Color(0xFF5D4037)); // stalk
        canvas.drawCircle(Offset(pr.r * 0.4, -pr.r - 2), pr.r * 0.3,
            Paint()..color = const Color(0xFF66BB6A)); // leaf
        canvas.restore();
        break;
      case 'firetornado':
        {
          // 대마법사 불: a swirling column of flame (no time field — swirl by x)
          final swirl = pr.x * 0.08;
          canvas.drawCircle(
              Offset(pr.x, pr.y),
              pr.r + 8,
              Paint()
                ..color = const Color(0xFFFF7043).withOpacity(0.3)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
          for (int i = 0; i < 5; i++) {
            final yy = pr.y + pr.r - i * (pr.r * 0.55);
            final ww = pr.r * (1.1 - i * 0.13);
            final ox = sin(swirl + i) * (pr.r * 0.3);
            final col =
                i.isEven ? const Color(0xFFFF7043) : const Color(0xFFFFB300);
            canvas.drawOval(
                Rect.fromCenter(
                    center: Offset(pr.x + ox, yy), width: ww, height: ww * 0.7),
                Paint()..color = col.withOpacity(0.9));
          }
          canvas.drawCircle(Offset(pr.x, pr.y - pr.r * 0.2), pr.r * 0.4,
              Paint()..color = const Color(0xFFFFF59D));
        }
        break;
      case 'windblade':
        {
          // 대마법사 바람: a spinning tri-blade of wind (spin phase from x)
          canvas.save();
          canvas.translate(pr.x, pr.y);
          canvas.rotate(pr.x * 0.18);
          final blade = Paint()
            ..color = pr.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round;
          for (int k = 0; k < 3; k++) {
            canvas.rotate(pi * 2 / 3);
            canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: pr.r),
                -0.6, 1.2, false, blade);
          }
          canvas.drawCircle(Offset.zero, pr.r * 0.25,
              Paint()..color = Colors.white.withOpacity(0.8));
          canvas.restore();
        }
        break;
      default: // ball
        final size = pr.r * 2;
        final main = Rect.fromLTWH(pr.x - pr.r, pr.y - pr.r, size, size);
        _pixelRect(canvas, main, pr.color.withOpacity(0.9));
        _pixelRect(canvas, Rect.fromLTWH(pr.x - pr.r * 0.5, pr.y - pr.r * 0.5,
            pr.r, pr.r), Colors.white.withOpacity(0.8));
    }
  }

  // ----------------------------------------------------------------
  // SKILL FLOURISHES — distinct cast visuals per skill name
  void _skillFx(Canvas canvas, SkillFx fx) {
    final pr = fx.prog;
    final fade = (1 - pr).clamp(0.0, 1.0);
    switch (fx.kind) {
      case 'seraphwings':
        {
          // 치천사 대천사의 날개: two huge feathered wings fanning out on cast
          final span =
              fx.size * Curves.easeOut.transform((pr * 2).clamp(0.0, 1.0));
          for (int side = -1; side <= 1; side += 2) {
            for (int f = 0; f < 6; f++) {
              final ff = f / 5.0;
              final len = span * (0.5 + ff * 0.5);
              final yo = -44 + ff * 78;
              final root = Offset(fx.x + side * 10.0, fx.y + yo);
              final tip = Offset(fx.x + side * len, fx.y + yo - len * 0.12);
              canvas.drawLine(
                  root,
                  tip,
                  Paint()
                    ..color = fx.color.withOpacity(0.5 * fade)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 7
                    ..strokeCap = StrokeCap.round);
              canvas.drawLine(
                  root,
                  tip,
                  Paint()
                    ..color = Colors.white.withOpacity(0.6 * fade)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 2
                    ..strokeCap = StrokeCap.round);
            }
          }
          _glow(canvas, Offset(fx.x, fx.y), 40 * fade + 12,
              fx.color.withOpacity(0.22 * fade), 18);
        }
        break;
      case 'ring':
        final r = fx.size * Curves.easeOut.transform(pr) + 6;
        canvas.drawCircle(
            Offset(fx.x, fx.y),
            r,
            Paint()
              ..color = fx.color.withOpacity(0.7 * fade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 7 * fade + 1);
        canvas.drawCircle(
            Offset(fx.x, fx.y),
            r * 0.7,
            Paint()
              ..color = Colors.white.withOpacity(0.4 * fade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade + 1);
        break;
      case 'dualring':
        for (int k = 0; k < 2; k++) {
          final ph = (pr - k * 0.18).clamp(0.0, 1.0);
          if (ph <= 0) continue;
          final r = fx.size * Curves.easeOut.transform(ph) + 6;
          canvas.drawCircle(
              Offset(fx.x, fx.y),
              r,
              Paint()
                ..color = (k == 0 ? fx.color : const Color(0xFFFFD166))
                    .withOpacity(0.7 * (1 - ph))
                ..style = PaintingStyle.stroke
                ..strokeWidth = 8 * (1 - ph) + 1);
        }
        if (pr < 0.4) {
          canvas.drawCircle(Offset(fx.x, fx.y), 26 * (1 - pr / 0.4),
              Paint()..color = Colors.white.withOpacity(0.8 * (1 - pr / 0.4)));
        }
        break;
      case 'runes':
        // rotating magic circle at the cast point
        final r = fx.size * (0.6 + 0.4 * pr);
        final a = fx.color.withOpacity(0.85 * fade);
        canvas.save();
        canvas.translate(fx.x, fx.y);
        canvas.drawCircle(Offset.zero, r,
            Paint()..color = a..style = PaintingStyle.stroke..strokeWidth = 2);
        canvas.drawCircle(Offset.zero, r * 0.7,
            Paint()..color = a..style = PaintingStyle.stroke..strokeWidth = 1.5);
        canvas.rotate(pr * 3);
        for (int i = 0; i < 8; i++) {
          final ang = i / 8 * pi * 2;
          _pixelRect(
              canvas,
              Rect.fromCenter(
                  center: Offset(cos(ang) * r, sin(ang) * r),
                  width: 6,
                  height: 6),
              a);
        }
        // inner rotating square
        canvas.rotate(-pr * 5);
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: r, height: r),
            Paint()
              ..color = a
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        canvas.restore();
        break;
      case 'ghost':
        // afterimage silhouettes left along a dash path
        const n = 5;
        for (int i = 0; i <= n; i++) {
          final gx = fx.x + fx.size * (i / n);
          final al = (0.5 * fade) * (1 - i / (n + 1.0));
          _ghostSilhouette(canvas, gx, fx.y, fx.dir, fx.color, al);
        }
        break;
      case 'crack':
        // ground fissure + rising shards
        final spread = fx.size * Curves.easeOut.transform(pr);
        final paint = Paint()
          ..color = fx.color.withOpacity(0.85 * fade)
          ..strokeWidth = 4 * fade + 1
          ..strokeCap = StrokeCap.round;
        for (final s in [-1, 1]) {
          double x = fx.x;
          double y = fx.y;
          final steps = (spread / 24).floor();
          for (int i = 0; i < steps; i++) {
            final nx = x + s * 24;
            final ny = fx.y + (i.isEven ? -6 : 6);
            canvas.drawLine(Offset(x, y), Offset(nx, ny), paint);
            x = nx;
            y = ny;
          }
        }
        // upward shards
        for (int i = 0; i < 6; i++) {
          final sx = fx.x + (i - 3) * (spread / 6);
          final hgt = 18 * fade * (0.6 + 0.4 * sin(i.toDouble()));
          _pixelRect(canvas, Rect.fromLTWH(sx - 3, fx.y - hgt, 6, hgt),
              fx.color.withOpacity(0.8 * fade));
        }
        break;
      case 'handrise':
        // a clawed shadow hand bursting up from the ground, then sinking back.
        // rises during the first 60% of life, lingers, then fades.
        final rise = Curves.easeOut.transform((pr / 0.6).clamp(0.0, 1.0));
        final h = fx.size * rise;
        final palm = fx.color.withOpacity(0.9 * fade);
        final claw = const Color(0xFFB388FF).withOpacity(0.95 * fade);
        final base = fx.y; // ground line
        final topY = base - h;
        // wrist/forearm
        _pixelRect(canvas, Rect.fromLTWH(fx.x - 4, topY + h * 0.45, 8, h * 0.55),
            const Color(0xFF311B92).withOpacity(0.85 * fade));
        // palm block
        _pixelRect(
            canvas, Rect.fromLTWH(fx.x - 7, topY + h * 0.3, 14, h * 0.25), palm);
        // four reaching fingers
        for (int f = -2; f <= 1; f++) {
          final fx0 = fx.x + f * 4.0 + 2;
          _pixelRect(canvas, Rect.fromLTWH(fx0 - 1.5, topY, 3, h * 0.42), claw);
        }
        break;
      case 'claw':
        // three parallel claw streaks in facing direction
        final reach = fx.size * (0.5 + 0.5 * pr);
        for (int i = -1; i <= 1; i++) {
          final y = fx.y + i * 14.0;
          canvas.drawLine(
              Offset(fx.x, y - i * 4),
              Offset(fx.x + fx.dir * reach, y + i * 6),
              Paint()
                ..color = fx.color.withOpacity(0.85 * fade)
                ..strokeWidth = 5 * fade + 1
                ..strokeCap = StrokeCap.round);
        }
        break;
      case 'slashArc':
        // crescent sweep in facing direction
        final r = fx.size * (0.7 + 0.3 * pr);
        final cx = fx.x + fx.dir * 12;
        final base = fx.dir >= 0 ? -pi / 2 : pi / 2;
        canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, fx.y), radius: r),
            base - 0.9,
            1.8,
            false,
            Paint()
              ..color = fx.color.withOpacity(0.8 * fade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 9 * fade + 1
              ..strokeCap = StrokeCap.round);
        canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, fx.y), radius: r * 0.82),
            base - 0.7,
            1.4,
            false,
            Paint()
              ..color = Colors.white.withOpacity(0.5 * fade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3 * fade + 1);
        break;
      case 'lightning':
        // jagged bolt arcing from (x,y) to (x2,y2)
        final dx = fx.x2 - fx.x, dy = fx.y2 - fx.y;
        final len = sqrt(dx * dx + dy * dy);
        if (len < 1) break;
        final px = -dy / len, py = dx / len; // perpendicular unit
        final path = Path()..moveTo(fx.x, fx.y);
        const seg = 6;
        for (int i = 1; i < seg; i++) {
          final tt = i / seg;
          final j = (i.isEven ? 1 : -1) * (8 + (i * 37 % 13)) * fade;
          path.lineTo(fx.x + dx * tt + px * j, fx.y + dy * tt + py * j);
        }
        path.lineTo(fx.x2, fx.y2);
        canvas.drawPath(
            path,
            Paint()
              ..color = fx.color.withOpacity(0.9 * fade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5 * fade + 2
              ..strokeCap = StrokeCap.round);
        canvas.drawPath(
            path,
            Paint()
              ..color = Colors.white.withOpacity(0.85 * fade)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2 * fade + 1);
        break;
      case 'fist':
        // martial-artist flurry of punches forward
        final reach = fx.size * (0.4 + 0.6 * pr);
        for (int i = 0; i < 2; i++) {
          final fxp = fx.x + fx.dir * (reach * (0.45 + 0.55 * i));
          final fyp = fx.y + (i == 0 ? -9 : 9);
          _fistShape(canvas, fxp, fyp, fx.dir, fx.color.withOpacity(0.9 * fade));
        }
        canvas.drawCircle(
            Offset(fx.x + fx.dir * reach, fx.y),
            10 * fade + 4,
            Paint()..color = fx.color.withOpacity(0.45 * fade));
        canvas.drawCircle(
            Offset(fx.x + fx.dir * reach, fx.y),
            6 * fade + 2,
            Paint()..color = Colors.white.withOpacity(0.6 * fade));
        break;
      case 'bigfist':
        // 정권지르기: one large fist driving forward, with motion streaks
        // behind it and a bright impact shock at the front.
        final reach = fx.size * (0.25 + 0.75 * pr);
        final fxp = fx.x + fx.dir * reach;
        final streak = Paint()
          ..color = fx.color.withOpacity(0.5 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 * fade + 2
          ..strokeCap = StrokeCap.round;
        for (int i = -1; i <= 1; i++) {
          canvas.drawLine(Offset(fx.x, fx.y + i * 11.0),
              Offset(fxp - fx.dir * 16, fx.y + i * 11.0), streak);
        }
        final sc = 2.6 * (1.0 - 0.18 * pr);
        canvas.save();
        canvas.translate(fxp, fx.y);
        canvas.scale(sc, sc);
        _fistShape(canvas, 0, 0, fx.dir, fx.color.withOpacity(0.95 * fade));
        canvas.restore();
        canvas.drawCircle(Offset(fxp + fx.dir * 16, fx.y), 30 * fade + 8,
            Paint()..color = fx.color.withOpacity(0.35 * fade));
        canvas.drawCircle(Offset(fxp + fx.dir * 16, fx.y), 16 * fade + 4,
            Paint()..color = Colors.white.withOpacity(0.55 * fade));
        break;
      case 'dragon':
        // 용기병 평타: a serpentine dragon lunges forward along the thrust,
        // its body a wavy chain of scales tipped with a fanged, horned head.
        final reach = fx.size * (0.35 + 0.65 * pr);
        final bodyC = fx.color.withOpacity(0.9 * fade);
        final bodyDk = Color.lerp(fx.color, const Color(0xFF0B0712), 0.45)!
            .withOpacity(0.9 * fade);
        const seg = 8;
        for (int i = 0; i <= seg; i++) {
          final tt = i / seg;
          final sx = fx.x + fx.dir * reach * tt;
          final sy = fx.y + sin(tt * pi * 1.6 + pr * 4) * 13 * (1 - tt * 0.35);
          final rr = (3.5 + (1 - tt) * 5) * fade;
          _pixelRect(
              canvas,
              Rect.fromCenter(
                  center: Offset(sx, sy), width: rr * 2, height: rr * 2),
              i.isEven ? bodyC : bodyDk);
        }
        final hx = fx.x + fx.dir * reach;
        _dragonShape(canvas, hx, fx.y, fx.dir, 1.0 + 0.3 * pr, fx.color, fade);
        // fiery breath flickers just ahead of the maw
        for (int i = 0; i < 3; i++) {
          final bx = hx + fx.dir * (10 + i * 7.0);
          canvas.drawCircle(
              Offset(bx, fx.y - 2 + (i - 1) * 3.0),
              (4 - i) * fade + 1,
              Paint()
                ..color = (i.isEven ? const Color(0xFFFFD166) : fx.color)
                    .withOpacity(0.6 * fade));
        }
        break;
      case 'lichscythe':
        _lichScythe(canvas, fx, pr, fade);
        break;
    }
  }

  // The wraith's legendary 사령의 대낫: a towering hooded lich filling the view,
  // sweeping a giant crescent scythe across the screen. Sized to the viewport.
  void _lichScythe(Canvas canvas, SkillFx fx, double pr, double fade) {
    final w = fx.size; // ≈ viewport width
    final cx = fx.x, cy = fx.y;
    final col = fx.color;
    final a = fade;
    // dark aura behind the apparition
    _glow(canvas, Offset(cx, cy + w * 0.12), w * 0.5,
        const Color(0xFF1A0A24).withOpacity(0.5 * a), 60);
    // ---- hood ----
    final hoodW = w * 0.36, hoodH = w * 0.30;
    final hood = Path()
      ..moveTo(cx, cy - hoodH * 0.75)
      ..lineTo(cx - hoodW * 0.5, cy + hoodH * 0.5)
      ..lineTo(cx - hoodW * 0.26, cy + hoodH * 0.62)
      ..lineTo(cx, cy + hoodH * 0.30)
      ..lineTo(cx + hoodW * 0.26, cy + hoodH * 0.62)
      ..lineTo(cx + hoodW * 0.5, cy + hoodH * 0.5)
      ..close();
    canvas.drawPath(hood, Paint()..color = const Color(0xFF120A1A).withOpacity(0.94 * a));
    canvas.drawPath(
        hood,
        Paint()
          ..color = col.withOpacity(0.35 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.006 + 2);
    // ---- face cavity + glowing eyes ----
    canvas.drawCircle(Offset(cx, cy + hoodH * 0.06), hoodW * 0.22,
        Paint()..color = Colors.black.withOpacity(0.85 * a));
    final eyeY = cy + hoodH * 0.04;
    for (final ex in const [-1.0, 1.0]) {
      final eo = Offset(cx + ex * hoodW * 0.11, eyeY);
      _glow(canvas, eo, w * 0.04, col.withOpacity(0.7 * a), 18);
      canvas.drawCircle(eo, w * 0.014 + 3, Paint()..color = col.withOpacity(0.95 * a));
      canvas.drawCircle(
          eo, w * 0.006 + 1, Paint()..color = Colors.white.withOpacity(0.9 * a));
    }
    // ---- giant sweeping scythe ----
    final pivot = Offset(cx + fx.dir * hoodW * 0.55, cy + hoodH * 0.55);
    final sweep = (-1.25 + 2.5 * pr) * fx.dir; // blade arcs across the screen
    final r = w * 0.52;
    canvas.drawLine(
        pivot,
        Offset(pivot.dx + cos(sweep) * r * 0.7, pivot.dy + sin(sweep) * r * 0.7),
        Paint()
          ..color = const Color(0xFF3A2A1A).withOpacity(0.9 * a)
          ..strokeWidth = w * 0.012 + 2
          ..strokeCap = StrokeCap.round);
    canvas.drawArc(
        Rect.fromCircle(center: pivot, radius: r),
        sweep - 0.55,
        1.5,
        false,
        Paint()
          ..color = col.withOpacity(0.85 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.022 + 3
          ..strokeCap = StrokeCap.round);
    canvas.drawArc(
        Rect.fromCircle(center: pivot, radius: r * 0.93),
        sweep - 0.45,
        1.2,
        false,
        Paint()
          ..color = Colors.white.withOpacity(0.5 * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.008 + 1
          ..strokeCap = StrokeCap.round);
  }

  // A stylized dragon head pointing outward (+x), used by the dragoon's basic
  // attack FX. Drawn around the origin; caller sets position/scale/facing.
  void _dragonShape(Canvas canvas, double x, double y, double dir, double scale,
      Color color, double fade) {
    final body = color.withOpacity(0.95 * fade);
    final dark = Color.lerp(color, const Color(0xFF0B0712), 0.5)!
        .withOpacity(0.95 * fade);
    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.45)!
        .withOpacity(0.95 * fade);
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(dir * scale, scale);
    // upper jaw / snout
    _pixelRect(canvas, const Rect.fromLTWH(-2, -8, 20, 7), body);
    _pixelRect(canvas, const Rect.fromLTWH(16, -7, 6, 4), body); // snout tip
    _pixelRect(canvas, const Rect.fromLTWH(-2, -8, 20, 2), light); // top light
    // lower jaw (open maw)
    _pixelRect(canvas, const Rect.fromLTWH(0, 2, 16, 4), dark);
    _pixelRect(canvas, const Rect.fromLTWH(14, 1, 5, 3), dark);
    // teeth
    _pixelRect(canvas, const Rect.fromLTWH(12, -2, 2, 3), light);
    _pixelRect(canvas, const Rect.fromLTWH(8, -2, 2, 3), light);
    _pixelRect(canvas, const Rect.fromLTWH(12, 2, 2, 2), light);
    // eye + nostril
    _pixelRect(canvas, const Rect.fromLTWH(2, -5, 3, 3),
        const Color(0xFFFFF59D).withOpacity(fade));
    _pixelRect(canvas, const Rect.fromLTWH(17, -6, 2, 2), dark);
    // swept-back horns + cheek frill
    _pixelRect(canvas, const Rect.fromLTWH(-2, -12, 4, 5), dark);
    _pixelRect(canvas, const Rect.fromLTWH(-7, -14, 5, 4), dark);
    _pixelRect(canvas, const Rect.fromLTWH(-6, -10, 4, 4), body);
    canvas.restore();
  }

  void _fistShape(Canvas canvas, double x, double y, double dir, Color color) {
    canvas.save();
    canvas.translate(x, y);
    canvas.scale(dir, 1);
    _pixelRect(canvas, const Rect.fromLTWH(-10, -9, 16, 18), color); // fist block
    for (int k = 0; k < 4; k++) {
      _pixelRect(canvas, Rect.fromLTWH(6, -9 + k * 4.5, 4, 4), color); // knuckles
    }
    _pixelRect(canvas, const Rect.fromLTWH(-14, -5, 5, 10),
        Color.lerp(color, const Color(0xFF000000), 0.25)!); // wrist
    _pixelRect(canvas, const Rect.fromLTWH(-9, -8, 14, 4),
        Color.lerp(color, const Color(0xFFFFFFFF), 0.3)!); // highlight
    canvas.restore();
  }

  void _ghostSilhouette(
      Canvas canvas, double x, double y, double dir, Color color, double alpha) {
    if (alpha <= 0.02) return;
    final c = color.withOpacity(alpha);
    // body + skull head, matching the player's blocky proportions
    _pixelRect(canvas, Rect.fromLTWH(x - 10, y - 4, 20, 22), c);
    _pixelRect(canvas, Rect.fromLTWH(x - 10, y - 22, 20, 18), c);
    _pixelRect(canvas, Rect.fromLTWH(x - 2 + dir * 4, y - 18, 4, 4),
        Colors.white.withOpacity(alpha));
  }

  void _particle(Canvas canvas, Particle pa) {
    final a = (pa.life / pa.maxLife).clamp(0.0, 1.0);
    final s = pa.size * a;
    _pixelRect(canvas,
        Rect.fromLTWH(pa.x - s / 2, pa.y - s / 2, s, s),
        pa.color.withOpacity(a));
  }

  // ----------------------------------------------------------------
  // PLAYER (skeleton with class-tinted body + per-skull weapon)
  void _player(Canvas canvas, Player p) {
    canvas.save();
    canvas.translate(p.cx, p.y);
    canvas.scale(p.facing.toDouble(), 1.0);
    final pHurt = (p.hurtTimer / 0.18).clamp(0.0, 1.0);
    if (pHurt > 0) {
      canvas.translate(-pHurt * 4, pHurt * 2);
      canvas.rotate(pHurt * 0.18);
    }

    final sk = p.skull;
    // 사신 유령화 / 야밤도 그림자 잠행: composite the whole body at reduced opacity
    final ghost = p.ghostTimer > 0;
    final veil = p.stealthTimer > 0;
    if (ghost || veil) {
      canvas.saveLayer(const Rect.fromLTWH(-90, -56, 180, 150),
          Paint()..color = Colors.white.withOpacity(veil ? 0.30 : 0.5));
    }
    final flashing = !ghost && p.invuln > 0 && ((p.invuln * 22).floor() % 2 == 0);
    final body = flashing ? Colors.white : sk.body;
    final moving = p.vx.abs() > 10 && p.onGround && !p.dodging;
    final t = p.animTime;
    final legSwing = moving ? sin(t * 16) * 7 : 0.0;
    final bob = moving ? (sin(t * 16).abs() * -2) : 0.0;
    final cy = bob;

    // skill flourish ring
    if (p.skillActive > 0) {
      canvas.drawCircle(
          Offset(0, p.h / 2),
          70 * (1 - p.skillActive / 0.32) + 20,
          Paint()
            ..color = sk.eye.withOpacity(0.4 * (p.skillActive / 0.32))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5);
    }

    // shadow
    _pixelRect(
        canvas, Rect.fromLTWH(-18, p.h - 6, 36, 8), Colors.black.withOpacity(0.28));

    // 망령기사 유령마: a spectral steed carrying the rider (drawn behind the body)
    if (p.rideTimer > 0) _ghostHorse(canvas, p, cy);
    // 약탈자 가시 반사: a spiked golden ward ringing the body
    if (p.reflectTimer > 0) {
      const gold = Color(0xFFFFCA28);
      final rr = 30.0 + sin(t * 12) * 2;
      _glow(canvas, Offset(0, 22 + cy), 26, gold.withOpacity(0.16), 14);
      canvas.drawCircle(
          Offset(0, 22 + cy),
          rr,
          Paint()
            ..color = gold.withOpacity(0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      for (int i = 0; i < 8; i++) {
        final a = t * 2 + i / 8 * pi * 2;
        canvas.drawCircle(Offset(cos(a) * rr, 22 + cy + sin(a) * rr), 2.2,
            Paint()..color = gold.withOpacity(0.9));
      }
    }

    // soft backlight aura (skull-colored) — bigger spectral purple halo in ghost
    _glow(canvas, Offset(0, 18 + cy), ghost ? 30 : 22,
        (ghost ? const Color(0xFFB388FF) : sk.eye).withOpacity(ghost ? 0.34 : 0.18),
        ghost ? 16 : 12);

    // ---- cape / cowl behind the body (dark, skull-tinted) — the Skul cloak ----
    final capeDk = Color.lerp(sk.body, const Color(0xFF0B0712), 0.62)!;
    final capeMd = Color.lerp(sk.body, const Color(0xFF0B0712), 0.45)!;
    final capeSwing = moving ? sin(t * 16) * 2.5 : 0.0;
    // raised collar framing the skull (the signature cowl)
    _pixelRect(canvas, Rect.fromLTWH(-11, -1 + cy, 22, 9), capeDk);
    _pixelRect(canvas, Rect.fromLTWH(-13, 1 + cy, 5, 9), capeDk); // left wing
    _pixelRect(canvas, Rect.fromLTWH(8, 1 + cy, 5, 9), capeDk); // right wing
    // flowing cape trailing behind the body
    _pixelRect(canvas, Rect.fromLTWH(-9 + capeSwing, 16 + cy, 7, 24), capeMd);
    _pixelRect(canvas, Rect.fromLTWH(-2 + capeSwing, 16 + cy, 7, 26), capeDk);
    _pixelRect(canvas, Rect.fromLTWH(-7 + capeSwing, 38 + cy, 5, 5), capeDk); // tattered tip
    _pixelRect(canvas, Rect.fromLTWH(1 + capeSwing, 40 + cy, 5, 4), capeMd);

    // ---- dragon wings (용기병 용의 비상) — behind the body, flapping ----
    if (p.flyTimer > 0) _wings(canvas, p, cy);

    // ---- legs (small skeletal) ----
    _pixelRect(canvas, Rect.fromLTWH(-8, 34 + cy, 6, 13), const Color(0xFF2E2A36));
    _pixelRect(canvas, Rect.fromLTWH(2, 34 + cy, 6, 13), const Color(0xFF2E2A36));
    _pixelRect(canvas, Rect.fromLTWH(-9 + legSwing * 0.4, 46 + cy, 8, 4),
        const Color(0xFF1C1922)); // foot
    _pixelRect(canvas, Rect.fromLTWH(2 - legSwing * 0.4, 46 + cy, 8, 4),
        const Color(0xFF1C1922));

    // ---- torso: separated upper garment (상의) + belt + lower garment (하의) ----
    final (bShadow, bMid, bLight) = _ramp(body);
    // lower garment is a darker tone of the body so top/bottom read apart
    final lower = Color.lerp(body, const Color(0xFF17121F), 0.5)!;
    final (lShadow, lMid, lLight) = _ramp(lower);

    // dark silhouette backing for the whole torso
    _pixelRect(canvas, Rect.fromLTWH(-11, 15 + cy, 22, 25),
        const Color(0xFF120E1C).withOpacity(0.9));

    // collar
    _pixelRect(canvas, Rect.fromLTWH(-6, 14 + cy, 12, 2), bLight);
    // shoulders (wide) tapering to the chest — breaks the boxy outline
    _pixelRect(canvas, Rect.fromLTWH(-10, 16 + cy, 20, 4), bMid); // shoulders
    _pixelRect(canvas, Rect.fromLTWH(-9, 20 + cy, 18, 6), bMid); // chest/waist
    _pixelRect(canvas, Rect.fromLTWH(-10, 16 + cy, 20, 2), bLight); // shoulder light
    _pixelRect(canvas, Rect.fromLTWH(-9, 24 + cy, 18, 2), bShadow); // under-chest shade
    _pixelRect(canvas, Rect.fromLTWH(-1, 17 + cy, 2, 9),
        Color.lerp(body, Colors.black, 0.22)!); // center placket seam
    _pixelRect(canvas, Rect.fromLTWH(7, 17 + cy, 2, 9), bLight.withOpacity(0.7)); // rim

    // belt with a skull-colored buckle
    _pixelRect(canvas, Rect.fromLTWH(-9, 26 + cy, 18, 3),
        Color.lerp(body, Colors.black, 0.55)!);
    _pixelRect(canvas, Rect.fromLTWH(-2, 26 + cy, 4, 3), sk.eye.withOpacity(0.85));

    // lower garment (하의): darker, slightly flared at the hem
    _pixelRect(canvas, Rect.fromLTWH(-9, 29 + cy, 18, 5), lMid);
    _pixelRect(canvas, Rect.fromLTWH(-10, 33 + cy, 20, 3), lMid); // hem flare
    _pixelRect(canvas, Rect.fromLTWH(-9, 29 + cy, 18, 2), lLight); // top light
    _pixelRect(canvas, Rect.fromLTWH(-10, 34 + cy, 20, 2), lShadow); // hem shadow
    _pixelRect(canvas, Rect.fromLTWH(-1, 29 + cy, 2, 6),
        Color.lerp(lower, Colors.black, 0.35)!); // center leg split

    // ---- the skull head (signature) ----
    _drawPlayerSkull(canvas, cy, sk.eye, flashing);
    // 검성 창천의 검기: a long blue energy blade wreathing the weapon
    if (p.auraTimer > 0) {
      const blue = Color(0xFF18FFFF);
      final by = 22 + cy;
      _glow(canvas, Offset(70, by), 20, blue.withOpacity(0.4), 14);
      final blade = Path()
        ..moveTo(14, by - 3)
        ..lineTo(120, by - 9)
        ..lineTo(134, by)
        ..lineTo(120, by + 9)
        ..lineTo(14, by + 3)
        ..close();
      canvas.drawPath(blade, Paint()..color = blue.withOpacity(0.5));
      canvas.drawPath(
          blade,
          Paint()
            ..color = Colors.white.withOpacity(0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
    // (ghost/veil opacity layer closed below)

    // ---- job identity + per-skull theming over the base skeleton ----
    _drawSkullGear(canvas, sk, cy, flashing, t);

    _weapon(canvas, p, cy);
    if (ghost || veil) canvas.restore(); // close the spectral opacity layer
    canvas.restore();
    _statusFx(canvas, p);
  }

  // Membrane dragon wings that unfurl while 용의 비상 is active. Drawn in the
  // player's facing-mirrored frame and flap with the animation clock.
  // 망령기사 유령마: a translucent spectral horse beneath the rider. Drawn in the
  // player's local space (origin = top-center, already scaled by facing so +x is
  // forward). Legs gallop with the player's animTime.
  void _ghostHorse(Canvas canvas, Player p, double cy) {
    const ghostA = 0.55;
    const horse = Color(0xFFB388FF);
    const horseDk = Color(0xFF7E57C2);
    final eye = p.skull.eye;
    final t = p.animTime;
    final gallop = sin(t * 14) * 3;
    final gy = p.h - 2 + cy; // hoof line near the player's feet
    _glow(canvas, Offset(2, gy - 12), 30, horse.withOpacity(0.22), 16);
    // tail streaming behind
    _pixelRect(canvas, Rect.fromLTWH(-30, gy - 20, 10, 4),
        horseDk.withOpacity(ghostA));
    _pixelRect(canvas, Rect.fromLTWH(-32, gy - 14, 12, 4),
        horse.withOpacity(ghostA * 0.8));
    // barrel / body
    _pixelRect(canvas, Rect.fromLTWH(-24, gy - 24, 44, 14),
        horse.withOpacity(ghostA));
    _pixelRect(canvas, Rect.fromLTWH(-24, gy - 24, 44, 3),
        horse.withOpacity(ghostA * 0.6));
    // chest + neck rising forward
    _pixelRect(canvas, Rect.fromLTWH(12, gy - 34, 12, 16),
        horse.withOpacity(ghostA));
    // head
    _pixelRect(canvas, Rect.fromLTWH(20, gy - 38, 14, 9),
        horse.withOpacity(ghostA));
    _pixelRect(canvas, Rect.fromLTWH(30, gy - 34, 6, 5),
        horseDk.withOpacity(ghostA)); // muzzle
    // mane
    _pixelRect(canvas, Rect.fromLTWH(10, gy - 38, 6, 18),
        horseDk.withOpacity(ghostA));
    // glowing eye
    canvas.drawCircle(Offset(26, gy - 33), 2.2, Paint()..color = eye);
    // four galloping legs
    _pixelRect(canvas, Rect.fromLTWH(-20 + gallop, gy - 12, 5, 14),
        horseDk.withOpacity(ghostA));
    _pixelRect(canvas, Rect.fromLTWH(-10 - gallop, gy - 12, 5, 14),
        horseDk.withOpacity(ghostA));
    _pixelRect(canvas, Rect.fromLTWH(6 + gallop, gy - 12, 5, 14),
        horseDk.withOpacity(ghostA));
    _pixelRect(canvas, Rect.fromLTWH(15 - gallop, gy - 12, 5, 14),
        horseDk.withOpacity(ghostA));
  }

  // 용기병 용의 비상: a pair of big, four-fingered dragon wings with a scalloped
  // membrane, glowing leading edge, finger-bones and claws — flapping in time.
  void _wings(Canvas canvas, Player p, double cy) {
    final flap = sin(p.animTime * 11); // -1..1 flap cycle
    final eye = p.skull.eye;
    final memb = Color.lerp(eye, const Color(0xFF140A1E), 0.34)!;
    final bone = Color.lerp(eye, Colors.white, 0.4)!;
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(0, 16 + cy); // shoulder root
      final open = 0.78 + 0.22 * (flap * 0.5 + 0.5); // spread amount
      final lift = -0.5 - 0.5 * flap; // flap up/down
      // wrist (the wing-arm's elbow), thrown up and out
      final wrist = Offset(side * 30 * open, lift * 22 - 14);
      // four finger tips fanning from the wrist outward and down
      final tips = <Offset>[
        Offset(side * 52 * open, lift * 16 - 6),
        Offset(side * 50 * open, lift * 6 + 12),
        Offset(side * 40 * open, lift * 2 + 26),
        Offset(side * 24 * open, 34),
      ];
      // membrane: root → wrist → scalloped (concave) web between the finger tips
      final m = Path()
        ..moveTo(0, 0)
        ..lineTo(wrist.dx, wrist.dy);
      var prev = wrist;
      for (final tp in tips) {
        final ctrl = Offset(
            (prev.dx + tp.dx) / 2 - side * 4, (prev.dy + tp.dy) / 2 + 9);
        m.quadraticBezierTo(ctrl.dx, ctrl.dy, tp.dx, tp.dy);
        prev = tp;
      }
      m
        ..lineTo(side * 6, 30)
        ..close();
      canvas.drawPath(m, Paint()..color = memb.withOpacity(0.92));
      // glowing leading edge (root → wrist → outer tip)
      canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(wrist.dx, wrist.dy)
            ..lineTo(tips[0].dx, tips[0].dy),
          Paint()
            ..color = eye.withOpacity(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
      // arm + finger bones
      canvas.drawLine(
          Offset.zero,
          wrist,
          Paint()
            ..color = bone
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round);
      final bp = Paint()
        ..color = bone
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (final tp in tips) {
        canvas.drawLine(wrist, tp, bp);
        canvas.drawCircle(tp, 1.8, Paint()..color = bone); // claw tip
      }
      canvas.drawCircle(wrist, 2.4, Paint()..color = bone); // wrist claw
      canvas.restore();
    }
  }

  // A stormcaller thunderhead hovering over its target. Brightens and crackles
  // the instant a bolt falls (boltFlash); the bolt itself is a 'lightning' FX.
  void _stormCloud(Canvas canvas, StormCloud c) {
    final fade = c.life < 1.0 ? c.life.clamp(0.0, 1.0) : 1.0;
    final flash = (c.boltFlash / 0.22).clamp(0.0, 1.0);
    final dark = Color.lerp(
        const Color(0xFF2A3340), const Color(0xFFE0F7FA), flash * 0.6)!;
    // underglow that flares on a strike
    _glow(canvas, Offset(c.x, c.y + 6), 34,
        const Color(0xFF18FFFF).withOpacity((0.16 + 0.45 * flash) * fade), 16);
    // base shadow strip
    _pixelRect(
        canvas,
        Rect.fromCenter(center: Offset(c.x, c.y + 8), width: 64, height: 10),
        Color.lerp(dark, const Color(0xFF0B0712), 0.4)!.withOpacity(0.9 * fade));
    // overlapping cloud lumps
    for (final o in [
      Offset(c.x - 22, c.y),
      Offset(c.x + 22, c.y),
      Offset(c.x - 10, c.y + 4),
      Offset(c.x + 12, c.y + 4),
      Offset(c.x, c.y - 6),
    ]) {
      _pixelRect(canvas, Rect.fromCenter(center: o, width: 30, height: 18),
          dark.withOpacity(0.92 * fade));
    }
    // a crackle of static under the cloud right after a strike
    if (flash > 0.05) {
      canvas.drawLine(
          Offset(c.x, c.y + 8),
          Offset(c.x + sin(c.t * 22) * 7, c.y + 22),
          Paint()
            ..color = const Color(0xFFE0F7FA).withOpacity(0.85 * fade)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round);
    }
  }

  // The hero's skull head, in the chibi reference style: a big rounded cranium
  // with a crisp dark outline, deep sockets with a flame glow, a small nasal
  // cavity and a toothed jaw. Centered on x=0; cranium top ≈ -6.
  void _drawPlayerSkull(Canvas canvas, double cy, Color eye, bool flashing) {
    const bone = Color(0xFFF3F5F6);
    const boneMid = Color(0xFFDBE0E4);
    const boneShade = Color(0xFFAEB6BE);
    const socket = Color(0xFF14101A);
    const outline = Color(0xFF1A1622);
    final y0 = cy;

    // flame glow behind the sockets
    _glow(canvas, Offset(-4, 8 + y0), 5, eye.withOpacity(0.5), 4);
    _glow(canvas, Offset(4, 8 + y0), 5, eye.withOpacity(0.5), 4);

    // ---- dark outline silhouette (one step larger than the bone fill) ----
    _pixelRect(canvas, Rect.fromLTWH(-6, -6 + y0, 12, 2), outline); // crown
    _pixelRect(canvas, Rect.fromLTWH(-9, -4 + y0, 18, 3), outline);
    _pixelRect(canvas, Rect.fromLTWH(-11, -1 + y0, 22, 12), outline); // main mass
    _pixelRect(canvas, Rect.fromLTWH(-8, 11 + y0, 16, 4), outline); // jaw

    // ---- bone fill (inset 1px inside the outline) for a rounded skull ----
    _pixelRect(canvas, Rect.fromLTWH(-5, -5 + y0, 10, 1), boneMid); // crown cap
    _pixelRect(canvas, Rect.fromLTWH(-8, -3 + y0, 16, 3), bone); // upper
    _pixelRect(canvas, Rect.fromLTWH(-10, 0 + y0, 20, 10), bone); // widest
    _pixelRect(canvas, Rect.fromLTWH(-8, 10 + y0, 16, 1), boneMid); // cheek taper
    // top sheen + side shade for volume
    _pixelRect(canvas, Rect.fromLTWH(-5, -5 + y0, 8, 2), Colors.white);
    _pixelRect(canvas, Rect.fromLTWH(-8, -3 + y0, 4, 2), Colors.white.withOpacity(0.85));
    _pixelRect(canvas, Rect.fromLTWH(8, 1 + y0, 2, 9), boneShade);

    // ---- eye sockets (big, deep) + glowing pupils + spark ----
    _pixelRect(canvas, Rect.fromLTWH(-8, 2 + y0, 6, 7), socket);
    _pixelRect(canvas, Rect.fromLTWH(2, 2 + y0, 6, 7), socket);
    final pupil = flashing ? Colors.white : eye;
    _pixelRect(canvas, Rect.fromLTWH(-7, 5 + y0, 4, 3), pupil);
    _pixelRect(canvas, Rect.fromLTWH(3, 5 + y0, 4, 3), pupil);
    _pixelRect(canvas, Rect.fromLTWH(-6, 5 + y0, 1, 1), Colors.white);
    _pixelRect(canvas, Rect.fromLTWH(4, 5 + y0, 1, 1), Colors.white);

    // nasal cavity (small inverted notch)
    _pixelRect(canvas, Rect.fromLTWH(-1, 9 + y0, 2, 2), socket);

    // ---- jaw + teeth ----
    _pixelRect(canvas, Rect.fromLTWH(-6, 11 + y0, 12, 3), boneMid);
    _pixelRect(canvas, Rect.fromLTWH(-6, 11 + y0, 12, 1),
        Color.lerp(boneMid, Colors.black, 0.3)!); // jaw shadow line
    for (final tx in [-4.0, -1.0, 2.0]) {
      _pixelRect(canvas, Rect.fromLTWH(tx, 12 + y0, 1, 2), socket); // teeth gaps
    }
  }

  // Map a skull to a visual archetype: specific flavor jobs first, then by
  // category, then by weapon — so every skull reads as its profession.
  String _skullLook(SkullSpec sk) {
    switch (sk.type) {
      case SkullType.farmhand:
        return 'farmer';
      case SkullType.miner:
        return 'miner';
      case SkullType.fisher:
        return 'fisher';
      case SkullType.militia:
      case SkullType.footman:
        return 'militia';
      default:
        break;
    }
    switch (sk.category) {
      case '기사':
        return 'knight';
      case '마법형':
        return 'mage';
      case '궁수형':
        return 'archer';
      case '짐승형':
        return 'beast';
      case '권사':
        return 'fist';
      case '창병':
        return 'spear';
      default: // 검사 / 특수형
        if (sk.weapon == 'scythe') return 'reaper';
        if (sk.weapon == 'daggers') return 'rogue';
        if (sk.weapon == 'axe' || sk.weapon == 'greatsword') return 'warrior';
        return 'sword';
    }
  }

  // Per-skull elemental theme, inferred from type/skill. Drives the aura accent
  // so e.g. a fire mage burns while a frost mage ices over — same archetype hat,
  // distinct identity.
  String _skullElement(SkullSpec sk) {
    switch (sk.type) {
      case SkullType.voidlord:
        return 'void';
      case SkullType.plagueDoctor:
        return 'poison';
      case SkullType.seraph:
      case SkullType.paladin:
      case SkullType.shaman:
        return 'holy';
      case SkullType.frostmage:
        return 'frost';
      case SkullType.pyromancer:
      case SkullType.torchbearer:
      case SkullType.imp:
        return 'fire';
      case SkullType.stormcaller:
        return 'lightning';
      default:
        break;
    }
    switch (sk.skill) {
      case 'flames':
      case 'firestorm':
        return 'fire';
      case 'plague':
        return 'arcane';
      case 'frost':
        return 'frost';
      case 'chain':
        return 'lightning';
      case 'heal':
        return 'holy';
      case 'meteor':
      case 'summon':
        return 'arcane';
      default:
        return 'none';
    }
  }

  // Draw job-defining headgear + per-skull theming on top of the base skeleton.
  // Armor/cloth are tinted from the skull's own body color (so dark knight =
  // black plate, paladin = bright gold, vagrant = weathered grey), then an
  // elemental aura is layered on. Skull head spans x[-10,10], crown ≈ -6.
  void _drawSkullGear(
      Canvas canvas, SkullSpec sk, double cy, bool flashing, double t) {
    final y0 = cy;
    final look = _skullLook(sk);
    final eye = sk.eye;
    // metallic palette tinted by the skull's body color
    final steel = sk.body;
    final steelLt = Color.lerp(sk.body, Colors.white, 0.42)!;
    final steelDk = Color.lerp(sk.body, Colors.black, 0.5)!;
    const dark = Color(0xFF1A1622);
    // dark cloth, hued by body, for hoods/robes
    final cloth = Color.lerp(sk.body, const Color(0xFF0E0B16), 0.58)!;
    final clothLt = Color.lerp(sk.body, const Color(0xFF0E0B16), 0.32)!;
    const straw = Color(0xFFD9B364);
    const strawDk = Color(0xFFB08A3E);

    void r(double x, double y, double w, double h, Color c) =>
        _pixelRect(canvas, Rect.fromLTWH(x, y + y0, w, h), c);

    switch (look) {
      case 'farmer': // wide conical straw hat
        r(-15, -2, 30, 3, strawDk); // brim
        r(-14, -1, 28, 1, straw);
        r(-8, -8, 16, 6, straw); // cone
        r(-5, -11, 10, 3, strawDk);
        r(-4, -11, 6, 2, straw);
        break;
      case 'miner': // dark helmet + glowing head-lamp
        r(-10, -10, 20, 7, steelDk);
        r(-10, -10, 20, 2, steel);
        r(-12, -4, 24, 2, steelDk); // brim
        _glow(canvas, Offset(9, -7 + y0), 6, const Color(0xFFFFF59D).withOpacity(0.8), 5);
        r(7, -8, 5, 4, const Color(0xFFFFF59D)); // lamp
        r(8, -7, 3, 2, Colors.white);
        break;
      case 'fisher': // floppy wide rain hat
        r(-13, -6, 26, 5, const Color(0xFFF4C430));
        r(-13, -6, 26, 2, const Color(0xFFFFE082));
        r(-15, -2, 6, 4, const Color(0xFFE0AE2E)); // drooping side
        r(9, -2, 6, 4, const Color(0xFFE0AE2E));
        break;
      case 'militia': // simple iron cap + cheek guards
        r(-9, -9, 18, 7, steel);
        r(-9, -9, 18, 2, steelLt);
        r(-11, -3, 22, 2, steelDk); // rim
        r(-9, 0, 2, 8, steelDk); // cheek guards
        r(7, 0, 2, 8, steelDk);
        break;
      case 'knight': // full helm w/ visor slit + crest plume + pauldrons
        r(-10, -10, 20, 14, steel);
        r(-10, -10, 20, 3, steelLt);
        r(10, -8, 2, 12, steelDk);
        r(-8, 2, 16, 3, dark); // visor slit (eyes glow through)
        _glow(canvas, Offset(-3, 3 + y0), 3, eye.withOpacity(0.6), 3);
        _glow(canvas, Offset(4, 3 + y0), 3, eye.withOpacity(0.6), 3);
        r(-5, 3, 3, 1, flashing ? Colors.white : eye);
        r(3, 3, 3, 1, flashing ? Colors.white : eye);
        r(-2, -14, 4, 5, eye); // crest base
        r(-1, -18, 2, 4, eye); // plume
        // pauldrons
        r(-13, 16, 6, 6, steel);
        r(-13, 16, 6, 2, steelLt);
        r(7, 16, 6, 6, steel);
        break;
      case 'mage': // tall pointed wizard hat, tipped back (hued per skull)
        r(-12, -4, 24, 3, cloth); // brim
        r(-12, -4, 24, 1, clothLt);
        r(-9, -9, 14, 5, cloth); // lower cone
        r(-9, -14, 10, 5, cloth);
        r(-9, -18, 7, 4, clothLt); // tip leaning back
        r(-9, -7, 14, 2, eye.withOpacity(0.75)); // glowing hat band
        r(-3, -17, 2, 2, eye); // gem on tip
        break;
      case 'archer': // pointed hood (hued per skull) + quiver behind shoulder
        r(-10, -10, 20, 6, cloth); // hood crown
        r(-11, -4, 22, 3, Color.lerp(cloth, Colors.black, 0.2)!);
        r(-7, -13, 8, 4, cloth); // peak
        r(-6, 14, 12, 3, Color.lerp(cloth, Colors.black, 0.2)!); // collar
        r(-12, 16, 4, 12, const Color(0xFF5D4037)); // quiver
        r(-11, 14, 2, 4, const Color(0xFFBDB76B)); // arrows
        r(-13, 14, 2, 4, const Color(0xFFBDB76B));
        break;
      case 'beast': // animal ears + snout + fangs (hued per skull body)
        final fur = sk.body;
        final furDk = Color.lerp(sk.body, Colors.black, 0.35)!;
        r(-10, -11, 6, 7, furDk);
        r(-9, -10, 4, 5, fur);
        r(4, -11, 6, 7, furDk);
        r(5, -10, 4, 5, fur);
        r(6, 8, 6, 4, fur); // snout pushed forward
        r(6, 8, 6, 1, Color.lerp(fur, Colors.white, 0.3)!);
        r(-5, 13, 2, 3, Colors.white); // fangs
        r(3, 13, 2, 3, Colors.white);
        break;
      case 'fist': // headband with trailing tails (eye-colored accent)
        final band = Color.lerp(eye, Colors.black, 0.15)!;
        r(-11, 1, 22, 3, band);
        r(-11, 1, 22, 1, Color.lerp(eye, Colors.white, 0.3)!);
        r(-15, 2, 5, 2, band); // tail
        r(-17, 4, 4, 2, Color.lerp(eye, Colors.black, 0.35)!);
        break;
      case 'spear': // light sallet helm with a tail
        r(-10, -9, 20, 8, steel);
        r(-10, -9, 20, 2, steelLt);
        r(-12, -2, 16, 2, steelDk); // neck flare to the back
        r(8, -1, 4, 2, steelDk); // short brim front
        break;
      case 'reaper': // tattered deep hood + small horns (hued per skull)
        r(-12, -9, 24, 13, cloth);
        r(-12, -9, 24, 2, clothLt);
        r(-9, 2, 18, 3, Color.lerp(cloth, Colors.black, 0.4)!); // shadowed brow
        _glow(canvas, Offset(-3, 4 + y0), 3, eye.withOpacity(0.6), 3);
        _glow(canvas, Offset(4, 4 + y0), 3, eye.withOpacity(0.6), 3);
        r(-9, -13, 3, 5, clothLt); // horns
        r(6, -13, 3, 5, clothLt);
        break;
      case 'rogue': // hood + lower-face mask band (hued per skull)
        r(-11, -9, 22, 8, cloth);
        r(-11, -9, 22, 2, clothLt);
        r(-8, -12, 7, 4, cloth); // peak
        r(-8, 9, 16, 4, Color.lerp(cloth, Colors.black, 0.3)!); // mask over jaw
        break;
      case 'warrior': // horned heavy helm (plate hued per skull)
        r(-10, -9, 20, 8, steelDk);
        r(-10, -9, 20, 2, steel);
        r(-8, 1, 16, 2, dark); // brow shadow
        r(-13, -12, 4, 7, const Color(0xFFE8E8E8)); // horns
        r(-15, -15, 3, 5, const Color(0xFFE8E8E8));
        r(9, -12, 4, 7, const Color(0xFFE8E8E8));
        r(12, -15, 3, 5, const Color(0xFFE8E8E8));
        break;
      default: // 'sword' — bandana hued per skull
        r(-10, 0, 20, 3, steelDk);
        r(-10, 0, 20, 1, steel);
        r(-13, 1, 4, 2, steelDk); // knot tail
    }

    // elemental aura layered on top for per-skull identity
    _drawSkullAura(canvas, _skullElement(sk), cy, eye, t);
  }

  // Animated elemental accents that distinguish skulls sharing an archetype
  // (fire mage vs frost mage vs storm mage, holy paladin vs dark knight, …).
  void _drawSkullAura(
      Canvas canvas, String element, double cy, Color eye, double t) {
    final y0 = cy;
    void r(double x, double y, double w, double h, Color c) =>
        _pixelRect(canvas, Rect.fromLTWH(x, y + y0, w, h), c);
    switch (element) {
      case 'fire': // licking flames above the head + warm glow
        _glow(canvas, Offset(0, -4 + y0), 12, const Color(0xFFFF6D00).withOpacity(0.25), 7);
        for (int i = 0; i < 3; i++) {
          final dx = (i - 1) * 6.0;
          final fl = 4 + sin(t * 18 + i * 2).abs() * 5;
          r(dx - 2, -8 - fl, 4, fl, const Color(0xFFFF7043));
          r(dx - 1, -8 - fl, 2, fl * 0.5, const Color(0xFFFFD54F));
        }
        break;
      case 'frost': // icy shoulder crystals + cold glow + floating shard
        _glow(canvas, Offset(0, 6 + y0), 13, const Color(0xFF80DEEA).withOpacity(0.22), 8);
        r(-13, 12, 3, 6, const Color(0xFFB3E5FC));
        r(-12, 11, 1, 3, Colors.white);
        r(10, 12, 3, 6, const Color(0xFFB3E5FC));
        r(8, -10 + sin(t * 3) * 2, 2, 4, const Color(0xFFE1F5FE));
        break;
      case 'lightning': // flickering electric arcs around the shoulders
        final on = (t * 12).floor() % 2 == 0;
        _glow(canvas, Offset(0, 4 + y0), 13,
            const Color(0xFF18FFFF).withOpacity(on ? 0.3 : 0.12), 8);
        if (on) {
          r(-14, 8, 2, 3, const Color(0xFF84FFFF));
          r(-16, 11, 2, 3, const Color(0xFFE0F7FA));
          r(12, 6, 2, 3, const Color(0xFF84FFFF));
          r(14, 9, 2, 3, const Color(0xFFE0F7FA));
        }
        break;
      case 'holy': // radiant halo ring above the head + bright glow
        _glow(canvas, Offset(0, 4 + y0), 16, const Color(0xFFFFF59D).withOpacity(0.3), 9);
        canvas.drawCircle(
            Offset(0, -11 + y0),
            7,
            Paint()
              ..color = const Color(0xFFFFF176).withOpacity(0.9)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        break;
      case 'void': // orbiting void wisps + violet glow
        _glow(canvas, Offset(0, 6 + y0), 16, const Color(0xFF7C4DFF).withOpacity(0.3), 10);
        for (int i = 0; i < 3; i++) {
          final a = t * 3 + i * 2.1;
          r(cos(a) * 12 - 1, 6 + sin(a) * 10 - 1, 2, 2, const Color(0xFFE040FB));
        }
        break;
      case 'poison': // rising toxic bubbles + green glow
        _glow(canvas, Offset(0, 6 + y0), 14, const Color(0xFF8BC34A).withOpacity(0.24), 8);
        for (int i = 0; i < 3; i++) {
          final yy = (t * 8 + i * 3) % 16;
          r((i - 1) * 6.0 - 1, 12 - yy, 2, 2, const Color(0xFFAEEA00));
        }
        break;
      case 'arcane': // floating arcane sparkles in the eye color
        _glow(canvas, Offset(0, 2 + y0), 12, eye.withOpacity(0.2), 7);
        for (int i = 0; i < 3; i++) {
          final a = t * 2 + i * 2.1;
          r(cos(a) * 11 - 1, 2 + sin(a * 1.3) * 9 - 1, 2, 2, eye);
        }
        break;
      default:
        break;
    }
  }

  void _weapon(Canvas canvas, Player p, double cy) {
    final sk = p.skull;
    double angle;
    if (sk.rangedBasic) {
      // ranged: aim the weapon forward with a brief firing recoil (no slash arc)
      final recoil = p.attacking
          ? (p.attackTimer / p.attackDuration).clamp(0.0, 1.0) * 0.45
          : 0.0;
      angle = -0.1 - recoil;
      canvas.save();
      canvas.translate(6, 22 + cy);
      canvas.rotate(angle);
      _pixelRect(canvas, const Rect.fromLTWH(-3, -3, 14, 6),
          const Color(0xFFCFD8DC));
      _pixelRect(
          canvas, const Rect.fromLTWH(-3, -3, 14, 2), const Color(0xFFECEFF1));
      _drawWeapon(canvas, sk.weapon, sk.eye);
      canvas.restore();
      return;
    }
    // martial artists (권사) jab with a bare fist instead of swinging a weapon
    if (sk.category == '권사') {
      _punch(canvas, p, cy, sk);
      return;
    }
    if (p.attacking) {
      final e =
          ((p.attackDuration - p.attackTimer) / p.attackDuration).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(e);
      switch (p.comboStep) {
        case 2:
          angle = 1.1 - 2.6 * eased;
          break;
        case 3:
          angle = -2.6 + 5.4 * eased;
          break;
        default:
          angle = -2.2 + 3.0 * eased;
      }
      final arcPaint = Paint()
        ..color = sk.eye.withOpacity(0.30 * (1 - e))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * (1 - e) + 2
        ..strokeCap = StrokeCap.round;
      final reach = (p.comboStep >= 3 ? 52.0 : 40.0) * sk.reachMul;
      canvas.drawArc(Rect.fromCircle(center: Offset(6, 22 + cy), radius: reach),
          angle - 0.6, 1.2, false, arcPaint);
    } else {
      angle = -0.5;
    }

    canvas.save();
    canvas.translate(6, 22 + cy);
    canvas.rotate(angle);
    // arm (blocky pixel gauntlet)
    _pixelRect(canvas, const Rect.fromLTWH(-3, -3, 14, 6), const Color(0xFFCFD8DC));
    _pixelRect(canvas, const Rect.fromLTWH(-3, -3, 14, 2), const Color(0xFFECEFF1));
    _drawWeapon(canvas, sk.weapon, sk.eye);
    canvas.restore();
  }

  // Bare-fist basic attack for 권사 skulls: a forward jab whose reach peaks
  // mid-swing, alternating high/low with the combo step. Drawn in the player's
  // facing-mirrored frame, so +x is always "forward".
  void _punch(Canvas canvas, Player p, double cy, SkullSpec sk) {
    double ext = 4; // forward reach of the fist in the hand frame
    double thrust = 0; // 0 at rest, peaks mid-jab
    double vy = 0; // alternate high/low jabs per combo step
    if (p.attacking) {
      final e = ((p.attackDuration - p.attackTimer) / p.attackDuration)
          .clamp(0.0, 1.0);
      thrust = sin(e * pi);
      ext = (4 + 30 * thrust) * sk.reachMul;
      vy = (p.comboStep == 2 ? -7.0 : (p.comboStep >= 3 ? 7.0 : 0.0)) * thrust;
    }
    canvas.save();
    canvas.translate(6, 22 + cy + vy);
    // taped forearm driving the fist forward
    _pixelRect(canvas, Rect.fromLTWH(-3, -3, ext, 6), const Color(0xFFCFD8DC));
    _pixelRect(canvas, Rect.fromLTWH(-3, -3, ext, 2), const Color(0xFFECEFF1));
    // knuckle wrap (skull-colored accent)
    _pixelRect(canvas, Rect.fromLTWH(ext - 2, -5, 4, 10), sk.eye.withOpacity(0.9));
    // the fist itself (knuckles point outward)
    _fistShape(canvas, ext + 4, 0, 1, sk.body);
    // impact flash at full extension
    if (thrust > 0.55) {
      canvas.drawCircle(Offset(ext + 12, 0), 6 * thrust + 2,
          Paint()..color = sk.eye.withOpacity(0.5 * thrust));
      canvas.drawCircle(Offset(ext + 12, 0), 3 * thrust + 1,
          Paint()..color = Colors.white.withOpacity(0.7 * thrust));
    }
    canvas.restore();
  }

  // pixel-art weapon shapes drawn in the rotated hand frame (+x = outward).
  void _drawWeapon(Canvas canvas, String weapon, Color eye) {
    const steel = Color(0xFFCFD8DC);
    const steelLt = Color(0xFFECEFF1);
    const steelDk = Color(0xFF90A4AE);
    const wood = Color(0xFF8D6E63);
    const woodDk = Color(0xFF5D4037);
    switch (weapon) {
      case 'staff':
        _pixelRect(canvas, const Rect.fromLTWH(10, -2, 30, 4), wood);
        _pixelRect(canvas, const Rect.fromLTWH(10, -2, 30, 1), const Color(0xFFA1887F));
        // orb: pixel diamond
        _pixelRect(canvas, const Rect.fromLTWH(38, -4, 10, 8), eye);
        _pixelRect(canvas, const Rect.fromLTWH(40, -6, 6, 12), eye);
        _pixelRect(canvas, const Rect.fromLTWH(40, -2, 4, 4), Colors.white);
        break;
      case 'axe':
        _pixelRect(canvas, const Rect.fromLTWH(10, -2, 26, 4), woodDk);
        // blocky stepped axe head
        _pixelRect(canvas, const Rect.fromLTWH(32, -14, 12, 28), steel);
        _pixelRect(canvas, const Rect.fromLTWH(44, -10, 4, 20), steel);
        _pixelRect(canvas, const Rect.fromLTWH(28, -6, 4, 12), steel);
        _pixelRect(canvas, const Rect.fromLTWH(32, -14, 12, 3), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(44, -10, 4, 4), eye);
        break;
      case 'daggers':
        _pixelRect(canvas, const Rect.fromLTWH(8, -3, 4, 6), woodDk);
        _pixelRect(canvas, const Rect.fromLTWH(12, -2, 18, 4), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(30, -1, 4, 2), steel);
        _pixelRect(canvas, const Rect.fromLTWH(12, -2, 18, 1), Colors.white);
        break;
      case 'claws':
        // three stepped claw blades
        for (int i = -1; i <= 1; i++) {
          final y = i * 6.0;
          _pixelRect(canvas, Rect.fromLTWH(10, y - 1.5, 8, 3), const Color(0xFFFFE082));
          _pixelRect(canvas, Rect.fromLTWH(17, y - 1.5 + i * 1.5, 7, 3), const Color(0xFFFFD54F));
          _pixelRect(canvas, Rect.fromLTWH(23, y - 1 + i * 3.0, 4, 2), Colors.white);
        }
        break;
      case 'greatsword':
        _pixelRect(canvas, const Rect.fromLTWH(8, -3, 8, 6), const Color(0xFF37474F));
        _pixelRect(canvas, const Rect.fromLTWH(6, -9, 14, 4), const Color(0xFF607D8B));
        _pixelRect(canvas, const Rect.fromLTWH(16, -4, 40, 8), steel);
        _pixelRect(canvas, const Rect.fromLTWH(56, -2, 8, 4), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(16, -4, 40, 2), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(16, 2, 40, 2), steelDk);
        break;
      case 'scythe':
        _pixelRect(canvas, const Rect.fromLTWH(10, -2, 42, 4), woodDk);
        // stepped curved blade
        _pixelRect(canvas, const Rect.fromLTWH(48, -6, 8, 8), eye);
        _pixelRect(canvas, const Rect.fromLTWH(52, -18, 8, 14), eye);
        _pixelRect(canvas, const Rect.fromLTWH(46, -28, 10, 12), eye);
        _pixelRect(canvas, const Rect.fromLTWH(40, -32, 10, 8), eye);
        _pixelRect(canvas, const Rect.fromLTWH(40, -32, 10, 3), Colors.white);
        break;
      case 'bomb':
        _pixelRect(canvas, const Rect.fromLTWH(10, -2, 14, 4), woodDk);
        _pixelRect(canvas, const Rect.fromLTWH(26, -8, 16, 16), const Color(0xFF263238));
        _pixelRect(canvas, const Rect.fromLTWH(26, -8, 16, 4), const Color(0xFF37474F));
        _pixelRect(canvas, const Rect.fromLTWH(30, -4, 4, 4), Colors.white24);
        _pixelRect(canvas, const Rect.fromLTWH(40, -14, 4, 6), const Color(0xFF8D6E63));
        _pixelRect(canvas, const Rect.fromLTWH(42, -18, 4, 4), const Color(0xFFFFB300));
        break;
      case 'spear':
        _pixelRect(canvas, const Rect.fromLTWH(8, -1.5, 50, 3), wood);
        _pixelRect(canvas, const Rect.fromLTWH(56, -6, 6, 12), steel);
        _pixelRect(canvas, const Rect.fromLTWH(62, -3, 6, 6), steel);
        _pixelRect(canvas, const Rect.fromLTWH(68, -1, 4, 2), steelLt);
        break;
      case 'bow':
        // vertical limbs (stepped arc)
        _pixelRect(canvas, const Rect.fromLTWH(6, -18, 4, 8), wood);
        _pixelRect(canvas, const Rect.fromLTWH(10, -14, 4, 28), wood);
        _pixelRect(canvas, const Rect.fromLTWH(6, 10, 4, 8), wood);
        _pixelRect(canvas, const Rect.fromLTWH(13, -14, 1, 28), Colors.white70);
        _pixelRect(canvas, const Rect.fromLTWH(14, -1, 26, 2), steel);
        _pixelRect(canvas, const Rect.fromLTWH(40, -3, 6, 6), steel);
        break;
      case 'gauntlet':
        _pixelRect(canvas, const Rect.fromLTWH(10, -7, 16, 14), const Color(0xFFB0BEC5));
        _pixelRect(canvas, const Rect.fromLTWH(10, -7, 16, 4), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(26, -6, 4, 4), eye);
        _pixelRect(canvas, const Rect.fromLTWH(26, 2, 4, 4), eye);
        break;
      case 'pickaxe':
        _pixelRect(canvas, const Rect.fromLTWH(10, -2, 26, 4), woodDk); // handle
        _pixelRect(canvas, const Rect.fromLTWH(30, -13, 5, 26), steel); // head bar
        // upper curved point
        _pixelRect(canvas, const Rect.fromLTWH(35, -13, 8, 4), steel);
        _pixelRect(canvas, const Rect.fromLTWH(42, -15, 4, 4), steelLt);
        // lower curved point
        _pixelRect(canvas, const Rect.fromLTWH(35, 9, 8, 4), steel);
        _pixelRect(canvas, const Rect.fromLTWH(42, 11, 4, 4), steelLt);
        break;
      case 'rod':
        // fishing rod: tapered pole, line dangling to a small hook + bobber
        _pixelRect(canvas, const Rect.fromLTWH(6, -1, 30, 3), woodDk); // pole
        _pixelRect(canvas, const Rect.fromLTWH(34, -1, 14, 2), wood); // tip
        _pixelRect(canvas, const Rect.fromLTWH(10, -3, 5, 5),
            const Color(0xFF455A64)); // reel
        _pixelRect(canvas, const Rect.fromLTWH(46, 0, 1, 12),
            const Color(0xFFB0BEC5)); // line
        _pixelRect(canvas, const Rect.fromLTWH(44, 11, 5, 3), eye); // bobber
        break;
      case 'sniper':
        // long-barreled rail rifle: stock, body, barrel, scope, muzzle glow
        _pixelRect(canvas, const Rect.fromLTWH(4, -3, 12, 7), woodDk); // stock
        _pixelRect(canvas, const Rect.fromLTWH(14, -3, 18, 6), const Color(0xFF37474F)); // body
        _pixelRect(canvas, const Rect.fromLTWH(30, -2, 34, 4), steelDk); // barrel
        _pixelRect(canvas, const Rect.fromLTWH(30, -2, 34, 1), steelLt); // highlight
        _pixelRect(canvas, const Rect.fromLTWH(20, -8, 10, 4), const Color(0xFF263238)); // scope
        _pixelRect(canvas, const Rect.fromLTWH(22, -7, 3, 2), eye); // scope lens
        _pixelRect(canvas, const Rect.fromLTWH(62, -2.5, 5, 5), eye); // muzzle glow
        break;
      case 'hammer':
        _pixelRect(canvas, const Rect.fromLTWH(10, -2.5, 28, 5), woodDk);
        _pixelRect(canvas, const Rect.fromLTWH(34, -14, 20, 28), const Color(0xFF78909C));
        _pixelRect(canvas, const Rect.fromLTWH(34, -14, 6, 28), const Color(0xFF546E7A));
        _pixelRect(canvas, const Rect.fromLTWH(48, -14, 6, 28), const Color(0xFF90A4AE));
        _pixelRect(canvas, const Rect.fromLTWH(34, -14, 20, 3), steelLt);
        break;
      case 'falchion':
        // 반월도: a broad, back-curved single-edged blade (half-moon falchion)
        _pixelRect(canvas, const Rect.fromLTWH(8, -3, 6, 7), woodDk); // grip
        _pixelRect(canvas, const Rect.fromLTWH(13, -5, 9, 3),
            const Color(0xFF7E57C2)); // crossguard
        // stepped, widening curved blade sweeping up toward the tip
        _pixelRect(canvas, const Rect.fromLTWH(20, -4, 16, 8), steel);
        _pixelRect(canvas, const Rect.fromLTWH(34, -8, 14, 11), steel);
        _pixelRect(canvas, const Rect.fromLTWH(46, -14, 10, 12), steel);
        _pixelRect(canvas, const Rect.fromLTWH(20, -4, 30, 2), steelLt); // edge
        _pixelRect(canvas, const Rect.fromLTWH(46, -14, 10, 3), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(52, -16, 5, 5), eye); // void glint
        break;
      default: // sword
        _pixelRect(canvas, const Rect.fromLTWH(10, -6, 4, 12), const Color(0xFF455A64));
        _pixelRect(canvas, const Rect.fromLTWH(8, -4, 8, 2), const Color(0xFF607D8B));
        _pixelRect(canvas, const Rect.fromLTWH(14, -2, 28, 4), const Color(0xFFE3F2FD));
        _pixelRect(canvas, const Rect.fromLTWH(42, -1, 4, 2), steel);
        _pixelRect(canvas, const Rect.fromLTWH(14, -2, 28, 1), Colors.white);
    }
  }

  // ----------------------------------------------------------------
  // ENEMIES
  void _enemy(Canvas canvas, Enemy e) {
    canvas.save();
    canvas.translate(e.cx, e.y);
    canvas.scale(e.facing.toDouble(), 1.0);
    final eHurt = (e.hurtTimer / 0.18).clamp(0.0, 1.0);
    if (eHurt > 0) {
      canvas.translate(-eHurt * 4, eHurt * 2);
      canvas.rotate(eHurt * 0.16);
    }
    final flash = e.hitFlash > 0;
    // aggro enemies get a faint menacing backlight
    if (e.aggro) {
      _glow(canvas, Offset(0, e.h * 0.5), e.w * 0.55,
          const Color(0xFFFF5252).withOpacity(0.12), 10);
    }
    // deep-floor reinforcement: tint the whole sprite toward darkening crimson
    final tint = _reinforce;
    final tinted = tint > 0.02;
    if (tinted) {
      canvas.saveLayer(
          Rect.fromLTWH(-e.w, -e.h * 0.5, e.w * 3, e.h * 2.2),
          Paint()
            ..colorFilter = ColorFilter.mode(
                _crimson.withOpacity((tint * 0.9).clamp(0.0, 0.85)),
                BlendMode.srcATop));
    }
    switch (e.kind) {
      case EnemyKind.grunt:
        _grunt(canvas, e, flash);
        break;
      case EnemyKind.bat:
        _bat(canvas, e, flash);
        break;
      case EnemyKind.mage:
        _mage(canvas, e, flash);
        break;
      case EnemyKind.fireMage:
        _fireMage(canvas, e, flash);
        break;
      case EnemyKind.slime:
        _slime(canvas, e, flash);
        break;
      case EnemyKind.archer:
        _archer(canvas, e, flash);
        break;
      case EnemyKind.brute:
        _brute(canvas, e, flash);
        break;
      case EnemyKind.goblin:
        _goblin(canvas, e, flash);
        break;
      case EnemyKind.assassin:
        _assassin(canvas, e, flash);
        break;
      case EnemyKind.heretic:
        _heretic(canvas, e, flash);
        break;
      case EnemyKind.thief:
        _thief(canvas, e, flash);
        break;
      case EnemyKind.knightSoldier:
        _knightSoldier(canvas, e, flash);
        break;
      case EnemyKind.brawler:
        _brawler(canvas, e, flash);
        break;
      case EnemyKind.gargoyle:
        _gargoyle(canvas, e, flash);
        break;
      case EnemyKind.ghoul:
        _ghoul(canvas, e, flash);
        break;
      case EnemyKind.dwarf:
        _dwarf(canvas, e, flash);
        break;
      case EnemyKind.darkElf:
        _darkElf(canvas, e, flash);
        break;
      case EnemyKind.plant:
        _plant(canvas, e, flash);
        break;
      case EnemyKind.hammer:
        _hammerFoe(canvas, e, flash);
        break;
      case EnemyKind.shield:
        _shieldFoe(canvas, e, flash);
        break;
    }
    if (tinted) canvas.restore(); // close the crimson tint layer
    canvas.restore();
    _enemyHp(canvas, e);
    _statusFx(canvas, e);
  }

  // A summoned skeleton soldier: small outlined skeleton with purple soul-fire
  // eyes and a short blade. Fades out over its last second of life.
  void _ally(Canvas canvas, Ally a) {
    final fade = a.life < 1.0 ? a.life.clamp(0.0, 1.0) : 1.0;
    // 공허군주의 공허 몬스터 / 대마법사의 거인 골렘: distinct creature renders.
    if (a.kind.isNotEmpty) {
      _kindAlly(canvas, a, fade);
      return;
    }
    // charmed monster: render as its original creature, marked friendly with a
    // cyan ground ring + aura instead of the enemy's red backlight.
    final src = a.source;
    if (src != null) {
      const friend = Color(0xFF64FFDA);
      _pixelRect(canvas, Rect.fromLTWH(a.cx - a.w * 0.5, a.y + a.h - 3, a.w, 4),
          friend.withOpacity(0.30 * fade));
      _glow(canvas, Offset(a.cx, a.y + a.h * 0.5), a.w * 0.6,
          friend.withOpacity(0.20 * fade), 10);
      _enemy(canvas, src);
      // small charm mark hovering above the head
      _glow(canvas, Offset(a.cx, a.y - 8), 5, friend.withOpacity(0.7 * fade), 4);
      return;
    }
    const purple = Color(0xFFB388FF);
    const bone = Color(0xFFE6E1EF);
    const boneDk = Color(0xFF9A93B0);
    const outline = Color(0xFF181425);
    final t = a.animTime;
    final moving = a.vx.abs() > 5;
    final swing = moving ? sin(t * 16) * 3 : 0.0;

    // ground shadow + summon aura (not affected by the fade layer)
    _pixelRect(canvas, Rect.fromLTWH(a.cx - 9, a.y + a.h - 3, 18, 4),
        Colors.black.withOpacity(0.22 * fade));
    _glow(canvas, Offset(a.cx, a.y + a.h * 0.5),
        15, purple.withOpacity(0.16 * fade), 8);

    canvas.save();
    canvas.translate(a.cx, a.y);
    canvas.scale(a.facing.toDouble(), 1.0);
    // whole body composited at the fade alpha
    canvas.saveLayer(Rect.fromLTWH(-22, -6, 44, a.h + 12),
        Paint()..color = Colors.white.withOpacity(fade));

    // legs
    _pixelRect(canvas, Rect.fromLTWH(-6 + swing, 20, 4, 9), outline);
    _pixelRect(canvas, Rect.fromLTWH(-5 + swing, 20, 2, 8), boneDk);
    _pixelRect(canvas, Rect.fromLTWH(2 - swing, 20, 4, 9), outline);
    _pixelRect(canvas, Rect.fromLTWH(3 - swing, 20, 2, 8), boneDk);
    // ribcage torso
    _pixelRect(canvas, Rect.fromLTWH(-6, 11, 12, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(-5, 12, 10, 9), boneDk);
    _pixelRect(canvas, Rect.fromLTWH(-5, 12, 10, 2), bone);
    _pixelRect(canvas, Rect.fromLTWH(-4, 15, 8, 1), bone); // ribs
    _pixelRect(canvas, Rect.fromLTWH(-4, 17, 8, 1), bone);
    // skull head + outline
    _pixelRect(canvas, Rect.fromLTWH(-6, -1, 12, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(-5, 0, 10, 10), bone);
    _pixelRect(canvas, Rect.fromLTWH(-5, 0, 10, 2), Colors.white);
    // soul-fire eyes
    _glow(canvas, Offset(-2, 4), 3, purple.withOpacity(0.6), 3);
    _pixelRect(canvas, Rect.fromLTWH(-4, 3, 3, 3), purple);
    _pixelRect(canvas, Rect.fromLTWH(1, 3, 3, 3), purple);
    _pixelRect(canvas, Rect.fromLTWH(-4, 8, 8, 1), boneDk); // jaw
    // short blade (swung when it just attacked)
    final atk = a.atkCd > 0.42;
    canvas.save();
    canvas.translate(5, 14);
    canvas.rotate(atk ? -0.7 : 0.25);
    _pixelRect(canvas, const Rect.fromLTWH(2, -1, 4, 2), Color(0xFF6D4C41)); // hilt
    _pixelRect(canvas, const Rect.fromLTWH(6, -1, 13, 2), Color(0xFFCFD8DC)); // blade
    _pixelRect(canvas, const Rect.fromLTWH(6, -1, 13, 1), Colors.white);
    canvas.restore();

    canvas.restore(); // saveLayer
    canvas.restore(); // translate/scale

    // tiny HP bar (world space) once the summon has taken damage
    if (a.hp < a.maxHp) {
      const bw = 22.0;
      final bx = a.cx - bw / 2;
      final by = a.y - 7;
      canvas.drawRect(Rect.fromLTWH(bx, by, bw, 3),
          Paint()..color = Colors.black.withOpacity(0.5 * fade));
      canvas.drawRect(
          Rect.fromLTWH(bx, by, bw * (a.hp / a.maxHp).clamp(0.0, 1.0), 3),
          Paint()..color = const Color(0xFFB388FF).withOpacity(fade));
    }
  }

  // 공허 몬스터 & 거인 골렘: compact creature sprites for special allies. Drawn in
  // the ally's local space (origin = top-center, scaled by facing).
  void _kindAlly(Canvas canvas, Ally a, double fade) {
    final t = a.animTime;
    final moving = a.vx.abs() > 5;
    final swing = moving ? sin(t * 16) * 3 : 0.0;
    final atk = a.atkCd > 0.42;
    final isGolem = a.kind == 'earthgolem';
    final aura = isGolem ? const Color(0xFFFFB300) : const Color(0xFFE040FB);

    _pixelRect(canvas, Rect.fromLTWH(a.cx - a.w * 0.5, a.y + a.h - 3, a.w, 4),
        Colors.black.withOpacity(0.22 * fade));
    _glow(canvas, Offset(a.cx, a.y + a.h * 0.5), a.w * 0.7,
        aura.withOpacity(0.18 * fade), 9);

    canvas.save();
    canvas.translate(a.cx, a.y);
    canvas.scale(a.facing.toDouble(), 1.0);
    canvas.saveLayer(Rect.fromLTWH(-a.w, -10, a.w * 2, a.h + 18),
        Paint()..color = Colors.white.withOpacity(fade));

    switch (a.kind) {
      case 'werewolf':
        const fur = Color(0xFF6D4C41);
        const furDk = Color(0xFF4E342E);
        _pixelRect(canvas, Rect.fromLTWH(-7 + swing, 24, 5, 11), furDk);
        _pixelRect(canvas, Rect.fromLTWH(2 - swing, 24, 5, 11), furDk);
        _pixelRect(canvas, const Rect.fromLTWH(-7, 12, 14, 14), fur);
        _pixelRect(canvas, const Rect.fromLTWH(-7, 12, 14, 3), Color(0xFF8D6E63));
        _pixelRect(canvas, Rect.fromLTWH(4, atk ? 14 : 16, 8, 4), fur);
        for (int i = -1; i <= 1; i++) {
          _pixelRect(canvas, Rect.fromLTWH(11, 14 + i * 3.0, 5, 2),
              const Color(0xFFFFE082));
        }
        _pixelRect(canvas, const Rect.fromLTWH(-2, 4, 12, 9), fur);
        _pixelRect(canvas, const Rect.fromLTWH(8, 7, 6, 4), furDk); // snout
        _pixelRect(canvas, const Rect.fromLTWH(-1, 1, 3, 4), fur); // ear
        _pixelRect(canvas, const Rect.fromLTWH(3, 1, 3, 4), fur); // ear
        canvas.drawCircle(const Offset(4, 8), 1.6,
            Paint()..color = const Color(0xFFFFCA28));
        break;
      case 'werebear':
        const bear = Color(0xFF5D4037);
        const bearDk = Color(0xFF3E2723);
        _pixelRect(canvas, Rect.fromLTWH(-10 + swing * 0.5, 26, 8, 12), bearDk);
        _pixelRect(canvas, Rect.fromLTWH(3 - swing * 0.5, 26, 8, 12), bearDk);
        _pixelRect(canvas, const Rect.fromLTWH(-12, 12, 24, 18), bear);
        _pixelRect(canvas, const Rect.fromLTWH(-12, 12, 24, 4), Color(0xFF6D4C41));
        _pixelRect(canvas, Rect.fromLTWH(8, atk ? 13 : 16, 8, 6), bear);
        for (int i = -1; i <= 1; i++) {
          _pixelRect(canvas, Rect.fromLTWH(15, 16 + i * 3.0, 5, 2),
              const Color(0xFFECEFF1));
        }
        _pixelRect(canvas, const Rect.fromLTWH(2, 4, 13, 11), bear);
        _pixelRect(canvas, const Rect.fromLTWH(12, 8, 5, 5), bearDk); // snout
        canvas.drawCircle(const Offset(4, 4), 3, Paint()..color = bear); // ear
        canvas.drawCircle(const Offset(12, 3), 3, Paint()..color = bear); // ear
        canvas.drawCircle(const Offset(8, 8), 1.6,
            Paint()..color = const Color(0xFFFF7043));
        break;
      case 'deathknight':
        const steel = Color(0xFF78909C);
        const steelDk = Color(0xFF455A64);
        const steelLt = Color(0xFFB0BEC5);
        const eyeG = Color(0xFF18FFFF);
        _pixelRect(canvas, Rect.fromLTWH(-6 + swing, 24, 5, 12), steelDk);
        _pixelRect(canvas, Rect.fromLTWH(2 - swing, 24, 5, 12), steelDk);
        _pixelRect(canvas, const Rect.fromLTWH(-7, 12, 14, 14), steel);
        _pixelRect(canvas, const Rect.fromLTWH(-7, 12, 14, 3), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(-1, 14, 2, 10), steelDk);
        _pixelRect(canvas, const Rect.fromLTWH(-9, 12, 4, 5), steelLt); // pauldron
        _pixelRect(canvas, const Rect.fromLTWH(5, 12, 4, 5), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(-5, 0, 10, 12), steel); // helm
        _pixelRect(canvas, const Rect.fromLTWH(-5, 0, 10, 3), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(-4, 5, 8, 2), Color(0xFF101418));
        _pixelRect(canvas, const Rect.fromLTWH(-3, 5, 2, 2), eyeG);
        _pixelRect(canvas, const Rect.fromLTWH(1, 5, 2, 2), eyeG);
        canvas.save();
        canvas.translate(6, 14);
        canvas.rotate(atk ? -0.8 : 0.2);
        _pixelRect(canvas, const Rect.fromLTWH(0, -1, 3, 2), Color(0xFF5D4037));
        _pixelRect(canvas, const Rect.fromLTWH(3, -1.5, 16, 3), steelLt);
        _pixelRect(canvas, const Rect.fromLTWH(3, -1.5, 16, 1), Colors.white);
        canvas.restore();
        break;
      case 'lich':
        const robe = Color(0xFF512DA8);
        const robeDk = Color(0xFF311B92);
        const purple = Color(0xFFE040FB);
        _pixelRect(canvas, const Rect.fromLTWH(-8, 16, 16, 18), robe);
        _pixelRect(canvas, const Rect.fromLTWH(-9, 30, 18, 4), robeDk); // hem
        _pixelRect(canvas, const Rect.fromLTWH(-8, 16, 16, 3), Color(0xFF7E57C2));
        _pixelRect(canvas, const Rect.fromLTWH(-6, 2, 12, 14), robe); // hood
        _pixelRect(canvas, const Rect.fromLTWH(-6, 2, 12, 3), Color(0xFF7E57C2));
        _pixelRect(canvas, const Rect.fromLTWH(-4, 7, 8, 5), Color(0xFF1A0A24));
        canvas.drawCircle(const Offset(-2, 10), 1.5, Paint()..color = purple);
        canvas.drawCircle(const Offset(2, 10), 1.5, Paint()..color = purple);
        canvas.save();
        canvas.translate(6, 12);
        _pixelRect(canvas, const Rect.fromLTWH(2, -2, 3, 24), Color(0xFF4E342E));
        canvas.drawCircle(const Offset(3.5, -4), 4,
            Paint()..color = purple.withOpacity(0.9));
        canvas.restore();
        break;
      case 'earthgolem':
        const rock = Color(0xFF6E5D50);
        const rockDk = Color(0xFF4E3F33);
        const rockLt = Color(0xFF8D7A6A);
        const crack = Color(0xFFFFB300);
        _pixelRect(canvas, Rect.fromLTWH(-14 + swing * 0.4, 40, 12, 16), rockDk);
        _pixelRect(canvas, Rect.fromLTWH(4 - swing * 0.4, 40, 12, 16), rockDk);
        _pixelRect(canvas, const Rect.fromLTWH(-26, 18, 9, 16), rock); // arm
        _pixelRect(canvas, const Rect.fromLTWH(17, 18, 9, 16), rock);
        _pixelRect(canvas, Rect.fromLTWH(-27, atk ? 28 : 32, 11, 9), rockDk);
        _pixelRect(canvas, Rect.fromLTWH(16, atk ? 28 : 32, 11, 9), rockDk);
        _pixelRect(canvas, const Rect.fromLTWH(-18, 12, 36, 30), rock); // body
        _pixelRect(canvas, const Rect.fromLTWH(-18, 12, 36, 5), rockLt);
        _pixelRect(canvas, const Rect.fromLTWH(-18, 36, 36, 4), rockDk);
        _pixelRect(canvas, Rect.fromLTWH(-6, 18, 3, 14), crack.withOpacity(0.85));
        _pixelRect(canvas, Rect.fromLTWH(2, 22, 8, 3, ), crack.withOpacity(0.85));
        _pixelRect(canvas, const Rect.fromLTWH(-7, 2, 14, 12), rock); // head
        _pixelRect(canvas, const Rect.fromLTWH(-7, 2, 14, 3), rockLt);
        canvas.drawCircle(const Offset(-3, 8), 2, Paint()..color = crack);
        canvas.drawCircle(const Offset(3, 8), 2, Paint()..color = crack);
        break;
    }

    canvas.restore(); // saveLayer
    canvas.restore(); // translate/scale

    if (a.hp < a.maxHp) {
      final bw = a.w + 2;
      final bx = a.cx - bw / 2;
      final by = a.y - 7;
      canvas.drawRect(Rect.fromLTWH(bx, by, bw, 3),
          Paint()..color = Colors.black.withOpacity(0.5 * fade));
      canvas.drawRect(
          Rect.fromLTWH(bx, by, bw * (a.hp / a.maxHp).clamp(0.0, 1.0), 3),
          Paint()..color = aura.withOpacity(fade));
    }
  }

  void _gargoyle(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF6E7B8B);
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF20262E);
    final flap = sin(e.animTime * 16) * 5;
    final diving = e.t2 > 0;
    // wings (flap, or swept back while diving)
    final wf = diving ? -6.0 : flap;
    _pixelRect(canvas, Rect.fromLTWH(-21, 2 + wf, 15, 13), outline);
    _pixelRect(canvas, Rect.fromLTWH(-20, 3 + wf, 13, 11),
        Color.lerp(body, Colors.black, 0.28)!);
    _pixelRect(canvas, Rect.fromLTWH(6, 2 - wf, 15, 13), outline);
    _pixelRect(canvas, Rect.fromLTWH(7, 3 - wf, 13, 11),
        Color.lerp(body, Colors.black, 0.28)!);
    // stone body
    _pixelRect(canvas, Rect.fromLTWH(-9, 7, 18, 17), outline);
    _pixelRect(canvas, Rect.fromLTWH(-8, 8, 16, 15), m);
    _pixelRect(canvas, Rect.fromLTWH(-8, 8, 16, 4), l);
    // horns + brow
    _pixelRect(canvas, Rect.fromLTWH(-7, 2, 4, 5), outline);
    _pixelRect(canvas, Rect.fromLTWH(3, 2, 4, 5), outline);
    final eyeC = diving ? const Color(0xFFFF5252) : const Color(0xFFFFCA28);
    _glow(canvas, Offset(-3, 12), 3, eyeC.withOpacity(0.55), 3);
    _glow(canvas, Offset(4, 12), 3, eyeC.withOpacity(0.55), 3);
    _pixelRect(canvas, Rect.fromLTWH(-5, 11, 3, 3), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(2, 11, 3, 3), eyeC);
    // talons
    _pixelRect(canvas, Rect.fromLTWH(-7, 22, 4, 4), outline);
    _pixelRect(canvas, Rect.fromLTWH(3, 22, 4, 4), outline);
  }

  void _ghoul(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF7E8C6A);
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF1A2014);
    final lunging = e.t2 > 0;
    final lean = lunging ? 6.0 : 0.0;
    final moving = e.vx.abs() > 5;
    final swing = moving ? sin(e.animTime * 16) * 3 : 0.0;
    _pixelRect(canvas, Rect.fromLTWH(-12, e.h + 1, 24, 5),
        Colors.black.withOpacity(0.25));
    // legs
    _pixelRect(canvas, Rect.fromLTWH(-6 + swing, 28, 5, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(-5 + swing, 28, 3, 11), s);
    _pixelRect(canvas, Rect.fromLTWH(1 - swing, 28, 5, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(2 - swing, 28, 3, 11), s);
    // hunched torso
    _pixelRect(canvas, Rect.fromLTWH(-9 + lean, 12, 18, 18), outline);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 13, 16, 16), m);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 13, 16, 4), l);
    _pixelRect(canvas, Rect.fromLTWH(-5 + lean, 17, 10, 1), l); // exposed ribs
    _pixelRect(canvas, Rect.fromLTWH(-5 + lean, 20, 10, 1), l);
    // lowered forward head
    _pixelRect(canvas, Rect.fromLTWH(2 + lean, 6, 14, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(3 + lean, 7, 12, 10), m);
    _pixelRect(canvas, Rect.fromLTWH(5 + lean, 14, 9, 3), outline); // gaping jaw
    final eyeC = lunging ? const Color(0xFFFF1744) : const Color(0xFFAEEA00);
    _glow(canvas, Offset(8 + lean, 11), 3, eyeC.withOpacity(0.55), 3);
    _pixelRect(canvas, Rect.fromLTWH(5 + lean, 10, 3, 3), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(10 + lean, 10, 3, 3), eyeC);
    // long clawed arm reaching forward
    _pixelRect(canvas, Rect.fromLTWH(12 + lean, 16, 10, 3), outline);
    _pixelRect(canvas, Rect.fromLTWH(20 + lean, 15, 5, 5), m);
  }

  void _knightSoldier(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF9FB3C0);
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF1A2127);
    final winding = e.windup > 0;
    final lunging = e.t2 > 0;
    final lean = lunging ? 8.0 : 0.0;
    final moving = e.vx.abs() > 5;
    final swing = moving && !lunging ? sin(e.animTime * 16) * 3 : 0.0;
    _pixelRect(canvas, Rect.fromLTWH(-15, e.h + 1, 30, 6),
        Colors.black.withOpacity(0.26));
    // greaves
    _pixelRect(canvas, Rect.fromLTWH(-8 + swing, 30, 7, 16), outline);
    _pixelRect(canvas, Rect.fromLTWH(-7 + swing, 30, 5, 15), s);
    _pixelRect(canvas, Rect.fromLTWH(2 - swing, 30, 7, 16), outline);
    _pixelRect(canvas, Rect.fromLTWH(3 - swing, 30, 5, 15), s);
    // plated torso
    _pixelRect(canvas, Rect.fromLTWH(-11 + lean, 10, 22, 22), outline);
    _pixelRect(canvas, Rect.fromLTWH(-10 + lean, 11, 20, 20), m);
    _pixelRect(canvas, Rect.fromLTWH(-10 + lean, 11, 20, 5), l);
    _pixelRect(canvas, Rect.fromLTWH(-10 + lean, 22, 20, 2), s); // belt line
    // pauldrons
    _pixelRect(canvas, Rect.fromLTWH(-13 + lean, 10, 5, 7), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12 + lean, 11, 4, 5), l);
    _pixelRect(canvas, Rect.fromLTWH(8 + lean, 10, 5, 7), outline);
    _pixelRect(canvas, Rect.fromLTWH(9 + lean, 11, 4, 5), m);
    // helmet w/ plume + visor slit
    _pixelRect(canvas, Rect.fromLTWH(-9 + lean, -2, 18, 13), outline);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, -1, 16, 11), m);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, -1, 16, 3), l);
    _pixelRect(canvas, Rect.fromLTWH(-2 + lean, -6, 4, 5),
        const Color(0xFFE53935)); // plume
    _pixelRect(canvas, Rect.fromLTWH(-7 + lean, 4, 14, 3), outline); // visor
    final ec = winding ? const Color(0xFFFF1744) : const Color(0xFF82B1FF);
    _glow(canvas, Offset(0 + lean, 5), 3, ec.withOpacity(0.55), 3);
    _pixelRect(canvas, Rect.fromLTWH(-4 + lean, 4, 3, 2), ec);
    _pixelRect(canvas, Rect.fromLTWH(2 + lean, 4, 3, 2), ec);
    // longsword (raised during windup, thrust during lunge)
    final raise = winding ? -12.0 : 0.0;
    final reach = lunging ? 18.0 : 12.0;
    _pixelRect(canvas, Rect.fromLTWH(10 + lean, 12 + raise, 4, 4),
        const Color(0xFF455A64)); // hilt
    _pixelRect(canvas, Rect.fromLTWH(reach + lean, 8 + raise, 4, 18),
        const Color(0xFFE3F2FD)); // blade
    _pixelRect(canvas, Rect.fromLTWH(reach + lean, 8 + raise, 4, 4), Colors.white);
  }

  void _brawler(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFFD7A86E);
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF2A1B10);
    final jab = e.t2 > 0;
    final lean = jab ? 6.0 : 0.0;
    final moving = e.vx.abs() > 5;
    final swing = moving && !jab ? sin(e.animTime * 18) * 3 : 0.0;
    _pixelRect(canvas, Rect.fromLTWH(-13, e.h + 1, 26, 5),
        Colors.black.withOpacity(0.25));
    // legs
    _pixelRect(canvas, Rect.fromLTWH(-7 + swing, 26, 6, 14), outline);
    _pixelRect(canvas, Rect.fromLTWH(-6 + swing, 26, 4, 13), const Color(0xFF4E342E));
    _pixelRect(canvas, Rect.fromLTWH(1 - swing, 26, 6, 14), outline);
    _pixelRect(canvas, Rect.fromLTWH(2 - swing, 26, 4, 13), const Color(0xFF4E342E));
    // burly bare torso
    _pixelRect(canvas, Rect.fromLTWH(-11, 8, 22, 20), outline);
    _pixelRect(canvas, Rect.fromLTWH(-10, 9, 20, 18), m);
    _pixelRect(canvas, Rect.fromLTWH(-10, 9, 20, 5), l);
    _pixelRect(canvas, Rect.fromLTWH(-1, 11, 2, 14), s); // pec/ab split
    // head + red headband
    _pixelRect(canvas, Rect.fromLTWH(-7, -1, 14, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(-6, 0, 12, 9), m);
    _pixelRect(canvas, Rect.fromLTWH(-7, 1, 14, 3), const Color(0xFFC62828));
    _pixelRect(canvas, Rect.fromLTWH(-10, 2, 4, 2), const Color(0xFFC62828)); // band tail
    _pixelRect(canvas, Rect.fromLTWH(-4, 5, 3, 3), const Color(0xFF3E2723));
    _pixelRect(canvas, Rect.fromLTWH(2, 5, 3, 3), const Color(0xFF3E2723));
    // big fists (one thrust forward when jabbing)
    _pixelRect(canvas, Rect.fromLTWH(8 + lean, 14, 8, 8), outline);
    _pixelRect(canvas, Rect.fromLTWH(9 + lean, 15, 6, 6), l);
    _pixelRect(canvas, Rect.fromLTWH(-14, 16, 7, 7), outline);
    _pixelRect(canvas, Rect.fromLTWH(-13, 17, 5, 5), m);
  }

  void _heretic(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF6A1B9A);
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF1A0A2A);
    final charge = e.atkCd < 0.8;
    final eyeC = charge ? const Color(0xFFFF4081) : const Color(0xFFE1BEE7);
    _pixelRect(canvas, Rect.fromLTWH(-14, e.h + 1, 28, 6),
        Colors.black.withOpacity(0.25));
    // long robe
    _pixelRect(canvas, Rect.fromLTWH(-13, 9, 26, e.h - 9), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12, 10, 24, e.h - 11), m);
    _pixelRect(canvas, Rect.fromLTWH(-12, 10, 24, 5), l);
    _pixelRect(canvas, Rect.fromLTWH(9, 10, 3, e.h - 11), s);
    // ritual sash
    _pixelRect(canvas, Rect.fromLTWH(-12, 24, 24, 2),
        Color.lerp(body, Colors.black, 0.4)!);
    // deep hood
    _pixelRect(canvas, Rect.fromLTWH(-10, -1, 20, 13), outline);
    _pixelRect(canvas, Rect.fromLTWH(-9, 0, 18, 11),
        Color.lerp(body, Colors.black, 0.25)!);
    _pixelRect(canvas, Rect.fromLTWH(-5, -5, 10, 5),
        Color.lerp(body, Colors.black, 0.25)!); // peak
    _glow(canvas, Offset(-4, 6), 4, eyeC.withOpacity(0.6), 3);
    _glow(canvas, Offset(4, 6), 4, eyeC.withOpacity(0.6), 3);
    _pixelRect(canvas, Rect.fromLTWH(-6, 5, 4, 3), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(2, 5, 4, 3), eyeC);
    // floating cursed tome with a glowing rune
    _pixelRect(canvas, Rect.fromLTWH(12, 18, 10, 12), const Color(0xFF4A148C));
    _pixelRect(canvas, Rect.fromLTWH(12, 18, 10, 2), const Color(0xFF7B1FA2));
    _glow(canvas, Offset(17, 24), charge ? 8 : 5, eyeC.withOpacity(0.7),
        charge ? 6 : 4);
    _pixelRect(canvas, Rect.fromLTWH(15, 22, 4, 4), eyeC);
  }

  void _thief(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF5D4037);
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF1A120C);
    final t = e.animTime;
    final fleeing = e.t2 > 0;
    final moving = e.vx.abs() > 5;
    final swing = moving ? sin(t * 22) * 4 : 0.0;
    _pixelRect(canvas, Rect.fromLTWH(-12, e.h + 1, 24, 5),
        Colors.black.withOpacity(0.25));
    // legs
    _pixelRect(canvas, Rect.fromLTWH(-6 + swing, 24, 5, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(-5 + swing, 24, 3, 11), s);
    _pixelRect(canvas, Rect.fromLTWH(1 - swing, 24, 5, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(2 - swing, 24, 3, 11), s);
    // loot sack on the back
    _pixelRect(canvas, Rect.fromLTWH(-12, 8, 8, 12), const Color(0xFF6D4C41));
    _pixelRect(canvas, Rect.fromLTWH(-12, 8, 8, 3), const Color(0xFF8D6E63));
    _pixelRect(canvas, Rect.fromLTWH(-9, 6, 3, 3), const Color(0xFFFFD166)); // coin
    // body
    _pixelRect(canvas, Rect.fromLTWH(-8, 8, 16, 18), outline);
    _pixelRect(canvas, Rect.fromLTWH(-7, 9, 14, 16), m);
    _pixelRect(canvas, Rect.fromLTWH(-7, 9, 14, 4), l);
    // bandana-masked head
    _pixelRect(canvas, Rect.fromLTWH(-7, 0, 14, 10), outline);
    _pixelRect(canvas, Rect.fromLTWH(-6, 1, 12, 8),
        Color.lerp(body, Colors.black, 0.1)!);
    _pixelRect(canvas, Rect.fromLTWH(-6, 5, 12, 3),
        const Color(0xFF263238)); // mask band
    final eyeC = fleeing ? const Color(0xFFFFD54F) : const Color(0xFFFFE082);
    _pixelRect(canvas, Rect.fromLTWH(-4, 3, 3, 2), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(2, 3, 3, 2), eyeC);
    // quick dagger
    _pixelRect(canvas, Rect.fromLTWH(7, 14, 9, 2), const Color(0xFFCFD8DC));
  }

  void _assassin(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF37474F);
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF101418);
    final t = e.animTime;
    final lunging = e.t2 > 0;
    final lean = lunging ? 7.0 : 0.0;
    final moving = e.vx.abs() > 5;
    final swing = moving ? sin(t * 20) * 4 : 0.0;
    _pixelRect(canvas, Rect.fromLTWH(-13, e.h + 1, 26, 6),
        Colors.black.withOpacity(0.25));
    // legs
    _pixelRect(canvas, Rect.fromLTWH(-7 + swing, 28, 6, 14), outline);
    _pixelRect(canvas, Rect.fromLTWH(-6 + swing, 28, 4, 13), s);
    _pixelRect(canvas, Rect.fromLTWH(1 - swing, 28, 6, 14), outline);
    _pixelRect(canvas, Rect.fromLTWH(2 - swing, 28, 4, 13), s);
    // cloaked torso
    _pixelRect(canvas, Rect.fromLTWH(-9 + lean, 9, 18, 22), outline);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 10, 16, 20), m);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 10, 16, 4), l);
    _pixelRect(canvas, Rect.fromLTWH(5 + lean, 10, 3, 20), s);
    _pixelRect(canvas, Rect.fromLTWH(-12 + lean, 12, 5, 10),
        Color.lerp(body, Colors.black, 0.2)!); // trailing scarf
    // hood
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 0, 16, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(-7 + lean, 1, 14, 9),
        Color.lerp(body, Colors.black, 0.15)!);
    _pixelRect(canvas, Rect.fromLTWH(-6 + lean, -3, 7, 4),
        Color.lerp(body, Colors.black, 0.15)!); // peak
    // glowing eyes (redden mid-lunge)
    final eyeC = lunging ? const Color(0xFFFF5252) : const Color(0xFFFF8A65);
    _glow(canvas, Offset(0 + lean, 6), 4, eyeC.withOpacity(0.6), 3);
    _pixelRect(canvas, Rect.fromLTWH(-4 + lean, 5, 3, 3), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(2 + lean, 5, 3, 3), eyeC);
    // twin daggers, thrust out during the lunge
    final dxx = lunging ? 14.0 : 8.0;
    _pixelRect(canvas, Rect.fromLTWH(dxx + lean, 14, 10, 2), const Color(0xFFCFD8DC));
    _pixelRect(canvas, Rect.fromLTWH(dxx + lean, 20, 10, 2), const Color(0xFFB0BEC5));
  }

  void _goblin(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF7CB342);
    final (s, m, l) = _ramp(body);
    final t = e.animTime;
    final moving = e.vx.abs() > 5;
    final bob = moving ? sin(t * 22).abs() * -1.5 : 0.0;
    final lunging = e.t2 > 0;
    final lean = lunging ? 4.0 : 0.0;
    const outline = Color(0xFF12200A);
    _pixelRect(canvas, Rect.fromLTWH(-12, e.h + 2, 24, 6),
        Colors.black.withOpacity(0.25));
    // legs (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-7, 21 + bob, 6, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(-6, 22 + bob, 4, 10), s);
    _pixelRect(canvas, Rect.fromLTWH(1, 21 + bob, 6, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(2, 22 + bob, 4, 10), s);
    // head/body: outline + shaded body
    _pixelRect(canvas, Rect.fromLTWH(-9 + lean, 7 + bob, 18, 18), outline);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 8 + bob, 16, 16), m);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 8 + bob, 16, 4), l); // top light
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 21 + bob, 16, 3), s); // chin shade
    _pixelRect(canvas, Rect.fromLTWH(5 + lean, 8 + bob, 3, 16), s); // side shade
    // big pointed ears (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-14 + lean, 7 + bob, 6, 6), outline);
    _pixelRect(canvas, Rect.fromLTWH(-13 + lean, 8 + bob, 5, 4), m);
    _pixelRect(canvas, Rect.fromLTWH(8 + lean, 7 + bob, 6, 6), outline);
    _pixelRect(canvas, Rect.fromLTWH(9 + lean, 8 + bob, 4, 4), m);
    // glaring eyes
    final eyeC = lunging ? const Color(0xFFFF1744) : const Color(0xFFFFEB3B);
    _glow(canvas, Offset(-2 + lean, 14 + bob), 4, eyeC.withOpacity(0.5), 3);
    _pixelRect(canvas, Rect.fromLTWH(-5 + lean, 13 + bob, 3, 3), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(2 + lean, 13 + bob, 3, 3), eyeC);
    // grin
    _pixelRect(canvas, Rect.fromLTWH(-4 + lean, 18 + bob, 8, 2), outline);
    // crude dagger (outlined)
    _pixelRect(canvas, Rect.fromLTWH(9 + lean, 13 + bob, 12, 4), outline);
    _pixelRect(canvas, Rect.fromLTWH(10 + lean, 14 + bob, 10, 2),
        const Color(0xFFCFD8DC));
  }

  void _dwarf(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF8D6E63);
    final (s, m, l) = _ramp(body);
    final t = e.animTime;
    final moving = e.vx.abs() > 5;
    final bob = moving ? sin(t * 14).abs() * -1.0 : 0.0;
    const outline = Color(0xFF1C140F);
    _pixelRect(canvas, Rect.fromLTWH(-18, e.h + 2, 36, 7),
        Colors.black.withOpacity(0.25));
    // stubby legs (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-13, 27 + bob, 11, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12, 28 + bob, 9, 10), const Color(0xFF4E342E));
    _pixelRect(canvas, Rect.fromLTWH(2, 27 + bob, 11, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(3, 28 + bob, 9, 10), const Color(0xFF4E342E));
    // broad torso: outline + shading
    _pixelRect(canvas, Rect.fromLTWH(-15, 9 + bob, 30, 22), outline);
    _pixelRect(canvas, Rect.fromLTWH(-14, 10 + bob, 28, 20), m);
    _pixelRect(canvas, Rect.fromLTWH(-14, 10 + bob, 28, 4), l); // top light
    _pixelRect(canvas, Rect.fromLTWH(11, 10 + bob, 3, 20), s); // side shade
    // helmet (outlined steel) with rim light + glowing eyes peering under it
    _pixelRect(canvas, Rect.fromLTWH(-13, 3 + bob, 26, 9), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12, 4 + bob, 24, 7), const Color(0xFF607D8B));
    _pixelRect(canvas, Rect.fromLTWH(-12, 4 + bob, 24, 2), const Color(0xFF90A4AE));
    _glow(canvas, Offset(-4, 15 + bob), 3.5, const Color(0xFFFFCA28).withOpacity(0.5), 3);
    _glow(canvas, Offset(4, 15 + bob), 3.5, const Color(0xFFFFCA28).withOpacity(0.5), 3);
    _pixelRect(canvas, Rect.fromLTWH(-6, 14 + bob, 3, 3), const Color(0xFFFFCA28));
    _pixelRect(canvas, Rect.fromLTWH(3, 14 + bob, 3, 3), const Color(0xFFFFCA28));
    // big braided beard (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-11, 19 + bob, 22, 10), outline);
    _pixelRect(canvas, Rect.fromLTWH(-10, 20 + bob, 20, 8), const Color(0xFFD7CCC8));
    _pixelRect(canvas, Rect.fromLTWH(-10, 20 + bob, 20, 2), const Color(0xFFECE7E2));
  }

  void _darkElf(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF4A148C);
    final (s, m, l) = _ramp(body);
    final float = sin(e.animTime * 3 + e.phase) * 1.6;
    final charge = e.atkCd < 0.7;
    const outline = Color(0xFF15082B);
    final eyeC = charge ? const Color(0xFFFF3D7F) : const Color(0xFFE040FB);
    // robe (outlined, 3-tone)
    _pixelRect(canvas, Rect.fromLTWH(-13, 9 + float, 26, 36), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12, 10 + float, 24, 34), m);
    _pixelRect(canvas, Rect.fromLTWH(-12, 10 + float, 24, 5), l);
    _pixelRect(canvas, Rect.fromLTWH(9, 10 + float, 3, 34), s);
    // hooded head + long ears
    _pixelRect(canvas, Rect.fromLTWH(-9, 1 + float, 18, 13), outline);
    _pixelRect(canvas, Rect.fromLTWH(-8, 2 + float, 16, 12), const Color(0xFF311B92));
    _pixelRect(canvas, Rect.fromLTWH(-14, 4 + float, 6, 3), const Color(0xFFD1B3FF));
    _pixelRect(canvas, Rect.fromLTWH(8, 4 + float, 6, 3), const Color(0xFFD1B3FF));
    _glow(canvas, Offset(-4, 8 + float), 4, eyeC.withOpacity(0.6), 3);
    _glow(canvas, Offset(4, 8 + float), 4, eyeC.withOpacity(0.6), 3);
    _pixelRect(canvas, Rect.fromLTWH(-6, 6 + float, 4, 4), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(2, 6 + float, 4, 4), eyeC);
    // staff with charging orb
    _pixelRect(canvas, Rect.fromLTWH(11, 6 + float, 3, 30), const Color(0xFF6A1B9A));
    _glow(canvas, Offset(12, 4 + float), charge ? 9 : 5, eyeC.withOpacity(0.7),
        charge ? 6 : 4);
    _pixelRect(canvas, Rect.fromLTWH(9, 0 + float, charge ? 7 : 5, charge ? 7 : 5),
        eyeC.withOpacity(0.95));
  }

  void _plant(Canvas canvas, Enemy e, bool flash) {
    // t2 in [0,1] = emergence; mostly hidden when dormant
    final rise = (e.t2).clamp(0.0, 1.0);
    // tint by trap variant so each reads distinctly:
    // 0 green (poison) · 1 purple (teleport) · 2 orange (fireball) · 3 teal (bind)
    const variantBody = <int, Color>{
      0: Color(0xFF558B2F),
      1: Color(0xFF7E57C2),
      2: Color(0xFFD84315),
      3: Color(0xFF00897B),
    };
    final body = flash
        ? Colors.white
        : (variantBody[e.plantVariant] ?? const Color(0xFF558B2F));
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF14250C);
    final hidden = 1 - rise;
    final yOff = e.h * hidden; // sink into the ground when dormant
    // base pod
    _pixelRect(canvas, Rect.fromLTWH(-18, e.h - 10, 36, 10), outline);
    _pixelRect(canvas, Rect.fromLTWH(-16, e.h - 9, 32, 8), const Color(0xFF33691E));
    // stem (outlined) rises out of the pod
    _pixelRect(canvas, Rect.fromLTWH(-7, 14 + yOff, 14, e.h - 20), outline);
    _pixelRect(canvas, Rect.fromLTWH(-6, 14 + yOff, 12, e.h - 20), m);
    _pixelRect(canvas, Rect.fromLTWH(-6, 14 + yOff, 4, e.h - 20), l);
    // big carnivorous head — lunges up above the rect at full emergence
    final headY = yOff - rise * 16;
    _pixelRect(canvas, Rect.fromLTWH(-15, headY, 30, 19), outline);
    _pixelRect(canvas, Rect.fromLTWH(-14, headY + 1, 28, 17), m);
    _pixelRect(canvas, Rect.fromLTWH(-14, headY + 1, 28, 4), l);
    _pixelRect(canvas, Rect.fromLTWH(11, headY + 1, 3, 16), s);
    // gaping maw
    _pixelRect(canvas, Rect.fromLTWH(-11, headY + 8, 22, 9), const Color(0xFF1B5E20));
    _pixelRect(canvas, Rect.fromLTWH(-11, headY + 10, 22, 5), Colors.black);
    if (rise > 0.4) {
      for (int i = 0; i < 5; i++) {
        _pixelRect(canvas, Rect.fromLTWH(-10 + i * 4.6, headY + 8, 2, 4), Colors.white);
        _pixelRect(canvas, Rect.fromLTWH(-8 + i * 4.6, headY + 14, 2, 3), Colors.white);
      }
    }
    // glaring eyes
    _glow(canvas, Offset(-6, headY + 5), 3, const Color(0xFFFFEB3B).withOpacity(0.5), 3);
    _glow(canvas, Offset(6, headY + 5), 3, const Color(0xFFFFEB3B).withOpacity(0.5), 3);
    _pixelRect(canvas, Rect.fromLTWH(-8, headY + 3, 4, 4), const Color(0xFFFFEB3B));
    _pixelRect(canvas, Rect.fromLTWH(4, headY + 3, 4, 4), const Color(0xFFFFEB3B));
  }

  void _hammerFoe(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF546E7A);
    final (s, m, l) = _ramp(body);
    final winding = e.windup > 0;
    final raise = winding ? -10.0 : 0.0;
    const outline = Color(0xFF161C22);
    _pixelRect(canvas, Rect.fromLTWH(-20, e.h + 2, 40, 8),
        Colors.black.withOpacity(0.28));
    // legs (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-15, e.h - 18, 13, 18), outline);
    _pixelRect(canvas, Rect.fromLTWH(-14, e.h - 18, 11, 17), const Color(0xFF37474F));
    _pixelRect(canvas, Rect.fromLTWH(2, e.h - 18, 13, 18), outline);
    _pixelRect(canvas, Rect.fromLTWH(3, e.h - 18, 11, 17), const Color(0xFF37474F));
    // bulky torso (outline + 3-tone)
    _pixelRect(canvas, Rect.fromLTWH(-17, 9, 34, e.h - 24), outline);
    _pixelRect(canvas, Rect.fromLTWH(-16, 10, 32, e.h - 26), m);
    _pixelRect(canvas, Rect.fromLTWH(-16, 10, 32, 6), l);
    _pixelRect(canvas, Rect.fromLTWH(13, 10, 3, e.h - 26), s);
    // helmet + glowing eye
    _pixelRect(canvas, Rect.fromLTWH(-13, -1, 26, 13), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12, 0, 24, 12), const Color(0xFF455A64));
    _pixelRect(canvas, Rect.fromLTWH(-12, 0, 24, 3), const Color(0xFF607D8B));
    final ec = winding ? const Color(0xFFFF1744) : const Color(0xFFFFCA28);
    _glow(canvas, Offset(2, 6), 4, ec.withOpacity(0.5), 3);
    _pixelRect(canvas, Rect.fromLTWH(0, 4, 5, 5), ec);
    // hammer: shaft + big head, raised during windup (telegraph)
    _pixelRect(canvas, Rect.fromLTWH(14, 8 + raise, 4, 24), const Color(0xFF5D4037));
    _pixelRect(canvas, Rect.fromLTWH(6, 0 + raise, 22, 14), outline);
    _pixelRect(canvas, Rect.fromLTWH(7, 1 + raise, 20, 12), const Color(0xFF90A4AE));
    _pixelRect(canvas, Rect.fromLTWH(7, 1 + raise, 20, 3), Colors.white24);
  }

  // C4: destructible shield-crystal that empowers nearby shield knights
  void _shieldCrystal(Canvas canvas, Rect r) {
    const c = Color(0xFF82B1FF);
    _glow(canvas, r.center, r.width * 1.6, c.withOpacity(0.4), 10);
    _pixelRect(canvas, Rect.fromLTWH(r.left - 5, r.bottom - 8, r.width + 10, 8),
        const Color(0xFF37474F));
    _pixelRect(canvas, r, const Color(0xFF283593));
    _pixelRect(canvas, Rect.fromLTWH(r.left + 3, r.top + 4, r.width - 9, r.height - 12),
        const Color(0xFF3949AB));
    _pixelRect(canvas, Rect.fromLTWH(r.left + 6, r.top + 6, r.width - 14, r.height - 18),
        c);
    _pixelRect(canvas, Rect.fromLTWH(r.left + 7, r.top + 8, 3, r.height - 24),
        Colors.white.withOpacity(0.7));
  }

  void _shieldFoe(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF78909C);
    final (s, m, l) = _ramp(body);
    final guarding = e.t2 > 0;
    const outline = Color(0xFF1A2127);
    _pixelRect(canvas, Rect.fromLTWH(-16, e.h + 2, 32, 7),
        Colors.black.withOpacity(0.26));
    // legs (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-13, e.h - 16, 11, 16), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12, e.h - 16, 9, 15), const Color(0xFF455A64));
    _pixelRect(canvas, Rect.fromLTWH(2, e.h - 16, 11, 16), outline);
    _pixelRect(canvas, Rect.fromLTWH(3, e.h - 16, 9, 15), const Color(0xFF455A64));
    // torso (outline + 3-tone)
    _pixelRect(canvas, Rect.fromLTWH(-13, 7, 26, e.h - 22), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12, 8, 24, e.h - 24), m);
    _pixelRect(canvas, Rect.fromLTWH(-12, 8, 24, 5), l);
    // helmet + eye
    _pixelRect(canvas, Rect.fromLTWH(-11, -1, 22, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(-10, 0, 20, 10), const Color(0xFF546E7A));
    _pixelRect(canvas, Rect.fromLTWH(-10, 0, 20, 3), const Color(0xFF78909C));
    _glow(canvas, Offset(2, 5), 3, const Color(0xFF82B1FF).withOpacity(0.5), 3);
    _pixelRect(canvas, Rect.fromLTWH(0, 3, 4, 4), const Color(0xFF82B1FF));
    // big tower shield on the front side (outlined)
    final sx = guarding ? 14.0 : 10.0;
    _pixelRect(canvas, Rect.fromLTWH(sx - 1, 3, 10, e.h - 14), outline);
    _pixelRect(canvas, Rect.fromLTWH(sx, 4, 8, e.h - 16), const Color(0xFFB0BEC5));
    _pixelRect(canvas, Rect.fromLTWH(sx, 4, 8, 3), Colors.white);
    _pixelRect(canvas, Rect.fromLTWH(sx + 2, e.h * 0.4, 4, 6),
        const Color(0xFFFFD166));
    if (guarding) {
      canvas.drawCircle(
          Offset(sx + 4, e.h / 2),
          22,
          Paint()
            ..color = const Color(0xFF82B1FF).withOpacity(0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  void _grunt(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF80B918);
    final (s, m, l) = _ramp(body);
    final t = e.animTime;
    final moving = e.vx.abs() > 5;
    final swing = moving ? sin(t * 18) * 4 : 0.0;
    final bob = moving ? sin(t * 18).abs() * -1.5 : 0.0;
    const outline = Color(0xFF15140A);
    _pixelRect(canvas, Rect.fromLTWH(-14, e.h + 2, 28, 8), Colors.black.withOpacity(0.25));
    if (e.attackAnim > 0) canvas.translate(e.attackAnim / 0.28 * 7, 0);
    // legs (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-9 + swing, 27 + bob, 8, 14), outline);
    _pixelRect(canvas, Rect.fromLTWH(-8 + swing, 28 + bob, 6, 12), s);
    _pixelRect(canvas, Rect.fromLTWH(1 - swing, 27 + bob, 8, 14), outline);
    _pixelRect(canvas, Rect.fromLTWH(2 - swing, 28 + bob, 6, 12), s);
    // torso: dark outline + 3-tone shaded body
    _pixelRect(canvas, Rect.fromLTWH(-13, 7 + bob, 26, 26), outline);
    _pixelRect(canvas, Rect.fromLTWH(-12, 8 + bob, 24, 24), m);
    _pixelRect(canvas, Rect.fromLTWH(-12, 8 + bob, 24, 5), l); // top light
    _pixelRect(canvas, Rect.fromLTWH(-12, 28 + bob, 24, 4), s); // bottom shade
    _pixelRect(canvas, Rect.fromLTWH(9, 8 + bob, 3, 24), s); // side shade
    // shoulder guards
    _pixelRect(canvas, Rect.fromLTWH(-13, 9 + bob, 5, 6), l);
    _pixelRect(canvas, Rect.fromLTWH(8, 9 + bob, 5, 6), m);
    // dark visor band with glowing eyes
    _pixelRect(canvas, Rect.fromLTWH(-10, 13 + bob, 20, 6), outline);
    _glow(canvas, Offset(-3, 16 + bob), 4, const Color(0xFFFF1744).withOpacity(0.5), 3);
    _glow(canvas, Offset(5, 16 + bob), 4, const Color(0xFFFF1744).withOpacity(0.5), 3);
    _pixelRect(canvas, Rect.fromLTWH(-5, 15 + bob, 3, 2), const Color(0xFFFF5252));
    _pixelRect(canvas, Rect.fromLTWH(3, 15 + bob, 3, 2), const Color(0xFFFF5252));
    // belt
    _pixelRect(canvas, Rect.fromLTWH(-12, 25 + bob, 24, 2), outline);
  }

  void _bat(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF4A4E69);
    final (s, m, l) = _ramp(body);
    const outline = Color(0xFF14141F);
    // wings flap with animation
    final flap = sin(e.animTime * 18) * 4;
    // left wing (outlined membrane)
    _pixelRect(canvas, Rect.fromLTWH(-18, 8 + flap, 14, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(-17, 9 + flap, 12, 9), const Color(0xFF22223B));
    _pixelRect(canvas, Rect.fromLTWH(-17, 9 + flap, 12, 2), s);
    // right wing
    _pixelRect(canvas, Rect.fromLTWH(4, 8 - flap, 14, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(5, 9 - flap, 12, 9), const Color(0xFF22223B));
    _pixelRect(canvas, Rect.fromLTWH(5, 9 - flap, 12, 2), s);
    // body (outlined + shaded)
    _pixelRect(canvas, Rect.fromLTWH(-11, 7, 22, 16), outline);
    _pixelRect(canvas, Rect.fromLTWH(-10, 8, 20, 14), m);
    _pixelRect(canvas, Rect.fromLTWH(-10, 8, 20, 4), l); // top light
    // pointed ears
    _pixelRect(canvas, Rect.fromLTWH(-8, 4, 4, 5), outline);
    _pixelRect(canvas, Rect.fromLTWH(4, 4, 4, 5), outline);
    // glowing eyes + tiny fangs
    _glow(canvas, Offset(-3, 13), 3, const Color(0xFFFFD60A).withOpacity(0.5), 3);
    _glow(canvas, Offset(3, 13), 3, const Color(0xFFFFD60A).withOpacity(0.5), 3);
    _pixelRect(canvas, Rect.fromLTWH(-5, 12, 3, 3), const Color(0xFFFFD60A));
    _pixelRect(canvas, Rect.fromLTWH(2, 12, 3, 3), const Color(0xFFFFD60A));
    _pixelRect(canvas, Rect.fromLTWH(-3, 19, 2, 2), Colors.white);
    _pixelRect(canvas, Rect.fromLTWH(1, 19, 2, 2), Colors.white);
  }

  void _fireMage(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF7A1E12);
    final (s, m, l) = _ramp(body);
    final float = sin(e.animTime * 3 + e.phase) * 2;
    const outline = Color(0xFF2A0A06);
    const fire = Color(0xFFFF7043);
    const fireL = Color(0xFFFFD54F);
    final charge = e.atkCd < 0.9;
    // robe (outlined, ember-hued)
    _pixelRect(canvas, Rect.fromLTWH(-15, 7 + float, 30, 40), outline);
    _pixelRect(canvas, Rect.fromLTWH(-14, 8 + float, 28, 38), m);
    _pixelRect(canvas, Rect.fromLTWH(-14, 8 + float, 28, 5), l);
    _pixelRect(canvas, Rect.fromLTWH(-14, 40 + float, 28, 6), s);
    _pixelRect(canvas, Rect.fromLTWH(11, 8 + float, 3, 38), s);
    // glowing ember trim down the robe
    _pixelRect(canvas, Rect.fromLTWH(-2, 14 + float, 2, 26), fire.withOpacity(0.7));
    // pointed hood
    _pixelRect(canvas, Rect.fromLTWH(-11, -2 + float, 22, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(-10, 0 + float, 20, 10),
        Color.lerp(body, Colors.black, 0.25)!);
    _pixelRect(canvas, Rect.fromLTWH(-4, -8 + float, 8, 8), outline);
    _pixelRect(canvas, Rect.fromLTWH(-3, -7 + float, 5, 7),
        Color.lerp(body, Colors.black, 0.25)!);
    // flame crown above the hood
    for (int i = 0; i < 3; i++) {
      final dx = (i - 1) * 6.0;
      final fl = 4 + sin(e.animTime * 16 + i * 2).abs() * 4;
      _pixelRect(canvas, Rect.fromLTWH(dx - 2, -8 + float - fl, 4, fl), fire);
      _pixelRect(canvas, Rect.fromLTWH(dx - 1, -8 + float - fl, 2, fl * 0.5), fireL);
    }
    // burning eyes
    _glow(canvas, Offset(-4, 8 + float), 4, fire.withOpacity(0.6), 3);
    _glow(canvas, Offset(4, 8 + float), 4, fire.withOpacity(0.6), 3);
    _pixelRect(canvas, Rect.fromLTWH(-6, 6 + float, 4, 4), fireL);
    _pixelRect(canvas, Rect.fromLTWH(2, 6 + float, 4, 4), fireL);
    // staff topped with a fireball
    _pixelRect(canvas, Rect.fromLTWH(12, 4 + float, 3, 34), const Color(0xFF5D4037));
    _glow(canvas, Offset(13, 2 + float), charge ? 10 : 6, fire.withOpacity(0.7),
        charge ? 7 : 5);
    _pixelRect(canvas, Rect.fromLTWH(10, -2 + float, charge ? 7 : 5, charge ? 7 : 5),
        fire);
    _pixelRect(canvas, Rect.fromLTWH(11, -1 + float, 3, 3), fireL);
  }

  void _mage(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF5A189A);
    final (s, m, l) = _ramp(body);
    final float = sin(e.animTime * 3 + e.phase) * 2;
    const outline = Color(0xFF1A0B2E);
    final charge = e.atkCd < 0.8;
    final eyeC = charge ? const Color(0xFFFF006E) : const Color(0xFF00F5D4);
    // robe (outlined, 3-tone)
    _pixelRect(canvas, Rect.fromLTWH(-15, 7 + float, 30, 40), outline);
    _pixelRect(canvas, Rect.fromLTWH(-14, 8 + float, 28, 38), m);
    _pixelRect(canvas, Rect.fromLTWH(-14, 8 + float, 28, 5), l);
    _pixelRect(canvas, Rect.fromLTWH(-14, 40 + float, 28, 6), s);
    _pixelRect(canvas, Rect.fromLTWH(11, 8 + float, 3, 38), s);
    // pointed hood
    _pixelRect(canvas, Rect.fromLTWH(-11, -2 + float, 22, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(-10, 0 + float, 20, 10),
        Color.lerp(body, Colors.black, 0.25)!);
    _pixelRect(canvas, Rect.fromLTWH(-4, -8 + float, 8, 8), outline);
    _pixelRect(canvas, Rect.fromLTWH(-3, -7 + float, 5, 7),
        Color.lerp(body, Colors.black, 0.25)!);
    // glowing eyes in the hood shadow
    _glow(canvas, Offset(-4, 8 + float), 4, eyeC.withOpacity(0.6), 3);
    _glow(canvas, Offset(4, 8 + float), 4, eyeC.withOpacity(0.6), 3);
    _pixelRect(canvas, Rect.fromLTWH(-6, 6 + float, 4, 4), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(2, 6 + float, 4, 4), eyeC);
    // staff + orb (charging glows brighter/bigger)
    _pixelRect(canvas, Rect.fromLTWH(12, 4 + float, 3, 34), const Color(0xFF5D4037));
    _glow(canvas, Offset(13, 2 + float), charge ? 9 : 5, eyeC.withOpacity(0.7),
        charge ? 6 : 4);
    _pixelRect(canvas, Rect.fromLTWH(10, -2 + float, charge ? 7 : 5, charge ? 7 : 5),
        eyeC.withOpacity(0.95));
  }

  void _slime(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF52B788);
    final (s, m, l) = _ramp(body);
    final float = !e.onGround ? -2.0 : sin(e.animTime * 10) * 1.5;
    const outline = Color(0xFF14321F);
    final top = e.h - 24 + float;
    // jelly body (outlined + 3-tone) with a shine
    _pixelRect(canvas, Rect.fromLTWH(-17, top, 34, 24), outline);
    _pixelRect(canvas, Rect.fromLTWH(-16, top + 1, 32, 22), m.withOpacity(0.95));
    _pixelRect(canvas, Rect.fromLTWH(-16, top + 1, 32, 5), l.withOpacity(0.9));
    _pixelRect(canvas, Rect.fromLTWH(-16, top + 17, 32, 5), s.withOpacity(0.9));
    _pixelRect(canvas, Rect.fromLTWH(-12, top + 3, 6, 3), Colors.white.withOpacity(0.7));
    // eyes
    _pixelRect(canvas, Rect.fromLTWH(-7, top + 8, 6, 6), Colors.white);
    _pixelRect(canvas, Rect.fromLTWH(3, top + 8, 6, 6), Colors.white);
    _pixelRect(canvas, Rect.fromLTWH(-5, top + 11, 4, 3), Colors.black);
    _pixelRect(canvas, Rect.fromLTWH(5, top + 11, 4, 3), Colors.black);
  }

  void _archer(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF457B9D);
    final (s, m, l) = _ramp(body);
    final bob = e.vx.abs() > 5 ? sin(e.animTime * 16).abs() * -1.5 : 0.0;
    const outline = Color(0xFF12202B);
    final aiming = e.atkCd < 0.7;
    // legs (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-7, 30 + bob, 6, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(-6, 30 + bob, 4, 11), const Color(0xFF2B4150));
    _pixelRect(canvas, Rect.fromLTWH(1, 30 + bob, 6, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(2, 30 + bob, 4, 11), const Color(0xFF2B4150));
    // cloak torso (outline + 3-tone)
    _pixelRect(canvas, Rect.fromLTWH(-11, 9 + bob, 22, 24), outline);
    _pixelRect(canvas, Rect.fromLTWH(-10, 10 + bob, 20, 22), m);
    _pixelRect(canvas, Rect.fromLTWH(-10, 10 + bob, 20, 4), l);
    _pixelRect(canvas, Rect.fromLTWH(7, 10 + bob, 3, 22), s);
    // hood
    _pixelRect(canvas, Rect.fromLTWH(-9, 1 + bob, 18, 11), outline);
    _pixelRect(canvas, Rect.fromLTWH(-8, 2 + bob, 16, 9), const Color(0xFF1D3557));
    _pixelRect(canvas, Rect.fromLTWH(-7, -2 + bob, 8, 4), const Color(0xFF1D3557));
    _glow(canvas, Offset(3, 7 + bob), 3, const Color(0xFFFFD166).withOpacity(0.5), 3);
    _pixelRect(canvas, Rect.fromLTWH(1, 6 + bob, 4, 3), const Color(0xFFFFD166));
    // bow + arrow (string drawn back while aiming)
    _pixelRect(canvas, Rect.fromLTWH(16, 6 + bob, 4, 24), outline);
    _pixelRect(canvas, Rect.fromLTWH(17, 7 + bob, 2, 22), const Color(0xFF8D6E63));
    if (aiming) {
      _pixelRect(canvas, Rect.fromLTWH(7, 17 + bob, 12, 2), const Color(0xFFCFD8DC));
      _pixelRect(canvas, Rect.fromLTWH(8, 16 + bob, 11, 1), Colors.white70);
    }
  }

  void _brute(Canvas canvas, Enemy e, bool flash) {
    final body = flash ? Colors.white : const Color(0xFF6D597A);
    final (s, m, l) = _ramp(body);
    final lunging = e.t2 > 0;
    final lean = lunging ? 6.0 : 0.0;
    const outline = Color(0xFF1B1422);
    _pixelRect(canvas, Rect.fromLTWH(-18, e.h + 2, 36, 7),
        Colors.black.withOpacity(0.3));
    // legs (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-16, e.h - 16, 12, 16), outline);
    _pixelRect(canvas, Rect.fromLTWH(-15, e.h - 16, 10, 15), s);
    _pixelRect(canvas, Rect.fromLTWH(4, e.h - 16, 12, 16), outline);
    _pixelRect(canvas, Rect.fromLTWH(5, e.h - 16, 10, 15), s);
    // hulking torso: outline + 3-tone shading
    _pixelRect(canvas, Rect.fromLTWH(-17 + lean, 7, 34, e.h - 20), outline);
    _pixelRect(canvas, Rect.fromLTWH(-16 + lean, 8, 32, e.h - 22), m);
    _pixelRect(canvas, Rect.fromLTWH(-16 + lean, 8, 32, 6), l); // top light
    _pixelRect(canvas, Rect.fromLTWH(13 + lean, 8, 3, e.h - 22), s); // side shade
    // big fists / shoulder masses (outlined)
    _pixelRect(canvas, Rect.fromLTWH(-23 + lean, 21, 12, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(-22 + lean, 22, 10, 10), Color.lerp(body, Colors.black, 0.25)!);
    _pixelRect(canvas, Rect.fromLTWH(11 + lean, 21, 12, 12), outline);
    _pixelRect(canvas, Rect.fromLTWH(12 + lean, 22, 10, 10), Color.lerp(body, Colors.black, 0.25)!);
    // horns (outlined bone)
    _pixelRect(canvas, Rect.fromLTWH(-15 + lean, 1, 9, 9), outline);
    _pixelRect(canvas, Rect.fromLTWH(-14 + lean, 2, 8, 7), const Color(0xFFE8E8E8));
    _pixelRect(canvas, Rect.fromLTWH(6 + lean, 1, 9, 9), outline);
    _pixelRect(canvas, Rect.fromLTWH(7 + lean, 2, 8, 7), const Color(0xFFE8E8E8));
    // furious glowing eyes
    final eyeC = lunging ? const Color(0xFFFF1744) : const Color(0xFFFFCA28);
    _glow(canvas, Offset(-5 + lean, 19, ), 5, eyeC.withOpacity(0.55), 4);
    _glow(canvas, Offset(13 + lean, 19), 5, eyeC.withOpacity(0.55), 4);
    _pixelRect(canvas, Rect.fromLTWH(-8 + lean, 16, 6, 6), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(10 + lean, 16, 6, 6), eyeC);
  }

  void _enemyHp(Canvas canvas, Enemy e) {
    if (e.hp >= e.maxHp) return;
    final w = e.w + 4;
    final x = e.cx - w / 2;
    final y = e.y - 10;
    canvas.drawRect(Rect.fromLTWH(x, y, w, 4),
        Paint()..color = Colors.black.withOpacity(0.5));
    canvas.drawRect(Rect.fromLTWH(x, y, w * (e.hp / e.maxHp), 4),
        Paint()..color = const Color(0xFF80ED99));
  }

  // priority order for which status drives the body-flash color
  static const _tintPriority = <StatusKind>[
    StatusKind.stun,
    StatusKind.bind,
    StatusKind.burn,
    StatusKind.infect,
    StatusKind.poison,
    StatusKind.bleed,
    StatusKind.slow,
    StatusKind.weaken,
  ];

  /// In-world status feedback (drawn in world space, after the entity sprite):
  /// a pulsing colored film over the body + a row of status badges over the head.
  void _statusFx(Canvas canvas, Entity e) {
    if (e.statuses.isEmpty) return;
    // body tint flash for the most prominent debuff (burn=red, poison=green…)
    StatusKind? tint;
    for (final k in _tintPriority) {
      if (e.hasStatus(k)) {
        tint = k;
        break;
      }
    }
    if (tint != null) {
      final pulse = 0.22 + 0.26 * (0.5 + 0.5 * sin(e.animTime * 12));
      canvas.drawRect(Rect.fromLTWH(e.x, e.y, e.w, e.h),
          Paint()..color = statusColor(tint).withOpacity(pulse));
    }
    // status badges above the head (small colored chips)
    final kinds = e.statuses.map((s) => s.kind).toList();
    const sz = 6.0, gap = 3.0;
    double bx = e.cx - (kinds.length * (sz + gap) - gap) / 2;
    final by = e.y - 20;
    for (final k in kinds) {
      canvas.drawRect(Rect.fromLTWH(bx - 1, by - 1, sz + 2, sz + 2),
          Paint()..color = Colors.black.withOpacity(0.55));
      canvas.drawRect(
          Rect.fromLTWH(bx, by, sz, sz), Paint()..color = statusColor(k));
      bx += sz + gap;
    }
  }

  // ----------------------------------------------------------------
  // BOSS
  void _boss(Canvas canvas, Boss b) {
    canvas.save();
    canvas.translate(b.cx, b.y);
    final winding = b.state == BossState.windup;
    final t = b.animTime;
    double sx = 1, sy = 1;
    if (winding) {
      final pulse = sin(t * 30) * 0.04;
      sx = 1.08 + pulse;
      sy = 0.94 - pulse;
    } else if (b.airborne) {
      sx = 0.9;
      sy = 1.12;
    } else if (b.state == BossState.recover) {
      sx = 1.16;
      sy = 0.86;
    }
    canvas.scale(b.facing.toDouble() * sx, sy);
    final bHurt = (b.hurtTimer / 0.18).clamp(0.0, 1.0);
    if (bHurt > 0) canvas.rotate(bHurt * 0.08);

    final flash = b.hitFlash > 0;
    final baseCol = _reinforced(b.spec.color); // deep-floor crimson reinforcement
    final col = flash ? Colors.white : baseCol;
    final dark = Color.lerp(baseCol, Colors.black, 0.4)!;

    canvas.drawOval(
        Rect.fromCenter(center: Offset(0, b.h - 2), width: 90, height: 16),
        Paint()..color = Colors.black.withOpacity(0.3));
    // ever-present menacing aura so the boss reads as imposing
    _glow(canvas, Offset(0, b.h * 0.5), 52,
        b.spec.color.withOpacity(0.16), 18);
    if (winding) {
      canvas.drawCircle(
          Offset(0, b.h / 2),
          70,
          Paint()
            ..color = const Color(0xFFFF1744).withOpacity(0.30)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }
    if (b.guard > 0) {
      canvas.drawCircle(
          Offset(0, b.h / 2),
          64,
          Paint()
            ..color = const Color(0xFF64B5F6).withOpacity(0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4);
      canvas.drawCircle(Offset(0, b.h / 2), 60,
          Paint()..color = const Color(0xFF64B5F6).withOpacity(0.12));
    }
    final eyeC = winding ? const Color(0xFFFF1744) : const Color(0xFFFFEA00);
    switch (b.spec.visual) {
      case 'knight':
        _bossKnight(canvas, b, col, dark, eyeC);
        break;
      case 'mercenary':
        _bossMercenary(canvas, b, col, dark, eyeC);
        break;
      case 'bandit':
        _bossBandit(canvas, b, col, dark, eyeC);
        break;
      case 'witch':
        _bossWitch(canvas, b, col, dark, eyeC);
        break;
      case 'demonKing':
        _bossDemonKing(canvas, b, col, dark, eyeC);
        break;
      case 'goblin':
        _bossGoblin(canvas, b, col, dark, eyeC);
        break;
      case 'boar':
        _bossBeast(canvas, b, col, dark, eyeC);
        break;
      case 'golem':
        _bossGolem(canvas, b, col, dark, eyeC);
        break;
      case 'eagle':
        _bossBird(canvas, b, col, dark, eyeC);
        break;
      case 'redBear':
        _bossRedBear(canvas, b, col, dark, eyeC);
        break;
      case 'rockBrute':
        _bossRockBrute(canvas, b, col, dark, eyeC);
        break;
      case 'mummy':
        _bossMummy(canvas, b, col, dark, eyeC);
        break;
      case 'doppel':
        _bossDoppel(canvas, b, col, dark, eyeC);
        break;
      case 'appleTree':
        _bossAppleTree(canvas, b, col, dark, eyeC);
        break;
      case 'worm':
        _bossWorm(canvas, b, col, dark, eyeC);
        break;
      case 'wolfKing':
        _bossWolfKing(canvas, b, col, dark, eyeC);
        break;
      case 'spider':
        _bossSpider(canvas, b, col, dark, eyeC);
        break;
      case 'dragon':
        _bossDragon(canvas, b, col, dark, eyeC);
        break;
      case 'dragonkin':
        _bossDragonkin(canvas, b, col, dark, eyeC);
        break;
      default:
        switch (b.spec.shape) {
          case BossShape.humanoid:
            _bossHumanoid(canvas, b, col, dark, eyeC);
            break;
          case BossShape.beast:
            _bossBeast(canvas, b, col, dark, eyeC);
            break;
          case BossShape.golem:
            _bossGolem(canvas, b, col, dark, eyeC);
            break;
          case BossShape.bird:
            _bossBird(canvas, b, col, dark, eyeC);
            break;
        }
    }
    canvas.restore();
    _statusFx(canvas, b);
  }

  // 용인족 전사: 비늘 갑주 + 작은 날개 + 뿔 달린 파충류 머리 + 검
  void _bossDragonkin(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final t = b.animTime;
    final lit = Color.lerp(col, Colors.white, 0.2)!;
    final lean = b.state == BossState.active ? 8.0 : 0.0;
    final flap = sin(t * 5) * 4;
    // tail + small wings
    _pixelRect(canvas, Rect.fromLTWH(-42, h - 30, 24, 8), col);
    _pixelRect(canvas, Rect.fromLTWH(-34, 10 + flap, 16, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(18, 10 - flap, 16, 22), dark);
    // legs
    _pixelRect(canvas, Rect.fromLTWH(-22, h - 26, 16, 26), dark);
    _pixelRect(canvas, Rect.fromLTWH(6, h - 26, 16, 26), dark);
    // scaled torso
    _pixelRect(canvas, Rect.fromLTWH(-22, 14, 44, h - 40), col);
    _pixelRect(canvas, Rect.fromLTWH(-22, 14, 44, 8), lit);
    _pixelRect(canvas, Rect.fromLTWH(-20, 30, 40, 2), dark);
    _pixelRect(canvas, Rect.fromLTWH(-20, 40, 40, 2), dark);
    // arms
    _pixelRect(canvas, Rect.fromLTWH(-30 + lean, 22, 12, 30), dark);
    _pixelRect(canvas, Rect.fromLTWH(18 + lean, 22, 12, 30), dark);
    // horned reptilian head
    _pixelRect(canvas, Rect.fromLTWH(-14, 0, 28, 16), col);
    _pixelRect(canvas, Rect.fromLTWH(-14, 0, 28, 4), lit);
    _pixelRect(canvas, Rect.fromLTWH(-16, 2, 4, 6), dark); // horns
    _pixelRect(canvas, Rect.fromLTWH(12, 2, 4, 6), dark);
    _pixelRect(canvas, Rect.fromLTWH(10, 8, 8, 5), lit); // snout
    _glow(canvas, Offset(-4, 7), 4, eyeC.withOpacity(0.6), 3);
    _glow(canvas, Offset(6, 7), 4, eyeC.withOpacity(0.6), 3);
    _pixelRect(canvas, Rect.fromLTWH(-6, 5, 5, 4), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(3, 5, 5, 4), eyeC);
    // greatsword
    _pixelRect(canvas, Rect.fromLTWH(28 + lean, 18, 6, 6),
        const Color(0xFF607D8B));
    _pixelRect(canvas, Rect.fromLTWH(30 + lean, -6, 6, 28),
        const Color(0xFFE3F2FD));
    _pixelRect(canvas, Rect.fromLTWH(30 + lean, -6, 6, 5), Colors.white);
  }

  // 거미 여제: 부푼 복부 + 8개 다리 + 다중 발광 눈 + 송곳니
  // 거미 여제(아라크네): 하체는 8각의 거미, 그 앞쪽 위로 인간 여성의 상체가
  // 솟아 붙은 합성형. 거미부는 col/dark, 인간부는 창백한 살결 + 짙은 머리칼.
  void _bossSpider(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final t = b.animTime;
    final lit = Color.lerp(col, Colors.white, 0.18)!;
    final skin = Color.lerp(col, Colors.white, 0.5)!; // 창백한 보랏빛 살결
    final skinDk = Color.lerp(skin, Colors.black, 0.18)!;
    final hair = Color.lerp(dark, Colors.black, 0.25)!;
    const hx = 9.0; // 인간 상체의 가로 중심 (몸통 앞쪽으로 약간 치우침)

    // ---- 거미 다리: 한쪽 4개씩, 무릎을 높이 세운 아치형 ----
    final legPaint = Paint()
      ..color = dark
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final legLit = Paint()
      ..color = lit.withOpacity(0.5)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 4; i++) {
      for (final s in const [-1, 1]) {
        final ph = sin(t * 5 + i * 1.0 + (s < 0 ? 0.6 : 0)) * 4;
        final hip = Offset(s * 8.0, 54);
        final knee = Offset(s * (22 + i * 9.0), 38 - i * 1.0 + ph);
        final foot = Offset(s * (30 + i * 11.0), 90.0);
        canvas.drawLine(hip, knee, legPaint);
        canvas.drawLine(knee, foot, legPaint);
        canvas.drawLine(hip, knee, legLit);
      }
    }

    // ---- 거미 하체: 뒤쪽 둥근 배 + 그 앞 두흉부 ----
    // 부푼 복부(뒤쪽)
    canvas.drawOval(
        Rect.fromLTWH(-44, 44, 42, 40), Paint()..color = col);
    canvas.drawOval(
        Rect.fromLTWH(-42, 46, 30, 12), Paint()..color = lit.withOpacity(0.7));
    _pixelRect(canvas, Rect.fromLTWH(-28, 56, 10, 18), dark); // 모래시계 무늬
    _pixelRect(canvas, Rect.fromLTWH(-26, 60, 6, 10), const Color(0xFFD32F2F));
    // 두흉부(인간이 솟아오르는 받침)
    _pixelRect(canvas, Rect.fromLTWH(-8, 48, 32, 28), dark);
    _pixelRect(canvas, Rect.fromLTWH(-6, 50, 28, 6), col);
    // 두흉부 앞면의 작은 홑눈 두 쌍(괴이함 유지)
    for (final e2 in const [[2, 58], [12, 58], [4, 64], [10, 64]]) {
      _pixelRect(canvas, Rect.fromLTWH(e2[0].toDouble(), e2[1].toDouble(), 3, 3),
          eyeC.withOpacity(0.85));
    }

    // ---- 인간 상체: 두흉부 앞쪽 위로 솟음 ----
    // 뒤로 흘러내리는 머리칼(상체 뒤)
    _pixelRect(canvas, Rect.fromLTWH(hx - 11, 6, 7, 34), hair);
    // 허리에서 거미 몸통으로 이어지는 골반
    _pixelRect(canvas, Rect.fromLTWH(hx - 7, 38, 16, 12), skinDk);
    _pixelRect(canvas, Rect.fromLTWH(hx - 8, 44, 18, 6), dark); // 결합부 비늘
    // 잘록한 허리 → 가슴으로 벌어지는 여성형 몸통(보디스)
    _pixelRect(canvas, Rect.fromLTWH(hx - 6, 30, 12, 12), skin); // 드러난 허리
    _pixelRect(canvas, Rect.fromLTWH(hx - 9, 18, 18, 14), col); // 보디스
    _pixelRect(canvas, Rect.fromLTWH(hx - 9, 18, 18, 3), lit);
    // 가슴 라인 암시
    canvas.drawCircle(Offset(hx - 4, 22), 3.4, Paint()..color = skin);
    canvas.drawCircle(Offset(hx + 4, 22), 3.4, Paint()..color = skin);
    _pixelRect(canvas, Rect.fromLTWH(hx - 9, 24, 18, 2), dark); // 보디스 상단 선

    // 팔: 한쪽은 들어 주문을 엮고, 한쪽은 아래로
    final armRaise = sin(t * 3) * 3;
    _pixelRect(canvas, Rect.fromLTWH(hx + 6, 18, 5, 16), skin); // 어깨→앞팔(아래)
    _pixelRect(canvas, Rect.fromLTWH(hx + 8, 30, 5, 8), skinDk);
    _pixelRect(canvas, Rect.fromLTWH(hx - 13, 14 + armRaise, 5, 14), skin); // 든 팔
    _pixelRect(canvas, Rect.fromLTWH(hx - 16, 8 + armRaise, 5, 8), skinDk);
    _glow(canvas, Offset(hx - 14, 8 + armRaise), 5,
        eyeC.withOpacity(0.5), 4); // 손끝 마력

    // 목 + 머리
    _pixelRect(canvas, Rect.fromLTWH(hx - 3, 12, 6, 6), skin);
    _pixelRect(canvas, Rect.fromLTWH(hx - 7, 0, 14, 13), skin); // 얼굴
    _pixelRect(canvas, Rect.fromLTWH(hx - 8, -3, 16, 6), hair); // 앞머리
    _pixelRect(canvas, Rect.fromLTWH(hx - 9, 1, 3, 12), hair); // 옆머리
    _pixelRect(canvas, Rect.fromLTWH(hx + 6, 1, 3, 12), hair);
    // 차가운 두 눈
    _glow(canvas, Offset(hx - 3, 6), 2.4, eyeC.withOpacity(0.5), 2);
    _glow(canvas, Offset(hx + 3, 6), 2.4, eyeC.withOpacity(0.5), 2);
    _pixelRect(canvas, Rect.fromLTWH(hx - 4, 5, 3, 3), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(hx + 2, 5, 3, 3), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(hx - 2, 10, 4, 1), skinDk); // 입
  }

  // 드래곤: 거대한 몸통 + 펄럭이는 날개 + 뿔 머리 + 화염 아가리 + 꼬리
  void _bossDragon(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final t = b.animTime;
    final lit = Color.lerp(col, Colors.white, 0.2)!;
    final flap = sin(t * 5) * 6;
    // wing (behind)
    _pixelRect(canvas, Rect.fromLTWH(-42, 4 + flap, 32, 24), dark);
    _pixelRect(canvas, Rect.fromLTWH(-40, 6 + flap, 28, 20),
        Color.lerp(col, Colors.black, 0.25)!);
    _pixelRect(canvas, Rect.fromLTWH(-40, 6 + flap, 28, 4), lit);
    // hind legs
    _pixelRect(canvas, Rect.fromLTWH(-16, h - 24, 13, 24), dark);
    _pixelRect(canvas, Rect.fromLTWH(6, h - 24, 13, 24), dark);
    // body
    _pixelRect(canvas, Rect.fromLTWH(-22, 26, 48, h - 44), col);
    _pixelRect(canvas, Rect.fromLTWH(-22, 26, 48, 8), lit);
    _pixelRect(canvas, Rect.fromLTWH(-20, h - 22, 44, 4), lit); // belly
    // tail trailing back
    _pixelRect(canvas, Rect.fromLTWH(-40, h - 30, 22, 8), col);
    _pixelRect(canvas, Rect.fromLTWH(-52, h - 26, 14, 6), dark);
    // raised neck + horned head at the front
    _pixelRect(canvas, Rect.fromLTWH(16, 8, 12, 26), col);
    _pixelRect(canvas, Rect.fromLTWH(24, -2, 24, 16), col);
    _pixelRect(canvas, Rect.fromLTWH(24, -2, 24, 4), lit);
    _pixelRect(canvas, Rect.fromLTWH(26, -8, 4, 7), dark); // horns
    _pixelRect(canvas, Rect.fromLTWH(34, -9, 4, 8), dark);
    _pixelRect(canvas, Rect.fromLTWH(30, 3, 4, 4), eyeC); // eye
    // fiery maw
    _pixelRect(canvas, Rect.fromLTWH(42, 8, 8, 7), dark);
    _glow(canvas, Offset(48, 11), 6, const Color(0xFFFF7043).withOpacity(0.6), 5);
    _pixelRect(canvas, Rect.fromLTWH(45, 8, 5, 5), const Color(0xFFFFD166));
  }

  // 대형 붉은 곰: 거대한 사족 곰, 혹등 + 주둥이 + 발광 눈
  void _bossRedBear(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 10.0 : 0.0;
    final furL = Color.lerp(col, Colors.white, 0.18)!;
    final paw = Color.lerp(dark, Colors.black, 0.25)!;
    _pixelRect(canvas, Rect.fromLTWH(-34, h - 22, 16, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(18, h - 22, 16, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(-22, h - 16, 16, 16), paw);
    _pixelRect(canvas, Rect.fromLTWH(6, h - 16, 16, 16), paw);
    _pixelRect(canvas, Rect.fromLTWH(-40, 18, 80, h - 34), col);
    _pixelRect(canvas, Rect.fromLTWH(-40, 18, 80, 10), furL); // back light
    _pixelRect(canvas, Rect.fromLTWH(-32, 8, 36, 16), col); // shoulder hump
    // head pushed forward
    final hx = 14 + lean;
    _pixelRect(canvas, Rect.fromLTWH(hx, 16, 12, 8), dark); // ears
    _pixelRect(canvas, Rect.fromLTWH(hx + 20, 16, 12, 8), dark);
    _pixelRect(canvas, Rect.fromLTWH(hx, 22, 32, 28), col);
    _pixelRect(canvas, Rect.fromLTWH(hx, 22, 32, 6), furL);
    _pixelRect(canvas, Rect.fromLTWH(hx + 24, 34, 14, 12), furL); // snout
    _pixelRect(canvas, Rect.fromLTWH(hx + 34, 37, 5, 6), Colors.black); // nose
    _glow(canvas, Offset(hx + 10, 30), 5, eyeC.withOpacity(0.6), 4);
    _glow(canvas, Offset(hx + 22, 30), 5, eyeC.withOpacity(0.6), 4);
    _pixelRect(canvas, Rect.fromLTWH(hx + 7, 28, 6, 5), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(hx + 19, 28, 6, 5), eyeC);
    // claws
    _pixelRect(canvas, Rect.fromLTWH(-24, h - 4, 18, 4), Colors.black54);
    _pixelRect(canvas, Rect.fromLTWH(6, h - 4, 18, 4), Colors.black54);
  }

  // 암석괴인: 육중한 바위 골렘, 갈라진 암석 플레이트 + 발광 코어
  void _bossRockBrute(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 12.0 : 0.0;
    final lit = Color.lerp(col, Colors.white, 0.2)!;
    _pixelRect(canvas, Rect.fromLTWH(-26, h - 22, 20, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(6, h - 22, 20, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(-38, 14, 76, h - 30), col); // boulder torso
    _pixelRect(canvas, Rect.fromLTWH(-38, 14, 76, 8), lit);
    // cracks
    _pixelRect(canvas, Rect.fromLTWH(-6, 22, 4, h - 44), Colors.black38);
    _pixelRect(canvas, Rect.fromLTWH(-24, 40, 16, 4), Colors.black38);
    // massive arms / fists
    _pixelRect(canvas, Rect.fromLTWH(-54 + lean, 20, 18, 30), col);
    _pixelRect(canvas, Rect.fromLTWH(-58 + lean, 46, 24, 22), dark); // fist
    _pixelRect(canvas, Rect.fromLTWH(36 + lean, 20, 18, 30), col);
    _pixelRect(canvas, Rect.fromLTWH(34 + lean, 46, 24, 22), dark);
    // small head + glowing core eye
    _pixelRect(canvas, Rect.fromLTWH(-12, 2, 24, 16), col);
    _pixelRect(canvas, Rect.fromLTWH(-12, 2, 24, 4), lit);
    _glow(canvas, Offset(0, 28), 10, eyeC.withOpacity(0.5), 8); // chest core
    _pixelRect(canvas, Rect.fromLTWH(-6, 24, 12, 10), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(-4, 8, 8, 5), eyeC); // eye
  }

  // 미이라: 붕대 감긴 인간형, 가로 붕대 줄 + 새어나오는 저주 눈
  void _bossMummy(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 12.0 : 0.0;
    final wrapD = Color.lerp(col, Colors.black, 0.3)!;
    _pixelRect(canvas, Rect.fromLTWH(-22, h - 26, 16, 26), dark);
    _pixelRect(canvas, Rect.fromLTWH(6, h - 26, 16, 26), dark);
    _pixelRect(canvas, Rect.fromLTWH(-34, 16, 68, h - 30), col); // wrapped body
    // bandage banding
    for (double yy = 20; yy < h - 16; yy += 8) {
      _pixelRect(canvas, Rect.fromLTWH(-34, yy, 68, 2), wrapD);
    }
    // outstretched arms (reaching)
    _pixelRect(canvas, Rect.fromLTWH(-58 + lean, 24, 26, 12), col);
    _pixelRect(canvas, Rect.fromLTWH(32 + lean, 24, 26, 12), col);
    _pixelRect(canvas, Rect.fromLTWH(-60 + lean, 24, 8, 16), wrapD); // dangling wraps
    // head
    _pixelRect(canvas, Rect.fromLTWH(-14, 2, 28, 16), col);
    _pixelRect(canvas, Rect.fromLTWH(-14, 8, 28, 2), wrapD);
    _glow(canvas, Offset(-4, 9), 4, eyeC.withOpacity(0.7), 4);
    _glow(canvas, Offset(6, 9), 4, eyeC.withOpacity(0.7), 4);
    _pixelRect(canvas, Rect.fromLTWH(-7, 7, 5, 4), eyeC); // glowing eyes through wraps
    _pixelRect(canvas, Rect.fromLTWH(3, 7, 5, 4), eyeC);
  }

  // 도플갱어: 그림자 인간형 (플레이어를 본뜬 듯), 일렁이는 어둠 + 두 발광 눈
  void _bossDoppel(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final t = b.animTime;
    final lean = b.state == BossState.active ? 10.0 : 0.0;
    final shade = Color.lerp(col, Colors.black, 0.45)!;
    // wispy shadow trails
    for (int i = 0; i < 3; i++) {
      final wy = 20 + i * 18.0 + sin(t * 4 + i) * 3;
      _pixelRect(canvas, Rect.fromLTWH(-44 - sin(t * 3 + i) * 4, wy, 8, 6),
          shade.withOpacity(0.5));
    }
    _pixelRect(canvas, Rect.fromLTWH(-20, h - 26, 14, 26), shade);
    _pixelRect(canvas, Rect.fromLTWH(6, h - 26, 14, 26), shade);
    _pixelRect(canvas, Rect.fromLTWH(-28, 16, 56, h - 30), col); // body
    _pixelRect(canvas, Rect.fromLTWH(-28, 16, 56, 5), shade);
    _pixelRect(canvas, Rect.fromLTWH(-46 + lean, 22, 16, 34), col); // arms
    _pixelRect(canvas, Rect.fromLTWH(30 + lean, 22, 16, 34), col);
    // skull-ish head with two soul eyes
    _pixelRect(canvas, Rect.fromLTWH(-14, 0, 28, 18), col);
    _pixelRect(canvas, Rect.fromLTWH(-14, 14, 28, 4), shade);
    _glow(canvas, Offset(-5, 8), 5, eyeC.withOpacity(0.7), 4);
    _glow(canvas, Offset(6, 8), 5, eyeC.withOpacity(0.7), 4);
    _pixelRect(canvas, Rect.fromLTWH(-8, 6, 6, 6), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(3, 6, 6, 6), eyeC);
  }

  // 폭탄 사과나무: 두꺼운 줄기 + 잎 캐노피 + 붉은 폭탄 사과 + 줄기의 얼굴
  void _bossAppleTree(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final t = b.animTime;
    final bark = col;
    final barkD = Color.lerp(col, Colors.black, 0.35)!;
    const leaf = Color(0xFF2E7D32);
    const leafL = Color(0xFF43A047);
    const apple = Color(0xFFE53935);
    // roots
    _pixelRect(canvas, Rect.fromLTWH(-34, h - 8, 24, 8), barkD);
    _pixelRect(canvas, Rect.fromLTWH(10, h - 8, 24, 8), barkD);
    // trunk
    _pixelRect(canvas, Rect.fromLTWH(-18, 26, 36, h - 30), bark);
    _pixelRect(canvas, Rect.fromLTWH(-18, 26, 8, h - 30), barkD); // bark shade
    // canopy
    _pixelRect(canvas, Rect.fromLTWH(-46, -6, 92, 34), leaf);
    _pixelRect(canvas, Rect.fromLTWH(-46, -6, 92, 8), leafL);
    _pixelRect(canvas, Rect.fromLTWH(-34, -16, 68, 12), leaf);
    _pixelRect(canvas, Rect.fromLTWH(-34, -16, 68, 4), leafL);
    // bomb apples (fuse glow blinks)
    final lit = (t * 3).floor() % 2 == 0;
    for (final ax in [-30.0, -2.0, 26.0]) {
      _pixelRect(canvas, Rect.fromLTWH(ax, 6, 10, 10), apple);
      _pixelRect(canvas, Rect.fromLTWH(ax + 2, 6, 3, 3), Colors.white24);
      _pixelRect(canvas, Rect.fromLTWH(ax + 4, 2, 2, 4),
          lit ? const Color(0xFFFFD166) : barkD); // fuse
    }
    // angry face on the trunk
    _glow(canvas, Offset(-6, 40), 4, eyeC.withOpacity(0.6), 4);
    _glow(canvas, Offset(8, 40), 4, eyeC.withOpacity(0.6), 4);
    _pixelRect(canvas, Rect.fromLTWH(-9, 38, 6, 5), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(5, 38, 6, 5), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(-8, 48, 16, 4), Colors.black54); // mouth knot
  }

  // 그레이트웜: 거대한 환절형 몸통 아치 + 이빨 고리 아가리
  void _bossWorm(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final t = b.animTime;
    final segL = Color.lerp(col, Colors.white, 0.16)!;
    // tail segments arcing down into the ground behind
    for (int i = 0; i < 4; i++) {
      final sxp = -44.0 + i * 6.0;
      final syp = h - 16 - i * 10.0 + sin(t * 3 + i * 0.6) * 3;
      final r = 18.0 - i * 1.5;
      _pixelRect(canvas, Rect.fromLTWH(sxp, syp, r, r), col);
      _pixelRect(canvas, Rect.fromLTWH(sxp, syp, r, 3), segL);
    }
    // rearing front body
    _pixelRect(canvas, Rect.fromLTWH(-12, 14, 40, h - 26), col);
    _pixelRect(canvas, Rect.fromLTWH(-12, 14, 12, h - 26), dark);
    for (double yy = 22; yy < h - 18; yy += 10) {
      _pixelRect(canvas, Rect.fromLTWH(-12, yy, 40, 2), dark); // segment rings
    }
    // round toothed maw at the top
    _pixelRect(canvas, Rect.fromLTWH(-16, 2, 48, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(-12, 6, 40, 14), Colors.black);
    for (int i = 0; i < 6; i++) {
      _pixelRect(canvas, Rect.fromLTWH(-12 + i * 7.0, 6, 3, 5), segL); // upper teeth
      _pixelRect(canvas, Rect.fromLTWH(-9 + i * 7.0, 15, 3, 5), segL); // lower teeth
    }
    _glow(canvas, Offset(8, 12), 8, eyeC.withOpacity(0.5), 6); // throat glow
  }

  // 늑대왕: 거대한 사족 늑대, 왕관 + 갈기 + 으르렁대는 아가리
  void _bossWolfKing(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 12.0 : 0.0;
    final furL = Color.lerp(col, Colors.white, 0.2)!;
    const gold = Color(0xFFFFD54F);
    _pixelRect(canvas, Rect.fromLTWH(-34, h - 22, 14, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(20, h - 22, 14, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(-20, h - 18, 12, 18), dark);
    _pixelRect(canvas, Rect.fromLTWH(8, h - 18, 12, 18), dark);
    _pixelRect(canvas, Rect.fromLTWH(-40, 20, 78, h - 36), col); // lean body
    _pixelRect(canvas, Rect.fromLTWH(-40, 20, 78, 8), furL);
    // mane
    _pixelRect(canvas, Rect.fromLTWH(8, 14, 22, 30), dark);
    // head forward + down
    final hx = 18 + lean;
    _pixelRect(canvas, Rect.fromLTWH(hx, 12, 8, 8), dark); // ears
    _pixelRect(canvas, Rect.fromLTWH(hx + 18, 12, 8, 8), dark);
    _pixelRect(canvas, Rect.fromLTWH(hx, 20, 30, 22), col);
    _pixelRect(canvas, Rect.fromLTWH(hx, 20, 30, 5), furL);
    _pixelRect(canvas, Rect.fromLTWH(hx + 22, 30, 16, 10), furL); // snout
    _pixelRect(canvas, Rect.fromLTWH(hx + 22, 38, 16, 3), Colors.black); // snarl
    for (int i = 0; i < 4; i++) {
      _pixelRect(canvas, Rect.fromLTWH(hx + 23 + i * 4.0, 35, 2, 4), Colors.white);
    }
    _glow(canvas, Offset(hx + 12, 26), 5, eyeC.withOpacity(0.65), 4);
    _glow(canvas, Offset(hx + 22, 26), 5, eyeC.withOpacity(0.65), 4);
    _pixelRect(canvas, Rect.fromLTWH(hx + 9, 24, 6, 5), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(hx + 19, 24, 6, 5), eyeC);
    // crown
    _pixelRect(canvas, Rect.fromLTWH(hx + 4, 6, 22, 6), gold);
    _pixelRect(canvas, Rect.fromLTWH(hx + 5, 2, 3, 5), gold);
    _pixelRect(canvas, Rect.fromLTWH(hx + 13, 1, 3, 6), gold);
    _pixelRect(canvas, Rect.fromLTWH(hx + 21, 2, 3, 5), gold);
  }

  void _bossHumanoid(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    _pixelRect(canvas, Rect.fromLTWH(-28, b.h - 26, 16, 26), dark);
    _pixelRect(canvas, Rect.fromLTWH(12, b.h - 26, 16, 26), dark);
    _pixelRect(canvas, Rect.fromLTWH(-40, 16, 80, b.h - 32), col);
    _pixelRect(canvas, Rect.fromLTWH(-26, 26, 52, 30), Color.lerp(col, Colors.white, 0.18)!);
    final armLean = b.state == BossState.active ? 10.0 : 0.0;
    _pixelRect(canvas, Rect.fromLTWH(-52 + armLean, 22, 16, 40), dark);
    _pixelRect(canvas, Rect.fromLTWH(36 + armLean, 22, 16, 40), dark);
    _pixelRect(canvas, Rect.fromLTWH(-28, 6, 12, 12), Color.lerp(col, Colors.white, 0.3)!);
    _pixelRect(canvas, Rect.fromLTWH(16, 6, 12, 12), Color.lerp(col, Colors.white, 0.3)!);
    _pixelRect(canvas, Rect.fromLTWH(-16, 30, 12, 10), Colors.black);
    _pixelRect(canvas, Rect.fromLTWH(12, 30, 12, 10), Colors.black);
    _pixelRect(canvas, Rect.fromLTWH(-14, 34, 6, 6), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(16, 34, 6, 6), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(-16, 50, 32, 8), Colors.black.withOpacity(0.6));
  }

  // 데스 나이트: 판금 갑옷 + 투구(슬릿) + 검 + 방패
  void _bossKnight(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 8.0 : 0.0;
    final steel = Color.lerp(col, const Color(0xFFB0BEC5), 0.45)!;
    // greaves
    _pixelRect(canvas, Rect.fromLTWH(-24, h - 24, 18, 24), dark);
    _pixelRect(canvas, Rect.fromLTWH(8, h - 24, 18, 24), dark);
    _pixelRect(canvas, Rect.fromLTWH(-24, h - 8, 22, 8), Colors.black54);
    _pixelRect(canvas, Rect.fromLTWH(6, h - 8, 22, 8), Colors.black54);
    // shield (back arm)
    _pixelRect(canvas, Rect.fromLTWH(-50, 26, 18, 40), dark);
    _pixelRect(canvas, Rect.fromLTWH(-46, 30, 10, 32), steel);
    _pixelRect(canvas, Rect.fromLTWH(-43, 40, 4, 12), eyeC);
    // torso plate
    _pixelRect(canvas, Rect.fromLTWH(-30, 22, 60, h - 44), col);
    _pixelRect(canvas, Rect.fromLTWH(-22, 28, 44, 22), steel);
    _pixelRect(canvas, Rect.fromLTWH(-4, 24, 8, h - 46), Colors.black26); // center ridge
    // pauldrons
    _pixelRect(canvas, Rect.fromLTWH(-40, 16, 18, 14), Color.lerp(col, Colors.white, 0.2)!);
    _pixelRect(canvas, Rect.fromLTWH(22, 16, 18, 14), Color.lerp(col, Colors.white, 0.2)!);
    // helmet
    _pixelRect(canvas, Rect.fromLTWH(-16, -2, 32, 24), dark);
    _pixelRect(canvas, Rect.fromLTWH(-16, -2, 32, 6), steel);
    _pixelRect(canvas, Rect.fromLTWH(-12, 8, 24, 5), Colors.black); // slit
    _pixelRect(canvas, Rect.fromLTWH(-9, 9, 6, 3), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(3, 9, 6, 3), eyeC);
    // plume / horns
    _pixelRect(canvas, Rect.fromLTWH(-3, -12, 6, 12), eyeC.withOpacity(0.85));
    // sword (front arm)
    _pixelRect(canvas, Rect.fromLTWH(30 + lean, 18, 12, 14), steel);
    _pixelRect(canvas, Rect.fromLTWH(40 + lean, -18, 7, 50), steel);
    _pixelRect(canvas, Rect.fromLTWH(34 + lean, 30, 20, 5), dark); // guard
    _pixelRect(canvas, Rect.fromLTWH(40 + lean, -18, 3, 50), Colors.white70);
  }

  // 용병단장: 가죽 갑옷 + 두건/망토 + 도끼
  void _bossMercenary(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 9.0 : 0.0;
    const leather = Color(0xFF6D4C41);
    const leatherDk = Color(0xFF4E342E);
    final cloak = Color.lerp(col, leatherDk, 0.5)!;
    // cape behind
    _pixelRect(canvas, Rect.fromLTWH(-34, 12, 20, h - 18), cloak);
    _pixelRect(canvas, Rect.fromLTWH(-34, h - 12, 22, 8), leatherDk);
    // boots
    _pixelRect(canvas, Rect.fromLTWH(-22, h - 22, 16, 22), leatherDk);
    _pixelRect(canvas, Rect.fromLTWH(8, h - 22, 16, 22), leatherDk);
    // torso leather
    _pixelRect(canvas, Rect.fromLTWH(-28, 22, 56, h - 42), leather);
    _pixelRect(canvas, Rect.fromLTWH(-28, 22, 56, 8), Color.lerp(leather, Colors.white, 0.15)!);
    // belt + straps
    _pixelRect(canvas, Rect.fromLTWH(-28, h - 30, 56, 6), leatherDk);
    _pixelRect(canvas, Rect.fromLTWH(-10, 24, 6, h - 46), leatherDk);
    // shoulder guard (col accent)
    _pixelRect(canvas, Rect.fromLTWH(-34, 18, 18, 12), col);
    // hood
    _pixelRect(canvas, Rect.fromLTWH(-16, 0, 32, 24), leatherDk);
    _pixelRect(canvas, Rect.fromLTWH(-12, 8, 24, 14), const Color(0xFF2B1B14)); // face shadow
    _pixelRect(canvas, Rect.fromLTWH(-8, 12, 5, 4), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(3, 12, 5, 4), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(-16, 0, 32, 5), col); // hood trim
    // axe (front)
    _pixelRect(canvas, Rect.fromLTWH(24 + lean, 16, 6, 40), const Color(0xFF5D4037));
    _pixelRect(canvas, Rect.fromLTWH(28 + lean, 10, 18, 20), const Color(0xFFB0BEC5));
    _pixelRect(canvas, Rect.fromLTWH(28 + lean, 10, 18, 4), Colors.white70);
  }

  // 도적 대장: 복면 + 쌍단검, 날렵한 체형
  void _bossBandit(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 12.0 : 0.0;
    final cloth = Color.lerp(col, Colors.black, 0.25)!;
    // legs (lean stance)
    _pixelRect(canvas, Rect.fromLTWH(-20, h - 22, 14, 22), dark);
    _pixelRect(canvas, Rect.fromLTWH(8, h - 22, 14, 22), dark);
    // slim torso
    _pixelRect(canvas, Rect.fromLTWH(-22, 20, 44, h - 42), cloth);
    _pixelRect(canvas, Rect.fromLTWH(-22, 20, 44, 7), col);
    _pixelRect(canvas, Rect.fromLTWH(-22, h - 30, 44, 5), Colors.black45); // sash
    // scarf tails (animated)
    final sway = sin(b.animTime * 4) * 4;
    _pixelRect(canvas, Rect.fromLTWH(-26 - sway, 26, 8, 20), col);
    // head + bandana mask
    _pixelRect(canvas, Rect.fromLTWH(-14, 0, 28, 22), const Color(0xFFE0C9A6)); // skin
    _pixelRect(canvas, Rect.fromLTWH(-14, 10, 28, 12), cloth); // mask
    _pixelRect(canvas, Rect.fromLTWH(-14, 0, 28, 6), col); // headband
    _pixelRect(canvas, Rect.fromLTWH(-9, 6, 5, 4), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(4, 6, 5, 4), eyeC);
    // twin daggers
    _pixelRect(canvas, Rect.fromLTWH(20 + lean, 22, 18, 4), const Color(0xFFE0F7FA));
    _pixelRect(canvas, Rect.fromLTWH(16 + lean, 34, 16, 4), const Color(0xFFE0F7FA));
    _pixelRect(canvas, Rect.fromLTWH(18 + lean, 22, 4, 4), dark);
  }

  // 숲의 마녀: 뾰족 모자 + 로브 치마 + 지팡이 오브
  void _bossWitch(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final robe = col;
    final robeDk = Color.lerp(col, Colors.black, 0.4)!;
    // robe skirt (stepped triangle, widening down)
    for (int i = 0; i < 6; i++) {
      final wHalf = 12.0 + i * 5.0;
      final y = 26 + i * ((h - 30) / 6);
      _pixelRect(canvas, Rect.fromLTWH(-wHalf, y, wHalf * 2, (h - 26) / 6 + 1), robe);
    }
    _pixelRect(canvas, Rect.fromLTWH(-42, h - 8, 84, 8), robeDk); // hem
    // bodice
    _pixelRect(canvas, Rect.fromLTWH(-14, 14, 28, 16), robeDk);
    // arms
    _pixelRect(canvas, Rect.fromLTWH(-22, 18, 8, 22), robe);
    _pixelRect(canvas, Rect.fromLTWH(14, 18, 8, 18), robe);
    // face (pale green)
    _pixelRect(canvas, Rect.fromLTWH(-11, 0, 22, 16), const Color(0xFFC5E1A5));
    _pixelRect(canvas, Rect.fromLTWH(-7, 5, 4, 4), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(3, 5, 4, 4), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(-2, 10, 4, 3), const Color(0xFF689F38)); // nose
    // pointed hat (stepped, leaning)
    final tilt = sin(b.animTime * 2) * 2;
    _pixelRect(canvas, Rect.fromLTWH(-18, -2, 36, 6), robeDk); // brim
    _pixelRect(canvas, Rect.fromLTWH(-12, -10, 24, 8), robeDk);
    _pixelRect(canvas, Rect.fromLTWH(-6 + tilt, -18, 14, 8), robeDk);
    _pixelRect(canvas, Rect.fromLTWH(-1 + tilt * 1.6, -26, 8, 8), robeDk);
    _pixelRect(canvas, Rect.fromLTWH(-18, -2, 36, 2), eyeC.withOpacity(0.6)); // hat band
    // staff with orb
    _pixelRect(canvas, Rect.fromLTWH(24, 4, 4, h - 12), const Color(0xFF5D4037));
    _pixelRect(canvas, Rect.fromLTWH(20, -2, 12, 12), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(23, 1, 6, 6), Colors.white);
  }

  // 마왕: 검은 판금 + 큰 뿔 + 붉은 눈 + 망토
  void _bossDemonKing(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 8.0 : 0.0;
    const black = Color(0xFF1A1320);
    final plate = Color.lerp(col, black, 0.45)!;
    final red = const Color(0xFFFF1744);
    // cape (wide, behind)
    final sway = sin(b.animTime * 2.2) * 5;
    _pixelRect(canvas, Rect.fromLTWH(-44 - sway * 0.4, 14, 18, h - 14), Color.lerp(col, black, 0.2)!);
    _pixelRect(canvas, Rect.fromLTWH(26 + sway * 0.4, 14, 18, h - 14), Color.lerp(col, black, 0.2)!);
    // greaves
    _pixelRect(canvas, Rect.fromLTWH(-28, h - 26, 20, 26), black);
    _pixelRect(canvas, Rect.fromLTWH(8, h - 26, 20, 26), black);
    // imposing torso
    _pixelRect(canvas, Rect.fromLTWH(-34, 18, 68, h - 40), plate);
    _pixelRect(canvas, Rect.fromLTWH(-24, 24, 48, 24), Color.lerp(plate, red, 0.18)!);
    _pixelRect(canvas, Rect.fromLTWH(-4, 20, 8, h - 42), red.withOpacity(0.4)); // core line
    // spiked pauldrons
    _pixelRect(canvas, Rect.fromLTWH(-46, 12, 20, 16), black);
    _pixelRect(canvas, Rect.fromLTWH(26, 12, 20, 16), black);
    _pixelRect(canvas, Rect.fromLTWH(-44, 6, 6, 8), black);
    _pixelRect(canvas, Rect.fromLTWH(38, 6, 6, 8), black);
    // helm
    _pixelRect(canvas, Rect.fromLTWH(-15, -2, 30, 22), black);
    _pixelRect(canvas, Rect.fromLTWH(-10, 8, 8, 6), red);
    _pixelRect(canvas, Rect.fromLTWH(2, 8, 8, 6), red);
    // big horns
    _pixelRect(canvas, Rect.fromLTWH(-20, -10, 8, 12), const Color(0xFFE8E0D0));
    _pixelRect(canvas, Rect.fromLTWH(-24, -20, 8, 12), const Color(0xFFE8E0D0));
    _pixelRect(canvas, Rect.fromLTWH(12, -10, 8, 12), const Color(0xFFE8E0D0));
    _pixelRect(canvas, Rect.fromLTWH(16, -20, 8, 12), const Color(0xFFE8E0D0));
    // sword arm
    _pixelRect(canvas, Rect.fromLTWH(30 + lean, 16, 12, 16), plate);
    _pixelRect(canvas, Rect.fromLTWH(40 + lean, -22, 8, 56), Color.lerp(red, Colors.black, 0.2)!);
    _pixelRect(canvas, Rect.fromLTWH(40 + lean, -22, 4, 56), red);
  }

  // 고블린 족장: 작고 다부진 + 큰 귀 + 몽둥이 + 방패
  void _bossGoblin(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final lean = b.state == BossState.active ? 7.0 : 0.0;
    final skin = col;
    final skinDk = Color.lerp(col, Colors.black, 0.35)!;
    // squat: push everything down, big body
    final top = h * 0.34;
    // feet
    _pixelRect(canvas, Rect.fromLTWH(-22, h - 16, 16, 16), skinDk);
    _pixelRect(canvas, Rect.fromLTWH(8, h - 16, 16, 16), skinDk);
    // shield (back)
    _pixelRect(canvas, Rect.fromLTWH(-44, top + 6, 16, h - top - 18), const Color(0xFF6D4C41));
    _pixelRect(canvas, Rect.fromLTWH(-40, top + 12, 8, h - top - 28), const Color(0xFF8D6E63));
    // stout torso
    _pixelRect(canvas, Rect.fromLTWH(-28, top, 56, h - top - 14), skin);
    _pixelRect(canvas, Rect.fromLTWH(-20, top + 6, 40, 14), Color.lerp(skin, Colors.white, 0.15)!);
    _pixelRect(canvas, Rect.fromLTWH(-28, top, 56, 5), skinDk);
    // armor scrap on chest
    _pixelRect(canvas, Rect.fromLTWH(-12, top + 4, 24, 10), const Color(0xFF78909C));
    // head
    _pixelRect(canvas, Rect.fromLTWH(-16, top - 22, 32, 24), skin);
    // big ears
    _pixelRect(canvas, Rect.fromLTWH(-28, top - 18, 12, 8), skinDk);
    _pixelRect(canvas, Rect.fromLTWH(16, top - 18, 12, 8), skinDk);
    // angry brow + eyes + tusks
    _pixelRect(canvas, Rect.fromLTWH(-12, top - 14, 24, 3), skinDk);
    _pixelRect(canvas, Rect.fromLTWH(-9, top - 11, 6, 5), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(3, top - 11, 6, 5), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(-8, top - 2, 4, 5), Colors.white); // tusk
    _pixelRect(canvas, Rect.fromLTWH(4, top - 2, 4, 5), Colors.white);
    // club (front)
    _pixelRect(canvas, Rect.fromLTWH(24 + lean, top + 4, 6, 30), const Color(0xFF5D4037));
    _pixelRect(canvas, Rect.fromLTWH(20 + lean, top - 8, 18, 18), const Color(0xFF6D4C41));
    _pixelRect(canvas, Rect.fromLTWH(34 + lean, top - 6, 5, 5), skinDk); // spike
  }

  void _bossBeast(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    _pixelRect(canvas, Rect.fromLTWH(-38, h - 20, 9, 20), dark);
    _pixelRect(canvas, Rect.fromLTWH(-16, h - 20, 9, 20), dark);
    _pixelRect(canvas, Rect.fromLTWH(14, h - 20, 9, 20), dark);
    _pixelRect(canvas, Rect.fromLTWH(34, h - 20, 9, 20), dark);
    _pixelRect(canvas, Rect.fromLTWH(-46, 24, 78, h - 40), col);
    final ridge = Color.lerp(col, Colors.black, 0.35)!;
    for (int i = 0; i < 5; i++) {
      final bx = -34 + i * 14.0;
      _pixelRect(canvas, Rect.fromLTWH(bx, 16, 10, 12), ridge);
    }
    _pixelRect(canvas, Rect.fromLTWH(40, 36, 24, 20), Color.lerp(col, dark, 0.2)!);
    _pixelRect(canvas, Rect.fromLTWH(54, 36, 16, 16), dark);
    _pixelRect(canvas, Rect.fromLTWH(64, 40, 4, 4), Colors.black);
    _pixelRect(canvas, Rect.fromLTWH(64, 46, 4, 4), Colors.black);
    _pixelRect(canvas, Rect.fromLTWH(50, 40, 6, 10), const Color(0xFFE0E0E0));
    _pixelRect(canvas, Rect.fromLTWH(62, 42, 6, 10), const Color(0xFFE0E0E0));
    _pixelRect(canvas, Rect.fromLTWH(34, 28, 6, 6), eyeC);
  }

  void _bossGolem(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    _pixelRect(canvas, Rect.fromLTWH(-34, h - 30, 26, 30), dark);
    _pixelRect(canvas, Rect.fromLTWH(10, h - 30, 26, 30), dark);
    _pixelRect(canvas, Rect.fromLTWH(-46, 18, 92, h - 38), col);
    _pixelRect(canvas, Rect.fromLTWH(-66, 24, 22, 44), dark);
    _pixelRect(canvas, Rect.fromLTWH(44, 24, 22, 44), dark);
    final crack = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(const Offset(-20, 22), Offset(-8, h - 30), crack);
    canvas.drawLine(const Offset(18, 30), const Offset(8, 70), crack);
    _pixelRect(canvas, Rect.fromLTWH(-16, 2, 32, 22), Color.lerp(col, Colors.white, 0.12)!);
    _pixelRect(canvas, Rect.fromLTWH(-16, 10, 8, 8), eyeC);
    _pixelRect(canvas, Rect.fromLTWH(8, 10, 8, 8), eyeC);
    canvas.drawCircle(
        Offset(0, 40),
        7,
        Paint()
          ..color = eyeC.withOpacity(0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }

  void _bossBird(Canvas canvas, Boss b, Color col, Color dark, Color eyeC) {
    final h = b.h;
    final flap = sin(b.animTime * (b.airborne ? 14 : 6)) * 6;
    final wingCol = Color.lerp(col, Colors.black, 0.25)!;
    _pixelRect(canvas, Rect.fromLTWH(-46, 30 - flap, 22, 14), wingCol);
    _pixelRect(canvas, Rect.fromLTWH(24, 30 - flap, 22, 14), wingCol);
    _pixelRect(canvas, Rect.fromLTWH(-22, 24, 44, h - 40), col);
    _pixelRect(canvas, Rect.fromLTWH(-10, h - 12, 4, 16), const Color(0xFFFFC107));
    _pixelRect(canvas, Rect.fromLTWH(10, h - 12, 4, 16), const Color(0xFFFFC107));
    _pixelRect(canvas, Rect.fromLTWH(14, 2, 16, 16), Color.lerp(col, dark, 0.15)!);
    _pixelRect(canvas, Rect.fromLTWH(26, 12, 18, 8), const Color(0xFFFFB300));
    _pixelRect(canvas, Rect.fromLTWH(18, 12, 4, 4), eyeC);
  }

  // ----------------------------------------------------------------
  (String, Color) _roomMeta(RoomType t) {
    switch (t) {
      case RoomType.combat:
        return ('전투', const Color(0xFFFF8A65));
      case RoomType.shop:
        return ('상점', const Color(0xFFFFD166));
      case RoomType.boss:
        return ('보스', const Color(0xFFE63946));
      case RoomType.start:
        return ('시작', const Color(0xFF80DEEA));
    }
  }

  Color _itemColor(String kind) {
    switch (kind) {
      case 'heal':
        return const Color(0xFF06D6A0);
      case 'maxhp':
        return const Color(0xFFEF476F);
      case 'atk':
        return const Color(0xFFFFD166);
      case 'shieldbuff':
        return const Color(0xFF4FC3F7);
      case 'regenbuff':
        return const Color(0xFF66BB6A);
      case 'hastebuff':
        return const Color(0xFFFFD54F);
      case 'atkupbuff':
        return const Color(0xFFEF5350);
      case 'lifesteal':
        return const Color(0xFFAB47BC);
    }
    return Colors.white;
  }

  Color _skullColor(SkullType t) => skull(t).eye;

  void _text(Canvas canvas, String s, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
