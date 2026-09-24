"use client";

import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { AlertTriangle } from "lucide-react";

interface DBSyncErrorPageProps {
  message?: string;
}

export default function DBSyncErrorPage({ message }: DBSyncErrorPageProps) {
  const router = useRouter();

  const handleRetry = () => {
    router.refresh();
  };

  return (
    <div className="flex h-screen w-full flex-col items-center justify-center px-6 text-center">
      <div className="mb-4 text-destructive">
        <AlertTriangle className="mx-auto mb-2 h-10 w-10" />
        <h2 className="text-xl font-semibold">
          Something went wrong with the database sync.
        </h2>
      </div>

      {message && (
        <p className="mb-6 max-w-md text-sm text-muted-foreground">{message}</p>
      )}

      <div className="flex items-center gap-3">
        <Button onClick={handleRetry} variant="outline">
          Retry
        </Button>
        <Button
          variant="outline"
          title="Send an email to a90.sattar@gmail.com via Gmail"
        >
          <a
            href="https://mail.google.com/mail/?view=cm&fs=1&to=a90.sattar@gmail.com"
            target="_blank"
            rel="noopener noreferrer"
          >
            Contact Support
          </a>
        </Button>
      </div>
    </div>
  );
}
