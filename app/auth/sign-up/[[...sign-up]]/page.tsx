import { redirect } from "next/navigation";

/** Public applicants submit directly; staff accounts are provisioned by the academy. */
export default function SignUpPage() {
  redirect("/interest");
}
