"use server";

import { z } from "zod";
import { actionClient } from "@/lib/action-client";
import { revalidatePath } from "next/cache";
import * as apiKeysService from "@/services/api-keys";
import * as webhookService from "@/services/webhook";
import * as organizationSettingsService from "@/services/organization-settings";

const createWebhookSchema = z.object({
  url: z.string(),
});

const updateWebhookUrlSchema = z.object({
  url: z.string(),
});

const createApiKeySchema = z.object({
  name: z.string(),
});

const updateOrganizationSettingsSchema = z.object({
  emailsEnabled: z.boolean().optional(),
  testModeEnabled: z.boolean().optional(),
  appealsEnabled: z.boolean().optional(),
  stripeApiKey: z.string().optional(),
  moderationPercentage: z.number().optional(),
});

export const createWebhook = actionClient
  .schema(createWebhookSchema)
  .action(async ({ parsedInput: { url }, ctx: { clerkOrganizationId } }) => {
    const webhook = await webhookService.createWebhook({ clerkOrganizationId, url });
    revalidatePath("/dashboard/developer");
    return webhook;
  });

export const updateWebhookUrl = actionClient
  .schema(updateWebhookUrlSchema)
  .bindArgsSchemas<[id: z.ZodString]>([z.string()])
  .action(async ({ parsedInput: { url }, bindArgsParsedInputs: [id], ctx: { clerkOrganizationId } }) => {
    const webhook = await webhookService.updateWebhookUrl({ clerkOrganizationId, id, url });
    revalidatePath("/dashboard/developer");
    return webhook;
  });

export const createApiKey = actionClient
  .schema(createApiKeySchema)
  .action(async ({ parsedInput: { name }, ctx: { clerkOrganizationId, clerkUserId } }) => {
    const apiKey = await apiKeysService.createApiKey({ clerkOrganizationId, clerkUserId, name });
    revalidatePath("/dashboard/developer");
    return apiKey;
  });

export const deleteApiKey = actionClient
  .bindArgsSchemas<[id: z.ZodString]>([z.string()])
  .action(async ({ bindArgsParsedInputs: [id], ctx: { clerkOrganizationId } }) => {
    await apiKeysService.deleteApiKey({ clerkOrganizationId, id });
    revalidatePath("/dashboard/developer");
  });

export const updateOrganizationSettings = actionClient
  .schema(updateOrganizationSettingsSchema)
  .action(async ({ parsedInput, ctx: { clerkOrganizationId } }) => {
    const settings = await organizationSettingsService.updateOrganizationSettings(clerkOrganizationId, parsedInput);
    revalidatePath("/dashboard/developer");
    return settings;
  });
