# SkulLike 작업 로드맵 / 진행 추적

> **이 문서의 목적**: 사용자가 요청한 대규모 수정사항을 단계별로 쪼개 기록한다.
> 토큰이 중간에 끊겨도, 다음 세션에서 이 문서의 **[현재 상태]** 절만 읽으면 바로 이어서 작업할 수 있다.
> 각 작업을 끝낼 때마다 체크박스(`[ ]`→`[x]`)와 **[현재 상태]** 절을 반드시 갱신할 것.

---

## ⭐ [현재 상태] — 다음에 할 일 (항상 최신화)

- **마지막 갱신**: 2026-06-15 (행운 특성 Phase 24 + 전투 상태효과·신규 몬스터·20스테이지 미완성분 완성)
- **완료**: Phase 1~6 ✅, **0 ✅(픽셀아트)**, **7 ✅(스컬 58종)**, **8 ✅(보스 외형 9종)**, **9 ✅(무덤 1회·1회성)**, **10 ✅(마을 특성 트리)**, **11 ✅(콤보 1차)**, **12 ✅(스킬 시각)**, **13 ✅(등급별 기본공격)** → **2차 요청까지 전부 완료**
- **이번 세션 완료**: **24 ✅(행운 특성)**, **추가 요청(전투 상태효과·넉백/기절/출혈, 신규 몹 6종 goblin·dwarf·darkElf·plant·hammer·shield, 20스테이지+보스 티어 곡선) ✅**, **저격수 스컬 ✅(sniper, railgun)**, **Phase 23 ✅(테라스 지형+오토 스텝업)**, **Phase 19 잔여 ✅(바이옴별 trap/boss 차등 + flame 함정)**, **7차 요청 ✅(상태이상 시각표시, 상자 지형정착, 대형맵 변형+세로 카메라)**.
- **다음 단계**: **8차 요청 — A/B/C/D 완료**. A2/A4/A5/E4, B1/B2/B3, C1(인간형 5종)/C3(식물 뒤레이어)/C4(방패 수정)/C6, **D1/D2/D3(PassiveKind 13종 + 기동 퍽)**, 보스 7종+런당 1회+신규 패턴 4종, 스컬 외형, 소환사. **남음**: C2(추가 대형 적 더), D3 선택 확장(획득량/저항/순간이동), **E1~E3(맵 오브젝트/지형/이동연출 + 무결성)**.
- **전체 남은 순서**: 8차 A→B→C→D→E (전투기반 → 상태이상 wiring → 신규 적/보스 → 직업 패시브 → 맵 연출).
- **완료 추가**: **20 ✅**, **방향 전환 ✅**, **21 ✅**, **16 ✅**, **22 ✅(직업 정체성)**, **17 ✅(보스 멀티패턴+평상시 행동)**, **바이옴 런마다 랜덤 ✅**.
- **메모(5·6차)**: per-class는 "5차 요청 Phase 22", 신규 대형 요청은 "6차 요청 Phase 23~24"(자연 지형/행운 특성)+저격수 스컬. 던지기 투사체 시스템으로 신규 직업 추가 쉬움. 보스 패턴은 `_bossPatterns`(visual별)로 확장.
- **참고(Phase 20/21)**: `Projectile.shape`(ball/arrow/orb/icicle/potion)+painter `_projectile` 분기. `SkullSpec.rangedBasic`(마법형/궁수형)→`_doRangedBasic`. SkillFx kind 추가: `lightning`(x2,y2 2엔드포인트), `fist`(+`_fistShape`). `_slamShockwave`+`Player.slamPending` 착지 트리거. 색/타입 라우팅: pounce 적색, dashstrike 권사=fist, meteor 연금술사=potion.
- **참고(Phase 13)**: `_finisher(p,mul)`(world) + Player `finisherFired`(entities, `_doAttack`서 리셋). `_resolveCombat` 3타 윈도우 1회 호출. 카테고리/무기/티어로 reach·dmg·fxKind 결정 후 `_fx` 연출.
- **참고(Phase 14)**: `_doAttack` 가드 `attackTimer>0.06`→`>0`(스윙 중 무조건 버퍼). 윈도우 0.5/버퍼 0.4, 버퍼 생존 중 step 리셋 보류. **원인=스윙 끝 0.06s 구간 입력이 리셋 유발**.
- **참고(Phase 15)**: `level_gen` 상점 아이템 먼저 배치→`shopXs`/`clearOfShops(150px)`. 상점방 도어 fx 0.84~0.94 우측만+shop 회피. 아이템 중심 `width*0.42`.
- **메모(4차 신규)**: Phase 20(직업별 공격속도+원거리 평타 투사체), 21(스킬 외형 직업 일치: 서리=고드름, 번개, 핏빛 손톱, 대지 착지진동). 원문/설계는 문서 하단 "4차 요청 — Phase 20~21" 절. **Phase 20은 Phase 14 콤보 버퍼와 충돌 주의**.
- **참고(Phase 12)**: `SkillFx{kind,x,y,t,maxT,dir,size,color}`(types). world `skillFx` 리스트 + `_fx()` 스폰 + `_updateParticles`에서 틱/제거 + 방/타운 진입 시 리셋. painter `_skillFx`(kind별: ring/dualring/runes/ghost/crack/claw/slashArc) + `_ghostSilhouette`. 카메라 transform 안에서 월드좌표로 렌더.
- **메모(3차)**: Phase 11 버퍼링으로도 콤보 연타가 여전히 끊김(→Phase 14 재조사). 14·15는 활성 버그라 필요 시 앞당겨도 됨. 3차 요청 원문/설계는 문서 하단 "3차 요청 (사용자 추가) — Phase 14~19" 절 참고.
- **참고(Phase 10)**: 특성은 `meta` `trAttack/trDefense/trUtility/trPull`(SharedPreferences). `maxPulls`는 이제 `1+trPull` getter(Phase 9의 저장 필드 폐지). 효과 적용 지점=world `atkMul`/`_enterTown`·`_startRun` maxHp/`_hurtPlayer`/`_updatePlayer` 이속, main `onRunEnd` 영혼배율. UI=main `_TraitOverlay`, 마을 오브젝트=`traitsRect`+painter `_traitShrine`, 진입=`TownUI.traits`.
- **참고(Phase 11)**: Player `attackBuffer`(entities). `_doAttack` 스윙 중 입력 → `attackBuffer=0.35` 버퍼. `_updatePlayer`에서 스윙 종료 시 버퍼 살아있으면 즉시 `_doAttack()` 재실행(콤보 체인). comboWindow=0.42 유지.
- **참고(Phase 9)**: 영구 해금 폐지. `meta.maxPulls`/`meta.preparedSkull`(SharedPreferences 키 `maxPulls`/`preparedSkull`). `_rollGraveyard`(world)에서 `pullsUsed` 증가+`preparedSkull` 세팅, `_enterTown`에서 `pullsUsed=0`, `_startRun`에서 `takeStartSkull()` 소모. UI는 main `_DepartOverlay._startSkullCard`.
- **참고(Phase 8)**: `BossSpec.visual`(types) + `level_gen` 9보스 지정. painter `_boss`가 `b.spec.visual`로 분기 → `_bossKnight/_bossMercenary/_bossBandit/_bossWitch/_bossDemonKing/_bossGoblin` 신규 + boar→`_bossBeast`/golem→`_bossGolem`/eagle→`_bossBird` 재사용. 좌표계는 translate(b.cx,b.y)+scale(facing*sx,sy), 머리 y≈0 발 y≈b.h.
- **핫픽스 로그(2026-06-14)**: (a) 방 이동 시 버프 사라짐 → `_enterRoom`에서 `player.statuses` carry(`_playerReady`). shopAtk/maxHp/lifesteal은 world 필드라 원래 유지됨. (b) 문 높이 150→120(+exitPortal 130→110), 문 근처 110px 내 부쉬/함정 미배치(`clearOfDoors`).
- **참고(Phase 0)**: 픽셀아트는 `painter.dart` `_pixelRect`/`_pixelPaint` 기반. 무기는 `_drawWeapon(canvas, weapon, eye)`로 분리(스텝 블록). 환경 오브젝트 `RoomProp{kind,rect,color}`(types) → `level_gen` 바이옴별 배치 → painter `_prop` 12종(crate/barrel/torch/skull/mushroom/stone/banner/pillar/root/stalactite/rune/sign). 글로우/블러는 포탈·상자·픽업 오라 등 "마법 효과"에만 잔존.
- **진행 중**: Phase 0 완료 → Phase 7(스컬 50종) 착수 예정.
- **참고(Phase 6)**: 상태효과 `StatusKind`(types) + `Status` + Entity `statuses`/`addStatus`/`hasStatus`. 틱은 `world._updateStatuses`(poison/burn DoT, regen 회복). 속도(slow/haste)는 `_updatePlayer`, 공격(weaken/atkUp)은 `atkMul` getter, 보호막은 `_hurtPlayer`. HUD는 `main.dart _statusRow`. 함정 `Trap`(spike/saw/arrow) → `world.traps`, `_updateTraps`, painter `_trap`. 아이템: `level_gen._shopDefs` 확장(버프물약 4종+흡혈), `_handleShop` 처리, `lifesteal` 런 유물(`_resolveCombat` 근접 흡혈).
- **참고(Phase 5)**: BossArchetype에 boarSmash/iaido/flurry/guardian 추가(types). 보스 패턴은 `world.dart` `_bossStartAttack`/`_bossActive`, 헬퍼 `_bossSmash`(땅부수기+`_launchPlayer` 공중띄움)/`_bossSlash`(전방 베기)/`_damageBoss`(guard 시 0.3배). Boss 필드 subTimer/hits/guard/enraged. 슬라임 분열은 death removeWhere 블록(`splits`). 보스 배정: 멧돼지=boarSmash, 데스나이트=iaido, 용병단장·도적대장=flurry, 고블린족장=guardian.
- **참고(Phase 3)**: perception `_updateEnemyAggro`(시야 dy<90 + `_lineOfSight` + `combatNoise`), 지상몹 `_groundNav`(점프 `vy=-820`, `dropTimer` 드롭스루), 부쉬 `Bush`+`player.hidden`, 공격/스킬 `_emitNoise`.
- **참고(Phase 4)**: Entity `hurtTimer`(damage()에서 0.18 세팅) → painter에서 회전+이동 플린치(player/enemy/boss). Enemy `attackAnim`/`windup` 필드. 공격 시 `attackAnim` 세팅(grunt 돌진/ mage·archer 발사/ slime 점프/ brute 런지). grunt에 근접 돌진 공격 추가.
- **참고**: 코드 변경 후 검증은 `flutter analyze` (에러 0 유지) → 필요시 `flutter build web`.
  관련 기본 문서는 `docs/DEVELOPMENT.md`.

---

## Phase 0 — 픽셀아트 그래픽 + 지형 다양화 (사용자 3차 요청 선행)

**목표**: 전체 그래픽을 `Skul: The Hero Slayer`를 레퍼런스로 한 **화려한 픽셀아트**로 통일. 맵도 플랫폼만이 아닌 테마별 지형(절벽, 대각선 처리, 환경 오브젝트) 추가.

