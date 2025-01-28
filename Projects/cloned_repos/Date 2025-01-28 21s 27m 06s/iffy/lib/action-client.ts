import { auth } from "@clerk/nextjs/server";
import { createSafeActionClient } from "next-safe-action";

export const actionClient = createSafeActionClient({
  handleServerError(e) {
    console.error("Action error:", e.message);
    throw e;
  },
}).use(async ({ next }) => {
  const { orgId, userId } = await auth();
  if (!userId) {
    throw new Error("Unauthorized: User not found.");
  }
  if (!orgId) {
    throw new Error("Unauthorized: Organization not found.");
  }

  return next({ ctx: { clerkOrganizationId: orgId, clerkUserId: userId } });
});
