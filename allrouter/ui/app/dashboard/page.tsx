"use client";

import { useEffect, useState } from "react";
import { ArrowUpRight, Cpu, Zap, DollarSign, Activity, Loader2 } from "lucide-react";
import CreateKeyModal from "@/components/CreateKeyModal";
import CostChart from "@/components/CostChart";
import { llmFetch } from "@/lib/litellm";

interface SpendLog {
  request_id?: string;
  model_group?: string;
  model?: string;
  request_duration_ms?: number;
  total_tokens?: number;
  prompt_tokens?: number;
  completion_tokens?: number;
  spend?: number;
  startTime?: string;
  api_key?: string;
  metadata?: { status?: string };
  status?: string;
}

interface ApiUsageRow {
  key: string;
  label: string;
  requests: number;
  tokens: number;
  spend: number;
  models: Set<string>;
}

function fmtKey(key: string): string {
  if (!key) return "알 수 없음";
  if (key === "litellm_proxy_master_key") return "master-key";
  const last = key.split("-").pop() || "";
  return `sk-…-${last}`;
}

export default function DashboardPage() {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [logs, setLogs] = useState<SpendLog[]>([]);
  const [globalSpend, setGlobalSpend] = useState<{ spend?: number; max_budget?: number } | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const [logsData, spendData] = await Promise.all([
          llmFetch("spend/logs?limit=1000"),
          llmFetch("global/spend"),
        ]);
        setLogs(Array.isArray(logsData) ? logsData : []);
        setGlobalSpend(spendData);
      } catch (e) {
        setError(e instanceof Error ? e.message : "데이터를 불러오지 못했습니다.");
      }
    })();
  }, []);

  const recentLogs = logs.slice(0, 6);
  const totalRequests = logs.length;
  const successCount = logs.filter((l) => (l.status ?? l.metadata?.status) !== "failure").length;
  const successRate =
    totalRequests > 0 ? Math.round((successCount / totalRequests) * 1000) / 10 : 100;
  const totalCost = logs.reduce((acc, l) => acc + (l.spend || 0), 0);
  const totalTokens = logs.reduce((acc, l) => acc + (l.total_tokens || 0), 0);
  const freeRequests = logs.filter((l) => !l.spend).length;
  const freeRate =
    totalRequests > 0 ? Math.round((freeRequests / totalRequests) * 1000) / 10 : 100;

  // 일별 토큰/비용 (실데이터)
  const dailyMap = new Map<string, { date: string; tokens: number; cost: number }>();
  logs.forEach((l) => {
    const d = (l.startTime || "").slice(0, 10);
    if (!d) return;
    const e = dailyMap.get(d) || { date: d, tokens: 0, cost: 0 };
    e.tokens += l.total_tokens || 0;
    e.cost += l.spend || 0;
    dailyMap.set(d, e);
  });
  const dailyData = [...dailyMap.values()]
    .sort((a, b) => a.date.localeCompare(b.date))
    .slice(-14);

  // API 키별 토큰 사용량
  const apiMap = new Map<string, ApiUsageRow>();
  logs.forEach((l) => {
    const k = l.api_key || "unknown";
    const row = apiMap.get(k) || {
      key: k,
      label: fmtKey(k),
      requests: 0,
      tokens: 0,
      spend: 0,
      models: new Set<string>(),
    };
    row.requests += 1;
    row.tokens += l.total_tokens || 0;
    row.spend += l.spend || 0;
    if (l.model_group || l.model) row.models.add(l.model_group || l.model || "");
    apiMap.set(k, row);
  });
  const apiUsage = [...apiMap.values()].sort((a, b) => b.tokens - a.tokens);

  const stats = [
    {
      name: "총 요청",
      value: totalRequests.toLocaleString(),
      icon: Zap,
      color: "text-[#d29922]",
    },
    {
      name: "총 토큰",
      value: totalTokens.toLocaleString(),
      icon: Cpu,
      color: "text-[#60a5fa]",
    },
    {
      name: "총 비용",
      value: `$${totalCost.toFixed(4)}`,
      icon: DollarSign,
      color: "text-[#3fb950]",
    },
    {
      name: "성공률",
      value: `${successRate}%`,
      icon: ArrowUpRight,
      color: "text-[#a78bfa]",
    },
  ];

  // 모델별 사용 비율
  const modelUsage = new Map<string, number>();
  logs.forEach((l) => {
    const m = l.model_group || l.model || "unknown";
    modelUsage.set(m, (modelUsage.get(m) || 0) + 1);
  });
  const topModels = Array.from(modelUsage.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([name, count]) => ({
      name,
      usage: totalRequests > 0 ? Math.round((count / totalRequests) * 100) : 0,
      color: ["#60a5fa", "#3fb950", "#a78bfa", "#d29922"][
        Array.from(modelUsage.keys()).indexOf(name) % 4
      ],
    }));

  return (
    <div className="p-8">
      <header className="mb-8 flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">대시보드</h1>
          <p className="mt-1 text-sm text-[var(--muted)]">
            AI 게이트웨이 실시간 모니터링
          </p>
        </div>
        <button
          onClick={() => setIsModalOpen(true)}
          className="rounded-lg bg-[var(--accent)] px-4 py-2 font-medium text-white shadow-lg shadow-[var(--accent)]/20 transition-all hover:bg-[var(--accent-hover)]"
        >
          + 새 API 키
        </button>
      </header>

      {error && (
        <div className="mb-6 rounded-xl border border-[#f85149]/30 bg-[#f85149]/10 p-4 text-sm text-[#f85149]">
          {error}
        </div>
      )}

      {/* 통계 카드 */}
      <div className="mb-8 grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => (
          <div
            key={stat.name}
            className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6 transition-colors hover:border-[var(--border-light)]"
          >
            <div className="mb-4 flex items-center justify-between">
              <div className={`rounded-lg bg-[var(--panel-2)] p-2 ${stat.color}`}>
                <stat.icon size={20} />
              </div>
              <Activity size={16} className="text-[var(--border-light)]" />
            </div>
            <p className="text-sm text-[var(--muted)]">{stat.name}</p>
            <h3 className="mt-1 text-2xl font-bold">{stat.value}</h3>
          </div>
        ))}
      </div>

      {/* 차트 + 모델 분포 */}
      <div className="mb-8 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <CostChart data={dailyData} freeRate={freeRate} />
        </div>
        <div className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
          <h2 className="mb-4 text-lg font-semibold">모델 분포</h2>
          {topModels.length === 0 ? (
            <p className="text-sm text-[var(--muted)]">아직 요청 기록이 없습니다.</p>
          ) : (
            <div className="space-y-5">
              {topModels.map((model) => (
                <div key={model.name}>
                  <div className="mb-1 flex justify-between text-sm">
                    <span className="truncate text-[var(--muted)]">{model.name}</span>
                    <span>{model.usage}%</span>
                  </div>
                  <div className="h-2 w-full rounded-full bg-[var(--panel-2)]">
                    <div
                      className={`h-2 rounded-full`}
                      style={{ width: `${model.usage}%`, backgroundColor: model.color }}
                    />
                  </div>
                </div>
              ))}
            </div>
          )}
          <div className="mt-6 rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4">
            <p className="text-xs text-[var(--muted)]">총 지출</p>
            <div className="mt-2 flex items-center justify-between text-sm">
              <span className="font-semibold">
                ${(globalSpend?.spend ?? 0).toFixed(4)} / $
                {(globalSpend?.max_budget ?? 0).toFixed(2)}
              </span>
              <span className="text-[var(--accent)]">
                {globalSpend?.max_budget
                  ? Math.round(((globalSpend.spend || 0) / globalSpend.max_budget) * 100)
                  : 0}
                %
              </span>
            </div>
            <div className="mt-2 h-2 w-full rounded-full bg-[var(--panel-2)]">
              <div
                className="h-2 rounded-full bg-[var(--accent)]"
                style={{
                  width: `${globalSpend?.max_budget ? Math.min(100, ((globalSpend.spend || 0) / globalSpend.max_budget) * 100) : 0}%`,
                }}
              />
            </div>
          </div>
        </div>
      </div>

      {/* API별 토큰 사용량 */}
      <div className="mb-8 overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--panel)]">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border)] p-6">
          <div>
            <h2 className="text-lg font-semibold">API별 토큰 사용량</h2>
            <p className="text-xs text-[var(--muted)]">
              지출 로그 기준 (총 {totalRequests.toLocaleString()}건 ·{" "}
              {totalTokens.toLocaleString()} 토큰 · 비용 ${totalCost.toFixed(4)})
            </p>
          </div>
          {freeRate >= 99.9 && (
            <span className="rounded-full bg-[#3fb950]/10 px-3 py-1 text-xs font-semibold text-[#3fb950]">
              무료 라우팅 {freeRate}%
            </span>
          )}
        </div>
        <div className="overflow-x-auto">
          <table className="w-full min-w-[520px] text-left text-sm">
            <thead className="bg-[var(--panel-2)] text-[var(--muted)]">
              <tr>
                <th className="p-4 font-medium">API 키</th>
                <th className="p-4 font-medium">요청</th>
                <th className="p-4 font-medium">토큰</th>
                <th className="p-4 font-medium">비용</th>
                <th className="p-4 font-medium">모델</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--border)]">
              {apiUsage.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-[var(--muted)]">
                    아직 요청 기록이 없습니다.
                  </td>
                </tr>
              ) : (
                apiUsage.map((row) => (
                  <tr key={row.key} className="transition-colors hover:bg-[var(--panel-2)]">
                    <td className="p-4 font-mono text-xs text-[var(--accent)]">
                      {row.label}
                    </td>
                    <td className="p-4">{row.requests.toLocaleString()}</td>
                    <td className="p-4 font-semibold">{row.tokens.toLocaleString()}</td>
                    <td className="p-4 text-[var(--muted)]">
                      ${row.spend.toFixed(4)}
                    </td>
                    <td className="p-4">
                      <div className="flex flex-wrap gap-1">
                        {[...row.models].slice(0, 4).map((m) => (
                          <span
                            key={m}
                            className="rounded bg-[var(--panel-2)] px-2 py-0.5 text-[11px] text-[var(--muted)]"
                          >
                            {m}
                          </span>
                        ))}
                        {row.models.size > 4 && (
                          <span className="text-[11px] text-[var(--muted)]">
                            +{row.models.size - 4}
                          </span>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* 최근 요청 */}
      <div className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--panel)]">
        <div className="border-b border-[var(--border)] p-6">
          <h2 className="text-lg font-semibold">최근 요청</h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--panel-2)] text-[var(--muted)]">
              <tr>
                <th className="p-4 font-medium">요청 ID</th>
                <th className="p-4 font-medium">모델</th>
                <th className="p-4 font-medium">응답 시간</th>
                <th className="p-4 font-medium">토큰</th>
                <th className="p-4 font-medium">상태</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--border)]">
              {logs.length === 0 ? (
                <tr>
                  <td colSpan={5} className="p-8 text-center text-[var(--muted)]">
                    아직 요청 기록이 없습니다.
                  </td>
                </tr>
              ) : (
                recentLogs.map((log) => {
                  const status = log.status ?? log.metadata?.status ?? "success";
                  const ok = status !== "failure";
                  return (
                    <tr key={log.request_id} className="transition-colors hover:bg-[var(--panel-2)]">
                      <td className="p-4 font-mono text-xs text-[var(--accent)]">
                        {log.request_id}
                      </td>
                      <td className="p-4">
                        <span className="rounded bg-[var(--panel-2)] px-2 py-1 text-xs">
                          {log.model_group || log.model || "—"}
                        </span>
                      </td>
                      <td className="p-4 text-[var(--muted)]">
                        {ok ? `${log.request_duration_ms ?? 0}ms` : "—"}
                      </td>
                      <td className="p-4 text-[var(--muted)]">
                        {ok ? (log.total_tokens ?? 0).toLocaleString() : "—"}
                      </td>
                      <td className="p-4">
                        {ok ? (
                          <span className="flex items-center gap-1.5 text-[#3fb950]">
                            <span className="h-2 w-2 rounded-full bg-[#3fb950]" />
                            성공
                          </span>
                        ) : (
                          <span className="flex items-center gap-1.5 text-[#f85149]">
                            <span className="h-2 w-2 rounded-full bg-[#f85149]" />
                            실패
                          </span>
                        )}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      <CreateKeyModal
        isOpen={isModalOpen}
        onClose={() => setIsModalOpen(false)}
      />
    </div>
  );
}
