import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'game/types.dart';
import 'game/skulls.dart';
import 'game/meta.dart';
import 'game/world.dart';
import 'game/painter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final meta = MetaState();
  await meta.load();
  runApp(SkulLikeApp(meta: meta));
}

class SkulLikeApp extends StatelessWidget {
  final MetaState meta;
  const SkulLikeApp({super.key, required this.meta});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skull Roguelite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'monospace', useMaterial3: true),
      home: RootScreen(meta: meta),
    );
  }
}

// ============================================================
// ROOT: Town scene <-> Run scene
// ============================================================
class RootScreen extends StatefulWidget {
  final MetaState meta;
  const RootScreen({super.key, required this.meta});
  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  bool inRun = false;
  int runKey = 0;

  @override
  Widget build(BuildContext context) {
    return PlayScene(
      key: ValueKey(inRun ? 'run$runKey' : 'town'),
      meta: widget.meta,
      town: !inRun,
      onStartRun: () => setState(() {
        inRun = true;
        runKey++;
      }),
      onRunEnd: (souls) {
        widget.meta.souls += (souls * widget.meta.soulGainMul).round();
        widget.meta.save();
        setState(() => inRun = false);
      },
    );
  }
}

// ============================================================
// PLAY SCENE  (hosts a GameWorld in town or run mode)
// ============================================================
class PlayScene extends StatefulWidget {
  final MetaState meta;
  final bool town;
  final VoidCallback onStartRun;
  final void Function(int souls) onRunEnd;
  const PlayScene({
    super.key,
    required this.meta,
    required this.town,
    required this.onStartRun,
    required this.onRunEnd,
  });
  @override
  State<PlayScene> createState() => _PlaySceneState();
}