**현 구현 상태**:
- `lib/game/level_gen.dart`에서 바이옴별로 장식 오브젝트 종류를 확장하여 랜덤 배치가 더 다양해짐.
- 새로운 `RoomProp` 유형(`root`, `stalactite`, `rune`)을 추가하여 지형 분위기를 강화함.
- `lib/game/painter.dart`에서 `RoomProp` 렌더러를 확장하여 새 장식 타입을 픽셀 아트 스타일로 표현함.
- `_ground` 렌더링에 픽셀 질감 효과를 추가하여 지면에 더 많은 깊이와 텍스처를 부여함.
- 해당 변경사항은 `flutter analyze` 기준으로 에러가 없는 상태임.

**핵심 설계**:

### (1) 픽셀아트 그래픽 시스템
- **스타일**: `Skul: The Hero Slayer` 레퍼런스를 기준으로, 화려한 스타일라이즈 픽셀아트 분위기를 구현. 8-16px 캐릭터 + 섬세한 애니메이션.
- **기준 해상도**: 게임 렌더링 해상도 960×600 유지, 각 엔티티/오브젝트는 상대적 스케일로 pixelated 폰트/이미지 표현.
- **구현 방식**:
  - `painter.dart`의 모든 `canvas.drawXxx()` 렌더링을 픽셀아트 스타일로 재작성.
  - 기존 원형/사각형 도형 기반 → **타일 기반 텍스처** 또는 **벡터→비트맵 변환**(Canvas 기반 픽셀 드로잉).
  - 간단한 픽셀 도트 그리기 함수 작성: `drawPixelRect(canvas, x, y, w, h, color, pixelSize)` 등.
  - 각 엔티티별 "스프라이트 시트" 개념: 상태별(걷기, 공격, 맞음) 프레임 정의.
- **레이어/톤 방식**:
  - 캐릭터: 기본 톤(body) + 음영(darker) + 밝음(lighter) 3단계 + 눈 색(eye).
  - 무기: 금속색/나무색/마법 색 구분.
  - 배경/지형: 바이옴별 톤(숲=초록, 동굴=회색, 성=석회색).

### (2) 맵 지형 다양화
- **기존 문제**: 플랫폼 배열만 있어서 단조로움.
- **신규 지형 요소**:
  - **대각선 플랫폼** (45도 경사): 점프 도달성 유지하되 시각적 다양성. `DiagonalPlatform { topLeft, bottomRight, color }`.
  - **절벽/낙사 영역**: 한 번 아래로 떨어지면 못 올라오는 "원웨이 플랫폼" 확장. 낙사 지점 명시.
  - **벽 & 처마**: 좌우 벽 판정(플레이어가 벗어날 수 없음), 처마 아래 숨을 수 있는 공간.
  - **환경 오브젝트** (충돌 없음, 시각만): 예)기사단 숙소에 "깃발", "방패 벽", "횃불", "동상", 간판 등.

- **바이옴 테마별 설계**:
  - **기사단 본영** (Tier 0): 석재 건축, 깃발, 사다리, 창고, 훈련장 기구(나무 더미, 과녁).
  - **숲 깊숙이** (Tier 1): 나뭇가지 플랫폼, 버섯, 나무뿌리 벽, 부쉬 다수.
  - **동굴** (Tier 2): 암석 플랫폼, 석순/종유석(매달린 것), 광석 빛남, 좁은 통로.
  - **흑마법탑** (Tier 3): 검은 돌, 마법진 판, 떠다니는 큐브, 검은 안개(배경).
  - 각 바이옴에 고유 색상 팔레트 & 배경(스크롤 또는 정적).

- **지형 생성 로직** (`level_gen.dart` 확장):
  - 현재: `List<Platform>` 만 생성 → 확장: `List<Terrain>` (Terrain = Platform | DiagonalPlatform | Cliff | Obstacle).
  - 바이옴별 배치 확률 지정(예: 기사단 깃발 30%, 나무뿌리 벽 20%, ...).
  - 환경 오브젝트는 painter에서만 렌더, 충돌 판정 없음.

### (3) 애니메이션 시스템 유지
- Phase 4의 `hurtTimer`/`attackAnim` 등은 모두 유지.
- 픽셀아트 애니메이션: 각 상태(idle/walk/attack/hurt)마다 **프레임 수열** 정의.
  - 예: walk = [frame0, frame1, frame2, frame1] (2개 프레임 반복 4프레임 사이클).
  - `animTimer`로 현재 프레임 계산.
- painter의 각 캐릭터 드로우 함수에서 프레임 기반 렌더.

### (4) 색상 & 톤 시스템
- 현재 SkullSpec의 `body`, `eye` Color는 유지.
- 추가 필드 (선택): `SkullSpec.shadow`(음영색), `accent`(악센트색).
- 렌더링 시 이 색을 기반으로 픽셀아트 톤 조정.

**구현 단계(작은 배치)**:
- [x] 1. 기본 픽셀 드로우 헬퍼 함수 작성 (`_pixelPaint`, `_pixelRect`).
- [x] 2. 플레이어 픽셀아트 & 애니메이션 (legSwing/bob walk, hurt flinch, 무기 아크).
- [x] 3. 일반몹 픽셀아트 & 프레임 (grunt/bat/mage/slime/archer/brute 모두 `_pixelRect`).
- [x] 4. 보스 픽셀아트 & 프레임 (humanoid/beast/golem/bird, bird 날갯짓 flap 추가).
- [x] 5. 무기 픽셀아트 (`_drawWeapon`로 분리, 13종 모두 `_pixelRect` 스텝 블록화).
- [x] 6. 지형 & 환경 오브젝트 (`_ground`/`_oneWay`/`_props` 12종 RoomProp).
- [x] 7. 배경 & 바이옴 색상 팔레트 (`_background` 픽셀 언덕/별, biome 팔레트).
- [x] 8. level_gen 확장 (RoomProp 타입 + 바이옴별 prop 배치).
- [x] 9. painter 전면 재작성 (캐릭터/지형/무기/픽업 모두 픽셀아트, 글로우 오라만 유지).
- [x] 10. 테스트 & 미세 조정 (analyze 에러/경고 0, build web 성공).

**완료 기준**: 모든 그래픽이 화려한 픽셀아트 스타일로 통일, 맵에 테마별 환경 오브젝트 다수, 애니메이션 부드러움, `flutter analyze` 에러 0.

---

## 요구사항 원문 요약 (사용자 8개 항목)

1. 점유된 슬롯에 다른 스컬을 장착하면, **기존 스컬은 바닥에 다시 떨어져야** 함(재획득 가능).
2. 방 이동 포탈/문이 전부 오른쪽에 몰려있지 말고 **다양한 위치**(맵 끝, 플랫폼 위)로 분산. 단 시작지점과 너무 가깝지 않게.
3. **직업(스컬) 약 50종 추가**.
4. 플레이어·몬스터·보스 모두 **기본 애니메이션**(이동/공격/피격) 필요.
5. **더 다양한 아이템 / 버프·디버프 / 함정**(플레이어를 공격하는 트랩).
6. **보스·몬스터 패턴 다양화**. 예: 멧돼지=돌진 후 땅 부수기(피격 시 공중에 띄움), 인간형=발도/초고속 연속베기/방어 등. 단 일반 몬스터는 보스 느낌 안 나게 **더 심플**하게.
7. 몬스터 **인지/추적 AI**: 플레이어가 시야에 보이거나 근처 전투 발생 시 추적. **플랫폼 아래에 있는데 뚫고 인지하면 안 됨**. **부쉬**(숨는 오브젝트) 추가. 몬스터도 **점프/플랫폼 상하 이동** 가능해야 함(갇히면 안 됨).
8. (메타) 모든 작업은 **문서부터 작성 후 구현**. 재개 가능하도록 문서화.

---

## Phase 1 — 스컬 교체 시 기존 스컬 드롭  (req #1)

**목표**: 슬롯에 스컬을 장착할 때 그 자리에 있던 스컬이 바닥 픽업으로 떨어져 다시 주울 수 있게.

**설계**:
- 현재 `world.dart`는 단일 `SkullType? skullOffer` + `offerX` + `offerNear` 모델. → **여러 개의 바닥 스컬 픽업**을 담는 리스트로 교체.
- `types.dart`에 `class SkullDrop { SkullType type; double x; bool near; double t; }` 추가.
- `world.dart`: `skullOffer` 단일 필드 → `List<SkullDrop> skullDrops = []`. 가장 가까운 drop을 `activeDrop`으로 계산.
- `_openChest`: 추첨된 스컬을 `skullDrops.add(SkullDrop(...))`.
- `_equipSlot(slot)`: 대상 drop을 제거하고 슬롯에 장착. 슬롯이 이미 차 있었다면 **기존 스컬을 같은 위치에 새 SkullDrop으로 추가**.
- `painter.dart` `_skullOffer` → 리스트 순회하며 각 drop 렌더(가장 가까운 것에 정보/안내 표시).
- `main.dart` `_SkullOfferPanel`: `world.activeDrop`(가장 가까운 drop) 기준으로 표시. 슬롯 버튼의 "현재: ..." 텍스트 유지.
- 마을 무덤(`_rollGraveyard`)은 영구 해금 방식이라 영향 없음.

**완료 기준**: 슬롯1에 A 장착 → 다른 스컬 B를 슬롯1에 장착 시 A가 바닥에 떨어지고 다시 주울 수 있음. analyze 에러 0.

- [x] SkullDrop 데이터 클래스 (`types.dart`)
- [x] world 리스트화 + activeDrop (`skullDrops`, `_handleChest` 근접 계산)
- [x] equip 시 기존 스컬 드롭 (`_equipSlot` displaced→SkullDrop)
- [x] painter/main UI 다중 drop 대응

---

## Phase 2 — 포탈/문 배치 다양화  (req #2)

**목표**: 출구 문/포탈을 맵 곳곳(바닥 끝, 플랫폼 위)에 분산. 시작점 근처 금지.

**설계** (`level_gen.dart` `buildRoom` 도어 생성부):
- 후보 위치 풀 생성: ground 위 x = `width*0.5 ~ width-120` 범위 여러 지점 + 일부 플랫폼의 상단(`platforms` 중 `left > width*0.4`인 것).
- 시작점(x<width*0.35) 제외.
- 문 개수만큼 후보에서 겹치지 않게 추출, 일부는 플랫폼 위(`y = platform.top - 150`)에 배치.
- `Door.rect`의 y를 바닥 고정(`kGroundY-150`)에서 배치 지점 기반으로 변경.
- 도달 가능성: 플랫폼 위 문은 그 플랫폼이 점프로 도달 가능한 것만 사용(생성된 `surfaces` 재활용).

**완료 기준**: 한 방에 문이 2개면 좌우/높낮이가 달라짐. 시작점 옆에 안 생김. 모두 도달 가능.

- [x] 문 후보 위치 풀(바닥+플랫폼) (`level_gen.dart` buildRoom 도어부)
- [x] 시작점 근접 제외 + 분산 배치 (x>width*0.42, 간격 180+)
- [x] 플랫폼 위 문 도달성 검증 (생성된 reachable platforms 재활용)

---

## Phase 3 — 적 인지/추적 AI + 플랫폼 이동 + 부쉬  (req #7)

**목표**: 몬스터가 시야/근접 전투로만 플레이어를 인지해 추적. 수직으로 막힌(플랫폼 너머) 경우 인지 금지. 점프/낙하로 플랫폼 이동. 부쉬에 숨으면 인지 해제.

