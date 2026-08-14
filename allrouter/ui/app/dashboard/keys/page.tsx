"use client";

import { useState, useEffect, useCallback } from "react";
import { Copy, Trash2, Plus, Loader2 } from "lucide-react";
import CreateKeyModal from "@/components/CreateKeyModal";
import { llmFetch } from "@/lib/litellm";

interface LlmKey {
  token_hash: string;
  key_name?: string | null;
  key_alias?: string | null;
  max_budget?: number | null;
  spend?: number;
  models?: string[];
  created_at?: string;
}

export default function KeysPage() {
  const [keys, setKeys] = useState<LlmKey[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const loadKeys = useCallback(async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await llmFetch("key/list");
      const hashes: string[] = data.keys || [];
      const details = await Promise.all(
        hashes.map(async (h) => {
          try {
            const info = await llmFetch(`key/info?key=${h}`);
            return info.info || {};
          } catch {
            return { token_hash: h };
          }
        })
      );
      setKeys(details);
    } catch (e) {
      setError(e instanceof Error ? e.message : "키 목록을 불러오지 못했습니다.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadKeys();
  }, [loadKeys]);

  const copy = (key: string) => {
    navigator.clipboard.writeText(key);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 1500);
  };

  const handleDelete = async (hash: string) => {
    if (!confirm("이 API 키를 삭제할까요?")) return;
    try {
      await llmFetch("key/delete", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ keys: [hash] }),
      });
      await loadKeys();
    } catch (e) {
      alert(e instanceof Error ? e.message : "키 삭제에 실패했습니다.");
    }
  };

  return (
    <div className="p-8">
      <header className="mb-8 flex flex-wrap items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">API 키</h1>
          <p className="mt-1 text-sm text-[var(--muted)]">
            키를 생성하고 사용자·프로젝트별 예산을 관리하세요.
          </p>
        </div>
        <button
          onClick={() => setIsModalOpen(true)}
          className="flex items-center gap-2 rounded-lg bg-[var(--accent)] px-4 py-2 font-medium text-white transition-all hover:bg-[var(--accent-hover)]"
        >
          <Plus size={16} /> 새 API 키
        </button>
      </header>

      {error && (
        <div className="mb-6 rounded-xl border border-[#f85149]/30 bg-[#f85149]/10 p-4 text-sm text-[#f85149]">
          {error}
        </div>
      )}

      <div className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--panel)]">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--panel-2)] text-[var(--muted)]">
              <tr>
                <th className="p-4 font-medium">이름</th>
                <th className="p-4 font-medium">키</th>
                <th className="p-4 font-medium">허용 모델</th>
                <th className="p-4 font-medium">예산</th>
                <th className="p-4 font-medium">사용액</th>
                <th className="p-4 font-medium">잔여</th>
                <th className="p-4 font-medium">작업</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--border)]">
              {loading ? (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-[var(--muted)]">
                    <span className="inline-flex items-center gap-2">
                      <Loader2 size={16} className="animate-spin" />
                      키 목록을 불러오는 중...
                    </span>
                  </td>
                </tr>
              ) : keys.length === 0 ? (
                <tr>
                  <td colSpan={7} className="p-8 text-center text-[var(--muted)]">
                    아직 생성된 API 키가 없습니다.
                  </td>
                </tr>
              ) : (
                keys.map((k) => {
                  const budget = k.max_budget ?? 0;
                  const spend = k.spend ?? 0;
                  const pct =
                    budget > 0 ? Math.min(100, Math.round((spend / budget) * 100)) : 0;
                  const masked = k.key_name || "sk-..." + k.token_hash.slice(-8);
                  return (
                    <tr key={k.token_hash} className="transition-colors hover:bg-[var(--panel-2)]">
                      <td className="p-4 font-medium">
                        {k.key_alias || k.key_name || "이름 없음"}
                      </td>
                      <td className="p-4 font-mono text-xs text-[var(--accent)]">
                        {masked}
                      </td>
                      <td className="p-4">
                        {k.models && k.models.length > 0 ? (
                          <span className="rounded bg-[var(--panel-2)] px-2 py-1 text-xs">
                            {k.models.join(", ")}
                          </span>
                        ) : (
                          <span className="text-xs text-[var(--muted)]">전체</span>
                        )}
                      </td>
                      <td className="p-4">
                        {budget > 0 ? `$${budget.toFixed(2)}` : "—"}
                      </td>
                      <td className="p-4">${spend.toFixed(4)}</td>
                      <td className="p-4">
                        <div className="flex items-center gap-2">
                          <div className="h-1.5 w-16 overflow-hidden rounded-full bg-[var(--panel-2)]">
                            <div
                              className={`h-full rounded-full ${
                                pct > 90
                                  ? "bg-[#f85149]"
                                  : pct > 70
                                    ? "bg-[#d29922]"
                                    : "bg-[#3fb950]"
                              }`}
                              style={{ width: `${pct}%` }}
                            />
                          </div>
                          <span className="text-xs text-[var(--muted)]">{pct}%</span>
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center gap-2">
                          <button
                            onClick={() => copy(k.token_hash)}
                            title="복사"
                            className="rounded-md p-1.5 text-[var(--muted)] transition-colors hover:bg-[var(--panel-2)] hover:text-white"
                          >
                            {copiedKey === k.token_hash ? (
                              <span className="text-xs text-[#3fb950]">복사됨</span>
                            ) : (
                              <Copy size={15} />
                            )}
                          </button>
                          <button
                            onClick={() => handleDelete(k.token_hash)}
                            title="삭제"
                            className="rounded-md p-1.5 text-[var(--muted)] transition-colors hover:bg-[#f85149]/10 hover:text-[#f85149]"
                          >
                            <Trash2 size={15} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      <div className="mt-6 rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
        <h2 className="mb-2 text-lg font-semibold">사용 예시</h2>
        <p className="mb-4 text-sm text-[var(--muted)]">
          OpenAI 호환 API이므로 base_url만 변경하면 됩니다.
        </p>
        <pre className="overflow-x-auto rounded-lg border border-[var(--border)] bg-[var(--panel-2)] p-4 text-xs leading-relaxed">
          <code>
            {"BASE_URL=https://api.privseai.com/v1\n"}
            {"API_KEY=sk-...\n"}
            {"MODEL=big-pickle  # 스마트 라우팅"}
          </code>
        </pre>
      </div>

      <CreateKeyModal
        isOpen={isModalOpen}
        onClose={() => {
          setIsModalOpen(false);
          loadKeys();
        }}
      />
    </div>
  );
}
