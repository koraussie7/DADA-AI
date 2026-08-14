# AllRouter

OpenRouter 스타일의 AI 게이트웨이. 모든 AI 모델을 하나의 OpenAI 호환 API로 통합합니다.

## 구조

```
allrouter/
├── ui/                 # Next.js 프론트엔드 (한글 랜딩 + 대시보드)
│   ├── app/
│   │   ├── page.tsx            # 랜딩 페이지
│   │   └── dashboard/          # 대시보드 (keys/logs/billing/models/settings)
│   └── components/             # Sidebar, CostChart, CreateKeyModal
├── docker-compose.yml  # LiteLLM + PostgreSQL + Redis (예정)
├── litellm/config.yaml # 모델 라우팅 설정 (예정)
└── README.md
```

## 도메인

- 홈페이지/대시보드: https://allrouter.privseai.com
- API 엔드포인트: https://allrouter.privseai.com/v1

## 개발

```bash
cd ui
npm install
npm run dev        # http://localhost:3000
npm run build      # 프로덕션 빌드
```

## 배포 (110 서버)

```bash
# 소스 업로드 후
cd /opt/allrouter/ui
npm ci --omit=dev && npm run build
npm run start -- -p 3001   # systemd 등록
```
