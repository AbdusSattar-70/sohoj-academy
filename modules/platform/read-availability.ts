/** Recover only transport failures; authorization, SQL and contract errors still throw. */
export async function readAvailable<T>(
  read: () => Promise<T>,
): Promise<T | null> {
  try {
    return await read();
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    if (
      !/^(?:TypeError: )?fetch failed$|^(?:AbortError|TimeoutError):/.test(
        message,
      )
    )
      throw error;
    return null;
  }
}
