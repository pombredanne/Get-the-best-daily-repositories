"use client";

import * as React from "react";
import { Bar, BarChart, CartesianGrid, XAxis } from "recharts";
import config from "@/lib/tailwind";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ChartConfig, ChartContainer, ChartTooltip, ChartTooltipContent } from "@/components/ui/chart";

export interface HourlyAnalyticsChartProps {
  stats: {
    time: Date;
    moderations: number;
    flagged: number;
  }[];
}

const chartConfig = {
  moderations: {
    label: "Moderations",
    color: config.theme.colors.black,
  },
  flagged: {
    label: "Flagged",
    color: config.theme.colors.red[600],
  },
} satisfies ChartConfig;

export function HourlyAnalyticsChart({ stats }: HourlyAnalyticsChartProps) {
  const { totalModerations, totalFlagged } = React.useMemo(() => {
    const totalModerations = stats.reduce((sum, stat) => sum + stat.moderations, 0);
    const totalFlagged = stats.reduce((sum, stat) => sum + stat.flagged, 0);
    return { totalModerations, totalFlagged };
  }, [stats]);

  return (
    <Card>
      <CardHeader className="flex flex-col items-stretch space-y-0 border-b p-0 dark:border-zinc-700 sm:flex-row">
        <div className="flex flex-1 flex-col justify-center gap-1 px-6 py-5 sm:py-6">
          <CardTitle className="dark:text-stone-100">Moderations</CardTitle>
          <CardDescription className="dark:text-stone-400">Last 24 hours</CardDescription>
        </div>
        <div className="flex">
          <div className="relative z-30 flex flex-1 flex-col justify-center gap-1 border-t px-6 py-4 text-left even:border-l dark:border-zinc-700 sm:border-l sm:border-t-0 sm:px-8 sm:py-6">
            <span className="text-muted-foreground text-xs">{chartConfig.moderations.label}</span>
            <span
              className="text-lg font-bold leading-none sm:text-3xl"
              style={{ color: chartConfig.moderations.color }}
            >
              {totalModerations.toLocaleString()}
            </span>
          </div>
          <div className="relative z-30 flex flex-1 flex-col justify-center gap-1 border-t px-6 py-4 text-left even:border-l dark:border-zinc-700 sm:border-l sm:border-t-0 sm:px-8 sm:py-6">
            <span className="text-muted-foreground text-xs">{chartConfig.flagged.label}</span>
            <span className="text-lg font-bold leading-none sm:text-3xl" style={{ color: chartConfig.flagged.color }}>
              {totalFlagged.toLocaleString()}
            </span>
          </div>
        </div>
      </CardHeader>
      <CardContent className="px-2 sm:p-6">
        <ChartContainer config={chartConfig} className="aspect-auto h-[250px] w-full">
          <BarChart
            accessibilityLayer
            data={stats}
            margin={{
              left: 12,
              right: 12,
            }}
          >
            <CartesianGrid vertical={false} />
            <XAxis
              dataKey="time"
              tickLine={false}
              axisLine={false}
              tickMargin={8}
              minTickGap={48}
              tickFormatter={(value: Date) => value.toLocaleTimeString("en-US", { hour: "numeric" })}
            />
            <ChartTooltip
              content={
                <ChartTooltipContent
                  className="w-[150px]"
                  labelKey="time"
                  labelFormatter={(_, payload) => {
                    const time = payload[0]!.payload.time;
                    return time.toLocaleTimeString("en-US", { hour: "numeric" });
                  }}
                />
              }
            />
            <Bar dataKey="moderations" fill="var(--color-moderations)" />
            <Bar dataKey="flagged" fill="var(--color-flagged)" />
          </BarChart>
        </ChartContainer>
      </CardContent>
    </Card>
  );
}
