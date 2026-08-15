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
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<Notice>(null);

  useEffect(() => {
    (async () => {
      try {
        const [settingsData, headroomData, claudeData, analyticsData, quotaData, budgetData, providersData] =
          await Promise.all([
            ccrFetch("settings"),
            ccrFetch("headroom/status"),
            ccrFetch("cli-tools/claude-settings"),
            ccrFetch("usage/analytics"),
            ccrFetch("usage/quota"),
            ccrFetch("usage/budget?apiKeyId=om-marketai-1"),
            ccrFetch("providers"),
          ]);
        setSettings({ ...defaultSettings, ...settingsData });
        setHeadroom(headroomData);
        setClaude(claudeData);
        setAnalytics(analyticsData);
        setQuota(quotaData);
        setBudget(budgetData);
        setProviders(providersData);
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
        <div className="max-w-2xl space-y-6">
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
