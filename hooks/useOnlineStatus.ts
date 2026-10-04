// hooks/useOnlineStatus.ts
import { useEffect, useState } from "react";
import { Status } from "@/types";
import { STATUS } from "@/lib/constants";

export function useOnlineStatus(): Status {
  const [status, setStatus] = useState<Status>(STATUS.ONLINE);

  useEffect(() => {
    let wasOffline = false;
    let backOnlineTimer: ReturnType<typeof setTimeout> | undefined;

    const update = () => {
      if (!navigator.onLine) {
        wasOffline = true;
        if (backOnlineTimer) clearTimeout(backOnlineTimer);
        setStatus(STATUS.OFFLINE);
        return;
      }

      if (!wasOffline) {
        setStatus(STATUS.ONLINE);
        return;
      }

      wasOffline = false;
      setStatus(STATUS.BACK_ONLINE);
      backOnlineTimer = setTimeout(() => {
        setStatus(STATUS.ONLINE);
        backOnlineTimer = undefined;
      }, 2000);
    };

    update();
    window.addEventListener("online", update);
    window.addEventListener("offline", update);

    return () => {
      window.removeEventListener("online", update);
      window.removeEventListener("offline", update);
      if (backOnlineTimer) clearTimeout(backOnlineTimer);
    };
  }, []);

  return status;
}