class _PlaySceneState extends State<PlayScene>
    with SingleTickerProviderStateMixin {
  late final GameWorld world;
  late final Ticker _ticker;
  final FocusNode _focus = FocusNode();
  Duration _last = Duration.zero;

  // collapsible character-stats panel
  bool _statsOpen = false;

  // ---- developer mode ----
  bool _devConsole = false; // command console overlay open
  bool _jobSelect = false; // class/job picker overlay open
  bool _godMode = false; // invulnerable + full HP each tick
  final TextEditingController _cmdCtrl = TextEditingController();
  final FocusNode _cmdFocus = FocusNode();
  final List<String> _devLog = ['개발자 콘솔 — "help" 입력 시 명령어 목록.'];

  bool get _devPaused => _devConsole || _jobSelect;

  @override
  void initState() {
    super.initState();
    world = GameWorld(widget.meta, town: widget.town);
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0 || dt > 0.1) dt = 1 / 60;
    // freeze the game while a developer overlay is open
    if (!_devPaused) {
      world.update(dt);
      if (_godMode && !world.town) {
        world.player.invuln = 1.0;
        world.player.hp = world.player.maxHp;
        world.curHp = world.player.hp;
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _focus.dispose();
    _cmdCtrl.dispose();
    _cmdFocus.dispose();
    super.dispose();
  }

  // ---- developer console ----
  void _toggleConsole() {
    setState(() {
      _devConsole = !_devConsole;
      if (_devConsole) {
        world.moveLeft = world.moveRight = false; // don't leave keys stuck
        world.moveUp = world.moveDown = false;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _cmdFocus.requestFocus());
      } else {
        _jobSelect = false;
        _focus.requestFocus();
      }
    });
  }

  void _escapeDev() {
    if (_jobSelect) {
      setState(() => _jobSelect = false);
    } else if (_devConsole) {
      _toggleConsole();
    }
  }

  void _log(String s) {
    setState(() {
      _devLog.add(s);
      if (_devLog.length > 60) _devLog.removeRange(0, _devLog.length - 60);
    });
  }

  void _runCommand(String raw) {
    final cmd = raw.trim();
    _cmdCtrl.clear();
    if (cmd.isEmpty) {
      _cmdFocus.requestFocus();
      return;
    }
    _log('> $cmd');
    final parts = cmd.split(RegExp(r'\s+'));
    final name = parts[0].toLowerCase();
    int? arg() => parts.length > 1 ? int.tryParse(parts[1]) : null;
    switch (name) {
      case 'help':
      case '도움말':
        _log('job(직업) · heal · gold <수> · souls <수> · god · clear · close');
        break;
      case 'job':
      case 'class':
      case 'jobs':
      case '직업':
        setState(() => _jobSelect = true);
        _log('직업 선택 창을 열었다.');
        break;
      case 'heal':
        world.player.hp = world.player.maxHp;
        world.curHp = world.player.hp;
        _log('체력을 모두 회복했다.');
        break;
      case 'gold':
        final n = arg();
        if (n == null) {
          _log('사용법: gold <수>');
        } else {
          world.gold += n;
          _log('골드 +$n → ${world.gold}');
        }
        break;
      case 'souls':
        final n = arg();
        if (n == null) {
          _log('사용법: souls <수>');
        } else {
          world.meta.souls += n;
          world.meta.save();
          _log('영혼 +$n → ${world.meta.souls}');
        }
        break;
      case 'god':
        setState(() => _godMode = !_godMode);
        _log('갓모드 ${_godMode ? "ON (무적)" : "OFF"}');
        break;
      case 'clear':
        setState(_devLog.clear);
        break;
      case 'close':
      case 'exit':
      case '닫기':
        _toggleConsole();
        return;
      default:
        _log('알 수 없는 명령어: $name   ("help" 참고)');
    }
    _cmdFocus.requestFocus();
  }

  void _pickJob(SkullType t) {
    world.devGiveSkull(t);
    final s = skull(t);
    _log('직업 변경 → ${s.name} (${tierLabel(s.tier)})');
    setState(() {
      _jobSelect = false;
      _devConsole = false;
    });
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    final k = e.logicalKey;
    final down = e is KeyDownEvent;
    final up = e is KeyUpEvent;
    // backtick (`) toggles the developer console at any time
    if (k == LogicalKeyboardKey.backquote) {
      if (down) _toggleConsole();
      return KeyEventResult.handled;
    }
    // Esc backs out of dev overlays (job picker first, then the console)
    if (k == LogicalKeyboardKey.escape && _devPaused) {
      if (down) _escapeDev();
      return KeyEventResult.handled;
    }
    // while a dev overlay is open, swallow game input so the world stays put
    if (_devPaused) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowLeft) {
      world.moveLeft = !up;
    } else if (k == LogicalKeyboardKey.arrowRight) {
      world.moveRight = !up;
    } else if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.space) {
      if (k == LogicalKeyboardKey.arrowUp) world.moveUp = !up; // 비행 상승
      if (down) world.queueJump();
    } else if (k == LogicalKeyboardKey.keyA) {
      if (down) world.queueAttack();
    } else if (k == LogicalKeyboardKey.shiftLeft ||
        k == LogicalKeyboardKey.shiftRight) {
      if (down) world.queueDodge();
    } else if (k == LogicalKeyboardKey.keyS) {
      if (down) world.queueSkill();
    } else if (k == LogicalKeyboardKey.keyQ) {
      if (down) world.queueSwap();
    } else if (k == LogicalKeyboardKey.digit1) {
      if (down) world.queueSlot1();
    } else if (k == LogicalKeyboardKey.digit2) {
      if (down) world.queueSlot2();
    } else if (k == LogicalKeyboardKey.keyE ||
        k == LogicalKeyboardKey.arrowDown) {
      if (k == LogicalKeyboardKey.arrowDown) world.moveDown = !up; // 비행 하강
      if (down) world.queueInteract();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final ended = !world.town &&
        (world.phase == GamePhase.gameover ||
            world.phase == GamePhase.victory);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: kViewW,
                height: kViewH,
                child: Stack(
                  children: [
                    Positioned.fill(
                        child: CustomPaint(painter: GamePainter(world))),
                    _Hud(world: world),
                    _TouchControls(world: world),
                    if (!world.town && world.activeDrop != null)
                      _SkullOfferPanel(world: world),
                    if (world.town && world.uiRequest == TownUI.blacksmith)
                      _BlacksmithOverlay(
                          meta: widget.meta, onClose: world.closeUI),
                    if (world.town && world.uiRequest == TownUI.traits)
                      _TraitOverlay(
                          meta: widget.meta, onClose: world.closeUI),
                    if (world.town && world.uiRequest == TownUI.depart)
                      _DepartOverlay(
                        meta: widget.meta,
                        onClose: world.closeUI,
                        onStart: widget.onStartRun,
                      ),
                    if (ended)
                      _EndOverlay(
                        victory: world.phase == GamePhase.victory,
                        floor: world.floor,
                        kills: world.kills,
                        souls: world.runSouls,
                        onTown: () => widget.onRunEnd(world.runSouls),
                      ),
                    // collapsible character-stats panel (toggle its header)
                    _StatsPanel(
                      world: world,
                      open: _statsOpen,
                      onToggle: () {
                        setState(() => _statsOpen = !_statsOpen);
                        _focus.requestFocus();
                      },
                    ),
                    // developer-mode affordances (always available)
                    _DevButton(open: _devConsole, onTap: _toggleConsole),
                    if (_devConsole)
                      _DevConsole(
                        log: _devLog,
                        controller: _cmdCtrl,
                        focusNode: _cmdFocus,
                        godMode: _godMode,
                        onSubmit: _runCommand,
                        onJobs: () => setState(() => _jobSelect = true),
                        onClose: _toggleConsole,
                      ),
                    if (_jobSelect)
                      _JobSelectOverlay(
                        current: world.player.skull.type,
                        onPick: _pickJob,
                        onClose: () => setState(() => _jobSelect = false),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HUD
// ============================================================
class _Hud extends StatelessWidget {
  final GameWorld world;
  const _Hud({required this.world});

  @override
  Widget build(BuildContext context) {
    if (world.town) return _townHud();
    return _runHud();
  }

  Widget _townHud() {
    return Stack(children: [
      Positioned(
        left: 24,
        top: 20,
        child: Row(children: [
          const Text('망자의 마을', style: _t1),
          const SizedBox(width: 16),
          const Icon(Icons.local_fire_department,
              color: Color(0xFF9DFFF0), size: 24),
          const SizedBox(width: 4),
          Text('${world.meta.souls}',
              style: _ts(22, FontWeight.bold,
                  color: const Color(0xFF9DFFF0))),
        ]),
      ),
      if (world.bannerTimer > 0)
        Positioned(
            left: 0,
            right: 0,
            top: 150,
            child: Center(child: _banner(world.bannerText))),
      Positioned(
        left: 0,
        right: 0,
        bottom: 18,
        child: Center(
          child: Text(
              '←/→ 이동 · 중앙 문 = 모험 시작 · 왼쪽 대장장이 = 강화 · 오른쪽 무덤 = 해골 깨우기 · E 상호작용',
              style: _ts(14, FontWeight.w500, color: Colors.white70)),
        ),
      ),
    ]);
  }

  Widget _runHud() {
    final p = world.player;
    return Stack(children: [
      Positioned(
        left: 24,
        top: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.layers, color: Colors.white70, size: 22),
              const SizedBox(width: 6),
              Text('${world.floor}/${world.totalFloors}층 · ${world.biome.name}',
                  style: _ts(20, FontWeight.bold)),
              const SizedBox(width: 14),
              const Icon(Icons.monetization_on,
                  color: Color(0xFFFFD166), size: 20),
              const SizedBox(width: 4),
              Text('${world.gold}',
                  style:
                      _ts(20, FontWeight.bold, color: const Color(0xFFFFD166))),
            ]),
            const SizedBox(height: 8),
            _bar(280, p.hp / p.maxHp, const Color(0xFF06D6A0),
                'HP  ${p.hp.toInt()}/${p.maxHp.toInt()}'),
            const SizedBox(height: 6),
            _comboPips(p.comboStep),
            const SizedBox(height: 10),
            _skullSlots(),
            const SizedBox(height: 8),
            _abilityRow(),
            const SizedBox(height: 8),
            _passiveRow(),
            const SizedBox(height: 8),
            _statusRow(),
          ],
        ),
      ),
      if (world.boss != null)
        Positioned(
          left: 0,
          right: 0,
          top: 24,
          child: Center(
            child: Column(children: [
              Text(world.boss!.name,
                  style:
                      _ts(24, FontWeight.bold, color: world.boss!.spec.color)),
              const SizedBox(height: 6),
              _bar(560, world.boss!.hp / world.boss!.maxHp,
                  const Color(0xFFE63946), null),
            ]),
          ),
        ),
      Positioned(right: 20, top: 18, child: _miniMap()),
      Positioned(right: 20, top: 78, child: _roomMiniMap()),
      if (world.roomType == RoomType.shop)
        Positioned(
          left: 0,
          right: 0,
          bottom: 150,
          child: Center(child: _pill('아이템 위에서 E 키로 구매', const Color(0xFFFFD166))),
        ),
      if (world.bannerTimer > 0 && world.phase == GamePhase.playing)
        Positioned(
            left: 0,
            right: 0,
            top: 150,
            child: Center(child: _banner(world.bannerText))),
      Positioned(
        right: 24,
        bottom: 18,
        child: Text(
          '←/→ 이동 · ↑/Space 점프 · A 공격 · Shift 회피 · S 스킬 · Q 교체 · E 입장/구매',
          style: _ts(13, FontWeight.w500, color: Colors.white60),
        ),
      ),
    ]);
  }

  Widget _banner(String s) => AnimatedOpacity(
        opacity: world.bannerTimer > 0.4 ? 1 : world.bannerTimer / 0.4,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Text(s, style: _ts(28, FontWeight.bold)),
        ),
      );

  Widget _skullSlots() {
    final slots = world.player.skulls;
    return Row(children: [
      for (int i = 0; i < 2; i++)
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (i < slots.length && i == world.player.active)
                  ? slots[i].eye
                  : Colors.white24,
              width: (i < slots.length && i == world.player.active) ? 2.5 : 1,
            ),
          ),
          child: Row(children: [
            Icon(Icons.face,
                size: 16,
                color: i < slots.length ? slots[i].eye : Colors.white24),
            const SizedBox(width: 5),
            Text(i < slots.length ? slots[i].name : '— 빈 슬롯 —',
                style: _ts(13, FontWeight.w600,
                    color: i < slots.length ? Colors.white : Colors.white38)),
          ]),
        ),
    ]);
  }

  Widget _abilityRow() {
    final pl = world.player;
    final skillReady = pl.skillTimer <= 0;
    final skillRatio =
        skillReady ? 1.0 : 1 - (pl.skillTimer / pl.skull.skillCd);
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: skillReady ? pl.skull.eye : Colors.white24),
        ),
        child: Row(children: [
          Icon(Icons.auto_awesome,
              size: 15, color: skillReady ? pl.skull.eye : Colors.white38),
          const SizedBox(width: 5),
          Text('${pl.skull.skillName} (S)',
              style: _ts(12, FontWeight.w600,
                  color: skillReady ? Colors.white : Colors.white54)),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: skillRatio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.white10,
                color: pl.skull.eye,
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.45),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(children: [
          const Icon(Icons.shield_moon, size: 15, color: Colors.white70),
          const SizedBox(width: 5),
          for (int i = 0; i < pl.dodgeMax; i++)
            Container(
              margin: const EdgeInsets.only(right: 3),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pl.dodgeCharge >= i + 1
                    ? const Color(0xFF64FFDA)
                    : Colors.white12,
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _passiveRow() {
    final pv = passiveOf(world.player.skull.type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD166).withOpacity(0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.bolt, size: 15, color: Color(0xFFFFD166)),
        const SizedBox(width: 5),
        Text('패시브 · ${pv.name}',
            style: _ts(12, FontWeight.bold, color: const Color(0xFFFFD166))),
        const SizedBox(width: 8),
        Text(passiveDesc(pv),
            style: _ts(12, FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  Widget _statusRow() {
    final st = world.player.statuses;
    if (st.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, children: [
      for (final s in st)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _statusColor(s.kind).withOpacity(0.22),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _statusColor(s.kind)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_statusLabel(s.kind),
                style: _ts(12, FontWeight.bold, color: _statusColor(s.kind))),
            const SizedBox(width: 4),
            Text(s.timer.toStringAsFixed(0),
                style: _ts(11, FontWeight.w600, color: Colors.white70)),
          ]),
        ),
    ]);
  }

  static Color _statusColor(StatusKind k) => statusColor(k);

  static String _statusLabel(StatusKind k) {
    switch (k) {
      case StatusKind.poison:
        return '중독';
      case StatusKind.burn:
        return '화상';
      case StatusKind.slow:
        return '둔화';
      case StatusKind.weaken:
        return '약화';
      case StatusKind.regen:
        return '재생';
      case StatusKind.shield:
        return '보호막';
      case StatusKind.haste:
        return '신속';
      case StatusKind.atkUp:
        return '공격력↑';
      case StatusKind.bleed:
        return '출혈';
      case StatusKind.stun:
        return '기절';
      case StatusKind.infect:
        return '전염';
      case StatusKind.bind:
        return '속박';
    }
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: _ts(18, FontWeight.w600, color: c)),
      );

  Widget _bar(double w, double ratio, Color c, String? label) => Container(
        width: w,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: Colors.white24),
        ),
        child: Stack(children: [
          FractionallySizedBox(
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(9))),
          ),
          if (label != null)
            Center(
                child: Text(label,
                    style: _ts(12, FontWeight.bold, color: Colors.white))),
        ]),
      );

  Widget _comboPips(int step) => Row(children: [
        for (int i = 1; i <= 3; i++)
          Container(
            margin: const EdgeInsets.only(right: 6),
            width: 26,
            height: 8,
            decoration: BoxDecoration(
              color: i <= step
                  ? const Color(0xFFFFD166)
                  : Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ]);

  // Spatial minimap of the CURRENT room: ground line + dots for the player
  // (cyan), enemies (red) and boss (big red). Trap monsters that haven't
  // emerged are omitted (and reappear here only while surfaced).
  Widget _roomMiniMap() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: CustomPaint(
        size: const Size(180, 60),
        painter: _MiniMapPainter(world),
      ),
    );
  }

  Widget _miniMap() {
    final g = world.graph;
    final curDepth = world.node.depth;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (int d = 0; d <= g.maxDepth; d++) ...[
          if (d > 0)
            Container(
                width: 14,
                height: 2,
                color: d <= curDepth ? Colors.white54 : Colors.white24),
          _depthChip(g.atDepth(d), d, curDepth),
        ],
      ]),
    );
  }

  Widget _depthChip(List<RoomNode> rooms, int depth, int curDepth) {
    final isCur = depth == curDepth;
    final r = rooms.first;
    IconData icon;
    Color c;
    switch (r.type) {
      case RoomType.start:
        icon = Icons.home;
        c = const Color(0xFF80DEEA);
        break;
      case RoomType.shop:
        icon = Icons.storefront;
        c = const Color(0xFFFFD166);
        break;
      case RoomType.boss:
        icon = Icons.dangerous;
        c = const Color(0xFFE63946);
        break;
      default:
        icon = Icons.sports_kabaddi;
        c = const Color(0xFFFF8A65);
    }
    if (rooms.length > 1 && depth != 0 && depth != world.graph.maxDepth) {
      icon = Icons.alt_route;
      c = const Color(0xFFB0BEC5);
    }
    final done = depth < curDepth;
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isCur ? c.withOpacity(0.85) : Colors.black.withOpacity(0.4),
        shape: BoxShape.circle,
        border: Border.all(
            color: isCur ? Colors.white : (done ? c : Colors.white30),
            width: isCur ? 2.5 : 1.5),
      ),
      child: Icon(icon,
          size: 17, color: isCur ? Colors.black : (done ? c : Colors.white54)),
    );
  }

  static const _t1 = TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      shadows: [Shadow(color: Colors.black, blurRadius: 4)]);
  static TextStyle _ts(double size, FontWeight w, {Color? color}) => TextStyle(
        fontSize: size,
        fontWeight: w,
        color: color ?? Colors.white,
        shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
      );
}

