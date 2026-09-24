"use client";

import {
  Sheet,
  SheetTrigger,
  SheetContent,
  SheetHeader,
  SheetFooter,
  SheetClose,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { ReactNode } from "react";
import { Button } from "@/components/ui/button";

export function UserProfileSheet({ children }: { children: ReactNode }) {
  return (
    <Sheet>
      <SheetTrigger asChild>{children}</SheetTrigger>
      <SheetContent
        side="bottom"
        className="h-full w-full max-w-full rounded-none p-0"
      >
        <SheetHeader className="border-b p-6">
          <SheetTitle>Account Management</SheetTitle>
          <SheetDescription>
            Sohoj Academy account settings are being migrated to Supabase.
          </SheetDescription>
        </SheetHeader>

        <div className="p-6">
          <div className="max-w-xl rounded-lg border p-5">
            <p className="font-medium">Profile settings</p>
            <p className="mt-2 text-sm text-muted-foreground">
              Your account is now authenticated by Supabase. Profile editing and
              password management will be available here in the next account
              settings step.
            </p>
          </div>
        </div>

        <SheetFooter className="border-t p-4">
          <SheetClose asChild>
            <Button variant="outline" size="sm">
              Close
            </Button>
          </SheetClose>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  );
}
