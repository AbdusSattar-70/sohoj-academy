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
import { useClerk } from "@clerk/nextjs";
import { ReactNode } from "react";
import { Button } from "@/components/ui/button";
import { toast } from "react-toastify";
import { ROUTES } from "@/lib/constants";

export function SignOutAlert({ children }: { children: ReactNode }) {
  const { signOut } = useClerk();

  const handleSignOut = async () => {
    await signOut({ redirectUrl: ROUTES.AUTH });
    toast.success("Signed out successfully");
  };

  return (
    <Dialog>
      <DialogTrigger asChild>{children}</DialogTrigger>
      <DialogContent className="sm:max-w-106.25">
        <DialogHeader>
          <DialogTitle>Confirm Sign Out</DialogTitle>
          <DialogDescription>
            Are you sure you want to sign out?
          </DialogDescription>
        </DialogHeader>

        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline">Cancel</Button>
          </DialogClose>
          <Button variant="outline" onClick={handleSignOut}>
            Sign Out
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
