"use client";

import { useState, useEffect } from "react";
import { KeyRound, Copy, X, CheckCircle, Loader2 } from "lucide-react";
import { llmFetch } from "@/lib/litellm";

interface CreateKeyModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export default function CreateKeyModal({ isOpen, onClose }: CreateKeyModalProps) {
  const [alias, setAlias] = useState("");
  const [budget, setBudget] = useState("10");
  const [models, setModels] = useState<string>("all");
  const [availableModels, setAvailableModels] = useState<string[]>([]);
  const [apiKey, setApiKey] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!isOpen) return;
    setAlias("");
    setBudget("10");
    setModels("all");
    setApiKey("");
    setCopied(false);
    (async () => {
      try {
        const data = await llmFetch("v1/model/info");
        const names = (data.data || []).map((m: { model_name: string }) => m.model_name);
        setAvailableModels(names);
      } catch {
        setAvailableModels([]);
      }
    })();
  }, [isOpen]);

  if (!isOpen) return null;

  const handleCreateKey = async () => {
    setIsLoading(true);
    try {
      const payload: Record<string, unknown> = {
        key_alias: alias || undefined,
        max_budget: parseFloat(budget) || undefined,
        models: models === "all" ? [] : [models],
      };
      const data = await llmFetch("key/generate", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });
      setApiKey(data.key || "");
    } catch (e) {
      alert(e instanceof Error ? e.message : "키 생성 중 오류가 발생했습니다.");
    } finally {
      setIsLoading(false);
    }
  };

  const copyToClipboard = () => {
    navigator.clipboard.writeText(apiKey);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 p-4 backdrop-blur-sm">
      <div className="animate-fade-up w-full max-w-md rounded-2xl border border-[var(--border)] bg-[var(--panel)] p-6 shadow-2xl">
        <div className="mb-6 flex items-center justify-between">
          <h2 className="flex items-center gap-2 text-lg font-bold">
            <KeyRound size={18} className="text-[var(--accent)]" />
            API 키 생성
          </h2>
          <button
            onClick={onClose}
            className="text-[var(--muted)] transition-colors hover:text-white"
          >
            <X size={20} />
          </button>
        </div>

        {!apiKey ? (
          <div className="space-y-4">
            <div>
              <label className="mb-2 block text-sm text-[var(--muted)]">
                키 이름
              </label>
              <input
                value={alias}
                onChange={(e) => setAlias(e.target.value)}
                className="w-full rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2 text-white outline-none transition-colors focus:border-[var(--accent)]"
                placeholder="예: 프로덕션 키"
              />
            </div>
            <div>
              <label className="mb-2 block text-sm text-[var(--muted)]">
                예산 (USD)
              </label>
              <input
                type="number"
                value={budget}
                onChange={(e) => setBudget(e.target.value)}
                className="w-full rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2 text-white outline-none transition-colors focus:border-[var(--accent)]"
                placeholder="예: 10"
              />
            </div>
            <div>
              <label className="mb-2 block text-sm text-[var(--muted)]">
                허용 모델
              </label>
              <select
                value={models}
                onChange={(e) => setModels(e.target.value)}
                className="w-full rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-4 py-2 text-white outline-none"
              >
                <option value="all">모든 모델</option>
                {availableModels.map((m) => (
                  <option key={m} value={m}>
                    {m}
                  </option>
                ))}
              </select>
            </div>
            <button
              onClick={handleCreateKey}
              disabled={isLoading}
              className="w-full rounded-lg bg-[var(--accent)] py-3 font-semibold text-white transition-all hover:bg-[var(--accent-hover)] disabled:opacity-50"
            >
              {isLoading ? (
                <span className="inline-flex items-center gap-2">
                  <Loader2 size={16} className="animate-spin" /> 생성 중...
                </span>
              ) : (
                "키 생성"
              )}
            </button>
          </div>
        ) : (
          <div className="animate-fade-up space-y-4">
            <div className="mb-4 rounded-lg border border-[var(--accent)]/30 bg-[var(--accent)]/10 p-4 text-sm text-[var(--accent)]">
              ⚠️ 이 키는 지금 바로 복사하세요. 다시 볼 수 없습니다!
            </div>
            <div className="flex items-center gap-2 rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] p-3 font-mono text-sm">
              <span className="flex-1 truncate">{apiKey}</span>
              <button
                onClick={copyToClipboard}
                className="rounded-md p-2 transition-colors hover:bg-[var(--panel)]"
              >
                {copied ? (
                  <CheckCircle size={18} className="text-[#3fb950]" />
                ) : (
                  <Copy size={18} />
                )}
              </button>
            </div>
            <button
              onClick={onClose}
              className="w-full rounded-lg bg-[var(--panel-2)] py-3 font-semibold transition-all hover:bg-[var(--border)]"
            >
              완료
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
