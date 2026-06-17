# SkulLike 개발 문서

"Skul: The Hero Slayer" 스타일의 2D 로그라이트. Flutter + 순수 `CustomPainter` 렌더링(게임 엔진/이미지 에셋 없이 도형으로 직접 그림).

---

## 1. 게임 실행 방법

연결된 디바이스: **Windows(데스크톱)**, **Chrome**, **Edge**.

### 방법 A — IDE 버튼 (가장 간단)
- **VS Code**: `lib/main.dart`를 연 상태에서
  1. 우측 하단 상태바의 디바이스 이름(예: `Windows` / `Chrome`)을 클릭해 실행할 디바이스 선택
  2. `F5` 또는 상단 메뉴 **Run ▸ Start Debugging** (또는 좌측 ▶ Run and Debug 패널의 초록 ▶ 버튼)
- **Android Studio / IntelliJ**: 상단 툴바 오른쪽에서
  1. 디바이스 드롭다운(`<디바이스 선택>`)에서 Chrome 또는 Windows 선택
  2. 초록 삼각형 **▶ Run** 버튼 클릭 (단축키 `Shift+F10`)

### 방법 B — 터미널
프로젝트 폴더(`D:\Portfolio\ClaudeProject\html\SkulLike`)에서:
```bash
flutter run -d chrome     # 브라우저로 실행 (권장: 가장 빠름)
flutter run -d windows    # 데스크톱 앱으로 실행
```
실행 중 단축키: `r` 핫 리로드, `R` 핫 리스타트, `q` 종료.

> 빌드 결과물만 만들려면 `flutter build web` / `flutter build windows`.

### 방법 C — 빌드된 웹게임을 클릭으로 실행
Flutter 웹은 `file://`(파일 더블클릭)로는 동작하지 않고 **HTTP 서버**로 띄워야 함.
1. (코드 변경 후) `flutter build web --release` → 결과물은 `build/web/`.
2. 프로젝트 루트의 **`게임실행.bat` 더블클릭** → 로컬 서버(`localhost:8000`)가 뜨고 브라우저가 자동으로 열림. (Python 필요)
   - 수동으로 하려면: `cd build/web` 후 `python -m http.server 8000` → 브라우저에서 `http://localhost:8000`.

### 블로그/웹에 삽입하기
1. `build/web/` 폴더 **전체**를 정적 호스팅에 업로드 (GitHub Pages, Netlify, Vercel, 또는 블로그가 지원하는 정적 파일 호스팅).
2. 하위 경로에 올린다면(예: `https.../games/skullike/`) 그 경로로 다시 빌드:
   ```bash
   flutter build web --release --base-href "/games/skullike/"
   ```
3. 블로그 글에는 iframe으로 삽입:
   ```html
   <iframe src="https://본인호스팅주소/games/skullike/"
           width="960" height="600" style="border:0;max-width:100%"
           allowfullscreen></iframe>
   ```
- 참고: Flutter 웹 번들은 CanvasKit 포함으로 첫 로딩이 수 MB. 블로그 임베드엔 문제없지만 초기 로딩이 조금 있음. 더 가벼운 게 필요하면 순수 HTML5 Canvas/JS로의 재작성이 대안(별도 대규모 작업).

### 조작법
- **←/→** 이동 · **↑ 또는 Space** 점프 · **A** 공격(콤보) · **Shift** 회피
- **S** 스킬 · **Q** 스컬 교체 · **E 또는 ↓** 상호작용(문/상자/상점/NPC)
- 스컬 상자 앞에서 **1 / 2** = 해당 슬롯에 장착
- 모바일/터치: 화면 하단 가상 버튼

---

## 2. 프로젝트 구조

```
lib/
  main.dart            앱 진입점 + 모든 Flutter UI(HUD, 오버레이, 터치 컨트롤, 마을 모달)
  game/
    types.dart         상수, enum, 단순 데이터 클래스(BiomeSpec, BossSpec, RoomData 등)
    entities.dart      Entity / Player / Enemy / Boss (물리 상태·스탯)
    skulls.dart        스컬 정의(SkullSpec), 티어 가중치, rollSkull() 추첨
    meta.dart          영구 저장(영혼, 강화 레벨, 해금 스컬) — shared_preferences
    level_gen.dart     층 그래프 생성 + 방 레이아웃 + 보스 풀
    world.dart         게임 루프/상태머신(업데이트, 전투, 입력, 마을 로직)
    painter.dart       모든 렌더링(배경, 캐릭터, 보스, 무기, 마을 오브젝트)
test/
  widget_test.dart     루트 위젯 빌드 스모크 테스트
docs/
  DEVELOPMENT.md       (이 문서)
```

### 데이터 흐름
`main.dart`의 `_PlaySceneState`가 `Ticker`로 매 프레임 `world.update(dt)` 호출 → `setState`로 다시 그림. `GamePainter`가 `world` 상태를 읽어 캔버스에 렌더. 입력은 `Focus.onKeyEvent` → `world.queueXxx()`로 큐잉되어 다음 업데이트에서 소비.

마을(`town: true`)과 모험(`town: false`)은 **같은 `GameWorld`**가 분기 처리. `RootScreen`이 `inRun` 플래그로 둘을 전환.

---

## 3. 핵심 시스템과 수정 위치

