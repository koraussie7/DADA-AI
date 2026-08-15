"use client";

import { useEffect, useState } from "react";
import {
  Activity,
  Box,
  Cpu,
  Loader2,
  Network,
  Server,
  Send,
  Zap,
} from "lucide-react";
import { ollaFetch } from "@/lib/olla";

interface Endpoint {
  name: string;
  type: string;
  status: string;
  response_time: string;
  model_count: number;
  request_count: number;
  min_latency_ms: number;
  max_latency_ms: number;
  active_connections: number;
  url: string;
  priority: number;
  health_check: string;
}

interface EndpointsResponse {
  total_count?: number;
  healthy_count?: number;
  routable_count?: number;
  endpoints?: Endpoint[];
}

interface DiscoveredModel {
  name: string;
  family: string;
  size: string;
  params: string;
  quant: string;
  last_seen: string;
  endpoints: string[];
}

interface ModelsResponse {
  recent_models?: DiscoveredModel[];
}

export default function OllaPage() {
  const [endpoints, setEndpoints] = useState<EndpointsResponse | null>(null);
  const [models, setModels] = useState<ModelsResponse | null>(null);
  const [gateway, setGateway] = useState<string>("unknown");
  const [error, setError] = useState<string | null>(null);
  const [testModel, setTestModel] = useState("qwen2.5:1.5b");
  const [testPrompt, setTestPrompt] = useState("안녕, 한 문장으로 자기소개 해줘.");
  const [testResult, setTestResult] = useState<string | null>(null);
  const [testLoading, setTestLoading] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const [health, endpointsData, modelsData] = await Promise.all([
          ollaFetch("internal/health"),
          ollaFetch("internal/status/endpoints"),
          ollaFetch("internal/status/models"),
        ]);
        setGateway(health?.status ?? "unknown");
        setEndpoints(endpointsData);
        setModels(modelsData);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Olla 정보를 불러오지 못했습니다.");
      }
    })();
  }, []);

  const fleet = endpoints?.endpoints ?? [];
  const totalRequests = fleet.reduce((acc, e) => acc + e.request_count, 0);
  const loading = !endpoints && !error;

  const runTest = async () => {
    setTestLoading(true);
    setTestResult(null);
    try {
      const data = await ollaFetch("olla/proxy/v1/chat/completions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          model: testModel,
          messages: [{ role: "user", content: testPrompt }],
          max_tokens: 64,
        }),
      });
      const text =
        data?.choices?.[0]?.message?.content ||
        (typeof data?.error === "string" ? data.error : JSON.stringify(data));
      setTestResult(text);
    } catch (e) {
      setTestResult(`오류: ${e instanceof Error ? e.message : "테스트 실패"}`);
    } finally {
      setTestLoading(false);
    }
  };

  const stats = [
    {
      label: "게이트웨이",
      value: gateway === "healthy" ? "정상" : gateway,
      ok: gateway === "healthy",
    },
    {
      label: "엔드포인트",
      value: `${endpoints?.healthy_count ?? 0}/${endpoints?.total_count ?? 0}`,
      ok: (endpoints?.healthy_count ?? 0) > 0,
    },
    {
      label: "발견 모델",
      value: `${models?.recent_models?.length ?? 0}개`,
      ok: (models?.recent_models?.length ?? 0) > 0,
    },
    {
      label: "총 요청",
      value: totalRequests.toLocaleString(),
      ok: true,
    },
  ];

  return (
    <div className="p-8">
      <header className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">Olla — 로컬 인퍼런스</h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          자체 인퍼런스 노드(Ollama/vLLM 등)용 엣지 로드밸런서 — 라우팅, 폴백,
          모델 통합을 담당합니다.
        </p>
      </header>

      {error && (
        <div className="mb-6 rounded-xl border border-[#f85149]/30 bg-[#f85149]/10 p-4 text-sm text-[#f85149]">
          {error}
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center gap-2 p-12 text-[var(--muted)]">
          <Loader2 size={18} className="animate-spin" />
          Olla 상태를 불러오는 중...
        </div>
      ) : (
        <div className="max-w-4xl space-y-6">
          {/* 상태 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Activity size={18} className="text-[var(--accent)]" />
              팔레트 헬스
            </h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              {stats.map((s) => (
                <div
                  key={s.label}
                  className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4"
                >
                  <p className="text-xs text-[var(--muted)]">{s.label}</p>
                  <p
                    className={`mt-1 flex items-center gap-2 text-base font-semibold ${
                      s.ok ? "" : "text-[#f85149]"
                    }`}
                  >
                    <span
                      className={`inline-block h-2 w-2 rounded-full ${
                        s.ok ? "bg-[#3fb950]" : "bg-[#f85149]"
                      }`}
                    />
                    {s.value}
                  </p>
                </div>
              ))}
            </div>

            <p className="mb-3 mt-6 text-xs text-[var(--muted)]">
              인퍼런스 노드 (endpoint)
            </p>
            <div className="space-y-3">
              {fleet.length === 0 ? (
                <p className="text-sm text-[var(--muted)]">엔드포인트 없음</p>
              ) : (
                fleet.map((e) => (
                  <div
                    key={e.name}
                    className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4"
                  >
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div className="flex items-center gap-2">
                        <span
                          className={`inline-block h-2 w-2 rounded-full ${
                            e.status === "healthy" ? "bg-[#3fb950]" : "bg-[#f85149]"
                          }`}
                        />
                        <span className="text-sm font-semibold">{e.name}</span>
                        <code className="font-mono text-xs text-[var(--muted)]">
                          {e.type}
                        </code>
                      </div>
                      <div className="flex items-center gap-3 text-xs text-[var(--muted)]">
                        <span className="flex items-center gap-1">
                          <Zap size={12} />
                          {e.response_time || "—"}
                        </span>
                        <span className="flex items-center gap-1">
                          <Cpu size={12} />
                          모델 {e.model_count}
                        </span>
                        <span className="flex items-center gap-1">
                          <Network size={12} />
                          {e.request_count.toLocaleString()}회
                        </span>
                      </div>
                    </div>
                    <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-xs text-[var(--muted)]">
                      <code className="font-mono">{e.url}</code>
                      <span>우선순위 {e.priority}</span>
                      <span>연결 {e.active_connections}</span>
                      <span>
                        지연 {e.min_latency_ms}–{e.max_latency_ms}ms
                      </span>
                      <span>마지막 헬스체크 {e.health_check}</span>
                    </div>
                  </div>
                ))
              )}
            </div>
          </section>

          {/* 발견된 모델 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Server size={18} className="text-[var(--accent)]" />
              발견된 모델 (디스커버리)
            </h2>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[520px] text-sm">
                <thead>
                  <tr className="border-b border-[var(--border)] text-left text-xs text-[var(--muted)]">
                    <th className="py-2 pr-3 font-medium">모델</th>
                    <th className="py-2 pr-3 font-medium">패밀리</th>
                    <th className="py-2 pr-3 font-medium">크기</th>
                    <th className="py-2 pr-3 font-medium">파라미터</th>
                    <th className="py-2 pr-3 font-medium">양자화</th>
                    <th className="py-2 font-medium">노드</th>
                  </tr>
                </thead>
                <tbody>
                  {(models?.recent_models ?? []).map((m) => (
                    <tr
                      key={m.name}
                      className="border-b border-[var(--border-light)]/50 last:border-0"
                    >
                      <td className="py-2 pr-3">
                        <code className="font-mono text-xs">{m.name}</code>
                      </td>
                      <td className="py-2 pr-3 text-xs text-[var(--muted)]">
                        {m.family}
                      </td>
                      <td className="py-2 pr-3 text-xs text-[var(--muted)]">
                        {m.size}
                      </td>
                      <td className="py-2 pr-3 text-xs text-[var(--muted)]">
                        {m.params}
                      </td>
                      <td className="py-2 pr-3">
                        <span className="rounded-full border border-[var(--border-light)] px-2 py-0.5 text-[11px]">
                          {m.quant}
                        </span>
                      </td>
                      <td className="py-2 text-xs text-[var(--muted)]">
                        {m.endpoints?.join(", ") ?? "—"}
                      </td>
                    </tr>
                  ))}
                  {(models?.recent_models ?? []).length === 0 && (
                    <tr>
                      <td colSpan={6} className="py-6 text-center text-sm text-[var(--muted)]">
                        발견된 모델 없음
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>

          {/* 빠른 테스트 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-1 flex items-center gap-2 text-lg font-semibold">
              <Box size={18} className="text-[var(--accent)]" />
              라우팅 빠른 테스트
            </h2>
            <p className="mb-4 text-xs text-[var(--muted)]">
              /olla/proxy 경로로 요청을 보내 로컬 라우팅/폴백을 검증합니다.
            </p>
            <div className="space-y-3">
              <div className="flex flex-col gap-2 sm:flex-row">
                <input
                  value={testModel}
                  onChange={(e) => setTestModel(e.target.value)}
                  placeholder="모델 (예: qwen2.5:1.5b)"
                  className="rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-3 py-2 text-sm outline-none focus:border-[var(--accent)]"
                />
                <input
                  value={testPrompt}
                  onChange={(e) => setTestPrompt(e.target.value)}
                  placeholder="프롬프트"
                  className="flex-1 rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-3 py-2 text-sm outline-none focus:border-[var(--accent)]"
                />
                <button
                  onClick={runTest}
                  disabled={testLoading}
                  className="flex items-center justify-center gap-2 rounded-lg bg-[var(--accent)] px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-[var(--accent-hover)] disabled:opacity-50"
                >
                  <Send size={14} />
                  {testLoading ? "요청 중..." : "테스트"}
                </button>
              </div>
              {testResult !== null && (
                <div className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4">
                  <p className="mb-1 text-xs text-[var(--muted)]">응답</p>
                  <p className="whitespace-pre-wrap text-sm">{testResult}</p>
                </div>
              )}
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
