# AllRouter LiteLLM — Bytez fallback tier

Bytez(serverless inference, 220k+ 모델)를 AllRouter 최후 fallback 티어로 추가하는 준비물.

## 상태

- **Bytez 키**: `<BYTEZ_API_KEY>` (Free 플랜, ≤7B / 동시 1, $1 크레딧, active) — 실제 키는 개인 환경변수/시크릿으로만 보관 (커밋 금지)
- **키 규격**: `Authorization: Key <key>` (SDK bytez.js v3.0.0 기준)
- **LiteLLM 규격**: `BYTEZ_API_KEY` env + `model: bytez/<org>/<repo>`
- **선택 모델**: `bytez/meta-llama/Llama-3.2-3B-Instruct` (3B, chat — Free 플랜 한도 내)
- **차단 항목 (2026-08-16 기준)**:
  1. Bytez 카탈로그 API 장애 — `list/models` 빈 배열, 모든 modelId "Model does not exist".
     공식 GitHub 이슈 #59(2026-08-05, open), #60(2026-08-11, open) 참조. 카탈로그 복구 전까지
     `bytez/` 호출은 오류 반환 → 통합 자체는 무해하나 실사용 불가.
  2. VPS 파일 접근 불가 — AllRouter 서버 Tailscale 노드 `privseai`(100.92.78.41:2222) 32일째 오프라인.
     LiteLLM API는 `https://allrouter.privseai.com/api/llm/...` 프록시로 동작 확인됨.

## 적용 절차 (SSH 복구 후)

서버(`/opt/allrouter/litellm`)에서:

```bash
# 1. 스크립트 실행 (config.yaml 백업 자동 생성, 멱등)
python3 apply-bytez.py --key $BYTEZ_API_KEY --dir /opt/allrouter/litellm

# 2. 적용 확인
cd /opt/allrouter/litellm && docker compose up -d --force-recreate allrouter-litellm

# 3. 스모크 테스트 (프록시 4001)
curl -s http://localhost:4001/v1/models | grep -i bytez
```

### 적용 내용

1. `.env` → `BYTEZ_API_KEY=<실제 키>` 추가
2. `docker-compose.yml` → allrouter-litellm 서비스 env에 `BYTEZ_API_KEY: ${BYTEZ_API_KEY}` 추가
3. `config.yaml` → 아래 별칭 그룹 각각의 model_list 맨 끝에 bytez 엔트리 추가:

```yaml
- model_name: <별칭>
  litellm_params:
    model: bytez/meta-llama/Llama-3.2-3B-Instruct
    api_key: os.environ/BYTEZ_API_KEY
```

대상 별칭 그룹(실행 중인 프록시 `/v1/models`에서 확인한 목록):

| 그룹 | 현행 구성 |
|---|---|
| `big-pickle` | openrouter nemotron-3-ultra-550b:free → gpt-oss-20b:free → … → openai/auto/glm |
| `deepseek-v4-pro` / `deepseek-v4-flash` | DeepSeek v4 계열 |
| `kimi-k2.6` / `kimi-k2.7-code` / `kimi-k3` | Kimi 계열 |
| `minimax-m2.5` / `minimax-m2.7` / `minimax-m3` | MiniMax 계열 |
| `glm-5.1` | GLM 계열 |
| `qwen3.6-plus` | Qwen 계열 |

> 참고: big-pickle은 `openai/auto/*` 라우터 그룹이 이미 존재하므로, bytez는 해당 그룹 최후 fallback이 됨.

> **주의**: 스크립트는 PyYAML로 `config.yaml`을 다시 직렬화하므로 기존 주석/포맷이 제거됩니다.
> 원본은 `config.yaml.bak-bytez-<타임스탬프>`로 백업됩니다. 주석 보존이 중요하면
> 스크립트 대신 위 스니펫을 수동으로 해당 그룹 끝에 추가하세요.

## 확인 이력

- Bytez 키 인증 통과, 크레딧 $1 정상, `list/tasks` 정상
- 카탈로그: 웹(bytez.com/models RSC)과 GraphQL(`models { id }`)에는 `meta-llama/Llama-3.2-3B-Instruct`,
  `google/gemma-4-E4B-it` 등 실제 모델 존재하나, REST API 서빙 카탈로그가 비어 있음
- `request/{modelId}` 응답: "Cannot queue job: Job previously succeeded" (모델은 이미 처리됨)
