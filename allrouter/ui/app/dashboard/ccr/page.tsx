"use client";

import { useEffect, useState } from "react";
import {
  Activity,
  Cpu,
  Eye,
  Loader2,
  Network,
  Route,
  Shield,
  Terminal,
} from "lucide-react";
import { ccrFetch } from "@/lib/ccr";

interface CCRSettings {
  fallbackStrategy: string;
  stickyRoundRobinLimit: number;
  comboStrategy: string;
  comboStickyRoundRobinLimit: number;
  requireLogin: boolean;
  requireApiKey: boolean;
  enableObservability: boolean;
  outboundProxyEnabled: boolean;
  outboundProxyUrl: string;
  outboundNoProxy: string;
}

interface HealthStatus {
  ok: boolean;
}

interface TunnelStatus {
  tunnel?: {
    enabled?: boolean;
    running?: boolean;
    publicUrl?: string;
  };
  tailscale?: {
    enabled?: boolean;
    running?: boolean;
    loggedIn?: boolean;
  };
}

interface HeadroomStatus {
  installed: boolean;
  running: boolean;
  url: string;
}

interface ClaudeSettings {
  installed: boolean;
  has9Router?: boolean;
  exaMcpEnabled?: boolean;
  settingsPath?: string;
}

type Notice = { type: "success" | "error"; text: string } | null;

function describeProxyError(message: string): string {
  if (/request was cancelled/i.test(message)) {
    return "연결이 취소되었습니다. 지정한 URL이 HTTP forward proxy로 동작하지 않는 것 같습니다. LiteLLM 등 일반 API 서버는 프록시가 아니므로 테스트에 실패합니다. http/https forward proxy URL을 입력하세요.";
  }
  if (/ECONNREFUSED/i.test(message)) {
    return "연결이 거부되었습니다. 해당 주소:포트에서 프록시가 실행 중인지 확인하세요.";
  }
  if (/Invalid URL protocol|must start with/i.test(message)) {
    return "http:// 또는 https:// 로 시작하는 URL만 지원됩니다. (SOCKS5 프록시는 지원되지 않습니다)";
  }
  if (/Invalid proxy URL/i.test(message)) {
    return "프록시 URL 형식이 올바르지 않습니다.";
  }
  if (/timed out|AbortError/i.test(message)) {
    return "프록시 테스트가 시간 초과되었습니다. 프록시 주소가 응답하는지 확인하세요.";
  }
  return message;
}

const defaultSettings: CCRSettings = {
  fallbackStrategy: "round-robin",
  stickyRoundRobinLimit: 3,
  comboStrategy: "fallback",
  comboStickyRoundRobinLimit: 1,
  requireLogin: true,
  requireApiKey: true,
  enableObservability: true,
  outboundProxyEnabled: false,
  outboundProxyUrl: "",
  outboundNoProxy: "",
};

