"use server";

import { z } from "zod";
import { actionClient } from "@/lib/action-client";
import { revalidatePath } from "next/cache";
import db from "@/db";
import * as schema from "@/db/schema";
import { updateEmailTemplateSchema } from "./schema";
import { validateContent } from "@/emails/render";

export const updateEmailTemplate = actionClient
  .schema(updateEmailTemplateSchema)
  .bindArgsSchemas([z.enum(schema.emailTemplateType.enumValues)])
  .action(
    async ({ parsedInput: { subject, heading, body }, bindArgsParsedInputs: [type], ctx: { clerkOrganizationId } }) => {
      validateContent({ subject, heading, body });

      const [emailTemplate] = await db
        .insert(schema.emailTemplates)
        .values({
          clerkOrganizationId,
          type,
          content: { subject, heading, body },
        })
        .onConflictDoUpdate({
          target: [schema.emailTemplates.clerkOrganizationId, schema.emailTemplates.type],
          set: {
            content: { subject, heading, body },
          },
        })
        .returning();

      revalidatePath("/dashboard/emails");
      return emailTemplate;
    },
  );