// Spatial radar of the current room: maps world positions into a small box.
class _MiniMapPainter extends CustomPainter {
  final GameWorld world;
  _MiniMapPainter(this.world);

  @override
  void paint(Canvas canvas, Size size) {
    final w = world.roomWidth <= 0 ? 1.0 : world.roomWidth;
    final top = (world.camMinY < 0 ? world.camMinY : 0.0) - 40;
    final bottom = kGroundY + 120;
    final hRange = bottom - top;
    double sx(double x) => ((x / w) * size.width).clamp(0.0, size.width);
    double sy(double y) =>
        (((y - top) / hRange) * size.height).clamp(0.0, size.height);

    // ground line
    canvas.drawLine(Offset(0, sy(kGroundY)), Offset(size.width, sy(kGroundY)),
        Paint()
          ..color = Colors.white24
          ..strokeWidth = 1);

    // one-way platforms: short horizontal bars at their top surface so the
    // vertical layout of the room is readable on the radar
    final plat = Paint()
      ..color = const Color(0xFF9CCC65).withOpacity(0.7)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final pf in world.platforms) {
      final y = sy(pf.top);
      canvas.drawLine(Offset(sx(pf.left), y), Offset(sx(pf.right), y), plat);
    }

    // room exit doors (faint markers showing where to progress)
    final doorP = Paint()..color = const Color(0xFFB0BEC5).withOpacity(0.8);
    for (final d in world.doors) {
      final c = Offset(sx(d.rect.center.dx), sy(d.rect.center.dy));
      canvas.drawRect(
          Rect.fromCenter(center: c, width: 4, height: 6), doorP);
    }

