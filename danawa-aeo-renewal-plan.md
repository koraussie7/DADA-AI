# 다나와(danawa.com) AEO 기반 사이트 리뉴얼 플랜

- 작성일: 2026-08-09
- 대상: danawa.com (주)커넥트웨이브 — 온라인 가격비교 플랫폼
- 목적: 생성형 AI(답변엔진)에서 다나와가 "가격·스펙 비교의 **출처**"로 인용되도록 하는 AEO(Answer Engine Optimization) 리뉴얼
- 전제: 다나와는 전통 SEO가 이미 우수함. 본 플랜은 "기존 SEO 자산을 AI 인용 체계로 전환"하는 고도화 중심

---

## 1. 현황 분석

### 1.1 플랫폼 구조 (서브도메인 맵)

| 도메인 | 역할 |
|---|---|
| www.danawa.com | 메인/가격비교 진입 |
| prod.danawa.com | 상품 리스트(PLP)/상품 상세(PDP) — `?pcode=` 기반 PHP |
| search.danawa.com | 통합검색 |
| dpg.danawa.com | 뉴스룸·구매가이드·커뮤니티(DPG) |
| shop.danawa.com | 샵다나와 (조립PC/유통) |
| auto / tour / brand / review | 자동차·여행·브랜드로그·리뷰 |
| auth / help / adcenter | 로그인·고객센터·광고센터 |

### 1.2 보유 강점 (AEO에 유리한 자산)

- **방대한 정형 데이터**: 상품 스펙 테이블, 가격 변동 추이(1/3/6/12개월), 등록년월, 별점·리뷰·평점 수, 배송/가격 필터 — AI가 인용하기 가장 좋은 구조
- **엔티티 분류 체계**: `남성신발 > 샌들/슬리퍼 > 플립플랍` 같은 cate 계층 = 곧 엔티티 그래프
- **VS검색**: 상품 스펙 간 비교 데이터 — 다만 JS 기반 도구로 크롤링 불가
- **구매가이드/히트브랜드/트렌드 리포트**: 데이터 기반 기사 다량 보유 — 질문형 콘텐츠로 재편 가능
- **MCP 서버 출시(2026-08-05, 바이라인네트워크·디지털데일리 보도)**: 국내 가격비교 플랫폼 최초 AI 가격비교 MCP — 클로드 **커넥터(Connectors)** 실시간 연동(대화창 좌하단 `+` → 다나와 선택). 국내 50+ 이커머스 수집·약 14억 상품 DB를 자연어 조건(가격대·스펙·후기·구매처) 질의로 탐색. 커넥트웨이브는 "AI 쇼핑 생태계의 데이터 허브"로 포지셔닝. AI 생태계 진입의 핵심 레버
- **전통 SEO**: 서브도메인+사이트맵+robots.txt 관리, PDP 메타데이터, PLP 대응 검색결과 페이지 (SEO 평론 확인)

### 1.3 AEO 관점 문제점 (GAP)

| # | 문제 | AEO 영향 |
|---|---|---|
| 1 | **LLM 크롤러 접근성 불명확 (차단 심각도 확인됨)** | **2026-08-09 로컬 가정 IP 검증**: 브라우저 UA·crawlie·헤드리스 크롬 전부 403 — WAF가 IP/TLS 핑거프린트 단위로 비브라우저 트래픽 차단(robots.txt조차 403). 서브도메인(prod/dpg/search/help/shop) 전부 동일. 즉 GPTBot·ClaudeBot·PerplexityBot 등 **AI 크롤러도 403 가능성 극히 높음** → AEO 최우선 차단 이슈 |
| 2 | **llms.txt 부재** | LLM 지식베이스용 표준 진입 파일 없음 → AI가 사이트 내부 구조 파악 어려움 |
| 3 | **PDP가 JS/PHP 동적 렌더링** | `?pcode=` 파라미터 URL + 동적 렌더링 → AI 크롤러가 스펙/가격 원문 추출 실패 가능 |
| 4 | **질문형(comparison/FAQ) 콘텐츠 부족** | "RTX 5090 vs 4090" 같은 질문에 AI가 다른 사이트 인용. VS검색은 도구라 인용 대상이 아님 |
| 5 | **스키마가 리치스니펫 지향** | Product/Offer 존재하나 AEO용 `@graph`(엔티티 통합), `FAQPage`, `ItemList`, `BreadcrumbList`, `hasVariant`, `priceValidUntil` 통합 부족 |
| 6 | **브랜드 엔티티 명시 부족** | "다나와 = 가격비교의 권위"를 Organization/SameAs/시장데이터로 AI가 명확히 인지하도록 하는 명시 선언 부재 |
| 7 | **신뢰 근거(출처) 연결 부재** | 히트브랜드 선정 근거, 가격 데이터 출처, 리뷰 집계 기준이 명시된 참조 구조가 없음 |
| 8 | **AI 가시성 측정 부재** | ChatGPT/Claude/AI Overview에서 다나와 언급률을 추적하는 체계 없음 (ELMO 등 도입 필요) |

