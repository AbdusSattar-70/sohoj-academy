import {
  financeQuery,
  getSimpleFinance,
} from "@/modules/finance/simple/queries";
import { SimpleFinance } from "@/modules/finance/simple/workspace";
export default async function Page({
  searchParams,
}: {
  searchParams: Promise<{ month?: string; page?: string; q?: string }>;
}) {
  const q = financeQuery(await searchParams);
  return <SimpleFinance data={await getSimpleFinance(q)} />;
}
