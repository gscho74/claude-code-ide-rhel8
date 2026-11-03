# Claude IDE for Emacs — RHEL 8 배포 소스 묶음

현재 사용 중인 codex-ide 0.5.0의 편집기 컨텍스트, 선택 영역 전달,
Ghostel 한글 조합/백스페이스/입력 반영 보정을 가져온 별도 Claude Code 버전입니다.
기존 ~/.emacs.d와 Codex 설정은 수정하지 않습니다. 계정/토큰/대화 기록은 포함하지 않습니다.

## Git 체크아웃과 배포 압축 파일의 차이

Git에는 소스·설치/빌드 스크립트·테스트를 저장합니다. 생성된 Ghostel 바이너리와
Zig 의존성 캐시, 빌드 로그·체크섬은 `.gitignore`로 제외합니다.
아래의 “동봉 모듈” 안내는 미리 만든 **배포 tar.gz**에 해당합니다.
Git으로 받은 경우 Zig 0.16.0을 설치하고 `bash scripts/build-ghostel.sh`를 먼저 실행하세요.

## 빠른 시작 (Emacs 28.1+와 Claude CLI가 이미 있는 RHEL 8 x86_64)

```bash
tar -xzf claude-ide-rhel8-x86_64-20261103.tar.gz
cd claude-ide-rhel8
bash scripts/install.sh
```

설치 스크립트가 출력하는 `(load ...)`를 Emacs init에 추가하고 Emacs를 다시 시작합니다.
`C-c a n`으로 실행하세요. x86_64용 Ghostel 모듈과 compat 소스는 포함되어 있습니다.
Emacs/Claude가 아직 없거나 ARM 장비이면 아래 설치 순서를 따르세요.

## 지원 범위

- RHEL 8 **x86_64용 Ghostel 바이너리 + 설치·소스 빌드 키트**. aarch64는 소스 빌드 경로를 제공합니다. RPM이나 Emacs/Claude까지 포함한 완성된 오프라인 실행 이미지는 아닙니다.
- Emacs 28.1 이상 + 동적 모듈 지원 필요. 검증한 개발 호스트는 Ubuntu/Emacs 30.2입니다.
  RHEL 기본 Emacs가 오래된 경우 아래 스크립트로 30.2를 별도 설치하세요.
- Python 3.6 이상. RHEL의 python3가 없으면 python36 또는 python39를 설치하고 경로를 지정하세요.
- Claude Code CLI 및 사용 가능한 인증/네트워크 연결 필요. 로그인은 대상 장비에서 수행합니다.
- Ghostel 소스 20261027.833, revision 97ec8f16eb90 포함. **Zig 0.16.0 정확히 필요**.
- 현재 Ubuntu의 ghostel-module.so는 glibc 2.34를 요구하므로 제외했습니다.
  동봉 모듈은 x86_64-linux-gnu.2.28 / baseline으로 새로 빌드했고 최대 요구 GLIBC_2.28을 확인했습니다. 사용한 Zig 의존성 소스 아카이브는 vendor/zig-cache/p에 포함했습니다.
- 새 모듈 로딩과 Ghostel 실제 PTY 입출력은 개발 호스트에서 통과했습니다. RHEL 8 실장비 실행, GUI 한글 입력 및 Claude 인증/실제 응답은 이 호스트에서 검증할 수 없습니다.

## 설치 순서

1. 이 폴더를 RHEL 8에 복사한 뒤 설치합니다. 기존 경로는 덮어쓰지 않습니다.

```bash
bash scripts/install.sh
cd ~/.local/share/claude-ide
```

2. Emacs 28.1+와 모듈 지원을 확인합니다. 부족하면 관리자가 개발 패키지를 설치한 후 빌드합니다.
   저장소 구성에 따라 일부 개발 패키지는 CodeReady Builder 저장소가 필요합니다.

```bash
sudo dnf install gcc gcc-c++ make gtk3-devel libXpm-devel libjpeg-turbo-devel giflib-devel libtiff-devel gnutls-devel ncurses-devel jansson-devel librsvg2-devel libpng-devel texinfo pkgconf-pkg-config curl tar xz python3 binutils
bash scripts/build-emacs.sh
export PATH="$HOME/.local/opt/emacs-30.2/bin:$HOME/.local/bin:$PATH"
```

3. compat 30.1.0.1 소스를 함께 넣었으므로 Emacs 패키지 다운로드는 필요하지 않습니다.

4. x86_64는 동봉한 모듈을 그대로 사용할 수 있어 이 단계를 생략합니다. aarch64 또는 재빌드 시 https://ziglang.org/download/ 에서 OS/CPU에 맞는 Zig **0.16.0**을 설치하고 PATH에 넣은 다음 아래를 실행합니다. 동봉한 소스 의존성 캐시를 사용하며 누락된 의존성은 온라인으로 가져옵니다.