export default function CcrPage() {
  const [settings, setSettings] = useState<CCRSettings | null>(null);
  const [health, setHealth] = useState<HealthStatus | null>(null);
  const [tunnel, setTunnel] = useState<TunnelStatus | null>(null);
  const [headroom, setHeadroom] = useState<HeadroomStatus | null>(null);
  const [claude, setClaude] = useState<ClaudeSettings | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<Notice>(null);
  const [proxyUrl, setProxyUrl] = useState("");
  const [noProxy, setNoProxy] = useState("");
  const [testingProxy, setTestingProxy] = useState(false);
  const [proxyTestMsg, setProxyTestMsg] = useState<Notice>(null);

  useEffect(() => {
    (async () => {
      try {
        const [settingsData, healthData, tunnelData, headroomData, claudeData] =
          await Promise.all([
            ccrFetch("settings"),
            ccrFetch("health"),
            ccrFetch("tunnel/status"),
            ccrFetch("headroom/status"),
            ccrFetch("cli-tools/claude-settings"),
          ]);
        setSettings({ ...defaultSettings, ...settingsData });
        setProxyUrl(settingsData.outboundProxyUrl || "");
        setNoProxy(settingsData.outboundNoProxy || "");
        setHealth(healthData);
        setTunnel(tunnelData);
        setHeadroom(headroomData);
        setClaude(claudeData);
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

  const testProxy = async () => {
    const url = proxyUrl.trim();
    if (!url) {
      setProxyTestMsg({ type: "error", text: "프록시 URL을 입력하세요." });
      return;
    }
    setTestingProxy(true);
    setProxyTestMsg(null);
    try {
      const data = await ccrFetch("settings/proxy-test", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ proxyUrl: url }),
      });
      setProxyTestMsg({
        type: "success",
        text: data?.ok
          ? `프록시 연결 성공 (HTTP ${data.status}) ${data.elapsedMs ?? ""}ms`
          : describeProxyError(data?.error || "프록시 테스트 실패"),
      });
    } catch (e) {
      setProxyTestMsg({
        type: "error",
        text: describeProxyError(
          e instanceof Error ? e.message : "프록시 테스트 실패"
        ),
      });
    } finally {
      setTestingProxy(false);
    }
  };

  const loading = !settings;

  return (
    <div className="p-8">
      <header className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">CCR 설정</h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          9Router (Claude Code Router) — 라우팅, 보안, 관측 설정을 관리합니다.
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
                      health?.ok ? "bg-[#3fb950]" : "bg-[#f85149]"
                    }`}
                  />
                  {health?.ok ? "정상" : "오류"}
                </p>
              </div>
              <div className="rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4">
                <p className="text-xs text-[var(--muted)]">터널</p>
                <p className="mt-1 flex items-center gap-2 text-sm font-semibold">
                  <span
                    className={`inline-block h-2 w-2 rounded-full ${
                      tunnel?.tunnel?.running || tunnel?.tailscale?.running
                        ? "bg-[#3fb950]"
                        : "bg-[var(--muted)]"
                    }`}
                  />
                  {tunnel?.tunnel?.running || tunnel?.tailscale?.running
                    ? "실행 중"
                    : "꺼짐"}
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
            {tunnel?.tunnel?.publicUrl && (
              <p className="mt-3 break-all font-mono text-xs text-[var(--muted)]">
                {tunnel.tunnel.publicUrl}
              </p>
            )}
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
              <ToggleRow
                title="API 키 필수"
                desc="ON이면 모델 API 요청에 API 키가 필요합니다."
                checked={settings.requireApiKey}
                onChange={() =>
                  patchSettings(
                    { requireApiKey: !settings.requireApiKey },
                    "API 키 필수"
                  )
                }
              />
            </div>
          </section>

          {/* 관측 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Eye size={18} className="text-[var(--accent)]" />
              관측 (Observability)
            </h2>
            <ToggleRow
              title="요청 기록 활성화"
              desc="요청 상세를 기록하여 로그 뷰에서 검사할 수 있습니다."
              checked={settings.enableObservability}
              onChange={() =>
                patchSettings(
                  { enableObservability: !settings.enableObservability },
                  "관측 설정"
                )
              }
            />
          </section>

          {/* 네트워크 */}
          <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
            <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
              <Network size={18} className="text-[var(--accent)]" />
              아웃바운드 프록시
            </h2>
            <div className="space-y-4">
              <ToggleRow
                title="프록시 사용"
                desc="OAuth 및 제공업체 아웃바운드 요청에 프록시를 적용합니다."
                checked={settings.outboundProxyEnabled}
                onChange={() =>
                  patchSettings(
                    { outboundProxyEnabled: !settings.outboundProxyEnabled },
                    "프록시 사용"
                  )
                }
              />
              {settings.outboundProxyEnabled && (
                <div className="space-y-4 border-t border-[var(--border)] pt-4">
                  <div>
                    <label className="mb-1.5 block text-sm text-[var(--muted)]">
                      프록시 URL
                    </label>
                    <input
                      type="text"
                      value={proxyUrl}
                      onChange={(e) => setProxyUrl(e.target.value)}
                      placeholder="http://127.0.0.1:7897"
                      className="w-full rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2 text-sm outline-none focus:border-[var(--accent)]"
                    />
                    <p className="mt-1 text-xs text-[var(--muted)]">
                      HTTP(S) forward proxy URL입니다 (예: http://127.0.0.1:7897).
                      LiteLLM 같은 LLM 게이트웨이는 forward proxy가 아니므로 테스트에
                      실패합니다. 비워두면 기존 환경 프록시를 상속합니다.
                    </p>
                  </div>
                  <div>
                    <label className="mb-1.5 block text-sm text-[var(--muted)]">
                      프록시 제외 (No Proxy)
                    </label>
                    <input
                      type="text"
                      value={noProxy}
                      onChange={(e) => setNoProxy(e.target.value)}
                      placeholder="localhost,127.0.0.1"
                      className="w-full rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2 text-sm outline-none focus:border-[var(--accent)]"
                    />
                    <p className="mt-1 text-xs text-[var(--muted)]">
                      프록시를 우회할 호스트를 쉼표로 구분.
                    </p>
                  </div>
                  {proxyTestMsg && (
                    <p
                      className={`text-sm ${
                        proxyTestMsg.type === "success"
                          ? "text-[#3fb950]"
                          : "text-[#f85149]"
                      }`}
                    >
                      {proxyTestMsg.text}
                    </p>
                  )}
                  <div className="flex flex-col gap-2 sm:flex-row">
                    <button
                      onClick={testProxy}
                      disabled={testingProxy}
                      className="flex-1 rounded-lg border border-[var(--border-light)] px-4 py-2 text-sm transition-colors hover:border-[var(--muted)] disabled:opacity-50"
                    >
                      {testingProxy ? "테스트 중..." : "프록시 테스트"}
                    </button>
                    <button
                      onClick={() =>
                        patchSettings(
                          {
                            outboundProxyUrl: proxyUrl.trim(),
                            outboundNoProxy: noProxy.trim(),
                          },
                          "프록시 설정"
                        )
                      }
                      className="flex-1 rounded-lg bg-[var(--accent)] px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-[var(--accent-hover)]"
                    >
                      적용
                    </button>
                  </div>
                </div>
              )}
            </div>
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
                <span className="text-sm text-[var(--muted)]">9Router 연동</span>
                <span className="text-sm font-semibold">
                  {claude?.has9Router ? "사용 중" : "미사용"}
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
