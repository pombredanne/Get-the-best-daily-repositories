import { auth } from "@clerk/nextjs/server";

export const createContext = async () => {
  const { orgId, userId } = await auth();

  return {
    clerkOrganizationId: orgId,
    clerkUserId: userId,
  };
};

export type Context = typeof createContext;