    // next-floor portal (bright green diamond) once it has opened
    final portal = world.exitPortal;
    if (portal != null) {
      final c = Offset(sx(portal.center.dx), sy(portal.center.dy));
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(pi / 4);
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: 6, height: 6),
          Paint()..color = const Color(0xFF69F0AE));
      canvas.restore();
    }

    final foe = Paint()..color = const Color(0xFFFF5252);
    for (final e in world.enemies) {
      if (e.dead) continue;
      // trap monsters stay off the radar until they surface
      if (e.kind == EnemyKind.plant && e.t2 <= 0.06) continue;
      canvas.drawCircle(Offset(sx(e.cx), sy(e.cy)), 2.6, foe);
    }
    final b = world.boss;
    if (b != null && !b.dead) {
      canvas.drawCircle(Offset(sx(b.cx), sy(b.cy)), 4.5,
          Paint()..color = const Color(0xFFE63946));
    }
    final p = world.player;
    canvas.drawCircle(Offset(sx(p.cx), sy(p.cy)), 3.2,
        Paint()..color = const Color(0xFF18FFFF));
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}

// ============================================================
// SKULL OFFER PANEL  (when standing by an opened chest's skull)
// ============================================================
class _SkullOfferPanel extends StatelessWidget {
  final GameWorld world;
  const _SkullOfferPanel({required this.world});
  @override
  Widget build(BuildContext context) {
    final s = skull(world.activeDrop!.type);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 110,
      child: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: s.eye, width: 2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.face, color: s.eye, size: 30),
              const SizedBox(width: 10),
              Text(s.name,
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: s.eye)),
              const SizedBox(width: 10),
              _tierBadge(s.tier),
              const Spacer(),
              Text('공격력 ${(s.atkMul * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 16, color: Color(0xFFFF8A65))),
              const SizedBox(width: 14),
              Text('스킬: ${s.skillName}',
                  style: const TextStyle(
                      fontSize: 16, color: Color(0xFF64FFDA))),
            ]),
            const SizedBox(height: 8),
            Text('${s.category} · ${s.desc}',
                style: const TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 6),
            Builder(builder: (_) {
              final pv = passiveOf(s.type);
              return Row(children: [
                const Icon(Icons.bolt, size: 16, color: Color(0xFFFFD166)),
                const SizedBox(width: 6),
                Text('패시브 · ${pv.name}: ',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD166))),
                Flexible(
                  child: Text(passiveDesc(pv),
                      style:
                          const TextStyle(fontSize: 14, color: Colors.white70)),
                ),
              ]);
            }),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _slotBtn('슬롯 1 장착 (1)',
                    world.player.skulls.isNotEmpty
                        ? '현재: ${world.player.skulls[0].name}'
                        : '비어있음,', s.eye, () => world.queueSlot1()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _slotBtn('슬롯 2 장착 (2)',
                    world.player.skulls.length > 1
                        ? '현재: ${world.player.skulls[1].name}'
                        : '빈 슬롯', s.eye, () => world.queueSlot2()),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _slotBtn(String label, String sub, Color c, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: c.withOpacity(0.2),
        foregroundColor: Colors.white,
        side: BorderSide(color: c),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(sub, style: const TextStyle(fontSize: 11, color: Colors.white60)),
      ]),
    );
  }
}