| 하고 싶은 것 | 파일 / 위치 |
|---|---|
| 해골 상자 등장 확률 조정 | `level_gen.dart` `buildRoom` — `rng.nextDouble() < 0.08` |
| 보스 처치 시 상자 드롭 | `world.dart` `update()` — `chest ??= Chest(...)` |
| 티어별 등장 확률 | `skulls.dart` `tierWeight()` (일반100/희귀45/영웅16/전설5) |
| 스컬 능력치/스킬 매핑 | `skulls.dart` `kSkulls` 맵 |
| 스킬 실제 효과 | `world.dart` `_doSkill()` switch |
| 보스 종류/스탯 | `level_gen.dart` `_tier0/_tier1/_tier2` + `pickBoss()` |
| 보스 외형 | `painter.dart` `_bossHumanoid/_bossBeast/_bossGolem/_bossBird` |
| 적(졸개) 종류/행동 | `types.dart` `EnemyKind` + `world.dart` `_updateEnemy()` |
| 마을 NPC/오브젝트 위치 | `world.dart` `_enterTown()` (`blacksmithRect` 등) |
| 마을 상호작용 | `world.dart` `_handleTownInteract()` |
| 강화 비용/효과 | `meta.dart` (`hpCost`, `buyHp` 등) |
| 상점 아이템 | `level_gen.dart` `_shopDefs()` + `world.dart` `_handleShop()` |
| HUD / 오버레이 UI | `main.dart` |
| 조작키 매핑 | `main.dart` `_onKey()` |
| 월드 상수(중력·점프·속도) | `types.dart` 상단 `k...` 상수 |

---

## 4. 콘텐츠 추가 가이드

### 새 스컬 추가
1. `types.dart` → `SkullType` enum에 값 추가 (예: `lancer`).
2. `skulls.dart` → `kSkulls`에 `SkullSpec` 항목 추가. `weapon`/`skill` 문자열, `tier`, `category`, 능력치 지정.
3. **새 스킬이면** `world.dart` `_doSkill()` switch에 `case '스킬명':` 효과 구현.
4. **새 무기면** `painter.dart` `_weapon()` switch에 `case '무기명':` 그리기 추가(없으면 기본 검).
5. 끝. 색은 `SkullSpec.eye`에서 자동 사용되므로 painter의 색 분기 수정 불필요.

> 스컬 색을 enum으로 하드코딩하지 말 것 — `_skullColor`는 `skull(t).eye`를 그대로 반환하도록 단순화돼 있음.

### 새 보스 추가
1. `level_gen.dart`의 적절한 `_tierN`에 `BossSpec(이름, 아키타입, 형태, 색, 체력, 이동속도)` 추가.
   - `archetype`: `charger`(돌진) / `caster`(원거리 탄막) / `jumper`(도약 강타) 중 택1 — 행동 로직 재사용.
   - `shape`: `humanoid` / `beast` / `golem` / `bird` — 외형 선택.
2. **완전히 새로운 행동**이 필요하면 `types.dart` `BossArchetype`에 값 추가 후 `world.dart`의 `_bossStartAttack` / `_bossActive` / `_updateBoss` 세 switch 모두에 케이스 구현.
3. **완전히 새로운 외형**이면 `types.dart` `BossShape` 추가 후 `painter.dart` `_boss()` switch와 새 `_bossXxx()` 헬퍼 작성.

### 새 적(졸개) 추가
1. `types.dart` `EnemyKind` 추가 → 바이옴 풀(`kBiomes`)에 편성.
2. `world.dart` `_makeEnemy()`(크기/체력)와 `_updateEnemy()`(AI), `_contactDmg()` 케이스 추가.
3. `painter.dart` `_enemy()` switch + `_그림함수` 추가.

---

## 5. 현재 구현된 기능 (2026-06-14 기준)

- **마을**: 중앙 문(모험 시작), 좌측 대장장이(영구 강화 NPC), 맵 끝 무덤(영혼 소모 → 랜덤 스컬 해금). `←/→`로 돌아다니며 `E`로 상호작용.
- **스컬 8종 / 5계열**: 검사(기본·광전사), 짐승형(야수), 마법형(마법사), 기사(기사), 특수형(암살자·폭심·망령).
- **스킬 8종**: spin, magicburst, slam, blink, pounce, guard, explode, phase.
- **티어 4단계**(일반/희귀/영웅/전설) — 좋을수록 낮은 확률. 상자·무덤·UI 배지에 반영.
- **해골 획득**: 전투방 8% 확률 상자 + 보스 처치 시 확정 상자 → 상호작용 시 가중 랜덤 추첨(중복 제외) → `1/2`로 원하는 슬롯 장착, 다가가면 정보(티어·스킬·공격력) 표시.
- **보스 9종 / 4외형**: 인간형(고블린·데스나이트·도적대장·용병단장·마녀·마왕), 짐승(멧돼지), 조류(독수리), 골렘.
- **던전**: 층 그래프(분기·상점 1개·보스), 5층 클리어 시 승리.
- **영구 진행**: 영혼으로 체력/공격/회피 강화 + 스컬 해금(shared_preferences 저장).

---

## 6. 참고 사항

- `flutter analyze` **에러 0개**. 남은 경고는 모두 `info` 수준이며 대부분 `withOpacity` deprecated(→ `withValues()` 권장). 기능에 영향 없음. 일괄 정리하려면 `withOpacity(` → `withValues(alpha: )` 치환.
- 이미지/오디오 에셋 없음 — 모든 그래픽은 코드로 그림. 외형 수정 = `painter.dart` 수정.
- 저장 데이터 초기화: 앱의 shared_preferences를 지우거나, 웹은 브라우저 사이트 데이터 삭제.
