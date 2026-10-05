import type { ReactNode } from "react";

/**
 * Render both translations in the server component. The language provider
 * toggles visibility through its data-locale attribute, so public pages do not
 * need a client component just to display static copy.
 */
export function LocalizedText({
  en,
  bn,
}: {
  en: ReactNode;
  bn: ReactNode;
}) {
  return (
    <>
      <span className="localized-en">{en}</span>
      <span className="localized-bn">{bn}</span>
    </>
  );
}

