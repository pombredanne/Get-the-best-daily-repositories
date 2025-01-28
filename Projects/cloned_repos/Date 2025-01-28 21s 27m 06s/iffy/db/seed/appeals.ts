import { faker } from "@faker-js/faker";
import db from "../index";
import * as schema from "../schema";
import { eq, desc, and } from "drizzle-orm";

export async function seedAppeals(clerkOrganizationId: string) {
  const recordUsers = await db.query.recordUsers.findMany({
    where: eq(schema.recordUsers.clerkOrganizationId, clerkOrganizationId),
    with: {
      actions: {
        orderBy: [desc(schema.recordUserActions.createdAt)],
      },
    },
  });

  for (const recordUser of recordUsers) {
    const userAction = recordUser.actions[0];
    if (!userAction || userAction.status !== "Suspended") {
      continue;
    }

    await db
      .insert(schema.appeals)
      .values({
        clerkOrganizationId,
        recordUserActionId: userAction.id,
      })
      .onConflictDoNothing();

    const [appeal] = await db
      .select()
      .from(schema.appeals)
      .where(
        and(
          eq(schema.appeals.clerkOrganizationId, clerkOrganizationId),
          eq(schema.appeals.recordUserActionId, userAction.id),
        ),
      );

    if (!appeal) {
      continue;
    }

    const [appealAction] = await db
      .insert(schema.appealActions)
      .values({
        clerkOrganizationId,
        appealId: appeal.id,
        status: "Open",
        via: "Inbound",
      })
      .returning();

    if (!appealAction) {
      continue;
    }

    await db
      .update(schema.appeals)
      .set({
        actionStatus: appealAction.status,
        actionStatusCreatedAt: appealAction.createdAt,
      })
      .where(and(eq(schema.appeals.clerkOrganizationId, clerkOrganizationId), eq(schema.appeals.id, appeal.id)));

    await db
      .update(schema.messages)
      .set({
        appealId: appeal.id,
      })
      .where(
        and(
          eq(schema.messages.clerkOrganizationId, clerkOrganizationId),
          eq(schema.messages.recordUserActionId, userAction.id),
        ),
      );

    await db.insert(schema.messages).values({
      clerkOrganizationId,
      recordUserActionId: userAction.id,
      fromId: recordUser.id,
      text: faker.lorem.paragraph(),
      appealId: appeal.id,
      type: "Inbound",
      status: "Delivered",
      subject: faker.lorem.sentence(),
    });
  }
  console.log("Seeded Appeals");
}
