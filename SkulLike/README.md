# SkulLike

"Skul: The Hero Slayer" 스타일의 2D 픽셀 로그라이트 게임 (Flutter + CustomPainter).

해골(스컬)을 갈아끼우며 직업을 바꿔 싸우는 횡스크롤 액션 로그라이트입니다.
등급별 스컬(일반·희귀·영웅·전설), 각 스컬 고유의 스킬·패시브·무기, 16개 지역(바이옴)과
다양한 보스가 등장합니다.

## 실행

### Windows — 배치 파일 더블클릭 (가장 간편)

- **`게임실행.bat`** — 이미 빌드된 게임을 바로 실행 (브라우저 자동 실행, 포트 8777). 재빌드하지 않아 빠릅니다.
- **`빌드후실행.bat`** — 소스를 수정했을 때: 웹을 다시 빌드한 뒤 실행합니다.

> Flutter와 Python(로컬 웹서버용)이 설치돼 있어야 합니다.

### Flutter CLI

```bash
flutter run -d chrome     # 브라우저 (권장)
flutter run -d windows    # 데스크톱 앱
flutter build web         # 웹 배포 번들 빌드 → build/web
```

또는 IDE(VS Code / Android Studio)에서 `lib/main.dart`를 열고 디바이스 선택 후 ▶ Run.

## 조작

- **←/→** 이동 · **↑ / Space** 점프 · **A** 공격 · **Shift** 회피 · **S** 스킬 · **Q** 스컬 교체 · **E** 상호작용
- **1 / 2** — 스컬 상자/드롭 앞에서 해당 슬롯에 장착
- **용기병**의 *용의 비상*(비행) 중에는 **↑/↓** 로 자유롭게 상하 이동

## 프로젝트 구조 (`lib/game`)

| 파일 | 역할 |
|------|------|
| `skulls.dart` | 스컬 스탯·스킬·패시브·무기 정의 |
| `world.dart` | 게임 루프 · 전투 · 스킬 · 적/보스 AI 로직 |
| `painter.dart` | 모든 렌더링 (CustomPainter, 픽셀아트) |
| `entities.dart` | 플레이어·적·소환수·보스 엔티티 |
| `types.dart` | 공용 enum·데이터 타입·바이옴 |
| `level_gen.dart` | 방/층 절차적 생성 |
| `meta.dart` | 영구 진행도(소울·업그레이드·특성) 저장 |

## 테스트

```bash
flutter test
```

## 개발 / 콘텐츠 추가

구조·시스템·스컬/보스 추가 방법은 [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md),
개발 계획은 [`docs/ROADMAP.md`](docs/ROADMAP.md) 를 참고하세요.
