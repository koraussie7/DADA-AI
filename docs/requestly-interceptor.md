# Requestly Desktop Interceptor — AllRouter 폴백 시뮬레이션 가이드

## 설치 상태 (2026-08-16)

| 항목 | 값 |
|---|---|
| 앱 | Requestly Desktop **26.6.29** (`C:\Users\korau\AppData\Local\Programs\requestly`) |
| 프록시 | `127.0.0.1:8281` (HTTP 프록시, HTTPS MITM 활성) |
| Root CA | `RQProxyCA` → `Cert:\CurrentUser\Root` 등록 완료 (사용자 저장소) |
| MITM 검증(curl) | `curl -x http://127.0.0.1:8281 https://allrouter.privseai.com/` → **200** |
| MITM 검증(Node) | `HTTPS_PROXY` + `NODE_EXTRA_CA_CERTS` 설정 후 `fetch` → **200** |
| CA 파일 | `%APPDATA%\Requestly\.tmp\certs\ca.pem` |
| 참고 | 시스템 프록시는 **미변경** (브레이크 방지, 아래 "프록시 연결" 참고) |

## 트래픽 유형별 프록시 연결 방법

### 1) curl (즉시 테스트)
```powershell
curl.exe -s -x http://127.0.0.1:8281 --ssl-no-revoke "https://allrouter.privseai.com/"
```
> schannel 리보케이션 검사 오류(`CRYPT_E_NO_REVOCATION_CHECK`)는 Windows curl에서만 발생.
> Node/브라우저 기반 클라이언트는 해당 없음.

### 2) 브라우저 (시스템 프록시 경유)
Requestly 앱 GUI의 **Interception 토글** 켜면 자동으로 시스템 프록시가 `127.0.0.1:8281`로 설정됨.
브라우저는 Windows 인증서 저장소를 쓰므로 CA 등록(완료)만으로 MITM 인증서 신뢰 가능.

### 3) Node 기반 CLI (opencode / Claude Code)
Node는 시스템 프록시를 무시 → env var로 명시 필요. CA도 Node가 별도 로드.
```powershell
$env:HTTPS_PROXY  = "http://127.0.0.1:8281"
$env:HTTP_PROXY   = "http://127.0.0.1:8281"
$env:NODE_EXTRA_CA_CERTS = "$env:APPDATA\Requestly\.tmp\certs\ca.pem"
```
> 주의: 현재 세션의 opencode는 이 프록시 없이 실행 중이므로, 시스템 프록시 전역 변경 시
> 기존 세션 TLS가 끊길 수 있음. 신규 셸에서만 적용 권장.

## 폴백/장애 시뮬레이션 규칙 (앱 GUI에서 생성)

Requestly 앱 → **Rules** → 각 규칙 유형 생성. 아래 사양 그대로 입력.

### 시나리오 A — 업스트림 장애(503) 주입 → 클라이언트 폴백 검증
| 필드 | 값 |
|---|---|
| Rule Type | **Mock API** |
| Source URL | `allrouter.privseai.com/*` (또는 대상 업스트림 도메인) |
| Response | **503 Service Unavailable** |
| Body | `{"error":"simulated outage"}` |

검증: 프록시 경유로 opencode/claude 실행 시 이 요청이 503을 받아
OmniRoute 폴백(`nv-*`/`cs-*`) 또는 다른 provider로 전환되는지 관찰.

### 시나리오 B — 지연 주입 → OmniRoute timeout/retry 검증
| 필드 | 값 |
|---|---|
| Rule Type | **Delay** |
| Source URL | `allrouter.privseai.com/*` |
| Delay | `10000` ms |

검증: OmniRoute `requestRetry`/타임아웃 경로가 실제로 발동하는지 확인.

### 시나리오 C — 헤더/모델명 리라이트 → alias 스위치 실전 검증
| 필드 | 값 |
|---|---|
| Rule Type | **Modify / Redirect** |
| Source URL | `allrouter.privseai.com/*` |
| 액션 | 요청 헤더 `model` 값을 `nv-glm-5.2` 등으로 교체 |

검증: 응답 `x-omniroute-route-class` / `x-omniroute-cache` 헤더로 실제 라우팅 경로 확인.

### 시나리오 D — 응답 캡처(세션 리플레이)
Requestly 앱의 **Sessions** 탭에서 프록시 경유 트래픽 전체 기록.
`x-omniroute-route-class` 헤더로 요청이 어떤 노드를 타는지 로그로 확인.

## 유틸리티

```powershell
# 프록시 상태 확인
Get-NetTCPConnection -State Listen | Where-Object LocalPort -eq 8281

# CA 재등록 (앱 재설치 후 인증 오류 시)
certutil -user -addstore -f "Root" "$env:APPDATA\Requestly\.tmp\certs\ca.pem"

# 시스템 프록시 해제 (GUI 토글 OFF 대신 수동으로 되돌릴 때)
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 0
```
