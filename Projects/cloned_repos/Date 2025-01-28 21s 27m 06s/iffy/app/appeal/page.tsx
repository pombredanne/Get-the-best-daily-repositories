import { validateAppealToken } from "@/services/appeals";
import { redirect } from "next/navigation";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";
import { Table, TableBody, TableCell, TableRow } from "@/components/ui/table";
import db from "@/db";
import * as schema from "@/db/schema";
import { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger } from "@/components/ui/tooltip";
import { AppealForm } from "./form";
import { Separator } from "@/components/ui/separator";
import { findOrCreateOrganizationSettings } from "@/services/organization-settings";
import { formatRecordStatus, formatUserActionStatus } from "@/lib/badges";
import { desc, eq, and, isNull } from "drizzle-orm";

// Ensure page is never cached
export const dynamic = "force-dynamic";

export default async function Page(props: { searchParams: Promise<{ [key: string]: string | string[] | undefined }> }) {
  const searchParams = await props.searchParams;
  const { token } = searchParams;
  if (!token || typeof token !== "string") {
    return redirect("/");
  }

  const [isValid, recordUserId] = validateAppealToken(token);
  if (!isValid) {
    return redirect("/");
  }

  const user = await db.query.recordUsers.findFirst({
    where: eq(schema.recordUsers.id, recordUserId),
    with: {
      actions: {
        orderBy: [desc(schema.recordUserActions.createdAt)],
        limit: 1,
        with: {
          appeal: true,
        },
      },
    },
  });

  if (!user) {
    return redirect("/");
  }

  const latestAction = user.actions[0];
  const latestAppeal = latestAction?.appeal;

  const { clerkOrganizationId } = user;
  const { appealsEnabled } = await findOrCreateOrganizationSettings(clerkOrganizationId);
  if (!appealsEnabled) {
    return redirect("/");
  }

  if (latestAction?.status === "Banned") {
    return (
      <div className="flex min-h-screen w-full items-center justify-center p-16">
        <Card className="w-full max-w-screen-sm">
          <CardHeader className="flex flex-row items-start justify-between gap-4">
            <div>
              <CardTitle className="text-lg lowercase">{user.email}</CardTitle>
              <CardDescription>Your account has been banned from Gumroad.</CardDescription>
            </div>
            <div>{formatUserActionStatus({ status: "Banned" })}</div>
          </CardHeader>
        </Card>
      </div>
    );
  }

  if (latestAction?.status === "Compliant") {
    return (
      <div className="flex min-h-screen w-full items-center justify-center p-16">
        <Card className="w-full max-w-screen-sm">
          <CardHeader className="flex flex-row items-start justify-between gap-4">
            <div>
              <CardTitle className="text-lg lowercase">{user.email}</CardTitle>
              <CardDescription>Your account is compliant with Gumroad&apos;s terms of service.</CardDescription>
            </div>
            <div>{formatUserActionStatus({ status: "Compliant" })}</div>
          </CardHeader>
        </Card>
      </div>
    );
  }

  if (latestAppeal) {
    return (
      <div className="flex min-h-screen w-full items-center justify-center p-16">
        <Card className="w-full max-w-screen-sm">
          <CardHeader className="flex flex-row items-start justify-between gap-4">
            <div>
              <CardTitle className="text-lg lowercase">{user.email}</CardTitle>
              <CardDescription>Your appeal has been submitted.</CardDescription>
            </div>
            <div>{formatUserActionStatus({ status: "Suspended" })}</div>
          </CardHeader>
        </Card>
      </div>
    );
  }

  const records = await db.query.records.findMany({
    where: and(
      eq(schema.records.clerkOrganizationId, clerkOrganizationId),
      eq(schema.records.recordUserId, user.id),
      isNull(schema.records.deletedAt),
    ),
    with: {
      moderations: {
        limit: 1,
        orderBy: [desc(schema.moderations.createdAt)],
      },
    },
  });

  return (
    <div className="flex min-h-screen w-full items-center justify-center p-16">
      <Card className="w-full max-w-screen-sm">
        <CardHeader className="flex flex-row items-start justify-between gap-4">
          <div>
            <CardTitle className="text-lg lowercase">{user.email}</CardTitle>
            <CardDescription>
              Please update the following products to be compliant with Gumroad&apos;s terms of service.
            </CardDescription>
          </div>
          <div>{formatUserActionStatus({ status: "Suspended" })}</div>
        </CardHeader>
        <CardContent>
          <Table>
            <TableBody>
              {records.map((record) => {
                const badge = formatRecordStatus(record);
                return (
                  <TableRow key={record.id}>
                    <TableCell>
                      <div className="font-medium">{record.name}</div>
                    </TableCell>
                    <TableCell className="hidden sm:table-cell">
                      <Badge variant="secondary">
                        <span>{record.entity}</span>
                      </Badge>
                    </TableCell>
                    <TableCell>{badge}</TableCell>
                    <TableCell className="hidden md:table-cell">
                      <TooltipProvider>
                        <Tooltip>
                          <TooltipTrigger className="text-left">{record.updatedAt.toLocaleDateString()}</TooltipTrigger>
                          <TooltipContent>
                            <p>{record.updatedAt.toISOString()}</p>
                          </TooltipContent>
                        </Tooltip>
                      </TooltipProvider>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </CardContent>
        <Separator />
        <CardFooter className="block px-6 py-4">
          <AppealForm token={token} />
        </CardFooter>
      </Card>
    </div>
  );
}
