"use client";

import { useEffect, useState } from "react";
import { Cpu, Loader2 } from "lucide-react";
import { llmFetch } from "@/lib/litellm";

interface ModelInfo {
  model_name: string;
  litellm_params?: {
    model?: string;
    api_base?: string;
    provider?: string;
  };
  model_info?: {
    id?: string;
    input_cost_per_token?: number | null;
    output_cost_per_token?: number | null;
  };
}

export default function ModelsPage() {
  const [models, setModels] = useState<ModelInfo[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const data = await llmFetch("v1/model/info");
        setModels(data.data || []);
      } catch (e) {
        setError(e instanceof Error ? e.message : "모델 목록을 불러오지 못했습니다.");
      }
    })();
  }, []);

  return (
    <div className="p-8">
      <header className="mb-8">
        <h1 className="text-2xl font-bold tracking-tight">모델 라우팅</h1>
        <p className="mt-1 text-sm text-[var(--muted)]">
          LiteLLM에 등록된 모델 목록과 우선순위입니다.
        </p>
      </header>

      {/* auto 강조 */}
      <div className="mb-6 rounded-xl border border-[var(--accent)]/30 bg-[#0f1a2e] p-6">
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-[var(--accent)] text-white">
            <Cpu size={20} />
          </div>
          <div>
            <h2 className="font-semibold">big-pickle (스마트 라우팅)</h2>
            <p className="text-sm text-[var(--muted)]">
              LiteLLM이 usage-based-routing-v2 전략으로 최적 모델을 자동 선택하고,
              실패 시 다음 모델로 폴백합니다.
            </p>
          </div>
        </div>
      </div>

      {error && (
        <div className="mb-6 rounded-xl border border-[#f85149]/30 bg-[#f85149]/10 p-4 text-sm text-[#f85149]">
          {error}
        </div>
      )}

      <div className="overflow-hidden rounded-xl border border-[var(--border)] bg-[var(--panel)]">
        <div className="border-b border-[var(--border)] p-6">
          <h2 className="text-lg font-semibold">등록된 모델</h2>
          <p className="mt-1 text-xs text-[var(--muted)]">
            라우팅 풀에 등록된 모델 우선순위입니다.
          </p>
        </div>
        {!models ? (
          <div className="flex items-center justify-center gap-2 p-12 text-[var(--muted)]">
            <Loader2 size={18} className="animate-spin" />
            모델 목록을 불러오는 중...
          </div>
        ) : (
          <div className="divide-y divide-[var(--border)]">
            {models.map((model, i) => (
              <div
                key={model.model_name}
                className="flex items-center gap-4 px-6 py-4 transition-colors hover:bg-[var(--panel-2)]"
              >
                <div className="flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-[var(--panel-2)] text-xs font-medium text-[var(--muted)]">
                  {i + 1}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="font-mono text-sm font-medium">{model.model_name}</p>
                  <p className="truncate text-xs text-[var(--muted)]">
                    {model.litellm_params?.model || "—"}
                    {model.litellm_params?.api_base
                      ? ` · ${model.litellm_params.api_base.replace(/^https?:\/\//, "")}`
                      : ""}
                  </p>
                </div>
                <span className="rounded-full bg-[var(--panel-2)] px-3 py-1 text-xs text-[var(--muted)]">
                  순위 {i + 1}
                </span>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
