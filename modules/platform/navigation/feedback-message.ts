/** Supports the provider's `bn-BD` HTML language and its `bn` locale value. */
export function savedFeedbackMessage(language: string) {
  return language.toLowerCase().split("-")[0] === "bn"
    ? "সফলভাবে সংরক্ষিত হয়েছে।"
    : "Saved successfully.";
}
