import * as schema from "@/db/schema";
import { Context, StrategyResult } from "@/services/moderations";
import type * as Blocklist from "./blocklist";
import type * as Prompt from "./prompt";
import type * as OpenAI from "./openai";

export interface StrategyInstance {
  name: string;
  accepts: (context: Context) => Promise<boolean>;
  test: (context: Context) => Promise<StrategyResult>;
}

export interface StrategyConstructor {
  new (options: unknown): StrategyInstance;
}

export type RawStrategy = typeof schema.ruleStrategies.$inferSelect | typeof schema.presetStrategies.$inferSelect;

export type Strategy =
  | (RawStrategy & {
      type: "Blocklist";
      options: Blocklist.Options;
    })
  | (RawStrategy & {
      type: "Prompt";
      options: Prompt.Options;
    })
  | (RawStrategy & {
      type: "OpenAI";
      options: OpenAI.Options;
    });