**설계**:
- `entities.dart` Enemy에 상태 추가: `bool aggro`, `double aggroTimer`, `double loseSightTimer`.
- 감지 로직(`world.dart` `_updateEnemy` 진입부 공통):
  - 거리 < 시야범위(예: 420) **그리고** 수직차 |dy| < 80 **그리고** 둘 사이에 solid 벽이 없을 때(간단 LoS: x샘플링하며 solids 충돌 검사) → aggro on, 타이머 갱신.
  - "근처 전투 발생"(플레이어가 공격했거나 다른 적이 피격) → 반경 내 적 aggro 트리거. world에 `double combatNoise` + 위치 기록, 공격 시 셋업.
  - 플레이어가 부쉬 안 + 비공격 상태면 시야 감지 무효(소음 감지만).
- 수직 분리: 플레이어가 플랫폼 위/아래로 |dy|가 크면 시야 인지 차단(현실적인 층 분리).
- 플랫폼 이동: 지상 적(grunt/brute 등)이 aggro 상태에서
  - 플레이어가 위에 있고 바로 위 도달 가능한 platform 있으면 점프(`vy = -jump`).
  - 플레이어가 아래에 있고 현재 one-way platform 위면 살짝 낙하(드롭스루: 짧게 platform 충돌 무시).
- `types.dart`에 `class Bush { Rect rect; }`. `level_gen` 방에 1~3개 스폰. world에 `List<Bush> bushes`. 플레이어 overlap+비공격 → `player.hidden=true`. painter에서 반투명 수풀 그리고, 숨었을 때 플레이어 반투명.

**완료 기준**: 아래층 몬스터가 위 플레이어를 뚫고 안 쫓아옴. aggro된 지상몹이 플랫폼을 오르내림. 부쉬에 들어가면 시야 몹이 추적 해제.

- [x] Enemy aggro 상태 + 시야/LoS 감지 (`_updateEnemyAggro`, `_lineOfSight`)
- [x] 전투 소음 전파 (`combatNoise`, `_emitNoise` on 공격/스킬)
- [x] 수직 분리(플랫폼 너머 인지 차단) (시야 dy<90 게이트)
- [x] 적 점프/드롭스루 이동 (`_groundNav`, `dropTimer`, `_moveAndCollide` canOneWay)
- [x] Bush 오브젝트 + 은신 (`Bush`, `bushes`, `player.hidden`, painter `_bush`)

---

## Phase 4 — 애니메이션 시스템 (이동/공격/피격)  (req #4)

**목표**: 플레이어·일반몹·보스 모두 이동/공격/피격 애니메이션.

**설계**:
- `entities.dart`: 공통 `double hurtTimer`(피격 플린치), 이미 있는 `hitFlash` 활용. Enemy/Boss에 `double attackAnim`(공격 모션 진행도), `bool windup`.
- 피격: damage() 시 `hurtTimer=0.18` 세팅 → painter에서 살짝 뒤로 젖힘/스케일 찌그러짐 + 흰 플래시(기존 hitFlash) 유지.
- 이동: 이미 일부 존재(걷기 스윙). 누락된 몹(mage/archer 등)에 보행/부유 모션 보강.
- 공격: 몹이 실제 공격할 때 `attackAnim` 구동 → painter에서 무기/팔/돌진 자세. 현재 enemy는 공격 모션 거의 없음(즉발). windup(예비동작) 0.2~0.4s 추가해 가독성↑.
- painter: 각 `_grunt/_bat/.../_boss/_player`에서 위 타이머를 읽어 변형.

**완료 기준**: 모든 캐릭터가 걷고/예비동작→공격/맞으면 움찔. analyze 에러 0.

- [x] Entity 공통 애니 타이머(hurt/attackAnim/windup)
- [x] damage()에서 hurt 모션 트리거
- [x] 플레이어 피격/공격 모션 보강 (hurt flinch + 기존 무기 아크)
- [x] 일반몹 공격 windup + 모션 (grunt 돌진/ranged charge/slime hop/brute lunge)
- [x] 보스 모션 (hurt flinch + 기존 windup/active)

---

## Phase 5 — 몬스터 & 보스 패턴 다양화  (req #6)

**목표**: 보스 패턴 다양화 + 일반몹도 패턴(단, 심플). "땅 부수기→공중 띄움" 같은 효과.

**설계**:
- 공통 이펙트: `world.dart`에 `_launchPlayer(force)`(공중 띄움), 지면 균열 파티클/충격파 헬퍼.
- 보스 아키타입 확장(`types.dart` BossArchetype에 추가, `world.dart` 3개 switch 모두 케이스):
  - `boarSmash`(멧돼지): 돌진 → 정지 → 땅 부수기(전방 충격파, 맞으면 launch).
  - `iaido`(인간형): 장시간 예비동작 후 순간 발도(긴 사거리 일격, 빠름).
  - `flurry`(인간형): 초고속 연속베기 3~5타.
  - `guardian`(인간형): 일정시간 방어자세(피해 감소/반사) 후 반격.
- 일반몹 패턴(심플, `_updateEnemy`에 1패턴씩): grunt=가끔 짧은 돌진베기, archer=후퇴 사격(kiting), slime=분열(죽을 때 작은 슬라임 2), brute=점프 내려찍기.
- 보스 페이즈: HP<50%에서 패턴 가속/추가.

**완료 기준**: 멧돼지 땅부수기에 맞으면 떠오름. 인간형 보스가 발도/연속베기/방어 섞어 씀. 일반몹도 단순 패턴 보유.

- [x] 공통 launch/충격파 헬퍼 (`_launchPlayer`/`_bossSmash`/`_bossSlash`)
- [x] 멧돼지 boarSmash 패턴 (돌진→땅부수기→공중띄움)
- [x] 인간형 iaido(발도)/flurry(연속베기)/guardian(방어+반격) 패턴
- [x] 일반몹 심플 패턴 (grunt 돌진/archer kite/slime 분열)
- [x] 보스 HP 페이즈 전환 (enraged <50%: windup·atkCd 가속, 타수 증가)

---

## Phase 6 — 상태효과(버프/디버프) + 함정 + 아이템 다양화  (req #5)

**목표**: 상태효과 시스템, 환경 함정, 아이템 확장.

**설계**:
- 상태효과: `types.dart` `enum StatusKind { poison, burn, slow, weaken, regen, shield, haste, atkUp }`. `class Status { StatusKind kind; double timer; double power; }`. Player(및 Enemy)에 `List<Status> statuses`. world `_updateStatuses(dt)`에서 틱 데미지/효과 적용. painter HUD에 아이콘 표시(main.dart).
- 함정: `types.dart` `class Trap { String kind; Rect rect; double timer; }` (kind: spike 상시, arrow 주기 발사, saw 이동, floorSpike 밟으면 발동). `level_gen`에서 방에 스폰. `world`에서 충돌 시 데미지/디버프. painter 렌더.
- 아이템 확장: `_shopDefs` 확대 + 전투방 드롭 아이템(상태효과 부여 물약/유물). 유물=영구(런 한정) 패시브.

**완료 기준**: 독/화상 등 디버프가 시간 경과로 데미지. 가시/화살 함정이 플레이어 공격. 상점/드롭 아이템 종류 증가. HUD에 상태 표시.

- [x] Status 시스템(8종) + 틱 처리 + HUD (`_statusRow`)
- [x] Trap 3종(spike/saw/arrow) + 스폰/충돌/렌더
- [x] 아이템/유물 확장 (버프물약 4종 + 흡혈 유물)

---

## Phase 7 — 스컬(직업) 약 50종 추가  (req #3)

**목표**: 스컬 ~50종 추가(현재 8종 → ~58종).

**설계**:
- 스킬을 모두 고유로 만들 수 없으므로 **스킬 라이브러리를 ~20종으로 확장**(Phase 5의 패턴/이펙트 재활용) 후, 스탯·무기·색·티어 조합으로 다수 스컬 구성.
- 무기 그래픽도 ~15종으로 확장(현재 8종). 부족하면 색/크기 변형으로 변주.
- 티어 분포: 일반 다수, 전설 소수(가중치 유지).
- **배치로 진행**(한 번에 10종씩, 5배치). 각 배치마다 analyze 통과 확인 → 체크.
- `SkullType` enum이 매우 커지므로, `_skullColor`처럼 enum 의존 switch가 없는지 확인(이미 spec 기반으로 정리됨).

**완료 기준**: 50종 내외 추가, 각 스컬 플레이 가능(스킬·무기 매핑 정상), analyze 에러 0.

- [x] 스킬 라이브러리 17종으로 확장 (spin/magicburst/slam/blink/pounce/guard/explode/phase + volley/meteor/chain/quake/dashstrike/bulwark/heal/flames/frost) — `world._doSkill`
- [x] 무기 그래픽 확장 12종 (sword/staff/axe/daggers/claws/greatsword/scythe/bomb + spear/bow/gauntlet/hammer) — painter `_drawWeapon`
- [x] 스컬 배치1~5 (+50): common 20 + rare 16 + epic 10 + legendary 4 = 50종 추가(총 58종). `SkullType` enum + `kSkulls`(skulls.dart) 정합 확인, build web 성공.

---

---

# 2차 요청 (사용자 추가) — Phase 8~13

> 사용자 지시: **Phase 7(이전 작업)까지 모두 끝낸 뒤** 시작. 시작 전 문서화 완료(이 절).

## 2차 요청 원문 요약
1. 보스 외형을 **이름에 맞게 개별화**. 기사단장=갑옷 인간형, 용병단장=가죽갑옷, 숲의 마녀=마녀복장 여성, 마왕=검은갑옷+뿔 인간형. 지금은 다 비슷함.
2. 무덤 스컬 뽑기는 **최대 1회**(특성으로 횟수 늘리기 전까지). 그리고 뽑은 스컬은 **영구 저장이 아니라 게임 시작 시 사용되고 사라지는 1회성**.
3. 마을에 **특성(스킬트리)** 시스템. 모은 영혼으로 공격특화→공격버프, 방어특화→방어버프 등을 찍음. **비싸게**.
4. **콤보 버그**: 연타 시 1,1,1,2,1,1,1,3… 식으로 콤보가 제대로 안 이어짐. 연타해도 콤보가 이어져야 함.
5. **스킬 시각 차별화**: 스킬 이름에 맞는 연출. 그림자 베기=지나간 자리 영혼 이펙트, 대지 강타=바닥으로 내리꽂으며 주변 지상 적 타격 등.
6. **등급별 화려한 기본공격**: 고등급일수록 기본공격이 스킬처럼 화려. 야수=발톱 허공 광역, 망령=3타에 망령이 큰 낫 휘두름, 기사=3타에 검 내리쳐 충격파 등.

---

## Phase 8 — 보스 외형 개별화 (2차 #1)
**목표**: 보스 이름/정체성에 맞는 고유 그래픽.
**설계**:
- 현재 `BossShape`(humanoid/beast/golem/bird)는 너무 거칢 → 보스별 정체성 키 도입.
  - 방법: `BossSpec`에 `String visual` 추가(예: 'knight','mercenary','witch','demonKing','goblin','boar','eagle','golem'). `level_gen` 보스 정의에 각각 지정.
  - `painter._boss`의 switch를 `b.spec.visual` 기준으로 변경, `_bossKnight/_bossMercenary/_bossWitch/_bossDemonKing/_bossGoblin` 신규 + 기존 `_bossBeast/_bossGolem/_bossBird` 재사용.
