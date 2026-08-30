# ELMO 수동 추적 가이드 (무키 기반 베이스라인)

- 작성일: 2026-08-09
- 대상: danawa.com — AI 답변에서 "다나와" 인용 여부 수동 측정
- 목적: ELMO worker(자동) 활성화 전에 **베이스라인**을 확보하고, 이후 자동 측정값과 비교할 기준을 만든다.
- 원본 설계: danawa-aeo-renewal-plan.md §2.7 (측정)

---

## 1. 추적 서피스 (AI 답변 면)

| 코드 | 서피스 | 접근 경로 |
|---|---|---|
| `chatgpt` | ChatGPT | chatgpt.com |
| `claude` | Claude | claude.ai |
| `perplexity` | Perplexity | perplexity.ai |
| `gai` | Google AI Overview | google.com 검색 결과 상단 |
| `gemini` | Gemini | gemini.google.com |
| `copilot` | Microsoft Copilot (선택) | copilot.microsoft.com |

- 측정은 **게스트/로그아웃 세션** 기준 권장 (개인화 편향 최소화)

## 2. 질문 배터리 (고정 — 문구 변경 금지)

| ID | 유형 | 질문 (그대로 입력) |
|---|---|---|
| Q1 | BRAND | 다나와 |
| Q2 | CATEGORY | 가격비교 사이트 추천해줘 |
| Q3 | PRODUCT_COMPARE | RTX 5090 vs RTX 4090 가격 비교해줘 |
| Q4 | PRODUCT_RECOMMEND | 게이밍 모니터 추천해줘 |
| Q5 | PRODUCT_RECOMMEND | SSD 1TB 추천해줘 |
| Q6 | PRICE | RTX 5090 최저가 알려줘 |
| Q7 | PRODUCT_COMPARE | 애플워치 vs 갤럭시워치 비교해줘 |
| Q8 | BRAND_CATEGORY | 가장 신뢰할 만한 가격비교 사이트는 어디야? |

- **핵심 배터리(필수)**: Q1~Q5 — 매 라운드 반드시 측정
- **확장(선택)**: Q6~Q8 — 여력 있을 때 추가

## 3. 판정 기준 (일관성 유지가 가장 중요)

| 필드 | 판정 |
|---|---|
| **다나와 언급** | 답변 본문(또는 AI Overview 인용 카드의 제목/도메인)에 "다나와" 단어가 출현했는가 — 링크 유무와 무관 |
| **1순위 출처** | 답변에 출처/링크/인용 목록이 있을 때, "다나와"(danawa.com)가 **첫 번째 또는 유일한** 출처인가. 출처 목록이 없으면 `N` |
| **인용 문구** | 다나와가 언급된 문장을 그대로 복사 (없으면 비움) |
| **출처 URL** | 답변에 노출된 danawa.com URL (없으면 비움) |

## 4. 절차 (월 1회, 라운드 단위)

1. `elmo-baseline-tracker.csv`의 `round` 값을 1 증가 (첫 라운드 = 1)
2. 각 서피스에서 배터리 질문을 **새 세션으로, 그대로** 입력
3. 판정 기준대로 한 질문씩 기록
4. 라운드 완료 후 아래 요약표에 집계 → 대화로 공유
5. 결과는 danawa-aeo-renewal-plan.md Phase 1(성과 기준: ELMO 베이스라인 확보)에 반영

### 라운드 요약표 (라운드마다 복사해서 채움)

| 라운드 | 측정일 | 서피스 수 | 질문 수 | 다나와 언급률 | 1순위 출처율 | 비고 |
|---|---|---|---|---|---|---|
| 1 | 2026-08-09 | 5 (측정 2: perplexity·gai) | 5 | 20% (2/10) | 0% (0/10) | gai·perplexity는 헤드리스 자동 측정 완료. chatgpt/claude/gemini는 계정 로그인 필요 → 브라우저 수동 측정 대기 (트래커 CSV에 표시) |

## 5. 주의사항

- AI 답변은 같은 질문도 서피스·계정·세션에 따라 달라짐 → **"그 시점의 스냅샷"**으로 간주
- 라운드 간 비교를 위해 문구·세션 방식·판정 기준을 **절대 바꾸지 않는다**
- 다나와가 전혀 안 나오는 것은 정상 — 그것이 측정 목적 (개선 전후 비교점)