// ============================================================
// TOWN OVERLAYS
// ============================================================
class _BlacksmithOverlay extends StatefulWidget {
  final MetaState meta;
  final VoidCallback onClose;
  const _BlacksmithOverlay({required this.meta, required this.onClose});
  @override
  State<_BlacksmithOverlay> createState() => _BlacksmithOverlayState();
}

class _BlacksmithOverlayState extends State<_BlacksmithOverlay> {
  MetaState get m => widget.meta;
  void _save() {
    m.save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _modal(
      title: '⚒  대장장이 — 영구 강화',
      souls: m.souls,
      onClose: widget.onClose,
      child: Column(children: [
        _upRow('체력 강화', 'Lv ${m.upMaxHp} · +${m.upMaxHp * 20} HP',
            '${m.hpCost()} 영혼', m.souls >= m.hpCost(), () {
          if (m.buyHp()) _save();
        }),
        _upRow('공격 강화', 'Lv ${m.upAtk} · +${m.upAtk * 10}%',
            '${m.atkCost()} 영혼', m.souls >= m.atkCost(), () {
          if (m.buyAtk()) _save();
        }),
        _upRow(
            '회피 강화',
            m.upDodge >= m.maxDodgeLevel
                ? 'MAX · ${m.dodgeCharges}회'
                : 'Lv ${m.upDodge} · ${m.dodgeCharges}회',
            m.upDodge >= m.maxDodgeLevel ? '-' : '${m.dodgeCost()} 영혼',
            m.upDodge < m.maxDodgeLevel && m.souls >= m.dodgeCost(), () {
          if (m.buyDodge()) _save();
        }),
      ]),
    );
  }

