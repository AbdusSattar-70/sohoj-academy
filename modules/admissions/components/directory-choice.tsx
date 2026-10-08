"use client";
import { useState, useTransition } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { createAdmissionDirectoryChoice } from "../directory-actions";
export function DirectoryChoice({
  entity,
  name,
  label,
  options,
}: {
  entity: "school" | "relationship";
  name: string;
  label: string;
  options: { id: string; name: string }[];
}) {
  const { locale } = useLanguage();
  const t = (en: string, bn: string) => (locale === "bn" ? bn : en);
  const [rows, setRows] = useState(options),
    [selected, setSelected] = useState(""),
    [creating, setCreating] = useState(false),
    [newName, setNewName] = useState(""),
    [message, setMessage] = useState("");
  const [pending, start] = useTransition();
  return (
    <div className="space-y-2 text-sm">
      <label className="block font-medium">
        {label}
        <select
          name={name}
          disabled={pending}
          value={selected}
          className="mt-1 min-h-11 w-full rounded-xl border bg-background px-3"
          onChange={(e) => {
            if (e.target.value === "__new__") {
              setCreating(true);
              return;
            }
            setSelected(e.target.value);
          }}
        >
          <option value="">{t("Not provided", "দেওয়া হয়নি")}</option>
          {rows.map((r) => (
            <option key={r.id} value={r.name}>
              {r.name}
            </option>
          ))}
          <option value="__new__">
            {t(
              `+ Add missing ${entity}`,
              entity === "school"
                ? "+ নতুন প্রতিষ্ঠান যোগ করুন"
                : "+ নতুন সম্পর্ক যোগ করুন",
            )}
          </option>
        </select>
      </label>
      {creating && (
        <div className="space-y-2 rounded-lg border p-3">
          <label className="block text-xs">
            {t(
              `New ${entity} name`,
              entity === "school" ? "প্রতিষ্ঠানের নাম" : "সম্পর্কের নাম",
            )}
            <input
              value={newName}
              disabled={pending}
              maxLength={160}
              onChange={(e) => setNewName(e.target.value)}
              className="mt-1 w-full rounded border bg-background p-2"
            />
          </label>
          <button
            type="button"
            disabled={pending || newName.trim().length < 2}
            aria-busy={pending}
            className="cursor-pointer rounded border px-3 py-2 text-xs"
            onClick={() =>
              start(async () => {
                setMessage("");
                const existing = rows.find(
                  (row) =>
                    row.name.trim().toLocaleLowerCase() ===
                    newName.trim().toLocaleLowerCase(),
                );
                if (existing) {
                  setSelected(existing.name);
                  setCreating(false);
                  setMessage(
                    t(
                      "Existing choice selected.",
                      "বিদ্যমান তথ্য নির্বাচন করা হয়েছে।",
                    ),
                  );
                  return;
                }
                try {
                  const r = await createAdmissionDirectoryChoice({
                    entity,
                    name: newName,
                  });
                  if (!r.ok) {
                    setMessage(r.message);
                    return;
                  }
                  setRows((old) =>
                    old.some((v) => v.id === r.row.id) ? old : [...old, r.row],
                  );
                  setSelected(r.row.name);
                  setCreating(false);
                  setMessage(
                    t("Saved and selected.", "সংরক্ষণ করে নির্বাচন করা হয়েছে।"),
                  );
                } catch {
                  setMessage(
                    t(
                      "Could not confirm the save. Your input is retained; check the list before retrying.",
                      "সংরক্ষণ নিশ্চিত করা যায়নি। লেখা রাখা হয়েছে; আবার চেষ্টা করার আগে তালিকা দেখুন।",
                    ),
                  );
                }
              })
            }
          >
            {pending
              ? t("Saving…", "সংরক্ষণ হচ্ছে…")
              : t("Save and select", "সংরক্ষণ করে নির্বাচন করুন")}
          </button>
          <button
            type="button"
            disabled={pending}
            className="ml-3 cursor-pointer rounded border px-3 py-2 text-xs"
            onClick={() => setCreating(false)}
          >
            {t("Cancel", "বাতিল")}
          </button>
        </div>
      )}
      {message && (
        <p role="status" className="text-xs">
          {message}
        </p>
      )}
    </div>
  );
}
