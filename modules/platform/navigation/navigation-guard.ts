"use client";
export function guardWorkspaceNavigation(
  e: { preventDefault: () => void },
  locale: string,
  region?: Element | null,
) {
  const root = region ?? document.querySelector("#erp-main");
  if (root?.querySelector('[data-editor][data-busy="true"]')) {
    e.preventDefault();
    window.dispatchEvent(
      new CustomEvent("erp:notice", {
        detail:
          locale === "bn"
            ? "চলমান কাজের ফল নিশ্চিত করে তারপর অন্য পেজ খুলুন।"
            : "Confirm the running request before opening another page.",
      }),
    );
    return;
  }
  if (
    root?.querySelector('[data-editor][data-dirty="true"]') &&
    !window.confirm(
      locale === "bn"
        ? "অসংরক্ষিত পরিবর্তন বাদ দিয়ে অন্য পেজ খুলবেন?"
        : "Discard unsaved changes and open another page?",
    )
  )
    e.preventDefault();
}