  Widget _upRow(String t, String sub, String cost, bool can, VoidCallback f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFF1E1830),
          borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            Text(sub,
                style: const TextStyle(fontSize: 12, color: Colors.white60)),
          ]),
        ),
        ElevatedButton(
          onPressed: can ? f : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9DFFF0),
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white12,
            disabledForegroundColor: Colors.white38,
          ),
          child: Text(cost, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _TraitOverlay extends StatefulWidget {
  final MetaState meta;
  final VoidCallback onClose;
  const _TraitOverlay({required this.meta, required this.onClose});
  @override
  State<_TraitOverlay> createState() => _TraitOverlayState();
}

class _TraitOverlayState extends State<_TraitOverlay> {
  MetaState get m => widget.meta;
  void _buy(String k) {
    if (m.buyTrait(k)) {
      m.save();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _modal(
      title: '✦  영혼의 비석 — 특성 (영구)',
      souls: m.souls,
      onClose: widget.onClose,
      child: Column(children: [
        _node('attack', '공격 특화', const Color(0xFFFF8A65),
            '모든 공격력 +6%/레벨, 근접 계열(검사·짐승형·권사·창병) +4% 추가'),
        _node('defense', '방어 특화', const Color(0xFF64B5F6),
            '받는 피해 -5%/레벨 (기사 추가), 최대 체력 +15/레벨'),
        _node('utility', '범용 특화', const Color(0xFF81C784),
            '영혼 획득 +12%/레벨, 이동 속도 +3%/레벨'),
        _node('pull', '무덤 발굴', const Color(0xFFB388FF),
            '무덤 뽑기 횟수 +1/레벨 · (선행: 범용 특화 2)'),
        _node('luck', '행운', const Color(0xFFFFD166),
            '무덤·상자의 고등급(희귀+) 스컬 확률 ↑ · (선행: 범용 특화 2)'),
      ]),
    );
  }

  Widget _node(String k, String name, Color color, String effect) {
    final lv = m.traitLevel(k);
    final maxLv = m.traitMax(k);
    final maxed = lv >= maxLv;
    final unlocked = m.traitUnlocked(k);
    final cost = m.traitCost(lv);
    final can = unlocked && !maxed && m.souls >= cost;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: unlocked ? const Color(0xFF1E1830) : const Color(0xFF15121E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: lv > 0 ? color.withOpacity(0.7) : Colors.white10,
            width: lv > 0 ? 2 : 1),
      ),
      child: Row(children: [
        Icon(unlocked ? Icons.auto_awesome : Icons.lock,
            color: unlocked ? color : Colors.white30, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(width: 8),
              Text('Lv $lv / $maxLv',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ]),
            Text(effect,
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ]),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: can ? () => _buy(k) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.black,
            disabledBackgroundColor: Colors.white12,
            disabledForegroundColor: Colors.white38,
          ),
          child: Text(
              maxed
                  ? 'MAX'
                  : !unlocked
                      ? '잠김'
                      : '$cost 영혼',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

class _DepartOverlay extends StatefulWidget {
  final MetaState meta;
  final VoidCallback onClose;
  final VoidCallback onStart;
  const _DepartOverlay(
      {required this.meta, required this.onClose, required this.onStart});
  @override
  State<_DepartOverlay> createState() => _DepartOverlayState();
}

class _DepartOverlayState extends State<_DepartOverlay> {
  MetaState get m => widget.meta;
  @override
  Widget build(BuildContext context) {
    final prepared = m.preparedSkull;
    return _modal(
      title: '🚪  모험 시작',
      souls: m.souls,
      onClose: widget.onClose,
      child: Column(children: [
        if (prepared != null)
          _startSkullCard(prepared, true)
        else
          _startSkullCard(SkullType.basic, false),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onStart,
            icon: const Icon(Icons.play_arrow),
            label: Text('${skull(m.startSkull).name}(으)로 출발',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64FFDA),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _startSkullCard(SkullType t, bool fromGrave) {
    final s = skull(t);
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: s.eye.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.eye, width: 2),
      ),
      child: Row(children: [
        Icon(Icons.face, color: s.eye, size: 26),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(s.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(width: 8),
                  _tierBadge(s.tier),
                ]),
                Text(
                    '${s.category} · 스킬: ${s.skillName} · 공격 ${(s.atkMul * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white60)),
                Text(
                    fromGrave
                        ? '무덤에서 깨운 1회성 해골 · 이번 런에만 사용'
                        : '무덤에서 해골을 깨우면 그 해골로 시작합니다',
                    style: TextStyle(
                        fontSize: 11,
                        color: fromGrave
                            ? const Color(0xFFB388FF)
                            : Colors.white38)),
              ]),
        ),
      ]),
    );
  }
}

Widget _tierBadge(SkullTier tier) {
  final c = tierColor(tier);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.18),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: c),
    ),
    child: Text(tierLabel(tier),
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: c)),
  );
}

