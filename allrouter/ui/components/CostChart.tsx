"use client";

import {
  AreaChart,
  Area,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";

export interface TokenPoint {
  date: string;
  tokens: number;
  cost: number;
}

function fmtTokens(n: number): string {
  if (n >= 1000000) return `${(n / 1000000).toFixed(1)}M`;
  if (n >= 1000) return `${(n / 1000).toFixed(1)}K`;
  return `${n}`;
}

export default function CostChart({
  data,
  freeRate,
}: {
  data: TokenPoint[];
  freeRate: number;
}) {
  const totalTokens = data.reduce((acc, d) => acc + (d.tokens || 0), 0);
  const totalCost = data.reduce((acc, d) => acc + (d.cost || 0), 0);
  const maxTokens = Math.max(...data.map((d) => d.tokens || 0), 1);

  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
      <div className="mb-2 flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold">토큰 사용량 & 비용</h2>
          <p className="text-xs text-[var(--muted)]">
            최근 {data.length}일 실사용 기준 (LiteLLM 지출 로그)
          </p>
        </div>
        <div className="flex items-center gap-4 text-sm">
          <div>
            <p className="text-xs text-[var(--muted)]">총 토큰</p>
            <p className="font-semibold">{totalTokens.toLocaleString()}</p>
          </div>
          <div>
            <p className="text-xs text-[var(--muted)]">총 비용</p>
            <p className="font-semibold">${totalCost.toFixed(4)}</p>
          </div>
          <div>
            <p className="text-xs text-[var(--muted)]">무료 라우팅</p>
            <p className="font-semibold text-[#3fb950]">{freeRate}%</p>
          </div>
        </div>
      </div>
      {freeRate >= 99.9 && (
        <p className="mb-4 flex items-center gap-1.5 text-xs text-[#3fb950]">
          ✓ 전량 무료 라우팅 — 토큰은 증가하지만 유료 비용이 발생하지 않습니다
          (절감 효과).
        </p>
      )}
      <div className="h-72 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data}>
            <defs>
              <linearGradient id="colorTokens" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
              </linearGradient>
              <linearGradient id="colorCost" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#f85149" stopOpacity={0.25} />
                <stop offset="95%" stopColor="#f85149" stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#21262d" vertical={false} />
            <XAxis
              dataKey="date"
              stroke="#8b949e"
              fontSize={12}
              tickLine={false}
              axisLine={false}
            />
            <YAxis
              yAxisId="tokens"
              stroke="#8b949e"
              fontSize={12}
              tickLine={false}
              axisLine={false}
              domain={[0, maxTokens]}
              tickFormatter={fmtTokens}
            />
            <YAxis
              yAxisId="cost"
              orientation="right"
              stroke="#8b949e"
              fontSize={12}
              tickLine={false}
              axisLine={false}
              tickFormatter={(v) => `$${v}`}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "#0b0e14",
                border: "1px solid #30363d",
                borderRadius: "8px",
                color: "#e6edf3",
              }}
              labelStyle={{ color: "#8b949e" }}
              formatter={(value, name) =>
                name === "비용"
                  ? [`$${((value as number) || 0).toFixed(4)}`, name]
                  : [((value as number) || 0).toLocaleString(), name]
              }
            />
            <Legend wrapperStyle={{ fontSize: 12 }} />
            <Area
              yAxisId="tokens"
              type="monotone"
              dataKey="tokens"
              name="토큰"
              stroke="#3b82f6"
              fillOpacity={1}
              fill="url(#colorTokens)"
              strokeWidth={2}
            />
            <Line
              yAxisId="cost"
              type="monotone"
              dataKey="cost"
              name="비용"
              stroke="#f85149"
              strokeWidth={2}
              dot={false}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
