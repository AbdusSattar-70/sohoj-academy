"use client";
import { useState, useTransition, type FormEvent } from "react";
import { requestStaffAccess } from "./actions";
export function StaffAccessRequestForm() {
  const [pending, start] = useTransition(),
    [message, setMessage] = useState(""),
    [sent, setSent] = useState(false);
  function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    start(async () => {
      try {
        const r = await requestStaffAccess(Object.fromEntries(f));
        setMessage(r.message);
        setSent(r.ok);
      } catch {
        setMessage("Request could not be sent. Please try again.");
      }
    });
  }
  const control = "mt-1 min-h-11 w-full rounded-xl border bg-background px-3";
  return (
    <form onSubmit={submit} className="space-y-5">
      {!sent && (
        <>
          <label className="block text-sm">
            Full name
            <input
              required
              maxLength={160}
              name="full_name"
              className={control}
            />
          </label>
          <label className="block text-sm">
            Email
            <input
              required
              type="email"
              maxLength={254}
              name="email"
              className={control}
            />
          </label>
          <label className="block text-sm">
            Mobile
            <input
              required
              pattern="01[3-9][0-9]{8}"
              name="mobile"
              className={control}
            />
          </label>
          <label className="block text-sm">
            Which role are you requesting?
            <select name="requested_role" required className={control}>
              <option value="">Choose role</option>
              <option value="ADMIN">Admin</option>
              <option value="OPERATOR">Operator</option>
              <option value="TEACHER">Teacher</option>
              <option value="ACCOUNTANT">Accountant</option>
            </select>
          </label>
          <label className="block text-sm">
            Why do you need access?
            <textarea
              name="purpose"
              required
              minLength={5}
              maxLength={500}
              className={`${control} py-3`}
            />
          </label>
          <input
            tabIndex={-1}
            autoComplete="off"
            name="website"
            className="hidden"
          />
          <button
            disabled={pending}
            className="min-h-11 w-full rounded-xl bg-primary font-semibold text-primary-foreground"
          >
            {pending ? "Sending…" : "Request staff access"}
          </button>
        </>
      )}
      {message && (
        <p role="status" className="rounded-xl border p-4 text-sm">
          {message}
        </p>
      )}
    </form>
  );
}
