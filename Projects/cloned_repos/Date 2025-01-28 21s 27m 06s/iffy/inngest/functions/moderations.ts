import { sendWebhook } from "@/services/webhook";
import { inngest } from "@/inngest/client";
import db from "@/db";
import { getFlaggedRecordsFromUser } from "@/services/users";
import { updatePendingModeration } from "@/services/moderations";
import { createUserAction } from "@/services/user-actions";
import * as schema from "@/db/schema";
import { eq, and } from "drizzle-orm";
import * as service from "@/services/moderations";

const moderate = inngest.createFunction(
  { id: "moderate" },
  { event: "moderation/moderated" },
  async ({ event, step }) => {
    const { clerkOrganizationId, moderationId, recordId } = event.data;

    const result = await step.run("moderate", async () => {
      return await service.moderate({ clerkOrganizationId, recordId });
    });

    return await step.run("update-moderation", async () => {
      return await updatePendingModeration({
        clerkOrganizationId,
        id: moderationId,
        ...result,
      });
    });
  },
);

const updateUserAfterModeration = inngest.createFunction(
  { id: "update-user-after-moderation" },
  { event: "moderation/status-changed" },
  async ({ event, step }) => {
    const { clerkOrganizationId, recordId, status } = event.data;

    const record = await step.run("fetch-record", async () => {
      const result = await db.query.records.findFirst({
        where: and(eq(schema.records.clerkOrganizationId, clerkOrganizationId), eq(schema.records.id, recordId)),
        with: {
          recordUser: true,
        },
      });

      if (!result) {
        throw new Error(`Record not found: ${recordId}`);
      }
      return result;
    });

    const recordUser = record.recordUser;
    if (!recordUser) {
      return;
    }

    const flaggedRecords = await step.run("fetch-user-flagged-records", async () => {
      return await getFlaggedRecordsFromUser({ clerkOrganizationId, id: recordUser.id });
    });

    let actionStatus: (typeof schema.recordUserActionStatus.enumValues)[number] | undefined;

    if (
      status === "Flagged" &&
      (!recordUser.actionStatus || recordUser.actionStatus === "Compliant") &&
      !recordUser.protected
    ) {
      actionStatus = "Suspended";
    }

    if (status === "Compliant" && flaggedRecords.length === 0 && recordUser.actionStatus === "Suspended") {
      actionStatus = "Compliant";
    }

    if (!actionStatus) {
      return;
    }

    await step.run("create-user-action", async () => {
      return await createUserAction({
        clerkOrganizationId,
        recordUserId: recordUser.id,
        status: actionStatus,
        via: "Automation",
      });
    });
  },
);

const sendModerationWebhook = inngest.createFunction(
  { id: "send-moderation-webhook" },
  { event: "moderation/status-changed" },
  async ({ event, step }) => {
    const { clerkOrganizationId, status, recordId } = event.data;

    const record = await step.run("fetch-record", async () => {
      const result = await db.query.records.findFirst({
        where: and(eq(schema.records.clerkOrganizationId, clerkOrganizationId), eq(schema.records.id, recordId)),
        with: {
          recordUser: true,
        },
      });

      if (!result) {
        throw new Error(`Record not found: ${recordId}`);
      }
      return result;
    });

    const recordUser = record.recordUser;

    await step.run("send-webhook", async () => {
      const webhook = await db.query.webhookEndpoints.findFirst({
        where: eq(schema.webhookEndpoints.clerkOrganizationId, clerkOrganizationId),
      });
      if (!webhook) throw new Error("No webhook found");

      const eventType = status === "Flagged" ? "record.flagged" : "record.compliant";
      await sendWebhook({
        id: webhook.id,
        event: eventType,
        payload: {
          entity: record.entity,
          clientId: record.clientId,
          user: recordUser?.protected
            ? {
                protected: true,
              }
            : undefined,
        },
      });
    });
  },
);

export default [moderate, updateUserAfterModeration, sendModerationWebhook];