- 각 그리기 가이드:
  - knight(기사단장/데스나이트): 판금 갑옷 몸통, 투구(슬릿 눈), 한손검+방패 실루엣, 어깨 견갑.
  - mercenary(용병단장): 가죽 갑옷(갈색 톤), 망토/두건, 한손도끼나 검, 거친 느낌.
  - witch(숲의 마녀): 뾰족 마녀모자, 로브 치마(여성 실루엣), 지팡이+오브, 가는 체형.
  - demonKing(마왕): 검은 판금 갑옷, 큰 뿔 2개, 붉은 눈, 망토, 위압적 큰 체형.
  - goblin(고블린 족장): 작고 다부진 체형, 큰 귀, 몽둥이/방패.
- `BossState.windup/active` 모션(기존)과 호환되도록 같은 좌표계(translate(b.cx,b.y), scale(facing*sx,sy)) 사용.

**완료 기준**: 보스 9종이 시각적으로 구분됨. analyze 0.
- [x] BossSpec에 visual 필드(`{this.visual=''}`) + level_gen 9종 지정(boar/goblin/eagle/golem/witch/mercenary/knight/bandit/demonKing)
- [x] painter 보스별 draw 함수(`_bossKnight/_bossMercenary/_bossBandit/_bossWitch/_bossDemonKing/_bossGoblin`)
- [x] 기존 beast(boar)/golem/bird(eagle) 재사용 연결, `b.spec.visual` switch + shape 폴백

## Phase 9 — 무덤 뽑기 1회 + 1회성 스컬 (2차 #2)
**목표**: 무덤 뽑기 횟수 제한(기본 1, 특성으로 증가) + 뽑은 스컬은 런 시작 시 소모되는 1회성.
**설계**:
- **현재**: `_rollGraveyard`가 영혼 소모로 `meta.unlocked`에 영구 추가 + `meta.startSkull` 설정(영구). → 변경 필요.
- **신규 모델**:
  - `meta.maxPulls`(기본 1, Phase 10 특성으로 +). 저장됨.
  - 마을 입장 시 `world.pullsUsed = 0`(town 진입마다 리셋). 뽑기는 `pullsUsed < meta.maxPulls`일 때만.
  - 뽑은 결과 = **이번 런 한정 시작 스컬**. `meta.preparedSkull`(저장 안 함, 또는 저장하되 런 시작 시 클리어). 영구 unlocked에 넣지 않음.
  - `_startRun()`에서 `preparedSkull`이 있으면 그걸로 시작하고 즉시 소모(null로). 없으면 기본 해골.
  - 출발 오버레이(`_DepartOverlay`)의 "시작 해골 선택"은 preparedSkull 있으면 그것 표시, 없으면 기본. (영구 unlocked 기반 선택 UI 제거 또는 축소.)
- 무덤 가중 추첨(`rollSkull`)은 유지하되 후보 = 전체 스컬(영구 해금 개념 폐지) 또는 기본 제외 전체.

**완료 기준**: 마을 방문당 1회만 뽑힘. 런 시작하면 그 스컬 쓰고 다음 런엔 사라짐. analyze 0.
- [x] meta: `maxPulls`(기본1, 저장) + `preparedSkull`(SkullType?, 저장하되 런 시작 시 소모). `startSkull`은 getter(=preparedSkull??basic), `takeStartSkull()` 소모 헬퍼. 기존 `unlocked`/`unlockSkull`/`lockedSkulls`/`unlockCost`/영구 startSkull 제거(+skulls.dart import 제거).
- [x] world: `pullsUsed`(town 진입 시 0 리셋), `_rollGraveyard` = pullsUsed<maxPulls 제한 + 후보 전체(basic 제외) + `preparedSkull` 세팅 + 마을 아바타 즉시 반영. graveyard 프롬프트에 남은 횟수 표시.
- [x] `_startRun`: `meta.takeStartSkull()`로 소모 후 save.
- [x] DepartOverlay: 영구 선택 리스트 제거 → 준비된 1회성 해골 카드 표시(없으면 기본 해골 안내).

## Phase 10 — 마을 특성(스킬트리) 시스템 (2차 #3)
**목표**: 영혼으로 영구 특성 투자(비쌈). 분기형 트리.
**설계**:
- `meta`에 특성 레벨 필드(저장): 예) `trAttack`, `trDefense`, `trUtility`, `trPull`(무덤 뽑기 +1 → Phase 9의 maxPulls에 반영) 등.
- 비용: 레벨당 급증(예: `120 * (1.6^lv)`), 영혼 소모.
- 효과 적용(파생 getter, `world.atkMul`/`maxHp`/`_hurtPlayer` 등에서 사용):
  - 공격 특화: 공격 카테고리(검사/짐승형) 스컬일 때 추가 atk. (카테고리는 `SkullSpec.category`.)
  - 방어 특화: 방어형(기사) 스컬일 때 피해 감소/максHP.
  - 범용: 회피/이속/영혼 획득 등.
- UI: `TownUI.traits` 추가, 마을에 특성 NPC/비석 또는 대장장이 탭 확장. `main.dart`에 `_TraitOverlay`(스킬트리 그리드, 노드 선후행).
- "스킬트리를 찍듯이" → 노드별 선행 조건(prereq) 표현.

**완료 기준**: 영혼으로 특성 투자 가능, 효과가 실제 스탯에 반영, 비용 비쌈. analyze 0.
- [x] meta: 특성 4종(`trAttack`/`trDefense`/`trUtility`/`trPull`) 저장 + 비용 `traitCost(lv)=120*1.6^lv` + 효과 getter(`atkTraitMul`/`defenseDrFor`/`traitBonusHp`/`soulGainMul`/`traitSpeedMul`/`maxPulls`) + `buyTrait(k)`(선행/맥스/비용 체크)
- [x] world/types: `TownUI.traits` + `traitsRect`(roomWidth*0.36) + `_handleTownInteract` 비석 상호작용
- [x] main: `_TraitOverlay` 스킬트리 UI(노드 4종, 선행 잠금/MAX/비용 표시) + painter `_traitShrine`(영혼 비석)
- [x] 효과 연결: atkMul(`atkTraitMul`), maxHp(`traitBonusHp` town/run), `_hurtPlayer`(`defenseDrFor`), 이속(`traitSpeedMul`), 영혼획득(onRunEnd `soulGainMul`), 뽑기(`maxPulls=1+trPull`, 선행=범용2)

## Phase 11 — 콤보 연타 버그 수정 (2차 #4)
**목표**: 연타해도 1→2→3 콤보가 이어지게.
**원인**: `_doAttack`는 `attackTimer > 0.06`이면 입력 무시. 스윙 중 누른 입력이 버려져, 콤보 윈도우에 우연히 맞은 입력만 단계 상승 → 1,1,1,2 패턴.
**설계(입력 버퍼링)**:
- Player에 `double attackBuffer = 0;`. 공격 입력 시 스윙 중이면 버퍼에 저장(예: 0.25s).
- 스윙 종료(또는 콤보 윈도우 진입) 시 버퍼가 살아있으면 다음 콤보 자동 실행.
- `_doAttack`: 스윙 중이면 `attackBuffer = 0.25` 후 return. 윈도우 중이면 즉시 다음 단계.
- `_updatePlayer`에서 attackBuffer 감쇠 + 윈도우 시작 시 버퍼 소비.
**완료 기준**: 빠르게 연타 시 1→2→3가 안정적으로 이어짐. analyze 0.
- [x] Player `attackBuffer` 필드 (entities.dart)
- [x] `_doAttack` 버퍼링: 스윙 중(attackTimer>0.06) 입력은 버리지 않고 `attackBuffer=0.35`
- [x] `_updatePlayer` 버퍼 소비: 스윙 종료(attackTimer<=0)+버퍼 생존 시 즉시 `_doAttack()` 재호출 → 1→2→3 체인

## Phase 12 — 스킬 시각 차별화 (2차 #5)
**목표**: 각 스킬 연출을 이름/효과에 맞게 뚜렷하게.
**설계(`world._doSkill` 이펙트 + 필요 시 painter)**:
- 그림자 베기(blink): 지나간 경로에 **영혼 위스프**(보라/청록 잔상) + 잔상 캐릭터 실루엣.
- 대지 강타(slam): 플레이어가 **공중에서 바닥으로 내리꽂고**, 착지 시 주변 **지상** 적에게 충격파(공중 적 제외), 지면 균열 파티클.
- 회전베기(spin): 회전 칼날 궤적(링) 강조.
- 마력 폭발(magicburst): 마법진→탄막 연출.
- 도약 발톱(pounce): 발톱 3선 잔상.
- 방어 태세(guard): 방패 오라 + 반격 링.
- 대폭발(explode): 폭심 섬광+이중 링.
- 유령 질주(phase): 반투명 유령 잔상 다수.
- 구현 메모: slam은 현재 전방 AoE → "내리꽂기" 위해 `p.vy` 하강 + onGround 트리거 시 충격파로 변경(2단계 스킬). 또는 즉발+착지판정.
**완료 기준**: 스킬마다 시각이 명확히 구분. analyze 0.
- [x] blink 영혼 잔상 (`ghost` 잔상 실루엣 + 기존 위스프)
- [x] slam 내리꽂기(공중 시전 시 급강하 vy=900)+지상 충격파(`crack`+`ring`)
- [x] 기타 스킬 연출 보강 — 경량 `SkillFx` 시스템 신규(types `SkillFx`, world `skillFx`/`_fx`/틱, painter `_skillFx`). 매핑: spin/guard/bulwark=`ring`, explode=`dualring`, magicburst=`runes`(회전 마법진), blink/phase/dashstrike=`ghost`(+dashstrike `slashArc`), pounce=`claw`(3선), slam/quake=`crack`, chain=타깃별 `ring`.

## Phase 13 — 등급별 화려한 기본공격 (2차 #6)
**목표**: 고등급 스컬일수록 기본공격(특히 3타 마무리)이 스킬급으로 화려.
**설계**:
- 콤보 3타(comboStep==3) 마무리에 **스컬별 특수 연출 + 추가 히트박스/이펙트**. 티어 높을수록 강화.
  - 야수: 허공 발톱 광역(넓은 부채꼴 추가 히트).
  - 망령: 망령이 나타나 전방 큰 낫 스윕(긴 사거리 광역).
  - 기사: 바닥에 검 내리쳐 충격파(전방 지면 AoE).
  - 광전사/검사: 강한 횡베기 + 큰 이펙트.
- 구현: `world._resolveCombat`의 3타 분기에서 `p.skull.type`/`weapon`/`tier`별 특수 효과 호출(`_finisher(p)` 헬퍼). painter `_weapon`/전용 이펙트.
- 기본 1·2타도 무기별로 약간씩 다르게(이미 무기 그래픽은 있음 → 궤적/잔상 추가).
**완료 기준**: 등급/스컬별 기본공격(특히 마무리)이 시각·범위에서 차별화. analyze 0.
- [x] 3타 마무리 스컬별 `_finisher(p, mul)` — `_resolveCombat` 3타 히트윈도우에서 1회(`finisherFired`). 카테고리별 광역 추가타+넉백, 티어 배율(common1.0/rare1.2/epic1.45/legendary1.8).
- [x] 야수=claw 광역 / 망령(scythe)=대형 slashArc 스윕 / 기사=crack 지면 충격파+ring / 검사·특수=강한 slashArc / 마법=ring 노바 / 권사=claw / 창병·궁수=slashArc.
- [x] 등급 강화 연출: epic+ 추가 ring, legendary 흰색 dualring 액센트.

