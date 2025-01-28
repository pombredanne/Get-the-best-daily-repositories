import { Separator } from "@/components/ui/separator";
import { formatModerationStatus, formatRecordStatus, formatRecordUserStatus, formatVia } from "@/lib/badges";
import { ExternalLink, FlaskConical, FlaskConicalOff } from "lucide-react";
import { RecordImages } from "./record-images";
import { Code, CodeInline } from "@/components/code";
import { Header, HeaderContent, HeaderPrimary, HeaderSecondary, HeaderActions } from "@/components/sheet/header";
import { Section, SectionContent, SectionTitle } from "@/components/sheet/section";
import { formatDateFull } from "@/lib/date";
import { Button } from "@/components/ui/button";
import Link from "next/link";
import { ActionMenu } from "../action-menu";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { formatRecordUserCompact } from "@/lib/record-user";
import { cn } from "@/lib/utils";
import { ModerationsTable } from "./moderations-table";
import { CopyButton } from "@/components/copy-button";

import * as schema from "@/db/schema";
import { eq, desc, and } from "drizzle-orm";
import db from "@/db";

export async function RecordDetail({ clerkOrganizationId, id }: { clerkOrganizationId: string; id: string }) {
  const record = await db.query.records.findFirst({
    where: and(eq(schema.records.clerkOrganizationId, clerkOrganizationId), eq(schema.records.id, id)),
    with: {
      moderations: {
        orderBy: [desc(schema.moderations.createdAt)],
        with: {
          moderationsToRules: {
            with: {
              rule: {
                with: {
                  preset: true,
                },
              },
            },
          },
        },
      },
      recordUser: true,
    },
  });

  if (!record) {
    return null;
  }

  const rules = record.moderations[0]?.moderationsToRules.map((moderationToRule) => moderationToRule.rule);

  return (
    <div>
      <Header>
        <HeaderContent>
          <HeaderPrimary className={cn(record.deletedAt && "line-through")}>{record.name}</HeaderPrimary>
          <HeaderSecondary>{record.entity}</HeaderSecondary>
        </HeaderContent>
        <HeaderActions className="flex items-center gap-4">
          {record.moderations[0]?.testMode ? (
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger>
                  <FlaskConical className="h-4 w-4 text-stone-500 dark:text-zinc-500" />
                </TooltipTrigger>
                <TooltipContent>
                  <p>Test Mode</p>
                </TooltipContent>
              </Tooltip>
            </TooltipProvider>
          ) : (
            <TooltipProvider>
              <Tooltip>
                <TooltipTrigger>
                  <FlaskConicalOff className="h-4 w-4 text-stone-300 dark:text-zinc-500" />
                </TooltipTrigger>
                <TooltipContent>
                  <p>Test Mode Off</p>
                </TooltipContent>
              </Tooltip>
            </TooltipProvider>
          )}
          {formatRecordStatus(record)}
          {!record.deletedAt && <ActionMenu record={record} />}
        </HeaderActions>
      </Header>
      <Separator className="my-2" />
      <Section>
        <SectionTitle>Details</SectionTitle>
        <SectionContent>
          <dl className="grid gap-3">
            {record.recordUser && (
              <div className="grid grid-cols-2 gap-4">
                <dt className="text-stone-500 dark:text-zinc-500">User</dt>
                <dd className="flex items-center gap-4">
                  <Button asChild variant="link" className="text-md -mx-4 -my-2 font-normal">
                    <Link href={`/dashboard/users/${record.recordUser.id}`}>
                      {formatRecordUserCompact(record.recordUser)}
                    </Link>
                  </Button>
                  {formatRecordUserStatus(record.recordUser)}
                </dd>
              </div>
            )}
            <div className="grid grid-cols-2 gap-4">
              <dt className="text-stone-500 dark:text-zinc-500">Client ID</dt>
              <dd className="flex items-center gap-2 break-words">
                <CodeInline>{record.clientId}</CodeInline>
                <CopyButton text={record.clientId} name="Client ID" />
              </dd>
            </div>
            {record.clientUrl && (
              <div className="grid grid-cols-2 gap-4">
                <dt className="text-stone-500 dark:text-zinc-500">Client URL</dt>
                <dd>
                  <Button asChild variant="link" className="text-md -mx-4 -my-2 font-normal">
                    <Link href={record.clientUrl} target="_blank" rel="noopener noreferrer">
                      Link <ExternalLink className="h-4 w-4" />
                    </Link>
                  </Button>
                </dd>
              </div>
            )}
            <div className="grid grid-cols-2 gap-4">
              <dt className="text-stone-500 dark:text-zinc-500">Created At</dt>
              <dd>{formatDateFull(record.createdAt)}</dd>
            </div>
            <div className="grid grid-cols-2 gap-4">
              <dt className="text-stone-500 dark:text-zinc-500">Updated At</dt>
              <dd>{formatDateFull(record.updatedAt)}</dd>
            </div>
            {record.deletedAt && (
              <div className="grid grid-cols-2 gap-4">
                <dt className="text-stone-500 dark:text-zinc-500">Deleted At</dt>
                <dd>{formatDateFull(record.deletedAt)}</dd>
              </div>
            )}
          </dl>
        </SectionContent>
      </Section>
      <Separator className="my-2" />
      <Section>
        <SectionTitle>Content</SectionTitle>
        <SectionContent>
          <Code>{record.text}</Code>
          {record.imageUrls.length > 0 ? <RecordImages imageUrls={record.imageUrls} /> : null}
        </SectionContent>
      </Section>
      {record.moderations[0] && (
        <>
          <Separator className="my-2" />
          <Section>
            <SectionTitle>Latest Moderation</SectionTitle>
            <SectionContent>
              <dl className="grid gap-3">
                <div className="grid grid-cols-2 gap-4">
                  <dt className="text-stone-500 dark:text-zinc-500">Status</dt>
                  <dd>{formatModerationStatus(record.moderations[0])}</dd>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <dt className="text-stone-500 dark:text-zinc-500">Via</dt>
                  <dd>{formatVia(record.moderations[0])}</dd>
                </div>
                {rules && rules.length > 0 && (
                  <div className="grid grid-cols-2 gap-4">
                    <dt className="text-stone-500 dark:text-zinc-500">Rules</dt>
                    <dd>{rules.map((rule) => (rule.preset ? rule.preset.name : rule.name)).join(", ")}</dd>
                  </div>
                )}
                <div className="grid grid-cols-2 gap-4">
                  <dt className="text-stone-500 dark:text-zinc-500">Reasoning</dt>
                  <dd>{record.moderations[0]?.reasoning}</dd>
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <dt className="text-stone-500 dark:text-zinc-500">Created At</dt>
                  <dd>{formatDateFull(record.moderations[0].createdAt)}</dd>
                </div>
              </dl>
            </SectionContent>
          </Section>
        </>
      )}
      {record.moderations.length > 1 && (
        <>
          <Separator className="my-2" />
          <Section>
            <SectionTitle>All Moderations</SectionTitle>
            <SectionContent>
              <ModerationsTable moderations={record.moderations} />
            </SectionContent>
          </Section>
        </>
      )}
    </div>
  );
}