```bash
bash scripts/build-ghostel.sh
```

5. Claude Code는 조직의 배포 정책에 맞게 설치합니다. 공식 온라인 설치 방법:

```bash
curl -fsSL https://claude.ai/install.sh | bash
claude --version
claude
```

로그인 및 최초 신뢰/권한 확인을 마치고 종료합니다. 이 묶음은 Claude 권한 우회를 설정하지 않습니다.
RHEL 8은 현재 공식 시스템 요구사항의 명시 OS 목록에 없으므로 CLI 실행 여부부터 확인하세요.

6. Emacs init 파일에 아래 한 줄을 추가합니다(설치 스크립트도 정확한 경로를 출력합니다).

```elisp
(load (expand-file-name "~/.local/share/claude-ide/claude-ide-init.el") nil t)
```

7. 점검 후 GUI Emacs에서 실행합니다.

```bash
bash scripts/doctor.sh
emacs
```

GUI 세션 또는 X11 forwarding이 필요합니다. DISPLAY를 임의로 wayland-0으로 설정하지 마세요.
한글 폰트는 D2Coding 또는 Noto Sans Mono CJK KR을 준비하세요. Windows 전용 폰트는 동봉하지 않습니다.

## 사용

- `C-c a a`: 메뉴, `C-c a n`: 새 세션, `C-c a s`: Claude 자체 대화 재개 선택기
- `C-c a p`: 질문과 현재 파일/선택 영역 전달, `C-c a r`: 선택 영역 질문
- `C-c a c`: 컨텍스트 지우기. 새 파일/영역 선택 시 다시 공유됩니다.
- 터미널 안 `C-c C-p`도 컨텍스트를 붙여 질문합니다.
- 직접 터미널에 입력한 질문은 Claude의 `emacs_editor/get_editor_context` MCP 도구로 최신 선택을 확인합니다.
  도구 사용 승인 여부는 Claude UI에서 결정합니다. 필요하면 “Emacs에서 선택한 코드 확인해줘”라고 요청하세요.
- 한영 전환: `C-\` 또는 한/영 키. Right Alt 매핑은 기존 PGTK 설정을 유지했지만
  RHEL의 GTK/X11에서는 데스크톱 키 매핑에 따라 다를 수 있습니다.
- 파일 수정은 Claude Code 자체 Edit/Write 도구와 권한 흐름이 수행합니다.
  MCP 브리지는 현재 파일/커서/선택/진단을 읽는 용도이며 편집을 실행하지 않습니다.
- 저장하지 않은 변경은 선택 영역 컨텍스트에 포함될 수 있습니다. 디스크 파일을 수정시키려면 먼저 저장하세요.
- 기존 Codex 전용 App Server/Ediff 승인, 대화 삭제/아카이브, Codex 색상/입력창 보정은 가져오지 않았습니다.
  변경 검토는 Git diff 또는 Emacs VC로 수행하세요. Claude 재개는 Claude 자체 선택기를 사용합니다.

## 설정

```elisp
(setq claude-ide-executable "/path/to/claude"
      claude-ide-python-executable "python3.9"
      claude-ide-permission-mode "default") ; 또는 "plan"
;; Ghostel 빌드 전 임시 대안 (Ghostel 전용 한글 보정은 적용되지 않음)
(setq claude-ide-terminal-backend 'term) ; 설치되어 있다면 'vterm 도 가능
```

다른 Emacs 패키지나 테마, 회사 프로젝트 경로는 복사하지 않았습니다.
기존 Codex IDE와 이름 공간이 분리되어 병행 로드할 수 있습니다.

## 검증 및 제한

`tests/run.sh`로 CLI 인수·선택 영역·MCP UTF-8/오류 처리와 가짜 CLI를 통한 터미널 연결을 검사합니다.
실제 Claude 모델 호출은 테스트에 사용하지 않습니다. TEST-RESULTS.md의 실제 수행 결과를 확인하세요.
x86_64 네이티브 모듈은 빌드 및 개발 호스트 로딩을 확인했습니다. GUI/Claude 로그인과 RHEL 8 실장비 실행은 추가 확인해야 합니다.
완전한 오프라인 배포에는 Emacs 소스/개발 RPM 또는 실행 환경, 필요 시 Zig 컴파일러, Claude 실행 파일과 서비스 연결 경로를 별도로 준비해야 합니다.

참고: https://code.claude.com/docs/en/setup
https://code.claude.com/docs/en/cli-reference
https://github.com/dakra/ghostel