---

---

# 3차 요청 (사용자 추가) — Phase 14~19

> 사용자 지시: 아래 6개 항목을 문서화한 뒤, **기존 로드맵의 Phase 12부터 순서대로** 진행한다(12→13→14~19). 단 14·15는 활성 버그라 필요 시 앞당겨도 됨.

## 3차 요청 원문 요약
1. **콤보 연타 버그 재발**: 기본공격을 너무 빠르게 연타하면 콤보가 초기화되거나 다음 콤보로 진행되지 않음. (Phase 11 버퍼링으로 부족 → 재조사 필요)
2. **상점 포탈 오작동**: 상점 아이템 근처에 포탈/문이 있으면 구매 중 실수로 다음 맵으로 넘어감. 상점방에선 포탈/문을 아이템 근처에 배치 금지.
3. **픽셀아트 화려함 부족**: 여전히 단조로움. `Skul: The Hero Slayer` 아트 컨셉(짙은 외곽선, 다층 셰이딩, 발광/하이라이트, 림라이트, 풍부한 디테일)을 더 적극 반영.
4. **보스 멀티 패턴 + 평상시 행동**: 보스마다 3~4개 패턴을 보유하고 **랜덤 사용**. 또 스킬 사이에 가만히 있지 말고 **천천히 이동/가끔 가드/가끔 평타**. 예시(기사단장): (P1) 점프로 사라졌다가 2~3초 뒤 플레이어 위치로 낙하하며 지면 융기 어스퀘이크 광역, (P2) 가드로 기 모으기→3~4초 유지 시 사방으로 맵 끝까지 가는 빠른 검기 발사, (P3) 크게 전진하며 광범위 베기.
5. **보스 중복 출현 방지**: 한 게임 세션 내에서 이미 등장(처치/사망)한 보스는 게임 재시작 전까지 다시 나오지 않음.
6. **층 환경 다양화**: 기사단 숙소, 적대 왕국 왕가, 고블린 부락, 드래곤 레어, 드워프 광산, 수정 광산, 끓는 마그마 화산, 붉은 곰의 동굴, 어두운 숲길, 침묵의 칼날 열대림, 핏빛 죽음의 강 등 다양한 테마. 테마별 오브젝트/함정/몬스터/보스 배치.

---

## Phase 14 — 콤보 연타 버그 재수정 (3차 #1)
**목표**: 아무리 빠르게 연타해도 1→2→3→(1)…가 끊김 없이 이어짐.
**재조사 포인트**(Phase 11 버퍼링이 부족했던 이유 가설):
- 입력 수집: `_attackQueued`가 매 프레임 `_clearInput`으로 초기화됨. 한 프레임에 두 번 눌러도 1회만 큐잉되어 매우 빠른 연타가 유실될 수 있음 → **눌림 횟수 카운트** 또는 keydown 이벤트에서 직접 버퍼 적립.
- 윈도우 타이밍: 스윙 종료 프레임에서만 버퍼 1회 소비. dt 변동으로 `attackTimer`가 한 프레임에 음수로 크게 지나가면 `comboWindow` 진입과 동시에 즉시 소비되는데, 그 직후 같은 프레임 추가 입력은 다시 스윙 중으로 간주되어 버려질 수 있음.
- `comboStep` 리셋 경로 점검: `comboWindow<=0`이 되는 순간 step=0. 버퍼가 살아있는데 윈도우가 만료되면 step이 초기화되어 1부터 다시 시작될 수 있음 → 버퍼 생존 시 윈도우 만료로 step 리셋 금지.
**설계(개선안)**:
- 입력 측에서 공격 키 down마다 `player.attackBuffer`를 직접 적립(프레임 큐 의존 제거) + 최근 입력 시간 기록.
- 스윙 종료 시 버퍼 있으면 즉시 다음 step, **버퍼가 살아있는 동안엔 comboStep 리셋 보류**.
- 콤보 윈도우를 넉넉히(0.5s) + 버퍼 0.4s. 단 한 프레임 2입력도 누락 없게.
- 디버그: 화면에 현재 comboStep/버퍼 잔량 임시 표기해 재현 후 제거.
**완료 기준**: 키를 미친듯이 연타해도 콤보 단계가 매끄럽게 상승/순환. analyze 0.
**실제 원인(발견)**: `_doAttack` 가드가 `attackTimer > 0.06`이라, 스윙 **마지막 0.06초 구간**에 들어온 입력이 버퍼링되지 않고 `else`로 빠져 `comboStep=1`로 리셋. 빠른 연타 시 이 구간에 입력이 자주 걸려 초기화됨.
- [x] 가드를 `attackTimer > 0`(스윙 중이면 무조건 버퍼)로 변경 — 스윙 중 입력은 절대 리셋 안 함
- [x] 버퍼 생존 중 comboStep 리셋 보류 (`comboWindow<=0 && attackBuffer<=0`일 때만 리셋)
- [x] 윈도우 0.42→0.5, 버퍼 0.35→0.4로 여유 확대 + 검증(build OK)

## Phase 15 — 상점 포탈/문 배치 수정 (3차 #2)
**목표**: 상점방에서 포탈/문이 아이템 가까이 생기지 않게 해 오구매·오이동 방지.
**구현**(`level_gen.dart`):
- 상점 아이템을 도어보다 **먼저** 배치하고 `shopXs`/`clearOfShops(x)`(안전반경 150px) 헬퍼 도출. 아이템 중심을 `width*0.42`로 좌측 정렬.
- 상점방 도어 후보는 **우측 끝(fx 0.84~0.94)**만 + `clearOfShops` 통과한 위치만, 폴백 배치도 우측. 일반방은 기존(fx 0.5~0.94) 유지.
**완료 기준**: 상점에서 아이템 구매 중 실수로 다음 층 진입 안 됨. analyze 0.
- [x] 상점방 도어/포탈을 아이템 안전반경(150px) 밖·우측 끝에 배치
- [x] 상점 아이템 좌측 정렬로 포탈과 물리 분리

## Phase 16 — 픽셀아트 화려함 강화 (3차 #3)
**목표**: `Skul: The Hero Slayer` 톤의 화려한 픽셀아트.
**아트 컨셉 키워드**: 짙은 외곽선(다크 아웃라인), 2~3단 셰이딩(코어섀도/미드/하이라이트), 림라이트(가장자리 발광), 강조색 악센트, 발광 이펙트(눈/무기/스킬), 디테일(갑옷 리벳/천 주름/모피 결).
**설계**:
- 공통 헬퍼 추가: `_outline(rect)`(엔티티 실루엣 1px 다크 외곽선), `_rim(rect,color)`(상단/전면 림라이트), 팔레트 램프(색 → [shadow,mid,light] 자동 생성).
- 플레이어/몹/보스 스프라이트에 외곽선 + 3단 셰이딩 + 눈·무기 발광 적용.
- 무기: 금속 하이라이트 줄, 마법무기 글로우.
- 배경: 다층 패럴럭스(원경 실루엣 + 근경 디테일), 바이옴별 분위기 입자(불티/눈/포자/재).
- 성능: 픽셀 사이즈 일관 유지, draw 호출 과다 주의.
**완료 기준**: 캐릭터·배경이 확연히 화려/입체적. analyze 0, build web OK.
- [x] `_glow`(블러 발광) + `_ramp`(base→shadow/mid/light) 헬퍼.
- [x] 플레이어: 백라이트 오라 + 다크 실루엣 백킹(외곽선 느낌) + 3단 셰이딩 + 눈 발광 + 림라이트. 적: aggro 시 적색 백라이트. 보스: 상시 색상 오라.
- [x] 배경: 원경 패럴럭스 언덕(느림/어두움) 1층 추가 + 달 헤일로 + 바이옴 분위기 입자(불티/재/포자) + 별 반짝임 + 비네트.
- [~] 무기 하이라이트는 Phase 0에서 일부 반영(추가 글로우는 차후). 전면 외곽선 패스는 비용상 백킹으로 대체.

## Phase 17 — 보스 멀티 패턴 + 평상시 행동 (3차 #4)
**목표**: 보스가 3~4개 패턴을 랜덤 사용하고, 패턴 사이에 살아있는 듯 행동.
**설계**:
- 패턴 셋: `BossSpec`에 `List<String> patterns`(또는 visual별 하드코딩 매핑). 보스별 3~4개.
  - 예) knight: `teleSlam`(점프→소멸→플레이어 위 낙하+지면 융기 광역), `chargeBeam`(가드로 기 모으기→유지 시 사방 검기 난사), `wideSlash`(전진 광역 베기), 기본 `combo`(평타).
- 패턴 선택: `_bossPickPattern()`가 쿨다운마다 가능한 패턴 중 가중 랜덤(직전 패턴 회피). HP<50% 시 고위력 패턴 가중↑.
- **평상시 행동(idle behavior)**: 패턴 쿨다운 동안 `BossState.idle`에서 플레이어 향해 천천히 이동(`walkSpeed*0.4`), 일정 확률 짧은 가드, 근접 시 가벼운 평타. "가만히 서있음" 제거.
- 신규 이펙트 헬퍼: 지면 융기 스파이크(`_eruptGround`), 사방 검기 발사(`_radialBeams`), 잔상 텔레포트.
- 기존 `_bossStartAttack`/`_bossActive` 구조를 패턴 디스패치로 확장.
**완료 기준**: 한 보스가 전투 중 2~3패턴을 섞고, 비패턴 시에도 이동/가드/평타. analyze 0.
- [x] `_bossPatterns(b)`(visual별 3~4종) + `_pickBossPattern`(직전 회피). Boss `pattern`/`idleActCd` 필드. `_bossStartAttack`/`_bossActive`/`_bossWindup`을 archetype→pattern 디스패치로 전환.
- [x] 신규 패턴: `teleslam`(플레이어 위로 순간이동→낙하→`_bossErupt` 지면 융기+공중띄움), `beam`(가드로 차징 후 사방 검기 난사), `wideslash`(전진 광역 2연베기).
- [x] 보스별 패턴셋: knight=[teleslam,beam,wideslash,iaido], demonKing=[teleslam,beam,cast,wideslash], witch=[cast,teleslam,beam], boar=[smash,charge,wideslash], golem=[leap,smash,wideslash], goblin=[guard,charge,smash], mercenary/bandit/eagle 등.
- [x] **평상시 행동**: idle에서 플레이어로 이동(walkSpeed*0.55), **근접 시 평타 스윕**(`_bossSlash`), 중거리 가끔 가드. "가만히 서있음" 제거 → 사용자 불만 해소.
- [x] painter 보스 공중 스쿼시를 archetype→`airborne` 기반으로.

