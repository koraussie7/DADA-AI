import Link from "next/link";
import {
  ArrowRight,
  Cpu,
  GitBranch,
  LineChart,
  KeyRound,
  ShieldCheck,
  Zap,
  Layers,
  Globe,
  Sparkles,
  CreditCard,
} from "lucide-react";

const features = [
  {
    icon: GitBranch,
    title: "스마트 라우팅",
    desc: "요청을 가장 적합한 모델로 자동 전환합니다. 장애가 나면 다른 모델로 즉시 폴백해 서비스가 멈추지 않습니다.",
  },
  {
    icon: LineChart,
    title: "실시간 비용 추적",
    desc: "모델별·키별·날짜별 토큰 사용량과 비용을 한눈에 확인하고, 예산 초과 시 자동으로 차단합니다.",
  },
  {
    icon: KeyRound,
    title: "API 키 관리",
    desc: "사용자별 키를 발급하고 잔액을 할당합니다. 키 하나로 모든 모델에 접근할 수 있습니다.",
  },
  {
    icon: Layers,
    title: "100+ 모델 통합",
    desc: "OpenAI, Anthropic, Google, 오픈소스 모델까지. OpenAI 호환 API 하나로 모두 사용하세요.",
  },
  {
    icon: ShieldCheck,
    title: "보안과 프라이버시",
    desc: "키는 절대 노출되지 않습니다. 자체 서버 운영으로 데이터 통제권을 완전히 가집니다.",
  },
  {
    icon: Zap,
    title: "낮은 지연시간",
    desc: "가벼운 게이트웨이 설계로 추가 지연을 최소화했습니다. 빠른 응답이 필요한 서비스에 적합합니다.",
  },
];

const steps = [
  {
    num: "01",
    title: "회원가입 & 로그인",
    desc: "간편하게 계정을 만들고 대시보드에 접속합니다.",
  },
  {
    num: "02",
    title: "API 키 발급",
    desc: "원하는 모델을 선택하고 예산을 설정해 키를 생성합니다.",
  },
  {
    num: "03",
    title: "OpenAI 호환 API 사용",
    desc: "base_url만 바꾸면 끝. 기존 코드는 그대로 유지됩니다.",
  },
];

