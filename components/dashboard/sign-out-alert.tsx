"use client";

import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { ReactNode, useState } from "react";
import { Button } from "@/components/ui/button";
import { toast } from "react-toastify";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import { ROUTES } from "@/lib/constants";

export function SignOutAlert({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  const handleSignOut = async () => {
    setLoading(true);
    const supabase = createClient();
    const { error } = await supabase.auth.signOut();

    if (error) {
      toast.error(error.message);
      setLoading(false);
      return;
    }

    toast.success("Signed out successfully");
    router.replace(ROUTES.AUTH);
    router.refresh();
  };

  return (
    <Dialog>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-106.25">
        <DialogHeader>
          <DialogTitle>Confirm Sign Out</DialogTitle>
          <DialogDescription>Are you sure you want to sign out?</DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline" disabled={loading}>Cancel</Button>
          </DialogClose>
          <Button variant="outline" onClick={handleSignOut} disabled={loading}>
            {loading ? "Signing out..." : "Sign Out"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
