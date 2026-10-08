"use client";
import Link from "next/link";
import { useEffect, useState } from "react";
import { Search } from "lucide-react";
import { useLanguage } from "@/components/providers/language-provider";
import {
  Dialog,
  DialogContent,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { erpRouteRegistry } from "@/modules/platform/navigation/erp-route-registry";
import { navigationLabel } from "@/modules/platform/navigation/workspace-navigation";
import {
  searchErpRecords,
  type SearchRecord,
} from "@/modules/platform/search/actions";
export function CentralSearch({ permissions }: { permissions: string[] }) {
  const { locale } = useLanguage();
  const t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [open, setOpen] = useState(false),
    [q, setQ] = useState(""),
    [rows, setRows] = useState<SearchRecord[]>([]),
    [busy, setBusy] = useState(false),
    [failed, setFailed] = useState(false);
  useEffect(() => {
    const key = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen(true);
      }
    };
    window.addEventListener("keydown", key);
    return () => window.removeEventListener("keydown", key);
  }, []);
  useEffect(() => {
    let current = true;
    const needle = q.trim();
    if (!open || needle.length < 2) return;
    const timer = setTimeout(() => {
      setBusy(true);
      setFailed(false);
      searchErpRecords(needle)
        .then((r) => {
          if (current) {
            setRows(r.rows);
            setFailed(r.failed);
          }
        })
        .catch(() => {
          if (current) setFailed(true);
        })
        .finally(() => {
          if (current) setBusy(false);
        });
    }, 300);
    return () => {
      current = false;
      clearTimeout(timer);
    };
  }, [q, open]);
  const pages = erpRouteRegistry
    .filter(
      (r) =>
        permissions.includes(r.permission) &&
        q.trim() &&
        (navigationLabel(r.id, r.title, locale) + " " + r.title)
          .toLowerCase()
          .includes(q.trim().toLowerCase()),
    )
    .slice(0, 8);
  return (
    <>
      <button
        type="button"
        className="flex min-h-11 items-center gap-2 rounded-lg border px-3 text-sm text-muted-foreground hover:bg-muted"
        onClick={() => setOpen(true)}
        aria-label={t("Search academy", "একাডেমিতে খুঁজুন")}
      >
        <Search className="size-4" />
        <span className="hidden md:inline">
          {t("Search academy…", "একাডেমিতে খুঁজুন…")}
        </span>
        <kbd className="hidden text-xs lg:inline">Ctrl / ⌘ K</kbd>
      </button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="max-h-[85vh] overflow-y-auto">
          <DialogTitle>{t("Search academy", "একাডেমিতে খুঁজুন")}</DialogTitle>
          <DialogDescription>
            {t(
              "Find pages and permitted records. Enter at least two characters for records. Staff directory results open the staff register.",
              "পেজ ও অনুমোদিত রেকর্ড খুঁজুন। রেকর্ডের জন্য অন্তত দুই অক্ষর লিখুন। স্টাফের ফল থেকে স্টাফ তালিকা খুলবে।",
            )}
          </DialogDescription>
          <label className="space-y-2">
            <span>{t("Name, ID or reference", "নাম, ID বা reference")}</span>
            <input
              autoFocus
              value={q}
              maxLength={80}
              onChange={(e) => {
                setQ(e.target.value);
                setRows([]);
                setFailed(false);
                setBusy(e.target.value.trim().length >= 2);
              }}
              className="min-h-11 w-full rounded-lg border bg-background px-3"
            />
          </label>
          <h3 className="font-semibold">{t("Pages & actions", "পেজ ও কাজ")}</h3>
          {pages.map((r) => (
            <Link
              prefetch={false}
              key={r.id}
              href={r.href}
              onClick={() => setOpen(false)}
              className="rounded-lg border p-3 hover:bg-muted"
            >
              {navigationLabel(r.id, r.title, locale)}
            </Link>
          ))}
          <h3 className="font-semibold">{t("Records", "রেকর্ড")}</h3>
          {busy && <p role="status">{t("Searching…", "খোঁজা হচ্ছে…")}</p>}
          {failed && (
            <p role="status">
              {t(
                "Some records could not be searched. Page links remain available; try again.",
                "কিছু রেকর্ড খোঁজা যায়নি। পেজের link ব্যবহার করতে পারেন; আবার চেষ্টা করুন।",
              )}
            </p>
          )}
          {rows.map((row) => (
            <Link
              prefetch={false}
              key={row.href + row.id}
              href={row.href}
              onClick={() => setOpen(false)}
              className="rounded-lg border p-3 hover:bg-muted"
            >
              <strong>{row.title}</strong>
              <p className="text-xs text-muted-foreground">{row.detail}</p>
            </Link>
          ))}
          {!busy && q.trim().length >= 2 && !rows.length && !failed && (
            <p>
              {t(
                "No permitted record matches. You can still open a page above.",
                "অনুমোদিত মিল পাওয়া যায়নি। উপরের পেজ খুলতে পারেন।",
              )}
            </p>
          )}
        </DialogContent>
      </Dialog>
    </>
  );
}
