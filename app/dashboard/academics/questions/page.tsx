import { requirePermission } from "@/modules/platform/auth/erp-context";
import {
  getQuestionDocuments,
  statuses,
} from "@/modules/academics/documents/queries";
import { QuestionDocuments } from "@/modules/academics/documents/questions";
import { boundedPage } from "@/modules/academics/planning/queries";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ page?: string; status?: string; session?: string }>;
}) {
  const context = await requirePermission("academics.view"),
    q = await searchParams;
  return (
    <QuestionDocuments
      actorId={context.profileId}
      initialSession={q.session}
      data={await getQuestionDocuments(
        boundedPage(q.page),
        statuses.includes(q.status ?? "") ? q.status! : "ALL",
        q.session,
      )}
    />
  );
}
