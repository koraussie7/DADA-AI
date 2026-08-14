"use client";

import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

const data = [
  { date: "08-07", cost: 1.2, tokens: 420000 },
  { date: "08-08", cost: 2.4, tokens: 850000 },
  { date: "08-09", cost: 1.8, tokens: 630000 },
  { date: "08-10", cost: 3.1, tokens: 1100000 },
  { date: "08-11", cost: 2.9, tokens: 1020000 },
  { date: "08-12", cost: 4.2, tokens: 1480000 },
  { date: "08-13", cost: 3.6, tokens: 1270000 },
];

export default function CostChart() {
  return (
    <div className="rounded-xl border border-[var(--border)] bg-[var(--panel)] p-6">
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h2 className="text-lg font-semibold">비용 분석</h2>
          <p className="text-xs text-[var(--muted)]">최근 7일간 지출 추이</p>
        </div>
        <select className="rounded-lg border border-[var(--border-light)] bg-[var(--panel-2)] px-3 py-1.5 text-xs text-[var(--muted)] outline-none">
          <option>최근 7일</option>
          <option>최근 30일</option>
        </select>
      </div>
      <div className="h-72 w-full">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data}>
            <defs>
              <linearGradient id="colorCost" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3} />
                <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
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
              stroke="#8b949e"
              fontSize={12}
              tickLine={false}
              axisLine={false}
              tickFormatter={(value) => `$${value}`}
            />
            <Tooltip
              contentStyle={{
                backgroundColor: "#0b0e14",
                border: "1px solid #30363d",
                borderRadius: "8px",
                color: "#e6edf3",
              }}
              labelStyle={{ color: "#8b949e" }}
              itemStyle={{ color: "#60a5fa" }}
            />
            <Area
              type="monotone"
              dataKey="cost"
              name="비용"
              stroke="#3b82f6"
              fillOpacity={1}
              fill="url(#colorCost)"
              strokeWidth={2}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
