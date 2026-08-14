"use client";

import { useEffect, useState } from "react";
import { Bell, Globe, Shield } from "lucide-react";

export default function SettingsPage() {
  const [notifyUsage, setNotifyUsage] = useState(true);
  const [notifyError, setNotifyError] = useState(true);
  const [threshold, setThreshold] = useState("80");
  const [masterKey, setMasterKey] = useState("");
  const [showKey, setShowKey] = useState(false);

  useEffect(() => {
    (async () => {
      try {
        const res = await fetch("/api/auth/master-key");
        const data = await res.json();
        if (data.master_key) setMasterKey(data.master_key);
      } catch {
        /* noop */
      }
    })();
  }, []);

  const masterKeyMasked = showKey
    ? masterKey
    : masterKey
      ? masterKey.slice(0, 12) + "••••" + masterKey.slice(-4)
      : "••••••••";

  return (
    <div className="p-8">
      <header className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">설정</h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          계정과 게이트웨이 기본 설정을 관리하세요.
        </p>
      </header>

      <div className="max-w-2xl space-y-6">
        {/* 마스터 계정 */}
        <section className="rounded-xl border border-[var(--accent)]/30 bg-[#0f1a2e] p-6">
          <h2 className="mb-1 flex items-center gap-2 text-lg font-semibold">
            <Shield size={18} className="text-[var(--accent)]" />
            마스터 계정
          </h2>
          <p className="mb-4 text-xs text-[var(--muted)]">
            전체 관리 권한을 가진 최상위 계정입니다. /login에서 이 정보로 접속하세요.
          </p>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <div>
              <label className="mb-1.5 block text-sm text-[var(--muted)]">
                아이디
              </label>
              <code className="block rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2 font-mono text-sm">
                admin
              </code>
            </div>
            <div>
              <label className="mb-1.5 block text-sm text-[var(--muted)]">
                비밀번호 (마스터 키)
              </label>
              <div className="flex items-center gap-2">
                <code className="flex-1 truncate rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2 font-mono text-sm">
                  {masterKeyMasked}
                </code>
                <button
                  onClick={() => {
                    navigator.clipboard.writeText(masterKey);
                    alert("복사되었습니다.");
                  }}
                  className="rounded-md bg-[var(--accent)] px-3 py-2 text-xs font-medium text-white transition-colors hover:bg-[var(--accent-hover)]"
                >
                  복사
                </button>
              </div>
              <button
                onClick={() => setShowKey((v) => !v)}
                className="mt-2 text-xs text-[var(--muted)] transition-colors hover:text-white"
              >
                {showKey ? "키 숨기기" : "키 표시"}
              </button>
            </div>
          </div>
        </section>

        {/* 알림 */}

        {/* 알림 */}
        <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
          <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
            <Bell size={18} className="text-[var(--accent)]" />
            알림
          </h2>
          <div className="space-y-4">
            <label className="flex items-center justify-between gap-4">
              <div>
                <p className="text-sm font-medium">예산 초과 알림</p>
                <p className="text-xs text-[var(--muted)]">
                  예산 사용량이 설정한 비율을 넘으면 이메일로 알립니다.
                </p>
              </div>
              <input
                type="checkbox"
                checked={notifyUsage}
                onChange={(e) => setNotifyUsage(e.target.checked)}
                className="h-5 w-5 accent-[var(--accent)]"
              />
            </label>
            {notifyUsage && (
              <div className="flex items-center gap-3">
                <span className="text-sm text-[var(--muted)]">임계값</span>
                <input
                  type="number"
                  value={threshold}
                  onChange={(e) => setThreshold(e.target.value)}
                  className="w-24 rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-3 py-1.5 text-sm outline-none focus:border-[var(--accent)]"
                />
                <span className="text-sm text-[var(--muted)]">%</span>
              </div>
            )}
            <label className="flex items-center justify-between gap-4 border-t border-[var(--border)] pt-4">
              <div>
                <p className="text-sm font-medium">오류 알림</p>
                <p className="text-xs text-[var(--muted)]">
                  API 요청 실패 시 즉시 알립니다.
                </p>
              </div>
              <input
                type="checkbox"
                checked={notifyError}
                onChange={(e) => setNotifyError(e.target.checked)}
                className="h-5 w-5 accent-[var(--accent)]"
              />
            </label>
          </div>
        </section>

        {/* 게이트웨이 */}
        <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
          <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
            <Globe size={18} className="text-[var(--accent)]" />
            API 엔드포인트
          </h2>
          <div className="flex items-center justify-between gap-4 rounded-lg border border-[var(--border)] bg-[var(--panel-2)] px-4 py-3">
            <code className="font-mono text-sm text-[var(--accent)]">
              https://api.privseai.com/v1
            </code>
            <button
              onClick={() => {
                navigator.clipboard.writeText(
                  "https://api.privseai.com/v1"
                );
                alert("복사되었습니다.");
              }}
              className="rounded-md bg-[var(--accent)] px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-[var(--accent-hover)]"
            >
              복사
            </button>
          </div>
        </section>

        {/* 보안 */}
        <section className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
          <h2 className="mb-4 flex items-center gap-2 text-lg font-semibold">
            <Shield size={18} className="text-[var(--accent)]" />
            보안
          </h2>
          <div className="flex items-center justify-between gap-4">
            <div>
              <p className="text-sm font-medium">비밀번호 변경</p>
              <p className="text-xs text-[var(--muted)]">
                정기적으로 비밀번호를 변경하는 것을 권장합니다.
              </p>
            </div>
            <button className="rounded-lg border border-[var(--border-light)] px-4 py-2 text-sm transition-colors hover:border-[var(--muted)]">
              변경하기
            </button>
          </div>
        </section>

        <button className="w-full rounded-lg bg-[var(--accent)] py-3 font-semibold text-white transition-all hover:bg-[var(--accent-hover)]">
          변경사항 저장
        </button>
      </div>
    </div>
  );
}