## Phase 18 — 보스 중복 출현 방지 (3차 #5)
**목표**: 한 게임 세션에서 이미 등장한 보스는 재시작 전까지 재출현 금지.
**설계**:
- `world`(또는 런 메타)에 `Set<String> usedBosses`(세션 한정, **저장 안 함**). 게임 시작/`_startRun` 시 초기화 정책 결정(요구는 "게임 재시작 전까지"이므로 **앱 세션 단위**로 보존 → `GameWorld` 생성 시 1회 초기화, 런 시작마다 유지).
- `pickBoss(floor, rng)`에서 `usedBosses`에 없는 후보만 추림. 모든 후보 소진 시(폴백) 전체에서 선택.
- 보스 등장 확정 시 `usedBosses.add(spec.name)`(방 생성 시점). 처치 여부와 무관히 "등장"하면 소비(요구: 한번 깨거나 죽기 전까지=등장하면 중복 금지로 해석).
**완료 기준**: 같은 보스가 한 세션에 두 번 안 나옴. 풀 소진 시 안전 폴백. analyze 0.
- [x] `MetaState.usedBosses`(비저장 Set, 앱 세션 지속 — PlayScene/world는 런마다 재생성되므로 meta에 보관).
- [x] `pickBoss(floor, rng, used)` 미사용 후보 우선 + 풀 소진 시 전체 폴백.
- [x] `buildRoom`에 `usedBosses` 전달, 보스 방 생성 시 `usedBosses.add(name)`.

## Phase 19 — 층 환경(바이옴) 다양화 (3차 #6)
**목표**: 다양한 테마 환경 + 테마별 오브젝트/함정/몬스터/보스.
**설계**:
- 바이옴 대폭 확장(`types.dart` `Biome` enum + `kBiomes` 팔레트): 기사단 숙소, 적대 왕국 왕가, 고블린 부락, 드래곤 레어, 드워프 광산, 수정 광산, 마그마 화산, 붉은 곰 동굴, 어두운 숲길, 침묵의 칼날 열대림, 핏빛 죽음의 강 등.
- 층→바이옴 매핑(`biomeForFloor`)을 테마 시퀀스로 확장(또는 층별 랜덤 풀).
- 바이옴별 데이터 묶음: 팔레트(skyTop/skyBottom/ground/platform/hill/accent), prop 종류 풀(Phase 0 `_props` 확장: 깃발/왕좌/수정/용알/광차/마그마분출구/곰뼈 등), 함정 가중(spike/saw/arrow + 신규?), 스폰 몬스터 풀, 보스 풀.
- `level_gen`의 prop/trap/spawn 선택이 바이옴 데이터를 참조하도록 리팩터.
- painter에 신규 prop/배경 렌더 추가.
**완료 기준**: 층마다 분위기·오브젝트·함정·몹·보스가 테마에 맞게 달라짐. analyze 0, build web OK.
- [x] **Biome enum/팔레트 대폭 확장 + 층 매핑**: 16개 바이옴(`kBiomes`) 팔레트 정의 + `FloorGraph.biome` 런마다 랜덤.
- [x] **바이옴별 prop/trap/몬스터/보스 풀 데이터화**: prop=바이옴별 propKinds switch, monster=`biome.pool`, **trap=바이옴별 trapPool(화산/마그마/레어=flame, 동굴/광산=saw, 성/왕국=arrow 가중)**, **boss=`_biomeBoss` 테마 선호**(층 티어 내에서 바이옴 맞는 비주얼 우선, 미사용 우선, 없으면 폴백).
- [x] **level_gen 바이옴 데이터 참조 리팩터**: prop/trap/spawn/boss 선택이 `g.biome` 참조.
- [x] **painter 신규 prop/배경 렌더**: crystal/stalactite/rune prop 렌더 완비, **신규 `flame` 함정**(분출 주기 1.4~2.4s, 화상 부여) world 로직+painter 화염 기둥 렌더. 배경은 바이옴 팔레트 기반 패럴럭스(Phase 16) 사용.

---

---

# 4차 요청 (사용자 추가) — Phase 20~21

> 사용자 지시: 진행 중 추가. 전투 감각/연출 다듬기. 문서화 후 순서에 맞춰 진행.

## 4차 요청 원문 요약
1. **직업별 공격속도 + 직업별 기본공격**: 직업마다 기본공격 속도가 달라야 함. 마법사 등 비근접은 느리게(예: 연타해도 **1초에 1회**를 못 넘게 기본공격 입력 자체를 제한). 또 기본공격 외형이 직업군마다 달라야 함 — 궁수=화살/석궁 발사, 마법사=원거리 구체 발사 식(원거리 직업은 평타가 투사체).
2. **스킬 외형을 이름·직업에 맞게**: 서리 마법사 스킬=구체가 아니라 **고드름** 형태의 날카로운 마법. 번개류=번개 낙하/스파크 폭발. 야수 돌진=**핏빛 손톱** 모양. 대지 강타류=아래로 내리찍고 **바닥에 닿는 순간** 진동+이펙트 폭발.

---

## Phase 20 — 직업별 공격속도 + 직업별 기본공격 (4차 #1)
**목표**: 직업군마다 기본공격 속도/사거리/형태가 뚜렷이 다름. 원거리 직업은 평타가 투사체.
**설계**:
- **공격 쿨다운(연타 제한)**: `SkullSpec`에 `attackCd`(기본공격 최소 간격) 추가하거나 category로 도출. 예) 근접 검사/짐승형 0.0~0.15(빠름), 마법형/궁수형 ~1.0(느림, 1초 1회). `_doAttack`/버퍼 소비 시 `attackTimer` 외에 별도 `nextAttackReady` 게이트 추가 → 연타해도 쿨다운 전에는 발동 금지(버퍼도 무시 또는 쿨다운까지 보류). **콤보 버퍼 로직과 충돌 없게**(Phase 14): 근접은 기존 콤보, 원거리는 쿨다운 단발.
- **직업별 기본공격 형태**:
  - 근접(검사/기사/짐승형/권사/창병): 기존 근접 스윙 히트박스(현행 유지) + 무기별 궤적.
  - 궁수형: 평타가 **화살/석궁 볼트** 투사체 발사(`Projectile`), 사거리 길고 속도 빠름, 콤보 없음.
  - 마법형: 평타가 **마력 구체** 투사체 발사, 약간 느림.
  - 특수형: 케이스별(단검=근접 빠름, 폭탄=투척 등).
- **구현 위치**: `_resolveCombat`/`_doAttack`에서 category 분기. 근접이면 현행 hitbox, 원거리면 투사체 스폰 + 평타 모션. 평타 투사체는 `Projectile(fromBoss:false)`로 기존 충돌 재사용.
- 데미지 밸런스: 원거리 평타는 단발이므로 1타 데미지를 근접 콤보 평균과 맞춤.
**완료 기준**: 마법사·궁수는 연타해도 1초 1발 내외의 원거리 평타, 근접은 빠른 콤보. analyze 0.
- [x] `SkullSpec.rangedBasic`(category 마법형/궁수형) + `_doRangedBasic` 쿨다운 게이트(마법 1.0s≈1발/s, 궁수 0.7s). 버퍼와 함께라 연타해도 쿨다운 못 넘음.
- [x] 궁수=화살(`Projectile.shape='arrow'`, 빠름 640) 평타 투사체 + painter 화살 렌더.
- [x] 마법=구체(`shape='orb'`, 470) 평타 투사체 + painter 발광 구체 렌더. 머즐 플래시 파티클.
- [x] 근접 현행 콤보 유지 + `_resolveCombat` 근접 히트박스에 `!rangedBasic` 게이트(원거리 평타가 근접딜 안 줌). painter `_weapon` 원거리는 슬래시 아크 대신 조준+반동.
- [x] (추가 요청) **공격 중 방향 전환 허용** — `_updatePlayer` facing 잠금(`!p.attacking`) 제거 → 스윙 중에도 뒤돌아 공격 가능.

## Phase 21 — 스킬 외형 직업/이름 일치 (4차 #2)
**목표**: 스킬 연출이 이름·직업 정체성과 일치.
**설계**(Phase 12 `SkillFx` 확장 + 투사체 외형):
- **서리(frost/서리마법사)**: 구체 → **고드름**(뾰족한 얼음 파편) 투사체 외형 + 파편 SkillFx. `Projectile`에 모양 키 또는 전용 fx.
- **번개(chain/conjurer/stormcaller)**: 직선 파티클 → **지그재그 번개 볼트** + 스파크 폭발 fx(타깃에 낙뢰/스파크).
- **야수 돌진(pounce/dashstrike 짐승형)**: **핏빛 손톱**(붉은 claw) 색/모양.
- **대지 강타(slam/quake)**: 공중→**내리찍기**(이미 vy 추가) + **바닥 접촉 순간** 진동(shake)·균열·솟구침 이펙트가 착지 타이밍에 터지게(즉발이 아닌 착지 트리거 고려).
- **신규 fx kind**: `icicle`(고드름), `lightning`(지그재그+스파크), 그리고 투사체 렌더 분기(`Projectile.shape`).
- painter `_projectile`/`_skillFx`에 모양 분기 추가.
**완료 기준**: 서리=고드름, 번개=번개, 야수=핏빛 손톱, 대지=착지 진동 연출로 각 스킬이 이름과 맞음. analyze 0.
- [x] `Projectile.shape`(ball/arrow/orb/icicle/potion) + painter 분기(고드름·물병 추가).
- [x] frost=**고드름**(icicle 투사체+서리 파편), 번개류(chain)=**지그재그 번개 볼트**(SkillFx `lightning`, 2 endpoint)+스파크 폭발.
- [x] 야수 돌진(pounce)=**핏빛 손톱**(claw fx 적색), finisher 짐승형도 적색.
- [x] 대지 강타(slam)=공중 시전 시 다이브 후 **착지 순간** `_slamShockwave`(진동+균열+솟구침). `Player.slamPending` + `_updatePlayer` 착지 트리거.
- [x] (추가) 무투사(권사 dashstrike)=**주먹 난타** fist fx, 연금술사(meteor)=**물병** potion 투사체.

---

---

# 5차 요청 (플레이테스트 피드백) — Phase 22

> 사용자가 플레이하며 직업별 정체성을 빠르게 요청. 시스템(던지기 투사체/모양별 깨짐/상태) 위에 직업별로 평타·스킬을 매핑. **앞으로 직업이 더 추가될 수 있음** — 이 절에 누적.

