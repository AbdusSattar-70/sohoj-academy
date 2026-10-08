import { getTeachingEarnings } from "@/modules/finance/simple/teaching-queries";
import { TeachingPay } from "@/modules/finance/simple/teaching-workspace";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const q = await searchParams;
  return (
    <TeachingPay
      data={await getTeachingEarnings(
        Math.max(1, Math.min(10000, Number.parseInt(q.page ?? "1", 10) || 1)),
      )}
    />
  );
}