### 1.4 경쟁사 접근성·GEO 벤치마크 (crawlie 0.5.3, 2026-08-09)

로컬 crawlie로 한국 커머스/가격비교 사이트 접근성과 GEO 준비도를 실측. 결론: **한국 커머스는 전반적으로 봇 차단 + GEO 공백 상태** — 다나와만의 문제가 아니며, AEO 선점 기회임을 확인.

| 사이트 | 접근성 | GEO 점수(홈) | 비고 |
|---|---|---|---|
| danawa.com | **403** (WAF, IP/TLS/헤드리스 전부 차단) | 감사 불가 | GAP #1 확인 |
| enuri.com | 200이지만 **오류 페이지** (소프트 차단) | 무효(오류페이지 감사) | robots/llms "found"는 오인 |
| gmarket.co.kr | **403** | — | |
| coupang.com | **403** (Access Denied) | — | |
| wemakeprice.com | 접속 실패 | — | |
| 11st.co.kr | 200 (렌더 필요, JS SPA) | 0 → 16(렌더) | blocked-by-robots 135, content-requires-js, structured data·llms.txt·sitemap 부재 |
| smartstore.naver.com | 200 (렌더 필요) | 0 | H1·description·canonical·structured data 부재 |

**시사점**:
1. 봇 차단은 한국 커머스 공통 현상 — 다나와 403은 특이 케이스가 아니지만, **AI 크롤러(GPTBot 등)도 함께 차단되므로 AEO 최우선 과제**는 유효
2. 접근 가능한 경쟁사조차 GEO 0~16점 — **국내 커머스/가격비교 시장은 AEO 공백 상태**
3. 리뉴얼 플랜(SSR + JSON-LD @graph + llms.txt + FAQ 콘텐츠) 시행 시 다나와가 **국내 AI 인용 1위 선점** 가능

---

## 2. 리뉴얼 전략 (핵심 방향)
> **목표: "가격비교 = 다나와"라는 지식이 AI 답변에 기본값으로 포함되는 상태.**
> 전략 축: **① 크롤링 접근성 → ② 구조화 데이터 → ③ 엔티티 그래프 → ④ 질문형 콘텐츠 → ⑤ 인용 신뢰 → ⑥ AI 채널(MCP/AI 비교) → ⑦ 측정.**

### 2.1 크롤링 접근성 (AI가 "읽게" 하라)

- robots.txt에 **GPTBot, ChatGPT-User, ClaudeBot, Claude-Web, PerplexityBot, Google-Extended, CCBot, Applebot-Extended** 허용 (분석 데이터 트래픽 제외 등 정교 정책과 병행)
- **봇 차단 정책 재설계**: IDC/봇 차단을 UA 기반 화이트리스트(LLM UA 허용) + rate-limit 방식으로 전환. AI 크롤러가 403을 받으면 사이트 전체가 AI 지식에서 사라짐
- `/llms.txt` + `/llms-full.txt` 도입:
  - 다나와 소개, 서비스 목록, 카테고리 트리, 상품 엔티티 진입점, MCP 서버 안내, FAQ 링크, 데이터 출처 정책