Widget _modal({
  required String title,
  required int souls,
  required VoidCallback onClose,
  required Widget child,
}) {
  return Positioned.fill(
    child: Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF150F22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const Icon(Icons.local_fire_department,
                  color: Color(0xFF9DFFF0), size: 22),
              const SizedBox(width: 4),
              Text('$souls',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9DFFF0))),
              const SizedBox(width: 10),
              IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, color: Colors.white70)),
            ]),
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: child)),
          ]),
        ),
      ),
    ),
  );
}

// ============================================================
// TOUCH CONTROLS
// ============================================================
class _TouchControls extends StatelessWidget {
  final GameWorld world;
  const _TouchControls({required this.world});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(children: [
              _hold(Icons.chevron_left, () => world.moveLeft = true,
                  () => world.moveLeft = false),
              const SizedBox(width: 12),
              _hold(Icons.chevron_right, () => world.moveRight = true,
                  () => world.moveRight = false),
            ]),
            Wrap(spacing: 12, children: [
              _tap(Icons.bolt, world.queueInteract, const Color(0xFF26A69A)),
              if (!world.town) ...[
                _tap(Icons.swap_horiz, world.queueSwap,
                    const Color(0xFF7E57C2)),
                _tap(Icons.auto_awesome, world.queueSkill,
                    const Color(0xFFAB47BC)),
                _tap(Icons.shield_moon, world.queueDodge,
                    const Color(0xFF42A5F5)),
                _tap(Icons.flash_on, world.queueAttack,
                    const Color(0xFFE63946)),
              ],
              _tap(Icons.arrow_upward, world.queueJump,
                  const Color(0xFF457B9D)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _hold(IconData icon, VoidCallback onDown, VoidCallback onUp) => Listener(
        onPointerDown: (_) => onDown(),
        onPointerUp: (_) => onUp(),
        onPointerCancel: (_) => onUp(),
        child: _circle(icon, Colors.white24),
      );

  Widget _tap(IconData icon, VoidCallback onTap, Color color) => Listener(
        onPointerDown: (_) => onTap(),
        child: _circle(icon, color),
      );

  Widget _circle(IconData icon, Color color) => Opacity(
        opacity: 0.5,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      );
}

// ============================================================
// END OVERLAY
// ============================================================
class _EndOverlay extends StatelessWidget {
  final bool victory;
  final int floor, kills, souls;
  final VoidCallback onTown;
  const _EndOverlay({
    required this.victory,
    required this.floor,
    required this.kills,
    required this.souls,
    required this.onTown,
  });

  @override
  Widget build(BuildContext context) {
    final color = victory ? const Color(0xFF64FFDA) : const Color(0xFFFF5252);
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.74),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(victory ? '승리!' : 'GAME OVER',
                style: TextStyle(
                  fontSize: 70,
                  fontWeight: FontWeight.bold,
                  color: color,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                )),
            const SizedBox(height: 10),
            Text(
                victory
                    ? '모든 층을 정복했다 🏆 · 처치 $kills'
                    : '$floor층에서 쓰러졌다 · 처치 $kills',
                style: const TextStyle(fontSize: 22, color: Colors.white70)),
            const SizedBox(height: 20),
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFF9DFFF0), size: 28),
              const SizedBox(width: 8),
              Text('영혼 +$souls',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF9DFFF0))),
            ]),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onTown,
              icon: const Icon(Icons.home),
              label: const Text('마을로 돌아가기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ============================================================
// CHARACTER STATS PANEL (collapsible)
// ============================================================

/// A small corner panel showing the active skull's effective stats — attack
/// (all upgrades/traits/passives/buffs applied), skill power, defense, move
/// speed, attack speed, max HP. Tap the header to collapse/expand.
class _StatsPanel extends StatelessWidget {
  final GameWorld world;
  final bool open;
  final VoidCallback onToggle;
  const _StatsPanel(
      {required this.world, required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final w = world;
    final sk = w.player.skull;
    final atk = w.atkMul; // skull × items × traits × passives × active buffs
    final defTrait = w.meta.defenseDrFor(sk.category);
    final pv = passiveOf(sk.type);
    final armor = pv.kind == PassiveKind.armor ? pv.value : 0.0;
    final totalDr = 1 - (1 - defTrait) * (1 - armor);
    double sm = sk.speedMul * w.meta.traitSpeedMul;
    if (w.player.hasStatus(StatusKind.haste)) sm *= 1.45;
    if (w.player.hasStatus(StatusKind.slow)) sm *= 0.55;
    final aps = sk.atkDur > 0 ? 1 / sk.atkDur : 0.0;

    return Positioned(
      right: 20,
      top: 150,
      child: Container(
        width: 234,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.58),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sk.eye.withOpacity(0.6)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // header — tap to collapse / expand
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(children: [
                  Icon(Icons.bar_chart, size: 16, color: sk.eye),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('스탯 · ${sk.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                      size: 18, color: Colors.white70),
                ]),
              ),
            ),
            if (open) ...[
              const Divider(height: 1, color: Colors.white24),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                child: Column(children: [
                  _row('공격력', '${(atk * 100).round()}%',
                      const Color(0xFFFF8A65)),
                  _row('스킬 위력', '×${atk.toStringAsFixed(2)}',
                      const Color(0xFF64FFDA)),
                  _row('방어력', '${(totalDr * 100).round()}% 감소',
                      const Color(0xFF64B5F6)),
                  _row('이동 속도', '${(sm * 100).round()}%',
                      const Color(0xFF81C784)),
                  _row('공격 속도', '${aps.toStringAsFixed(1)}회/초',
                      const Color(0xFFFFD166)),
                  _row('최대 체력', w.player.maxHp.toStringAsFixed(0),
                      const Color(0xFF06D6A0)),
                  _row('스킬',
                      '${sk.skillName} · 쿨 ${sk.skillCd.toStringAsFixed(0)}s',
                      Colors.white70),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.white60)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold, color: c)),
          ),
        ]),
      );
}

