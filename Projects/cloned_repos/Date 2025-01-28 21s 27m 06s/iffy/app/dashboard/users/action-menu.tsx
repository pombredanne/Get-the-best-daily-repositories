"use client";

import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { MoreHorizontal } from "lucide-react";
import { trpc } from "@/lib/trpc";
import { createUserActions, setUserProtectedMany } from "./actions";
import { toast } from "@/hooks/use-toast";
import * as schema from "@/db/schema";

type RecordUser = typeof schema.recordUsers.$inferSelect;

export const BulkActionMenu = ({ recordUsers }: { recordUsers: RecordUser[] }) => {
  const utils = trpc.useUtils();
  const createUserActionsWithIds = createUserActions.bind(
    null,
    recordUsers.map((recordUser) => recordUser.id),
  );
  const setUserProtectedManyWithIds = setUserProtectedMany.bind(
    null,
    recordUsers.map((recordUser) => recordUser.id),
  );

  const hideSuspend = recordUsers.length === 1 && recordUsers[0]?.actionStatus === "Suspended";
  const hideUnsuspend = recordUsers.length === 1 && recordUsers[0]?.actionStatus !== "Suspended";

  const hideBan = recordUsers.length === 1 && recordUsers[0]?.actionStatus === "Banned";
  const hideUnban = recordUsers.length === 1 && recordUsers[0]?.actionStatus !== "Banned";

  const disableSuspendAndBan = recordUsers.length === 1 && recordUsers[0]?.protected;

  const hideProtect = recordUsers.length === 1 && recordUsers[0]?.protected;
  const hideUnprotect = recordUsers.length === 1 && !recordUsers[0]?.protected;

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button variant="outline" className="h-8 w-8 p-0">
          <span className="sr-only">Open menu</span>
          <MoreHorizontal className="h-4 w-4" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        {!hideUnprotect && (
          <DropdownMenuItem
            onClick={async (event) => {
              try {
                event.stopPropagation();
                await setUserProtectedManyWithIds(false);
                await utils.user.infinite.invalidate();
              } catch (error) {
                toast({
                  title: "Error",
                  description: "Failed to unprotected user.",
                  variant: "destructive",
                });
                console.error("Error unprotecting user:", error);
              }
            }}
          >
            Unprotect user
          </DropdownMenuItem>
        )}
        {!hideProtect && (
          <DropdownMenuItem
            onClick={async (event) => {
              try {
                event.stopPropagation();
                await setUserProtectedManyWithIds(true);
                await utils.user.infinite.invalidate();
              } catch (error) {
                toast({
                  title: "Error",
                  description: "Failed to protect user.",
                  variant: "destructive",
                });
                console.error("Error protecting user:", error);
              }
            }}
          >
            Protect user
          </DropdownMenuItem>
        )}
        {!hideUnsuspend && (
          <DropdownMenuItem
            onClick={async (event) => {
              try {
                event.stopPropagation();
                await createUserActionsWithIds({
                  status: "Compliant",
                });
                await utils.user.infinite.invalidate();
              } catch (error) {
                toast({
                  title: "Error",
                  description: "Failed to unsuspend user.",
                  variant: "destructive",
                });
                console.error("Error unsuspending user:", error);
              }
            }}
          >
            Unsuspend user
          </DropdownMenuItem>
        )}
        {!hideSuspend && (
          <DropdownMenuItem
            disabled={disableSuspendAndBan}
            onClick={async (event) => {
              try {
                event.stopPropagation();
                await createUserActionsWithIds({
                  status: "Suspended",
                });
                await utils.user.infinite.invalidate();
              } catch (error) {
                toast({
                  title: "Error",
                  description: "Failed to suspend user.",
                  variant: "destructive",
                });
                console.error("Error suspending user:", error);
              }
            }}
          >
            Suspend user
          </DropdownMenuItem>
        )}
        {!hideUnban && (
          <DropdownMenuItem
            onClick={async (event) => {
              try {
                event.stopPropagation();
                await createUserActionsWithIds({
                  status: "Compliant",
                });
                await utils.user.infinite.invalidate();
              } catch (error) {
                toast({
                  title: "Error",
                  description: "Failed to unban user.",
                  variant: "destructive",
                });
                console.error("Error unbanning user:", error);
              }
            }}
          >
            Unban user
          </DropdownMenuItem>
        )}
        {!hideBan && (
          <DropdownMenuItem
            disabled={disableSuspendAndBan}
            onClick={async (event) => {
              try {
                event.stopPropagation();
                await createUserActionsWithIds({
                  status: "Banned",
                });
                await utils.user.infinite.invalidate();
              } catch (error) {
                toast({
                  title: "Error",
                  description: "Failed to ban user.",
                  variant: "destructive",
                });
                console.error("Error banning user:", error);
              }
            }}
          >
            Ban user
          </DropdownMenuItem>
        )}
      </DropdownMenuContent>
    </DropdownMenu>
  );
};

export const ActionMenu = ({ recordUser }: { recordUser: RecordUser }) => {
  return <BulkActionMenu recordUsers={[recordUser]} />;
};