- PDP/PLP를 **SSR(서버렌더)/정적 HTML**로 전환해 스펙·가격·리뷰 요약을 HTML 원문에 포함
- sitemap 확장: PDP 1차 sitemap + 신규 비교/FAQ 콘텐츠 sitemap + `lastmod` 갱신

### 2.2 구조화 데이터 (AI가 "구조로" 읽게 하라)

모든 페이지에 JSON-LD `@graph` 통합 (리치스니펫용 기존 스키마와 병행):

| 페이지 | 스키마 |
|---|---|
| PDP | `Product` + `brand` + `gtin` + `image` + `AggregateOffer`(`priceCurrency`, `lowPrice`, `highPrice`, `offerCount`, `priceValidUntil`) + `Review`/`AggregateRating` + `BreadcrumbList` + `hasVariant`(옵션) + `subjectOf`(FAQ) |
| PLP | `ItemList` + `OfferCatalog` + `BreadcrumbList` + `WebPage`(카테고리 설명) |
| 비교/가이드 | `FAQPage` + `Article` + `ItemList`(비교 대상) + `ReviewedBy` |
| 브랜드로그 | `Brand` + `Organization` + `sameAs`(공식몰/위키/소셜) + `brandOffering` |
| 전사 | `Organization`(다나와) + `WebSite` + `SearchAction`(통합검색) + `sameAs` + `corporateContact` |

- 가격 데이터는 `priceValidUntil`·`availability`·`offerCount`로 **"실시간 최저가"의 신뢰성**을 명시
- 리뷰 집계는 `aggregateRating`에 **집계 기준(리뷰 수, 기간)** 명시

### 2.3 엔티티 그래프 (AI가 "연결로" 이해하게 하라)

- 카테고리 계층(`cate`)을 **엔티티 허브**로 승격: 카테고리 페이지마다 대표 상품·브랜드·비교질문·관련 가이드 상호링크
- 상품 → 브랜드 → 카테고리 → 관련 질문 → 리뷰/가이드 → 가격 데이터의 내부 링크 완성
- 상품명에 정규명·동의어·영문명 명시 (`alternateName`): "RTX 5090 / 지포스 RTX 5090 / Geforce RTX 5090" 모두 동일 엔티티로 인지되도록
- **지식 그래프 아카이브** 운영: 공개 `entities.json`/`graph.json`로 주요 상품·브랜드·스펙 관계를 LLM이 즉시 소비 가능한 형태로 노출 (llms.txt와 연동)

### 2.4 질문형 콘텐츠 (AI가 "인용할 문장"을 가지게 하라)

- **VS검색의 콘텐츠화**: JS 도구 → 정적 비교 페이지 전환. `상품A vs 상품B` 비교 기사를 스펙표·차이점·가격·결론(누구에게 추천) 구조로 정적 생성
- **구매가이드 FAQ화**: 기존 가이드를 FAQPage 스키마 + 질문 타이틀(`H1`)로 재편 — "게이밍 모니터 27인치 추천", "RTX 5090 vs 4090 차이", "선풍기 vs 에어서큘레이터" 형태
- **가격 데이터 기반 답변 블록**: "2026년 8월 기준 XX 카테고리 최저가 TOP", "가격 하락률 TOP10" 같은 **데이터 저널리즘** 콘텐츠 (다나와만 만들 수 있는 독점 인용자산)
- **질문-답변 패턴**: 각 PDP/PLP에 해당 상품군의 상위 질문 5~8개 FAQ 임베드 (AI가 답변 원문으로 사용)
- 이미지 대체텍스트·캡션에 스펙 수치 포함 (AI 이미지 이해 보조)

### 2.5 인용 신뢰 (AI가 "출처로 인용"하게 하라)