export default function LandingPage() {
  return (
    <div className="min-h-screen bg-[var(--background)] text-[var(--foreground)]">
      {/* 내비게이션 */}
      <header className="sticky top-0 z-50 border-b border-[var(--border)] bg-[#0b0e14]/80 backdrop-blur-md">
        <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-6">
          <div className="flex items-center gap-2">
            <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-[var(--accent)] text-sm font-bold text-white">
              AR
            </div>
            <span className="text-lg font-bold">AllRouter</span>
          </div>
          <nav className="hidden items-center gap-8 text-sm text-[var(--muted)] md:flex">
            <a href="#features" className="transition-colors hover:text-white">
              기능
            </a>
            <a href="#how" className="transition-colors hover:text-white">
              사용 방법
            </a>
            <a href="#models" className="transition-colors hover:text-white">
              모델
            </a>
            <a href="#pricing" className="transition-colors hover:text-white">
              요금제
            </a>
          </nav>
          <div className="flex items-center gap-3">
            <Link
              href="/dashboard"
              className="hidden text-sm text-[var(--muted)] transition-colors hover:text-white sm:block"
            >
              로그인
            </Link>
            <Link
              href="/dashboard"
              className="rounded-lg bg-[var(--accent)] px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-[var(--accent-hover)]"
            >
              시작하기
            </Link>
          </div>
        </div>
      </header>

      {/* 히어로 */}
      <section className="relative overflow-hidden">
        <div className="pointer-events-none absolute inset-0 bg-[radial-gradient(ellipse_at_top,rgba(59,130,246,0.12),transparent_55%)]" />
        <div className="mx-auto max-w-6xl px-6 pt-24 pb-20 text-center">
          <div className="mx-auto mb-6 inline-flex items-center gap-2 rounded-full border border-[var(--border)] bg-[var(--panel)] px-4 py-1.5 text-xs text-[var(--muted)]">
            <Sparkles size={14} className="text-[var(--accent)]" />
            모든 주요 AI 모델을 지원합니다
          </div>
          <h1 className="mx-auto max-w-3xl text-4xl font-bold leading-tight tracking-tight md:text-6xl">
            모든 AI 모델을
            <br />
            <span className="bg-gradient-to-r from-[#60a5fa] to-[#a78bfa] bg-clip-text text-transparent">
              하나의 API
            </span>
            로
          </h1>
          <p className="mx-auto mt-6 max-w-2xl text-base text-[var(--muted)] md:text-lg">
            AllRouter는 여러 AI 모델을 하나의 OpenAI 호환 API로 통합합니다.
            스마트 라우팅, 실시간 비용 추적, API 키 관리를 통해
            AI 인프라를 간편하게 운영하세요.
          </p>
          <div className="mt-10 flex flex-col items-center justify-center gap-4 sm:flex-row">
            <Link
              href="/dashboard"
              className="group flex items-center gap-2 rounded-lg bg-[var(--accent)] px-6 py-3 font-medium text-white transition-all hover:bg-[var(--accent-hover)]"
            >
              무료로 시작하기
              <ArrowRight size={16} className="transition-transform group-hover:translate-x-1" />
            </Link>
            <a
              href="#features"
              className="flex items-center gap-2 rounded-lg border border-[var(--border-light)] bg-[var(--panel)] px-6 py-3 font-medium transition-colors hover:border-[var(--muted)]"
            >
              기능 살펴보기
            </a>
          </div>

          {/* 데모 코드 블록 */}
          <div className="mx-auto mt-16 max-w-2xl text-left">
            <div className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--panel-2)]">
              <div className="flex items-center gap-2 border-b border-[var(--border)] px-4 py-3">
                <span className="h-3 w-3 rounded-full bg-[#f85149]" />
                <span className="h-3 w-3 rounded-full bg-[#d29922]" />
                <span className="h-3 w-3 rounded-full bg-[#3fb950]" />
                <span className="ml-3 text-xs text-[var(--muted)]">
                  quickstart.py
                </span>
              </div>
              <pre className="overflow-x-auto p-4 text-sm leading-relaxed">
                <code className="font-mono">
                  <span className="text-[#f0883e]">from</span>{" "}
                  <span className="text-[#79c0ff]">openai</span>{" "}
                  <span className="text-[#f0883e]">import</span>{" "}
                  <span className="text-[#79c0ff]">OpenAI</span>
                  {"\n\n"}
                  <span className="text-[#7ee787]">client</span> ={" "}
                  <span className="text-[#79c0ff]">OpenAI</span>({"\n  "}
                  <span className="text-[#ffa657]">base_url</span>={" "}
                  <span className="text-[#a5d6ff]">"https://allrouter.privseai.com/v1"</span>,{"\n  "}
                  <span className="text-[#ffa657]">api_key</span>={" "}
                  <span className="text-[#a5d6ff]">"sk-allrouter-..."</span>,{"\n"}
                  )
                  {"\n\n"}
                  <span className="text-[#79c0ff]">resp</span> ={" "}
                  <span className="text-[#79c0ff]">client</span>.
                  <span className="text-[#d2a8ff]">chat</span>.
                  <span className="text-[#d2a8ff]">completions</span>.
                  <span className="text-[#d2a8ff]">create</span>(
                  {"\n  "}
                  <span className="text-[#ffa657]">model</span>={" "}
                  <span className="text-[#a5d6ff]">"auto"</span>,
                  {"\n  "}
                  <span className="text-[#ffa657]">messages</span>=[
                  {"\n    "}
                  {"{"}
                  <span className="text-[#ffa657]">"role"</span>:{" "}
                  <span className="text-[#a5d6ff]">"user"</span>,{" "}
                  <span className="text-[#ffa657]">"content"</span>:{" "}
                  <span className="text-[#a5d6ff]">"안녕하세요!"</span>
                  {"}"}
                  {"\n  "}
                  {"],"}
                  {"\n"}
                  )
                </code>
              </pre>
            </div>
          </div>
        </div>
      </section>

      {/* 아키텍처 다이어그램 */}
      <section id="models" className="border-t border-[var(--border)] bg-[var(--panel-2)]">
        <div className="mx-auto max-w-6xl px-6 py-20">
          <h2 className="text-center text-3xl font-bold md:text-4xl">
            어떻게 동작하나요?
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-center text-[var(--muted)]">
            하나의 API 키로 모든 모델에 접근. AllRouter가 최적의 모델을 선택하고
            비용을 관리합니다.
          </p>
          <div className="mx-auto mt-12 max-w-4xl">
            <div className="rounded-2xl border border-[var(--border)] bg-[var(--panel)] p-8">
              <div className="flex flex-col items-center justify-center gap-6 md:flex-row">
                <div className="flex flex-col items-center gap-2 rounded-xl border border-[var(--border)] bg-[var(--panel-2)] px-6 py-4">
                  <Globe size={20} className="text-[var(--accent)]" />
                  <span className="text-sm font-medium">당신의 앱</span>
                </div>
                <ArrowRight size={20} className="text-[var(--muted)]" />
                <div className="flex flex-col items-center gap-2 rounded-xl border border-[var(--accent)]/40 bg-[#0f1a2e] px-8 py-4">
                  <Layers size={20} className="text-[var(--accent)]" />
                  <span className="text-sm font-semibold text-[var(--accent)]">
                    AllRouter 게이트웨이
                  </span>
                  <span className="text-xs text-[var(--muted)]">
                    라우팅 · 폴백 · 과금 · 모니터링
                  </span>
                </div>
                <ArrowRight size={20} className="text-[var(--muted)]" />
                <div className="flex gap-4">
                  {["GPT", "Claude", "Gemini", "오픈소스"].map((m) => (
                    <div
                      key={m}
                      className="flex flex-col items-center gap-1 rounded-xl border border-[var(--border)] bg-[var(--panel-2)] px-4 py-3 text-xs"
                    >
                      <Cpu size={16} className="text-[#a78bfa]" />
                      {m}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 기능 */}
      <section id="features" className="mx-auto max-w-6xl px-6 py-20">
        <h2 className="text-center text-3xl font-bold md:text-4xl">
          모든 것이 필요한 이유
        </h2>
        <p className="mx-auto mt-4 max-w-2xl text-center text-[var(--muted)]">
          AI 서비스를 운영하는 데 필요한 모든 기능을 한 곳에서 제공합니다.
        </p>
        <div className="mt-12 grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
          {features.map((f) => (
            <div
              key={f.title}
              className="group rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6 transition-all hover:-translate-y-1 hover:border-[var(--border-light)]"
            >
              <div className="mb-4 flex h-10 w-10 items-center justify-center rounded-lg bg-[var(--accent)]/10 text-[var(--accent)] transition-colors group-hover:bg-[var(--accent)] group-hover:text-white">
                <f.icon size={20} />
              </div>
              <h3 className="mb-2 text-lg font-semibold">{f.title}</h3>
              <p className="text-sm leading-relaxed text-[var(--muted)]">
                {f.desc}
              </p>
            </div>
          ))}
        </div>
      </section>

      {/* 사용 방법 */}
      <section id="how" className="border-t border-[var(--border)] bg-[var(--panel-2)]">
        <div className="mx-auto max-w-6xl px-6 py-20">
          <h2 className="text-center text-3xl font-bold md:text-4xl">
            3분이면 시작
          </h2>
          <p className="mx-auto mt-4 max-w-2xl text-center text-[var(--muted)]">
            복잡한 설정 없이 단 세 단계로 AI 게이트웨이를 사용하세요.
          </p>
          <div className="mt-12 grid grid-cols-1 gap-6 md:grid-cols-3">
            {steps.map((s) => (
              <div
                key={s.num}
                className="relative rounded-xl border border-[var(--border)] bg-[var(--panel)] p-8"
              >
                <span className="absolute top-6 right-6 text-4xl font-bold text-[var(--border)]">
                  {s.num}
                </span>
                <h3 className="mb-2 text-lg font-semibold">{s.title}</h3>
                <p className="text-sm text-[var(--muted)]">{s.desc}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 요금제 */}
      <section id="pricing" className="mx-auto max-w-6xl px-6 py-20">
        <h2 className="text-center text-3xl font-bold md:text-4xl">
          투명한 요금제
        </h2>
        <p className="mx-auto mt-4 max-w-2xl text-center text-[var(--muted)]">
          실제 사용한 토큰만큼만 지불하세요. 숨겨진 비용이 없습니다.
        </p>
        <div className="mt-12 grid grid-cols-1 gap-6 md:grid-cols-3">
          <div className="flex flex-col rounded-xl border border-[var(--border)] bg-[var(--panel)] p-8">
            <h3 className="text-lg font-semibold">스타터</h3>
            <p className="mt-2 text-3xl font-bold">
              $0<span className="text-sm font-normal text-[var(--muted)]">/월</span>
            </p>
            <p className="mt-2 text-sm text-[var(--muted)]">
              간단한 테스트와 개인 프로젝트용
            </p>
            <ul className="mt-6 flex-1 space-y-3 text-sm">
              <li>월 1,000 크레딧</li>
              <li>3개 모델 접근</li>
              <li>커뮤니티 지원</li>
            </ul>
            <Link
              href="/dashboard"
              className="mt-8 rounded-lg border border-[var(--border-light)] py-2.5 text-center text-sm font-medium transition-colors hover:border-[var(--muted)]"
            >
              시작하기
            </Link>
          </div>
          <div className="relative flex flex-col rounded-xl border border-[var(--accent)]/40 bg-[#0f1a2e] p-8">
            <span className="absolute -top-3 left-1/2 -translate-x-1/2 rounded-full bg-[var(--accent)] px-3 py-0.5 text-xs font-semibold text-white">
              인기
            </span>
            <h3 className="text-lg font-semibold">프로</h3>
            <p className="mt-2 text-3xl font-bold">
              $10<span className="text-sm font-normal text-[var(--muted)]">/월</span>
            </p>
            <p className="mt-2 text-sm text-[var(--muted)]">
              활발한 개발과 소규모 서비스용
            </p>
            <ul className="mt-6 flex-1 space-y-3 text-sm">
              <li>월 10,000 크레딧</li>
              <li>모든 모델 접근</li>
              <li>스마트 라우팅</li>
              <li>우선 지원</li>
            </ul>
            <Link
              href="/dashboard"
              className="mt-8 rounded-lg bg-[var(--accent)] py-2.5 text-center text-sm font-medium text-white transition-colors hover:bg-[var(--accent-hover)]"
            >
              프로 시작하기
            </Link>
          </div>
          <div className="flex flex-col rounded-xl border border-[var(--border)] bg-[var(--panel)] p-8">
            <h3 className="text-lg font-semibold">엔터프라이즈</h3>
            <p className="mt-2 text-3xl font-bold">
              맞춤형<span className="text-sm font-normal text-[var(--muted)]"> 문의</span>
            </p>
            <p className="mt-2 text-sm text-[var(--muted)]">
              대규모 트래픽과 SLA가 필요한 기업용
            </p>
            <ul className="mt-6 flex-1 space-y-3 text-sm">
              <li>무제한 크레딧</li>
              <li>전용 인프라</li>
              <li>SLA 보장</li>
              <li>전담 엔지니어</li>
            </ul>
            <a
              href="mailto:contact@privseai.com"
              className="mt-8 rounded-lg border border-[var(--border-light)] py-2.5 text-center text-sm font-medium transition-colors hover:border-[var(--muted)]"
            >
              문의하기
            </a>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="border-t border-[var(--border)] bg-[var(--panel-2)]">
        <div className="mx-auto max-w-4xl px-6 py-20 text-center">
          <div className="mx-auto mb-6 flex h-14 w-14 items-center justify-center rounded-2xl bg-[var(--accent)] text-white">
            <CreditCard size={24} />
          </div>
          <h2 className="text-3xl font-bold md:text-4xl">
            지금 바로 시작하세요
          </h2>
          <p className="mx-auto mt-4 max-w-xl text-[var(--muted)]">
            신용카드 없이 무료로 시작할 수 있습니다. 첫 1,000 크레딧은
            서비스를 경험해보시라고 드립니다.
          </p>
          <Link
            href="/dashboard"
            className="group mt-8 inline-flex items-center gap-2 rounded-lg bg-[var(--accent)] px-8 py-3.5 font-medium text-white transition-all hover:bg-[var(--accent-hover)]"
          >
            무료 계정 만들기
            <ArrowRight size={16} className="transition-transform group-hover:translate-x-1" />
          </Link>
        </div>
      </section>

      {/* 푸터 */}
      <footer className="border-t border-[var(--border)]">
        <div className="mx-auto flex max-w-6xl flex-col items-center justify-between gap-6 px-6 py-12 md:flex-row">
          <div className="flex items-center gap-2">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-[var(--accent)] text-xs font-bold text-white">
              AR
            </div>
            <span className="text-sm font-semibold">AllRouter</span>
          </div>
          <p className="text-xs text-[var(--muted)]">
            © 2026 PrivseAI · allrouter.privseai.com
          </p>
          <div className="flex gap-6 text-xs text-[var(--muted)]">
            <a href="#" className="transition-colors hover:text-white">
              이용약관
            </a>
            <a href="#" className="transition-colors hover:text-white">
              개인정보처리방침
            </a>
            <a href="mailto:contact@privseai.com" className="transition-colors hover:text-white">
              문의
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
