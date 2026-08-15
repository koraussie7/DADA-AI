"use client";

import { useEffect, useState } from "react";
import {
  Activity,
  BadgeDollarSign,
  Loader2,
  PiggyBank,
  Route,
  Shield,
  Terminal,
  TrendingDown,
  Zap,
} from "lucide-react";
import { ccrFetch } from "@/lib/ccr";

interface CCRSettings {
  fallbackStrategy: string;
  stickyRoundRobinLimit: number;
  comboStrategy: string;
  comboStickyRoundRobinLimit: number;
  requireLogin: boolean;
  requestRetry: number;
  apiPort: number;
  machineId: string;
}

interface HeadroomStatus {
  installed: boolean;
  running: boolean;
  url: string;
}

interface ClaudeSettings {
  installed: boolean;
  settingsPath?: string;
}

interface UsageAnalytics {
  summary?: {
    totalRequests: number;
    totalTokens: number;
    totalCost: number;
    successRatePct: number;
    avgLatencyMs: number;
    fallbackCount: number;
    fallbackRatePct: number;
    flexSavings: number;
    flexUsageSavingsTokens: number;
  };
}

interface QuotaProvider {
  name: string;
  provider: string;
  connectionId: string;
  quotaUsed: number;
  quotaTotal: number | null;
  percentRemaining: number;
  resetAt: string | null;
  tokenStatus: string;
}

interface QuotaStatus {
  providers?: QuotaProvider[];
}

interface BudgetStatus {
  budgetCheck?: {
    allowed: boolean;
    dailyUsed: number;
    dailyLimit: number;
    remaining: number;
    warningReached: boolean;
  };
  totalCostToday?: number;
  totalCostMonth?: number;
}

interface ProvidersStatus {
  connections?: {
    provider: string;
    name: string;
    isActive: boolean;
    testStatus: string;
  }[];
}

interface ModelAliasResponse {
  aliases?: Record<string, string>;
}

interface CatalogModel {
  id: string;
  name: string;
  type: string;
  context_length: number | null;
  custom?: boolean;
}

interface CatalogGroup {
  provider: string;
  active: boolean;
  models?: CatalogModel[];
}

interface ModelCatalog {
  catalog?: Record<string, CatalogGroup>;
}

interface ProviderNode {
  id: string;
  name: string;
  prefix: string;
  baseUrl: string;
}

interface ProviderNodesResponse {
  nodes?: ProviderNode[];
}

type Notice = { type: "success" | "error"; text: string } | null;

const defaultSettings: CCRSettings = {
  fallbackStrategy: "round-robin",
  stickyRoundRobinLimit: 3,
  comboStrategy: "fallback",
  comboStickyRoundRobinLimit: 1,
  requireLogin: true,
  requestRetry: 3,
  apiPort: 20128,
  machineId: "",
};

function fmtUsd(value: number | undefined): string {
  if (typeof value !== "number" || !Number.isFinite(value)) return "$0.00";
  if (value < 0.005) return "≈ $0";
  return `$${value.toFixed(4)}`;
}