- 각 사실 주장(최저가, 히트브랜드, 점유율, 리뷰 수)에 **출처·집계기준·업데이트일** 명시 ("2026년 6월 다나와 판매데이터 기준")
- **데이터 정책 페이지**: 가격 수집 방법, 업데이트 주기, 리뷰 검증 절차를 공개해 AI의 신뢰 판정(E-E-A-T) 대응
- 히트브랜드/리포트에 외부 검증 링크(시험기관, 언론보도) 연결
- **MCP + 웹 동시 운영**: MCP는 "실시간 정확 데이터" 채널, 웹 콘텐츠는 "인용 가능한 지식" 채널로 역할 분담. MCP 서버 메타데이터에 출처 URL 포함

### 2.6 AI 채널 확장

- **MCP 서버 고도화**: 클로드 외 ChatGPT(도구 호출)·Gemini(도구) 연동 확대, 판매몰·스펙·가격히스토리·리뷰 요약을 표준 도구로 노출
- **AI 비교 대시보드(소비자용)**: "AI에게 물어보면 다나와가 답한다"를 사용자 체험으로 전환 (AI 비교 랜딩)
- **벤더·입점사 대상 AEO 리포트 상품화**: 입점사에게 "ChatGPT에서 내 브랜드가 다나와를 통해 인용되는지" 리포트 판매 → 수익 모델 겸 데이터 품질 인센티브

### 2.7 측정 (AI 가시성 모니터링)

- **ELMO 스택** (셀프호스팅, `github.com/elmohq/elmo`) 도입: ChatGPT/Claude/Google AI Overview/Perplexity에서 "다나와" 브랜드·상품명 언급/인용 여부·문구·링크 추적
- 핵심 질문 배터리 자동화:
  - "RTX 5090 vs 4090 가격 비교", "게이밍 모니터 추천", "SSD 1TB 추천", "다나와", "가격비교 사이트"
- KPI: **AI 인용률(언급/인용 질문 대비)**, 인용 문구 정확도, AI 추천에서 다나와가 1순위 출처인 비율, AI 유입 트래픽(UTM), MCP 호출 수

---

## 3. 실행 로드맵

### Phase 1 — 진단·기반 (0~4주)
- [ ] GPTBot 등 LLM 크롤러 실제 접근 로그 확인 + robots.txt 허용 정책 배포
- [ ] 봇 차단 정책 재설계 (UA 화이트리스트 + rate-limit)
- [ ] `llms.txt`/`llms-full.txt` 파일 생성
- [ ] 전사 `Organization`/`WebSite` JSON-LD 배포
- [ ] ELMO 모니터링 구축 (키워드 배터리 + 베이스라인 측정)
- **성과 기준**: LLM 크롤러 200 응답 100%, ELMO 베이스라인 확보

### Phase 2 — 핵심 페이지 구조화 (5~8주)
- [ ] PDP JSON-LD `@graph`(Product+AggregateOffer+Review) 전 상품 적용
- [ ] PLP `ItemList`+카테고리 설명 스키마
- [ ] PDP/PLP SSR 전환 (상위 20% 트래픽 페이지 우선)
- [ ] sitemap 확장·갱신
- **성과 기준**: PDP 스키마 검증(GTT/리치리포트) 통과, SSR 페이지 100%

### Phase 3 — 콘텐츠·엔티티 (9~16주)
- [ ] VS검색 정적 비교 페이지 전환 (핵심 카테고리 50건 파일럿 → 전체)
- [ ] 구매가이드 FAQPage 재편 (기존 가이드 변환)
- [ ] 데이터 기반 답변 블록 10종 신규 (최저가 TOP/가격하락률 등)
- [ ] 엔티티 허브(카테고리 페이지) 상호링크 + `entities.json`
- **성과 기준**: AI 인용 질문 3개 이상에서 다나와 출처 등장, 비교 페이지 유입 증가

### Phase 4 — 고도화·확장 (17~24주)
- [ ] MCP 서버 도구 확장(ChatGPT/Gemini) + 메타데이터 출처 명시
- [ ] AI 비교 대시보드(소비자) 랜딩
- [ ] 입점사 AEO 리포트 상품화
- [ ] 지속 측정 → 분기별 AI 인용 리포트
- **성과 기준**: AI 인용률 목표(예: 핵심 10개 질문에서 50%+ 1순위 출처), MCP 월 호출 증가