## 처리됨 (이번 배치)
- [x] **바이옴 반복 버그**: `biomeForFloor`가 floor 인덱스 고정 매핑(1=숲…)이라 매 런 동일 → `FloorGraph.biome`에 **런마다 랜덤** 저장(`generateFloor`에서 `rng`로 선택), world/level_gen이 `graph.biome` 사용. (Phase 19 #3 선반영)
- [x] **원거리 평타 히트박스**: 투사체를 약간 아래(`p.cy+8`)에서 + 반경↑(화살9/구체12)으로 발사해 납작한 슬라임도 맞음.
- [x] **던지기 투사체 시스템**: `Projectile.grav`(아크) + `_updateProjectiles` 중력 + 모양별 깨짐 `_shatters`(potion/bomb/net) + `_thrownBurst`(스플래시/링/셰이크) + `_projectileOnHit`(상태이상). 바닥·몬스터 둘 다에서 깨짐.
- [x] **연금술사**: 평타=물약 투척(독), 스킬(meteor)=물약 낙하—**둘 다 깨짐 모션**.
- [x] **폭탄마**: 평타=폭탄 투척(화상).
- [x] **어부**: 평타=낚싯대 채찍(reachMul 1.6 장거리), 스킬=`net` 그물 투척(둔화).
- [x] **광부**: 평타=곡괭이(weapon `pickaxe` 신규 그래픽), 스킬=`rockthrow` 광석 투척(아크 3발).
- [x] **발키리**: 스킬=`valkyrie` 발키리 강림 전방 돌진(전방 코리도 광역+잔상/검기 연출).
- 신규 투사체 모양: potion/bomb/net/rock + painter 렌더. 신규 무기: pickaxe.

## 대기 (추가 직업 정체성 — 사용자 요청 시 누적)
- [x] **저격수 스컬(신규)**: `SkullType.sniper`(epic, 궁수형=`rangedBasic`). `_doRangedBasic`에 sniper 분기 — cd 1.4s(연타해도 ~0.7발/s), 속도 1150·사거리 life 2.4·데미지 42·`bolt` 모양. 스킬 `railgun`=일직선 관통 빔(reach 820, dmg 48, `lightning` fx+빔 파티클). 무기 `sniper` 그래픽(개머리판/총열/스코프/총구 발광), `bolt` 투사체 전용 발광 슬러그 렌더. analyze 0 / build web OK.
- [ ] 그 외 직업별 평타/스킬 정체성(요청 들어오는 대로). 권장: 원하는 직업 목록을 한 번에 정리하면 배치 처리.

---

---

# 6차 요청 (플레이테스트) — Phase 23~24

## Phase 23 — 자연스러운 지형 생성 (6차)
**목표**: `Skul`처럼 플랫폼 떡칠이 아닌 자연스러운 맵. 대각선/계단 지형, 다양한 맵 크기, 랜덤 방 모양/크기, 층 바이옴 랜덤(✅ 선반영됨).
**설계**:
- `level_gen` 플랫폼 생성 로직 재작성: 지면 높낮이(계단식 단차), 경사 구간, 플랫폼 밀도/배치 다양화, 빈 공간(낙하 구간) 허용.
- 신규 지형 타입: 대각선/계단(`Terrain`/`Slope`), 단차 지면. 충돌(`_moveAndCollide`)이 경사/계단 지원하도록 확장(또는 계단을 작은 플랫폼 묶음으로 근사).
- 방 크기/모양 랜덤: width 범위 확대, 천장 높이, 구역 분할.
- painter: 경사/계단/단차 렌더.
**완료 기준**: 방마다 지형·크기·모양이 확연히 달라지고 자연스러움. analyze 0.
- [x] **지면 단차/경사 생성**: 전투방 지면을 단일 평면 → **계단식 테라스**(`groundSegments` 컬럼들)로 재작성. 입구 340px는 평평(스폰 안전), 이후 평지(plateau)+계단(경사 근사, rise≤26px) 반복. 언덕(kGroundY-150)~계곡(kGroundY+80) 범위. 낙사 구덩이 없음(모든 x에 바닥) → fall-death 불필요(리스크↓).
- [x] **플랫폼 배치 자연화**: 플랫폼 높이를 `groundTopAt(x)` 로컬 지형 기준으로 띄움(언덕/계곡 위에서도 도달 가능).
- [x] **방 크기/모양 랜덤 확대**: 전투방 width 1500~2400(기존 1400~1920)로 변동 확대.
- [x] **충돌·렌더 경사/계단 지원**: `_moveAndCollide`에 **오토 스텝업**(rise≤`kStepUp`=30px면 vx 유지한 채 올라섬, `_canStandAt` 천장 가드) → 계단/경사 자연 보행. `_wallAhead`는 얕은 단차를 벽으로 안 침. painter는 `groundSegments` 각각 `_ground` 렌더. 도어/스폰/부쉬/함정/프롭 모두 `groundTopAt`로 지형에 정착. build web OK.

---

## **추가 요청 — 전투 상태효과·신규 몬스터·스테이지 확장**

사용자 추가 요청을 반영하여 다음 항목을 로드맵에 정식 추가합니다. 각 항목은 문서화 후 구현하며, 구현 시 관련 타입(`StatusKind`/`Trap`/`EnemyKind`), `world._updateStatuses`, `entities.dart`의 `hurtTimer`/`t2`/`stun` 플래그, `level_gen`의 몬스터 스폰 풀, `painter`의 시각 이펙트를 함께 수정합니다.

1) 전투 상태효과 및 넉백/경직/기절
- 보스(또는 특정 보스 아키타입)는 **스턴류 면역**으로 설정. 일반 몬스터 및 플레이어는 히트 시 **짧은 경직**(hurtTimer 증가) 또는 **넉백(launch/knockback)**을 받도록 구현.
- `StatusKind`에 `stun`, `knockback`(또는 `push`) 항목 추가(필요하면 `stagger` 구분). `Status.timer`로 지속시간 제어. `world._updateStatuses`에서 틱 처리.
- 강타/대지강타/망치류 공격, 돌진 스킬 등은 **확률 또는 확정으로 기절(stun)**을 유발. 보스는 기본적으로 스턴 면역이나 일부 보스 패턴에서는 예외적 스턴 처리 허용(설계에 따름).
- 방어 중인 보스/몬스터를 공격하면 **뒤로 밀려나는(후퇴) 반응**을 주도록 패턴화.
- 기존 화상/독/동상(ice) 디버프는 이미 존재하므로, 이들로 인한 **데미지·이속·공속·공격력 감소** 효과를 확장하여 연동.

2) 신규 몬스터/준보스 패턴
- **망치를 든 몬스터**(HammerEnemy) 추가: 둔기 충격 스킬(지면 강타) 보유, 적중 시 높은 넉백/기절 확률.
- **도적류 고등급 몬스터 & 신규 종족**: 고블린(특화), 난쟁이(드워프 적), 다크엘프(후반 출현) 추가 및 일부에게는 **출혈(bleed)** 확률 부여.
- **야수류** 몬스터는 적중 시 플레이어에 **이동속도 감소(slow)** 디버프를 낮은 확률로 부여.
- **식물형 함정 몬스터**: 플레이어 접근 시 바닥에서 솟아나 공격(독침/화염구 투사) — 트랩처럼 보이다가 발동하는 몬스터.
- **준보스형 기사(쉴드 보유)**: 특정 오브젝트(예: 방 한쪽에 박힌 수정/기둥)를 파괴할 때까지 **무적 방어막**(shield) 활성. 오브젝트 파괴 후 방어막 해제 및 본격 전투 개시.

3) 맵/스테이지 확장 (20 스테이지)
- 현재 `world.totalFloors`(기본 5)을 **20 스테이지**로 확장하고, `biomeForFloor`/`FloorGraph` 매핑을 재조정하여 각 구간에 적합한 바이옴과 보스 풀을 배치.
- 각 스테이지의 방 크기/수량을 증가시키고, 보스·미니보스·중간 이벤트(준보스·함정방)를 더 자주 배치하여 다양성 확보.
- 레벨 밸런스(난이도曲선): 1~6(튜토리얼/초중반), 7~12(중반, 새로운 몬스터 등장), 13~16(후반 전개), 17~20(최종 구간·전용 보스/엔딩 트랙).

우선순위 제안: (1) 상태효과·넉백 시스템 확장 → (2) 맹타/망치 계열 몬스터 및 출혈·감속 프로시저 → (3) 식물형/방어막 준보스 추가 → (4) 스테이지 수/바이옴 확장 및 밸런스 조정.

각 구현은 작은 단위(타입 추가 → 월드 로직 → painter 연출 → 레벨 제너레이터 스폰)로 나누어 TODO에 등록하고, 구현마다 `flutter analyze` 검사를 시행합니다.

### 처리됨 (2026-06-15 — 미완성 enum 스텁 완성)
> 직전 커밋이 `EnemyKind`(goblin/dwarf/darkElf/plant/hammer/shield)·`StatusKind`(bleed/stun)만 선언하고 동작/렌더/스폰을 비워둬 analyze 에러 6개로 막혀 있던 상태를 완성.
- [x] **(1) 상태효과·넉백**: `bleed`(지속딜)·`stun`(행동불가) 틱은 world `_updateStatuses`에 존재. `_hurtPlayer(.., {stun, kb})`로 기절·넉백 강화. 플레이어 stun 시 `_updatePlayer`에서 입력 전면 차단. 적 stun 시 `_updateEnemy` 진입부에서 AI 정지(보스는 stun 미부여=면역). `Projectile.onHit/onHitDur/onHitPow`로 투사체 상태이상(`_projectileOnHit`+적→플레이어 분기 양쪽 적용).
- [x] **(2) 망치/맹타 + 출혈·감속**: `hammer`(지면 강타 `_hammerSlam`→넉백+기절), `dwarf`(묵직한 밀치기, 접촉 시 추가 넉백 `_contactProc`), `goblin`(쾌속 단검, 접촉 시 출혈), `darkElf`(저주 볼트=bleed onHit). 야수 감속은 net/slow 기존 시스템으로 커버.
- [x] **(3) 식물형/방어막**: `plant`(접근 시 t2로 솟아올라 독침 투척, 멀어지면 수축), `shield`(t2>0 가드 시 전방 근접 85% 감소+플레이어 반동, 근접 시 방패 밀치기). 준보스 "오브젝트 파괴 전 무적"은 향후 확장 여지(현재는 가드 감소로 근사).
- [x] **(4) 스테이지 20 + 바이옴**: `world.totalFloors` 5→20. `pickBoss` 티어 곡선 재조정(1~7 tier0 / 8~13 tier1 / 14~20 tier2, usedBosses 풀 소진 시 폴백). 16개 바이옴 풀에 신규 몹 테마 편성(고블린부락=goblin, 드워프/수정광산=dwarf/hammer/darkElf, 숲길/열대림=plant, 기사단/왕국=shield/hammer, 핏빛강=darkElf 등).
- [x] painter: `_goblin/_dwarf/_darkElf/_plant/_hammerFoe/_shieldFoe` 6종 픽셀아트 + `_enemy` switch 분기. main HUD `_statusColor/_statusLabel`에 출혈/기절 추가.
- **검증**: `flutter analyze` 에러 0(info 141=기존 withOpacity 등 린트), `flutter build web` 성공.
- **메모(환경)**: 로컬 Flutter 3.44.1=Dart 3.12.1인데 pubspec `sdk: ^3.12.2`라 pub get 실패 → `^3.12.1`로 하향(상위호환, 3.12.2도 충족). 향후 3.12.2+면 영향 없음.

## Phase 24 — 특성: 고등급 스컬 확률 증가 (6차)
**목표**: 마을 특성에 무덤/드롭의 고등급(희귀+) 확률을 올리는 노드.
**설계**:
- `meta`에 `trLuck`(저장) + `luckMul` getter. `rollSkull`이 티어 가중에 luck 반영(희귀/영웅/전설 가중 ↑). `rollSkull` 시그니처에 luck 전달 또는 meta 참조.
- `_TraitOverlay`에 '행운' 노드 추가(비쌈). 무덤 뽑기/전투 드롭 추첨에 적용.
**완료 기준**: 행운 투자 시 고등급 스컬 체감 증가. analyze 0.
- [x] meta `trLuck`(저장, 선행=범용2, max5) + `luckMul`(1+0.35*lv) + `rollSkull(.., {luckMul})` 반영(희귀+ 가중에 곱, common 유지, double 가중). world 무덤·상자 두 호출 모두 `meta.luckMul` 전달.
- [x] `_TraitOverlay` 행운 노드(금색) 추가.

---

# 7차 요청 (플레이테스트 피드백) — 2026-06-15

