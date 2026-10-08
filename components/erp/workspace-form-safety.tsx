"use client";
import { useEffect } from "react";
import { useLanguage } from "@/components/providers/language-provider";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
export function WorkspaceFormSafety() {
  const { locale } = useLanguage();
  useEffect(() => {
    const root = document.querySelector("#erp-main");
    if (!root) return;
    let submitted: HTMLFormElement | null = null;
    const editor = (target: EventTarget | null) =>
      target instanceof HTMLElement
        ? target.closest<HTMLFormElement>("form[data-editor]")
        : null;
    const changed = (e: Event) => {
      const form = editor(e.target);
      if (form) form.dataset.dirty = "true";
    };
    const submit = (e: Event) => {
      const form = e.target;
      if (!(form instanceof HTMLFormElement)) return;
      if (form.hasAttribute("data-editor")) {
        submitted = form;
        return;
      }
      guardWorkspaceNavigation(e, locale);
      if (e.defaultPrevented) e.stopPropagation();
    };
    const saved = () => {
      if (submitted?.isConnected) submitted.dataset.dirty = "false";
      submitted = null;
    };
    const click = (e: MouseEvent) => {
      if (
        e.defaultPrevented ||
        e.button !== 0 ||
        e.metaKey ||
        e.ctrlKey ||
        e.shiftKey ||
        e.altKey
      )
        return;
      const link =
        e.target instanceof Element
          ? e.target.closest<HTMLAnchorElement>("a[href]")
          : null;
      if (!link || link.target === "_blank" || link.hasAttribute("download"))
        return;
      let target: URL;
      try {
        target = new URL(link.href, window.location.href);
      } catch {
        return;
      }
      if (
        target.origin !== window.location.origin ||
        (target.pathname === window.location.pathname &&
          target.search === window.location.search)
      )
        return;
      guardWorkspaceNavigation(e, locale);
      if (e.defaultPrevented) e.stopPropagation();
    };
    const unload = (e: BeforeUnloadEvent) => {
      if (
        root.querySelector(
          '[data-editor][data-dirty="true"], [data-editor][data-busy="true"]',
        )
      ) {
        e.preventDefault();
        e.returnValue = "";
      }
    };
    root.addEventListener("input", changed, true);
    root.addEventListener("change", changed, true);
    root.addEventListener("submit", submit, true);
    document.addEventListener("click", click, true);
    window.addEventListener("beforeunload", unload);
    window.addEventListener("erp:saved", saved);
    return () => {
      root.removeEventListener("input", changed, true);
      root.removeEventListener("change", changed, true);
      root.removeEventListener("submit", submit, true);
      document.removeEventListener("click", click, true);
      window.removeEventListener("beforeunload", unload);
      window.removeEventListener("erp:saved", saved);
    };
  }, [locale]);
  return null;
}