---

## 4. 기술 명세 (요약)

- `robots.txt` 허용: `GPTBot`, `ChatGPT-User`, `ClaudeBot`, `Claude-Web`, `PerplexityBot`, `Google-Extended`, `CCBot`, `Applebot-Extended`, `DataForSEO`(모니터링용)
- `llms.txt`: 서비스 소개 → 카테고리 트리 → 상품 엔티티 진입점 → MCP 안내 → FAQ/가이드 색인 → 데이터 정책
- JSON-LD: 전 페이지 `@graph` 단일 주입 (SSR에서 렌더)
- 렌더링: PDP/PLP SSR 전환, 비교/FAQ 정적 생성(SSG) + ISR
- URL: 비교 페이지 `https://prod.danawa.com/compare/{a}-vs-{b}` 정규화 (쿼리 의존 제거)
- 모니터링: ELMO(`elmo.privseai.com` 스택, worker에 스크래핑/AI 키 연동) + 구글서치콘솔(FAQ/제품 스키마 보고서) + GA4(이벤트: AI 유입) + crawlie(로컬 무료 GEO 크롤러, `npm i -g crawlie`. 단 danawa 직접 감사는 403 확인 — 아카이브 경유 필요)
- **ELMO worker의 LLM 프로바이더는 커스텀 엔드포인트 미지원** (소스 확인, worker 0.2.18): `openai-api`=`createOpenAI({apiKey})`(SDK 기본값 api.openai.com), `anthropic-api`=`createAnthropic({apiKey})`(api.anthropic.com), `mistral-api`=하드코딩 `https://api.mistral.ai`, `openrouter`=하드코딩 `https://openrouter.ai/api/v1`. → **freellmpool 등 무료 LLM 풀은 ELMO worker 연동 불가**, 실질 무료 경로는 OpenRouter 실계정 키(`openrouter` 프로바이더) + 스크레이퍼 키(DataForSEO 등)뿐. 수동 추적(CSV)은 지금도 가능

---

## 5. 리스크

| 리스크 | 대응 |
|---|---|
| 안티-봇 완화 → 스크래핑 증가 | UA별 rate-limit + 스크래핑 방지(가격 도용)는 유지하되 **LLM UA만 통과**시키는 별도 정책 |
| 가격 실시간성 vs AI 캐시 | `priceValidUntil`+`lastmod` 명시, MCP로 실시간 보강, AI 오답 대비 데이터 타임스탬프 |
| 정적 비교 페이지 과도 생성 | 핵심 비교(검색량 상위)만 파일럿 후 확장, 노이즈 페이지 방지 |
| LLM 크롤러 트래픽 부하 | LLM UA 별로 클라우드플레어 캐시(TTL 짧게) + CDN, 크롤링 전용 엣지 |
| 광고계약 논란(신뢰도) | 데이터 정책·집계기준 투명화로 중립성 신호 강화 (AEO=신뢰 게임) |

---

## 6. 성공 지표 (KPI)

1. **AI 인용률**: 핵심 질문 배터리에서 다나와 언급/인용 비율 (분기 대비)
2. **AI 1순위 출처율**: AI 답변에서 다나와가 첫 출처인 비율
3. **AI 유입 트래픽**: GA4 UTM(`utm_medium=ai`) 세션 증가
4. **MCP 활용**: 월 호출 수, 연동 파트너(AI 서비스) 수
5. **검색 스키마 지표**: 구글 리치리포트 유효 스키마 수, FAQ 노출 수
6. **비교/FAQ 콘텐츠 CTR·전환**: 신규 정적 비교 페이지의 CTR·이탈·구매전환

> **핵심 메시지**: 다나와가 가진 데이터(가격·스펙·리뷰·트렌드)는 AI 시대의 최고급 지식자산. 리뉴얼은 "보여주기"에서 "AI가 읽고 인용하는 구조"로 데이터를 재포장하는 작업이며, MCP 출시와 ELMO 측정으로 첫 진입은 이미 시작됐습니다.