1. **상태이상 시각 표시** — 플레이어/몬스터 위에 상태이상 표시 + 화상=빨강/독=초록 등 캐릭터 점멸.
   - [x] `types.dart`에 `statuses` 공유용 `statusColor(StatusKind)` 추가(main `_statusColor`는 위임으로 DRY화).
   - [x] painter `_statusFx(canvas, entity)` — 월드 좌표(스프라이트 위)로 ① **본체 점멸 필름**(우선순위 stun>burn>poison>bleed>slow>weaken 색, `sin(animTime*12)` 펄스) ② **머리 위 상태 뱃지**(상태별 색 칩 나열). player/enemy/boss 모두 호출.
2. **상자 스폰 지형 정착** — 땅속/공중 스폰 버그.
   - [x] `Chest`에 `groundY` 필드 추가, `rect`가 `groundY` 기준. `level_gen`에서 `groundTopAt(cx)`로 정착, 보스 처치 상자는 평지라 `kGroundY`.
3. **대형 맵 변형** — 가로 큰/세로 큰/둘 다 큰 버전.
   - [x] `level_gen` 전투방 크기 클래스: normal(1500~2100) / wide(2500~3600) / tall(1500~2000+세로) / huge(wide+tall) 랜덤.
   - [x] tall 방은 플랫폼을 최대 6단 climbable 스택으로 높이 쌓고, `camMinY`를 최고 플랫폼에서 도출.
   - [x] **세로 카메라**: world `camY`/`camMinY` 추가, `_camera`가 위로만 스크롤(지상 기본 고정), painter `translate(-camX, -camY)`. 박쥐도 tall 방에서 더 높이 스폰.
   - **검증**: analyze 0(info 148), build web OK.

---

# 8차 요청 (대규모 — 전투/콘텐츠/맵 심화) — 2026-06-15

> 사용자 13개 항목을 체크박스로 재정리. 일부는 기존 Phase에서 이미 구현됨(→ `[x]` + 위치 표기),
> 신규/심화 요구는 `[ ]`. **진행 순서 권장**: A(전투 기반) → B(상태이상 wiring) → C(콘텐츠/적·보스) → D(직업 패시브) → E(맵 연출).

## 진행 중 / 이번 세션 선행 완료
- [x] 스컬 **직업별 외형** 시스템 (`painter._skullLook`/`_drawSkullGear`: 농부·광부·어부·민병·기사·마법·궁수·짐승·권사·창병·사신·도적·전사·검사 헤드기어/갑옷).
- [x] 스컬 **개별 정체성**(고유색 틴트 + 속성 오라 fire/frost/lightning/holy/void/poison/arcane) `_skullElement`/`_drawSkullAura`.
- [x] **소환술사 스킬 교체**: `chain`(연쇄번개) → `summon`(해골 소환). `Ally` 엔티티 + `world.allies` + `_updateAlly`(추적·공격·복귀·7s 수명) + `painter._ally`.
- [x] 일반몹 외형 개편 **12종 전부**(외곽선+3톤음영+발광눈): grunt/goblin/dwarf/brute/bat + mage/archer/darkElf/slime/plant/hammer/shield. *(C6 완료)*
- [x] **보스 7종 추가**(redBear/rockBrute/mummy/doppel/appleTree/worm/wolfKing) → 총 16종, 외형·패턴·바이옴 배정 완료.
- [x] **보스 런당 1회**: `pickBoss`가 사용된 보스 제외(티어 소진 시 타 티어 미사용분), `_startRun`에서 `usedBosses.clear()`.

## A. 전투 기반 시스템
- [x] A1. `StatusKind`에 **stun/bleed** 추가 + `_updateStatuses`에서 bleed(tick) / stun(행동불가·플린치) 처리. *(기존 추가요청서 완료)*
- [x] A2. **보스 stun 면역** — `Entity.addStatus`에서 `this is Boss && k==stun`이면 무시. *(완료)*
- [x] A3. **넉백/경직 헬퍼** `Entity.applyKnockback(vx,vy)` 존재 → 공격/스킬 적중부에서 호출. *(boss smash/player slam/hammer 등 적용 점검)*
- [x] A4. **상태이상 데미지 = 가해자/난이도 비례** — 몬스터/함정 DoT는 `_foePow(base)=base*(0.5+floor*0.09)`로 층 비례, 플레이어 스킬 DoT(flames/explode burn)는 `*mul`(atkMul) 비례. *(완료)*
- [x] A5. **보스 기본공격 대형 텔레그래프** — 평타를 `'basic'` 패턴으로 만들어 windup 상태(확대 펄스+붉은 오라+붉은 눈, 0.4s)를 거친 뒤 런지 슬래시. 즉발 공격 제거 → 인지 가능. *(완료)*

## B. 몬스터 → 플레이어 상태이상 wiring
- [x] B1. 적 **접촉** 시 상태이상 wiring(`_contactProc`): goblin=출혈, slime/plant=중독, hammer=기절+강넉백, shield/dwarf=넉백. 투사체 onHit·함정 burn도 연결됨. *(완료, 단 floor<6 차단)*
  - 남음: 적 **원거리 투사체**에 속성 상태이상 부여(B2의 fireMage 등과 함께).
- [x] B2. **불속성 몬스터 분리** — `EnemyKind.fireMage` 신규(enum/`_makeEnemy`/`_updateEnemy`/`_contactDmg`/painter `_fireMage`). 불타는 오브를 쏘고 `onHit: burn`(`_foePow` 층비례). 기존 `mage`는 비화염 유지. (접촉: slime/plant=poison, hammer=stun+강넉백 — B1 완료)
- [x] B3. **고층 편중** — `floor<6` 행동 차단 + `level_gen`에서 fireMage는 **6층+ 화염 바이옴**(volcano/magma/dragonLair)에서만, 깊을수록 확률↑(`0.12+floor*0.015`).

## C. 신규 몬스터 / 보스 (외형 + 행동)
- [x] C1. **인간형 몹 5종 추가** — 암살자(도약 돌진+출혈)·이단자(저주 시전, 약화)·도둑(히트앤런+골드 약탈)·기사단원(`knightSoldier`: 텔레그래프 돌진 베기, 장갑)·주먹왈패(`brawler`: 빠른 연타). 각 바이옴/층 스폰.
- [x] C2. **대형 적·보스 추가 완료** — 보스: **거미 여제(`spider`)**·**드래곤(`dragon`)**·**용인족 전사(`dragonkin`)** → 보스 총 **19종**. 몹: **가고일(`gargoyle`)**(비행 석상, 급강하 다이브) + **구울(`ghoul`)**(언데드 도약 + 중독). 미노타우루스≈brute/redBear, 용병단원≈mercenary 보스로 기존 커버.
- [x] C3. **plant(육식식물) 뒤레이어** — painter에서 지면보다 먼저 그려 묻힌 몸통은 지형에 가려지고, 플레이어 감지(거리<170) 시 머리가 지면 위로 크게 돌출(`headY -= rise*16`)해 독액 발사. *(완료)*
- [x] C4. **shielded knight + 파괴 수정** — shield 적이 있는 방에 발광 수정(`shieldCrystal`, HP 60+floor*4) 배치. 수정이 살아있으면 방패 상시 유지 + 피해 0.12배(거의 무적). 근접/투사체로 수정 파괴 시 방패 해제(배너+입자). painter `_shieldCrystal`.
- [ ] C5. hammer 계열(강넉백+스턴) `_makeEnemy`/`_updateEnemy` 케이스 정비. *(기본 hammer는 존재 → 스턴/넉백 강화)*
- [x] C6. 남은 일반몹 7종 외형 개편(외곽선+음영+발광눈) — mage/archer/darkElf/slime/plant/hammer/shield. *(완료)*

## D. 직업별 패시브 (특색 강화)
- [x] D1. 패시브 배선 — 카테고리+티어 기반으로 world에서 적용(`_passiveAtkMul`/`_playerOnHit`). 별도 필드 없이 기존 category/tier/weapon에서 파생.
- [x] D2. 카테고리별 핵심 패시브 (등급 비례):
  - 검사/권사/창병: 공격력↑ (+5%~+20%, `atkMul`에 반영)
  - 도적(특수형 단검/낫): 적중 시 **출혈**(atk·티어 비례)
  - 궁수형: 적중 시 **둔화**
  - 마법형: 30% 확률 **화상**(atk·티어 비례)
  - 저격수: 4~7% 확률 **즉사**(보스 제외)
  - 기사: 받는 피해 -12% (패시브)
- [x] D3. 범용 패시브 풀 — **`PassiveKind` 시스템**(skulls.dart `kPassives`: 스컬별 13종 — atkUp/armor/evade/lifesteal/crit/bleedHit/burnHit/poisonHit/slowHit/stunHit/execute/berserk/regenIdle, 설명 자동생성 `passiveDesc`)으로 구현. world의 `_passiveAtkMul`/`_critMul`/`_playerOnHit`/`_perkEvade`/armor/lifesteal/regenIdle가 모두 `_passive`에 위임(중복 적용 없음). 추가로 **이단 점프**(`_skullAgile`)·**추가 대시**(`_skullExtraDash`) 기동 퍽 공존.
  - 선택 확장(미구현): 영혼/골드 획득↑·각종 저항·피격 순간이동 — 새 `PassiveKind` 추가 + 일부 스컬 재배정 필요(현재 스컬별 패시브는 의도 배정이라 임의 변경 보류).

## (보스) 신규 공격 패턴 — 8차 추가
- [x] **triplesmash** — 3연속 도약 + 착지마다 대지강타. → golem/rockBrute/redBear
- [x] **swordbeam** — 일자 관통 검기(3중) 발사. → knight/mercenary/doppel
- [x] **divebomb** — 비행 보스: 도약 후 관측 위치로 대각 내리찍기(`aimX` 락온). → eagle/worm
- [x] **vortex** — 플레이어를 끌어당겨 폭발. → witch/demonKing/mummy
- 모두 windup 텔레그래프(0.4~0.7s) 경유 + 적절 보스 패턴 풀 배정.

## E. 맵 연출 / 지형 생성
- [ ] E1. **맵 레퍼런스 기반 오브젝트 자연 배치** + 배경·지형 자연 생성. (레퍼런스 `map/`)
- [ ] E2. **이동 연출 오브젝트**: 타고 오르는 플랫폼, 순간이동 오브젝트 등으로 맵 탐험성↑.
- [ ] E3. **무결성 보장(필수)**: 지형 관통 이동/땅속 순간이동/복귀 불가(soft-lock) 지형이 **절대 생기지 않도록** 검증.
- [x] E4. **클리어 시 함정 비활성** — `_updateTraps`에서 `roomCleared`면 early-return → 모든 함정 휴면. *(완료. 추후 painter에서 휴면 스파이크 시각 디밍 가능)*

---

## 진행 규칙 (재개 시 반드시 따를 것)

1. 작업 시작 전 이 문서 **[현재 상태]** 절을 읽는다.
2. 한 Phase의 한 항목을 끝내면 즉시 체크박스 갱신 + **[현재 상태]** 갱신(무엇을 끝냈고 다음이 무엇인지).
3. 각 코드 변경 후 `flutter analyze`로 **에러 0** 유지.
4. Phase는 1→7 순서 권장(뒤로 갈수록 앞 시스템에 의존).
5. 토큰 소진으로 끊기면, 사용자가 "이어서" 지시 시 [현재 상태]에서 재개.