export default function CcrPage() {
  const [settings, setSettings] = useState<CCRSettings | null>(null);
  const [headroom, setHeadroom] = useState<HeadroomStatus | null>(null);
  const [claude, setClaude] = useState<ClaudeSettings | null>(null);
  const [analytics, setAnalytics] = useState<UsageAnalytics | null>(null);
  const [quota, setQuota] = useState<QuotaStatus | null>(null);
  const [budget, setBudget] = useState<BudgetStatus | null>(null);
  const [providers, setProviders] = useState<ProvidersStatus | null>(null);
  const [aliases, setAliases] = useState<ModelAliasResponse | null>(null);
  const [catalog, setCatalog] = useState<ModelCatalog | null>(null);
  const [nodes, setNodes] = useState<ProviderNodesResponse | null>(null);
  const [routeQuery, setRouteQuery] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<Notice>(null);

  useEffect(() => {
    (async () => {
      try {
        const [settingsData, headroomData, claudeData, analyticsData, quotaData, budgetData, providersData, aliasesData, catalogData, nodesData] =
          await Promise.all([
            ccrFetch("settings"),
            ccrFetch("headroom/status"),
            ccrFetch("cli-tools/claude-settings"),
            ccrFetch("usage/analytics"),
            ccrFetch("usage/quota"),
            ccrFetch("usage/budget?apiKeyId=om-marketai-1"),
            ccrFetch("providers"),
            ccrFetch("models/alias"),
            ccrFetch("models/catalog"),
            ccrFetch("provider-nodes"),
          ]);
        setSettings({ ...defaultSettings, ...settingsData });
        setHeadroom(headroomData);
        setClaude(claudeData);
        setAnalytics(analyticsData);
        setQuota(quotaData);
        setBudget(budgetData);
        setProviders(providersData);
        setAliases(aliasesData);
        setCatalog(catalogData);
        setNodes(nodesData);
      } catch (e) {
        setError(e instanceof Error ? e.message : "CCR 정보를 불러오지 못했습니다.");
      }
    })();
  }, []);

  const patchSettings = async (patch: Partial<CCRSettings>, label: string) => {
    try {
      const data = await ccrFetch("settings", {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(patch),
      });
      setSettings((prev) => ({ ...(prev || defaultSettings), ...data, ...patch }));
      setNotice({ type: "success", text: `${label} 저장됨` });
      setTimeout(() => setNotice(null), 2500);
    } catch (e) {
      setNotice({
        type: "error",
        text: e instanceof Error ? e.message : "저장에 실패했습니다.",
      });
      setTimeout(() => setNotice(null), 4000);
    }
  };

  const loading = !settings;
  const summary = analytics?.summary;
  const activeConns = providers?.connections?.filter((c) => c.isActive) ?? [];
  const gatewayOk = !!settings;

  const aliasEntries = Object.entries(aliases?.aliases ?? {});
  const nodeList = nodes?.nodes ?? [];
  const connNames = providers?.connections?.map((c) => c.name) ?? [];
  const catalogGroups = Object.entries(catalog?.catalog ?? {}).sort(
    (a, b) => (b[1].models?.length ?? 0) - (a[1].models?.length ?? 0)
  );
  const routeRows = catalogGroups.flatMap(([key, g]) =>
    (g.models ?? []).map((m) => {
      const base = m.id.split("/").slice(1).join("/");
      return {
        ...m,
        groupKey: key,
        providerName: g.provider,
        active: g.active,
        aliased: !!aliases?.aliases?.[base],
      };
    })
  );
  const totalModels = routeRows.length;
  const q = routeQuery.trim().toLowerCase();
  const filteredRows = q
    ? routeRows.filter(
        (r) =>
          r.id.toLowerCase().includes(q) ||
          r.providerName.toLowerCase().includes(q) ||
          r.type.toLowerCase().includes(q)
      )
    : routeRows;

  return (
    <div className="p-8">
      <header className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">CCR 설정</h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          OmniRoute (Claude Code Router) — 라우팅, 보안, 비용 관리를 관리합니다.
        </p>
      </header>

      {error && (
        <div className="mb-6 rounded-xl border border-[#f85149]/30 bg-[#f85149]/10 p-4 text-sm text-[#f85149]">
          {error}
        </div>
      )}

      {notice && (
        <div
          className={`mb-6 rounded-xl border p-4 text-sm ${
            notice.type === "success"
              ? "border-[#3fb950]/30 bg-[#3fb950]/10 text-[#3fb950]"
              : "border-[#f85149]/30 bg-[#f85149]/10 text-[#f85149]"
          }`}
        >
          {notice.text}
        </div>
      )}

      {loading ? (
        <div className="flex items-center justify-center gap-2 p-12 text-[var(--muted)]">
          <Loader2 size={18} className="animate-spin" />
          CCR 상태를 불러오는 중...
        </div>
      ) : (
        <div className="max-w-4xl space-y-6">
          {/* 상태 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Activity size={18} className="text-[var(--accent)]" />
              시스템 상태
            </h2>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
              <div className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4">
                <p className="text-xs text-[var(--muted)]">게이트웨이</p>
                <p className="mt-1 flex items-center gap-2 text-sm font-semibold">
                  <span
                    className={`inline-block h-2 w-2 rounded-full ${
                      gatewayOk ? "bg-[#3fb950]" : "bg-[#f85149]"
                    }`}
                  />
                  {gatewayOk ? `정상 (${settings.apiPort})` : "오류"}
                </p>
              </div>
              <div className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4">
                <p className="text-xs text-[var(--muted)]">프로바이더 연결</p>
                <p className="mt-1 flex items-center gap-2 text-sm font-semibold">
                  <span
                    className={`inline-block h-2 w-2 rounded-full ${
                      activeConns.length > 0 ? "bg-[#3fb950]" : "bg-[#f85149]"
                    }`}
                  />
                  {activeConns.length > 0
                    ? `${activeConns.length}개 활성`
                    : "연결 없음"}
                </p>
              </div>
              <div className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4">
                <p className="text-xs text-[var(--muted)]">Headroom</p>
                <p className="mt-1 flex items-center gap-2 text-sm font-semibold">
                  <span
                    className={`inline-block h-2 w-2 rounded-full ${
                      headroom?.running ? "bg-[#3fb950]" : "bg-[var(--muted)]"
                    }`}
                  />
                  {headroom?.running ? "실행 중" : "꺼짐"}
                </p>
              </div>
            </div>
          </section>

          {/* 라우팅 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Route size={18} className="text-[var(--accent)]" />
              라우팅 전략
            </h2>
            <div className="space-y-4">
              <ToggleRow
                title="라운드 로빈"
                desc="계정을 순환하며 부하를 분산합니다 (끄면 Fill-First)."
                checked={settings.fallbackStrategy === "round-robin"}
                onChange={() =>
                  patchSettings(
                    {
                      fallbackStrategy:
                        settings.fallbackStrategy === "round-robin"
                          ? "fill-first"
                          : "round-robin",
                    },
                    "라우팅 전략"
                  )
                }
              />
              {settings.fallbackStrategy === "round-robin" && (
                <NumberRow
                  title="스티키 라운드 로빈 한도"
                  desc="계정 전환 전 호출 수"
                  value={settings.stickyRoundRobinLimit}
                  min={1}
                  max={10}
                  onSave={(v) =>
                    patchSettings({ stickyRoundRobinLimit: v }, "스티키 한도")
                  }
                />
              )}
              <ToggleRow
                title="콤보 라운드 로빈"
                desc="콤보 모델도 첫 모델이 아닌 순환 사용"
                checked={settings.comboStrategy === "round-robin"}
                onChange={() =>
                  patchSettings(
                    {
                      comboStrategy:
                        settings.comboStrategy === "round-robin"
                          ? "fallback"
                          : "round-robin",
                    },
                    "콤보 전략"
                  )
                }
              />
              {settings.comboStrategy === "round-robin" && (
                <NumberRow
                  title="콤보 스티키 한도"
                  desc="콤보 모델 전환 전 호출 수"
                  value={settings.comboStickyRoundRobinLimit}
                  min={1}
                  max={100}
                  onSave={(v) =>
                    patchSettings(
                      { comboStickyRoundRobinLimit: v },
                      "콤보 스티키 한도"
                    )
                  }
                />
              )}
              <NumberRow
                title="재시도 횟수"
                desc="실패한 요청의 자동 재시도 수"
                value={settings.requestRetry}
                min={0}
                max={10}
                onSave={(v) => patchSettings({ requestRetry: v }, "재시도")}
              />
            </div>
          </section>

          {/* 라우팅 맵 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Route size={18} className="text-[var(--accent)]" />
              API 라우팅 맵
            </h2>
            <div className="grid grid-cols-1 gap-3 md:grid-cols-[1fr_auto_1fr_auto_1fr]">
              <MapColumn
                title="요청 모델 (별칭)"
                items={aliasEntries.slice(0, 12).map(([k]) => k)}
                note={aliasEntries.length > 12 ? `외 ${aliasEntries.length - 12}개` : ""}
              />
              <div className="flex items-center justify-center text-[var(--muted)] md:px-1">
                →
              </div>
              <MapColumn
                title="라우팅 노드"
                items={nodeList.map((n) => n.name)}
                note={
                  nodeList.length > 0
                    ? `${nodeList[0].prefix} · ${nodeList[0].baseUrl}`
                    : ""
                }
              />
              <div className="flex items-center justify-center text-[var(--muted)] md:px-1">
                →
              </div>
              <MapColumn
                title="프로바이더 연결"
                items={connNames}
                note={activeConns.length > 0 ? `${activeConns.length}개 활성` : ""}
              />
            </div>

            <p className="mb-3 mt-6 text-xs text-[var(--muted)]">
              프로바이더 그룹 (카탈로그)
            </p>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
              {catalogGroups.map(([key, g]) => (
                <div
                  key={key}
                  className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-3"
                >
                  <div className="flex items-center justify-between gap-2">
                    <code className="font-mono text-xs text-[var(--accent)]">{key}</code>
                    <span
                      className={`inline-block h-2 w-2 shrink-0 rounded-full ${
                        g.active ? "bg-[#3fb950]" : "bg-[var(--muted)]"
                      }`}
                    />
                  </div>
                  <p className="mt-1 truncate text-xs text-[var(--muted)]" title={g.provider}>
                    {g.provider}
                  </p>
                  <p className="mt-1 text-sm font-semibold">
                    {(g.models?.length ?? 0).toLocaleString()} 모델
                  </p>
                </div>
              ))}
            </div>
          </section>

          {/* 라우팅 테이블 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-1 flex items-center gap-2 text-lg font-semibold">
              <Route size={18} className="text-[var(--accent)]" />
              API 라우팅 테이블
            </h2>
            <p className="mb-4 text-xs text-[var(--muted)]">
              카탈로그 모델 {totalModels.toLocaleString()}개 — "별칭" 배지는
              요청 모델명이 별칭으로 라우팅됨을 의미합니다.
            </p>
            <input
              type="search"
              value={routeQuery}
              onChange={(e) => setRouteQuery(e.target.value)}
              placeholder="모델/프로바이더/유형 검색..."
              className="mb-4 w-full max-w-sm rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-3 py-2 text-sm outline-none focus:border-[var(--accent)]"
            />
            <div className="overflow-x-auto">
              <table className="w-full min-w-[560px] text-sm">
                <thead>
                  <tr className="border-b border-[var(--border)] text-left text-xs text-[var(--muted)]">
                    <th className="py-2 pr-3 font-medium">모델</th>
                    <th className="py-2 pr-3 font-medium">프로바이더</th>
                    <th className="py-2 pr-3 font-medium">유형</th>
                    <th className="py-2 pr-3 text-right font-medium">컨텍스트</th>
                    <th className="py-2 font-medium">라우팅</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredRows.slice(0, 100).map((r, i) => (
                    <tr
                      key={`${r.id}-${i}`}
                      className="border-b border-[var(--border-light)]/50 last:border-0"
                    >
                      <td className="py-2 pr-3">
                        <code className="font-mono text-xs">{r.id}</code>
                      </td>
                      <td className="py-2 pr-3 text-xs text-[var(--muted)]">
                        {r.providerName}
                      </td>
                      <td className="py-2 pr-3">
                        <span className="rounded-full border border-[var(--border-light)] px-2 py-0.5 text-[11px]">
                          {r.type || "chat"}
                        </span>
                      </td>
                      <td className="py-2 pr-3 text-right text-xs text-[var(--muted)]">
                        {r.context_length ? r.context_length.toLocaleString() : "—"}
                      </td>
                      <td className="py-2">
                        {r.aliased ? (
                          <span className="rounded-full bg-[#3fb950]/10 px-2 py-0.5 text-[11px] font-semibold text-[#3fb950]">
                            별칭
                          </span>
                        ) : (
                          <span className="text-[11px] text-[var(--muted)]">직접</span>
                        )}
                      </td>
                    </tr>
                  ))}
                  {filteredRows.length === 0 && (
                    <tr>
                      <td colSpan={5} className="py-6 text-center text-sm text-[var(--muted)]">
                        일치하는 모델 없음
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            {filteredRows.length > 100 && (
              <p className="mt-3 text-xs text-[var(--muted)]">
                {filteredRows.length - 100}개 이상은 검색으로 확인하세요.
              </p>
            )}
          </section>

          {/* 보안 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Shield size={18} className="text-[var(--accent)]" />
              보안
            </h2>
            <div className="space-y-4">
              <ToggleRow
                title="대시보드 로그인 필수"
                desc="ON이면 대시보드 접속 시 비밀번호가 필요합니다."
                checked={settings.requireLogin}
                onChange={() =>
                  patchSettings({ requireLogin: !settings.requireLogin }, "로그인 필수")
                }
              />
            </div>
          </section>

          {/* 무료예산 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <BadgeDollarSign size={18} className="text-[var(--accent)]" />
              무료 예산
            </h2>
            <div className="space-y-3">
              <div className="flex items-center justify-between rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4">
                <div>
                  <p className="text-xs text-[var(--muted)]">월간 지출</p>
                  <p className="mt-1 text-lg font-semibold">
                    {fmtUsd(budget?.totalCostMonth ?? summary?.totalCost)}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-xs text-[var(--muted)]">예산 상태</p>
                  <p
                    className={`mt-1 text-sm font-semibold ${
                      budget?.budgetCheck?.allowed === false
                        ? "text-[#f85149]"
                        : "text-[#3fb950]"
                    }`}
                  >
                    {budget?.budgetCheck?.allowed === false
                      ? "제한됨"
                      : "정상"}
                  </p>
                </div>
              </div>
              <div className="space-y-2">
                <p className="text-xs text-[var(--muted)]">
                  무료 쿼터 잔량 (프로바이더)
                </p>
                {quota?.providers && quota.providers.length > 0 ? (
                  quota.providers.map((p) => (
                    <div
                      key={p.connectionId}
                      className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-3"
                    >
                      <div className="flex items-center justify-between text-sm">
                        <span className="font-medium">{p.name}</span>
                        <span
                          className={`text-xs ${
                            p.percentRemaining < 25
                              ? "text-[#f85149]"
                              : p.percentRemaining < 60
                                ? "text-[#d29922]"
                                : "text-[var(--muted)]"
                          }`}
                        >
                          잔량 {Math.round(p.percentRemaining)}%
                        </span>
                      </div>
                      <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-[var(--border-light)]">
                        <div
                          className={`h-full rounded-full ${
                            p.percentRemaining < 25
                              ? "bg-[#f85149]"
                              : p.percentRemaining < 60
                                ? "bg-[#d29922]"
                                : "bg-[#3fb950]"
                          }`}
                          style={{ width: `${p.percentRemaining}%` }}
                        />
                      </div>
                      {p.resetAt && (
                        <p className="mt-1 text-xs text-[var(--muted)]">
                          리셋: {p.resetAt}
                        </p>
                      )}
                    </div>
                  ))
                ) : (
                  <p className="text-sm text-[var(--muted)]">쿼터 정보 없음</p>
                )}
              </div>
            </div>
          </section>

          {/* 폴백 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Zap size={18} className="text-[var(--accent)]" />
              폴백 상태
            </h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <Stat
                label="폴백 발생"
                value={`${summary?.fallbackCount ?? 0}회`}
              />
              <Stat
                label="폴백 비율"
                value={`${summary?.fallbackRatePct ?? 0}%`}
              />
              <Stat
                label="콤보 전략"
                value={settings.comboStrategy === "round-robin" ? "순환" : "폴백"}
              />
              <Stat
                label="계정 전략"
                value={
                  settings.fallbackStrategy === "round-robin"
                    ? "라운드 로빈"
                    : "Fill-First"
                }
              />
            </div>
          </section>

          {/* 절감 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <PiggyBank size={18} className="text-[var(--accent)]" />
              절감 현황
            </h2>
            <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
              <Stat label="총 비용" value={fmtUsd(summary?.totalCost)} />
              <Stat label="절감액" value={fmtUsd(summary?.flexSavings)} />
              <Stat
                label="절감 토큰"
                value={`${(summary?.flexUsageSavingsTokens ?? 0).toLocaleString()}`}
              />
              <Stat
                label="총 요청"
                value={`${(summary?.totalRequests ?? 0).toLocaleString()}`}
              />
            </div>
            {summary && summary.totalCost < 0.005 && (
              <p className="mt-3 flex items-center gap-1.5 text-sm text-[#3fb950]">
                <TrendingDown size={14} />
                무료 제공자(무료 쿼터)만 사용 중 — AI 달러 비용 0원으로 운영 중입니다.
              </p>
            )}
          </section>

          {/* Claude Code */}
          <section className="rounded-xl border border-[var(--accent)]/30 bg-[#0f1a2e] p-6">
            <h2 className="mb-1 flex items-center gap-2 text-lg font-semibold">
              <Terminal size={18} className="text-[var(--accent)]" />
              Claude Code 통합
            </h2>
            <p className="mb-4 text-xs text-[var(--muted)]">
              CCR이 Claude Code에 주입하는 후킹 설정입니다.
            </p>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm text-[var(--muted)]">설치됨</span>
                <span className="flex items-center gap-2 text-sm font-semibold">
                  <span
                    className={`inline-block h-2 w-2 rounded-full ${
                      claude?.installed ? "bg-[#3fb950]" : "bg-[#f85149]"
                    }`}
                  />
                  {claude?.installed ? "예" : "아니오"}
                </span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm text-[var(--muted)]">설정 파일</span>
                <code className="break-all font-mono text-xs text-[var(--accent)]">
                  {claude?.settingsPath || "—"}
                </code>
              </div>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}

function ToggleRow({
  title,
  desc,
  checked,
  onChange,
}: {
  title: string;
  desc: string;
  checked: boolean;
  onChange: () => void;
}) {
  return (
    <label className="flex items-center justify-between gap-4">
      <div>
        <p className="text-sm font-medium">{title}</p>
        <p className="text-xs text-[var(--muted)]">{desc}</p>
      </div>
      <input
        type="checkbox"
        checked={checked}
        onChange={onChange}
        className="h-5 w-5 accent-[var(--accent)]"
      />
    </label>
  );
}

function NumberRow({
  title,
  desc,
  value,
  min,
  max,
  onSave,
}: {
  title: string;
  desc: string;
  value: number;
  min: number;
  max: number;
  onSave: (v: number) => void;
}) {
  const [draft, setDraft] = useState(String(value));

  useEffect(() => {
    setDraft(String(value));
  }, [value]);

  const save = () => {
    const n = parseInt(draft, 10);
    if (Number.isNaN(n) || n < min || n > max) {
      setDraft(String(value));
      return;
    }
    onSave(n);
  };

  return (
    <div className="flex items-center justify-between gap-4 border-t border-[var(--border)] pt-4">
      <div>
        <p className="text-sm font-medium">{title}</p>
        <p className="text-xs text-[var(--muted)]">{desc}</p>
      </div>
      <div className="flex items-center gap-2">
        <input
          type="number"
          min={min}
          max={max}
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          onBlur={save}
          onKeyDown={(e) => {
            if (e.key === "Enter") save();
          }}
          className="w-20 rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-3 py-1.5 text-center text-sm outline-none focus:border-[var(--accent)]"
        />
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4">
      <p className="text-xs text-[var(--muted)]">{label}</p>
      <p className="mt-1 text-base font-semibold">{value}</p>
    </div>
  );
}

function MapColumn({
  title,
  items,
  note,
}: {
  title: string;
  items: string[];
  note?: string;
}) {
  return (
    <div className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-3">
      <p className="mb-2 text-xs font-medium text-[var(--muted)]">{title}</p>
      <div className="flex flex-wrap gap-1.5">
        {items.map((it) => (
          <code
            key={it}
            className="rounded bg-[var(--border-light)]/40 px-1.5 py-0.5 font-mono text-[11px]"
          >
            {it}
          </code>
        ))}
        {items.length === 0 && <span className="text-xs text-[var(--muted)]">—</span>}
      </div>
      {note && <p className="mt-2 truncate text-[11px] text-[var(--muted)]">{note}</p>}
    </div>
  );
}
