# Games Portfolio site

이 폴더는 게임들을 동일 페이지에서 바로 플레이할 수 있도록 임베드한 정적 사이트입니다.

설치 및 배포 (GitHub Pages):

1. 이 리포지토리를 GitHub에 푸시합니다.
2. 리포지토리의 `gh-pages` 브랜치 또는 `main` 브랜치를 GitHub Pages로 설정하세요.

3. 기본 경로(루트)로 페이지를 서빙하면 `site/index.html`에 접근하려면 리포지토리 루트로 이동한 뒤 `site/`를 열어야 합니다. 더 쉬운 방법은 `site/` 내용을 루트로 옮기거나 GitHub Actions로 `site/` 내용을 `gh-pages` 브랜치로 배포하는 것입니다.

GitHub Pages 자동배포 (이미 워크플로우 추가됨):

- 이 저장소의 `main` 또는 `master` 브랜치에 푸시하면 `.github/workflows/deploy-site.yml`이 `site/` 폴더 내용을 `gh-pages` 브랜치로 배포합니다. 추가 설정은 필요 없습니다.

AdSense 설정 (자리표시자 포함):

- `site/index.html`과 `site/portfolio.html`에 주석으로 예시 스니펫을 넣어두었습니다. 배포 전에 아래 항목을 수정하세요:
	- `data-ad-client`에 당신의 `ca-pub-XXXXXXXX` 값을 넣으세요.
	- 광고 슬롯(`data-ad-slot`) 번호는 AdSense에서 생성한 슬롯을 사용하세요.

로컬 테스트:

```powershell
# 파워셸에서 (Python이 설치된 경우)
python -m http.server 8000

# 또는, Node.js가 있다면
npx http-server -c-1
```

브라우저에서 `http://localhost:8000/site/index.html`을 열어 테스트하세요.
