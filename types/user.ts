import { z } from "zod";
import { userSchema } from "@/lib/zod-schemas/user";

export type User = z.infer<typeof userSchema>;

export type UserStore = {
  user: User | null;
  setUser: (user: User) => void;
  clearUser: () => void;
};
