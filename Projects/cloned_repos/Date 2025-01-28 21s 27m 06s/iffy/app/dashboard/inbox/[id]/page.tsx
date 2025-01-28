import db from "@/db";
import * as schema from "@/db/schema";
import { auth } from "@clerk/nextjs/server";
import { notFound, redirect } from "next/navigation";
import { Appeal } from "../appeal";
import { subDays } from "date-fns";
import { and, desc, eq, gte, inArray } from "drizzle-orm";

const HISTORY_DAYS = 7;

const Inbox = async (props: { params: Promise<{ id: string }> }) => {
  const params = await props.params;
  const { orgId } = await auth();
  if (!orgId) {
    redirect("/");
  }
  const { id } = params;

  const appealWithMessages = await db.query.appeals.findFirst({
    where: and(eq(schema.appeals.clerkOrganizationId, orgId), eq(schema.appeals.id, id)),
    with: {
      recordUserAction: {
        with: {
          recordUser: true,
        },
      },
      actions: {
        orderBy: [desc(schema.appealActions.createdAt)],
      },
      messages: {
        orderBy: [desc(schema.messages.createdAt)],
        with: {
          from: true,
        },
      },
    },
  });

  if (!appealWithMessages) {
    return notFound();
  }

  const { messages, actions, ...appeal } = appealWithMessages;

  const recordUserId = appeal.recordUserAction.recordUser.id;

  const records = await db.query.records.findMany({
    where: and(eq(schema.records.clerkOrganizationId, orgId), eq(schema.records.recordUserId, recordUserId)),
  });

  const moderations = await db.query.moderations.findMany({
    where: and(
      eq(schema.moderations.clerkOrganizationId, orgId),
      gte(schema.moderations.createdAt, subDays(appeal.createdAt, HISTORY_DAYS)),
      inArray(
        schema.moderations.recordId,
        records.map((r) => r.id),
      ),
    ),
    orderBy: [desc(schema.moderations.createdAt)],
    with: {
      record: true,
    },
  });

  const userActions = await db.query.recordUserActions.findMany({
    where: and(
      eq(schema.recordUserActions.clerkOrganizationId, orgId),
      eq(schema.recordUserActions.recordUserId, recordUserId),
      gte(schema.recordUserActions.createdAt, subDays(appeal.createdAt, HISTORY_DAYS)),
    ),
    orderBy: [desc(schema.recordUserActions.createdAt)],
  });

  return (
    <Appeal
      appeal={appeal}
      actions={actions}
      messages={messages}
      records={records}
      moderations={moderations}
      userActions={userActions}
    />
  );
};

export default Inbox;
