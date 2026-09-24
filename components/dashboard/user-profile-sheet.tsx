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
import { UserProfile } from "@clerk/nextjs";
import { Button } from "@/components/ui/button";

export function UserProfileSheet({ children }: { children: ReactNode }) {
  return (
    <Sheet>
      <SheetTrigger asChild>{children}</SheetTrigger>
      <SheetContent
        side="bottom"
        className="h-full w-full max-w-full bg-[#00002e] rounded-none p-0 [&>button.absolute]:hidden"
      >
        <SheetHeader className="sr-only">
          <SheetTitle>Account Management</SheetTitle>
          <SheetDescription>
            Make changes to your profile here. Click save when you&apos;re done.
          </SheetDescription>
        </SheetHeader>
        <div className="p-4 h-full scrollable">
          <UserProfile />
        </div>
        <SheetFooter>
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