// ============================================================
// DEVELOPER MODE
// ============================================================

/// Small always-on toggle that opens the developer console (also bound to `).
class _DevButton extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;
  const _DevButton({required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 4,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: open ? 0.95 : 0.45,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1330),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: open
                        ? const Color(0xFF64FFDA)
                        : Colors.white24),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.terminal, size: 15, color: Color(0xFF64FFDA)),
                SizedBox(width: 6),
                Text('DEV  ( ` )',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The developer command console: a scrolling log + a text input. Recognized
/// commands are dispatched by the parent (see [_PlaySceneState._runCommand]).
class _DevConsole extends StatelessWidget {
  final List<String> log;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool godMode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onJobs;
  final VoidCallback onClose;
  const _DevConsole({
    required this.log,
    required this.controller,
    required this.focusNode,
    required this.godMode,
    required this.onSubmit,
    required this.onJobs,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Container(
            width: 720,
            height: 440,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF120D1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF64FFDA), width: 1.5),
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.terminal, color: Color(0xFF64FFDA), size: 22),
                const SizedBox(width: 8),
                const Text('개발자 콘솔',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(width: 12),
                if (godMode)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD166).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFD166)),
                    ),
                    child: const Text('GOD',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFD166))),
                  ),
                const Spacer(),
                IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70)),
              ]),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView(
                    reverse: true,
                    children: [
                      for (final line in log.reversed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(line,
                              style: TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                  color: line.startsWith('> ')
                                      ? const Color(0xFF64FFDA)
                                      : Colors.white70)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    cursorColor: const Color(0xFF64FFDA),
                    textInputAction: TextInputAction.go,
                    onSubmitted: onSubmit,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '명령어 입력 (help)',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: Colors.black.withOpacity(0.4),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Color(0xFF64FFDA)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: onJobs,
                  icon: const Icon(Icons.badge),
                  label: const Text('직업 선택'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF64FFDA),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Developer class picker: every skull grouped by tier. Tapping one equips it
/// instantly via [onPick]. [current] highlights the active class.
class _JobSelectOverlay extends StatelessWidget {
  final SkullType current;
  final ValueChanged<SkullType> onPick;
  final VoidCallback onClose;
  const _JobSelectOverlay({
    required this.current,
    required this.onPick,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const tiers = [
      SkullTier.common,
      SkullTier.rare,
      SkullTier.epic,
      SkullTier.legendary,
    ];
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.78),
        child: Center(
          child: Container(
            width: 1060,
            constraints: const BoxConstraints(maxHeight: 660),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF150F22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Icon(Icons.badge, color: Color(0xFF64FFDA), size: 24),
                const SizedBox(width: 8),
                const Text('직업 선택 — 개발자 모드',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Spacer(),
                Text('현재: ${skull(current).name}',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.white60)),
                const SizedBox(width: 8),
                IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close, color: Colors.white70)),
              ]),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final t in tiers) _tierSection(t),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tierSection(SkullTier tier) {
    final types =
        allSkullTypes.where((t) => skull(t).tier == tier).toList();
    if (types.isEmpty) return const SizedBox.shrink();
    final c = tierColor(tier);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Row(children: [
            Container(width: 4, height: 16, color: c),
            const SizedBox(width: 8),
            Text(tierLabel(tier),
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: c)),
            const SizedBox(width: 8),
            Text('${types.length}종',
                style: const TextStyle(fontSize: 12, color: Colors.white38)),
          ]),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final t in types) _card(t)],
        ),
      ]),
    );
  }

  Widget _card(SkullType t) {
    final s = skull(t);
    final selected = t == current;
    return GestureDetector(
      onTap: () => onPick(t),
      child: Container(
        width: 196,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? s.eye.withOpacity(0.22)
              : const Color(0xFF1E1830),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? s.eye : Colors.white12,
              width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(Icons.face, color: s.eye, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('${s.category} · 공격 ${(s.atkMul * 100).round()}%',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.white54)),
                ]),
          ),
        ]),
      ),
    );
  }
}
