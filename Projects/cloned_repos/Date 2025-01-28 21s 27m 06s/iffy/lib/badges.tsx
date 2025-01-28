import { Badge } from "@/components/ui/badge";
import * as schema from "@/db/schema";
import { ViaWithClerkUserOrRecordUser } from "./types";

type Appeal = typeof schema.appeals.$inferSelect;
type AppealAction = typeof schema.appealActions.$inferSelect;
type Moderation = typeof schema.moderations.$inferSelect;
type Record = typeof schema.records.$inferSelect;
type RecordUser = typeof schema.recordUsers.$inferSelect;
type RecordUserAction = typeof schema.recordUserActions.$inferSelect;

export function formatModerationStatus({ status, pending }: Partial<Pick<Moderation, "status" | "pending">>) {
  if (pending) {
    return (
      <Badge variant="outline" key="pending">
        Pending
      </Badge>
    );
  } else if (status === "Flagged") {
    return (
      <Badge variant="failure" key="flagged">
        Flagged
      </Badge>
    );
  } else if (status === "Compliant") {
    return (
      <Badge variant="secondary" key="compliant">
        Compliant
      </Badge>
    );
  } else {
    return (
      <Badge variant="outline" key="skipped">
        Skipped
      </Badge>
    );
  }
}

export function formatVia({ via }: ViaWithClerkUserOrRecordUser) {
  if (via === "Automation") {
    return <Badge variant="outline">Automated</Badge>;
  } else if (via === "AI") {
    return <Badge variant="outline">AI</Badge>;
  } else if (via === "Inbound") {
    return <Badge variant="outline">Inbound</Badge>;
  } else {
    return <Badge variant="outline">Manual</Badge>;
  }
}

export function formatUserActionStatus({ status }: Pick<RecordUserAction, "status">) {
  switch (status) {
    case "Suspended":
      return <Badge variant="warning">Suspended</Badge>;
    case "Banned":
      return <Badge variant="failure">Banned</Badge>;
    case "Compliant":
      return <Badge variant="secondary">Compliant</Badge>;
  }
}

export function getAppealActionStatus({ status }: Pick<AppealAction, "status">) {
  if (status === "Approved") {
    return <Badge variant="success">Approved</Badge>;
  } else if (status === "Rejected") {
    return <Badge variant="failure">Rejected</Badge>;
  } else {
    return <Badge variant="secondary">Open</Badge>;
  }
}

export function formatRecordStatus({
  moderationStatus,
  moderationPending,
}: Pick<Record, "moderationStatus" | "moderationPending">) {
  if (moderationStatus || moderationPending) {
    return formatModerationStatus({ status: moderationStatus ?? undefined, pending: moderationPending });
  }
  return null;
}

export function formatRecordVia({ moderations }: { moderations: Moderation[] }) {
  if (moderations.length > 0) {
    return formatVia(moderations[0]!);
  }
  return null;
}

export function formatRecordUserStatus({ actionStatus }: Pick<RecordUser, "actionStatus">) {
  if (actionStatus) {
    return formatUserActionStatus({ status: actionStatus });
  }
  return null;
}

export function formatRecordUserVia({ actions }: { actions: RecordUserAction[] }) {
  if (actions.length > 0) {
    return formatVia(actions[0]!);
  }
  return null;
}

export function formatAppealStatus({ actionStatus }: Pick<Appeal, "actionStatus">) {
  if (actionStatus) {
    return getAppealActionStatus({ status: actionStatus });
  }
  return null;
}
