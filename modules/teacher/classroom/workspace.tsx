"use client";
import { useRef, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { useLanguage } from "@/components/providers/language-provider";
import { guardWorkspaceNavigation } from "@/modules/platform/navigation/navigation-guard";
import type {
  ClassLogWorkspace,
  SessionWorkspace,
} from "@/modules/academics/operations/schema";
import { ClassLogForm } from "@/modules/academics/operations/class-log-form";
import { ClassStudentAttendance } from "./student-attendance";
import { ClassPreparation } from "./preparation";
import { runTeacherClass } from "./actions";
import { AcademicForm } from "@/modules/academics/operations/command-form";
import type { ClassCommand, ClassFlow } from "./schema";
import { ClockCorrection } from "./clock-correction";
import { TeachingReport, useTeachingDetails } from "./teaching-report";
export function TeacherClassroom({
  data,
  logs,
  flow,
}: {
  data: SessionWorkspace;
  logs: ClassLogWorkspace;
  flow: ClassFlow;
}) {
  const { locale } = useLanguage(),
    t = (en: string, bn: string) => (locale === "bn" ? bn : en),
    router = useRouter();
  const last = logs.logs[0],
    attendance = data.submissions[0];
  const [clock, setClock] = useState(flow.clock),
    [step, setStep] = useState(
      !flow.clock ? 0 : !attendance ? 1 : flow.clock.ended_at ? 4 : 2,
    ),
    [message, setMessage] = useState(""),
    [pending, start] = useTransition(),
    [uncertain, setUncertain] = useState(false),
    [submitted, setSubmitted] = useState(false);
  const details = useTeachingDetails(data, logs);
  const { setDirty } = details;
  const attempt = useRef<ClassCommand | null>(null);
  const locked =
    submitted || last?.status === "SUBMITTED" || last?.status === "APPROVED";
  function send(payload: ClassCommand, nextStep?: number) {
    attempt.current = payload;
    start(async () => {
      try {
        const r = await runTeacherClass(payload);
        setMessage(
          r.ok
            ? {
                START: t(
                  "Class started. Take student attendance next.",
                  "ক্লাস শুরু হয়েছে। এখন শিক্ষার্থীদের উপস্থিতি নিন।",
                ),
                END: t(
                  "Class ending recorded. Review and submit the report.",
                  "ক্লাসের শেষ সময় সংরক্ষিত। রিপোর্ট যাচাই করে জমা দিন।",
                ),
                CORRECT_CLOCK: t(
                  "Actual times corrected with audit history.",
                  "প্রকৃত সময় audit history-সহ সংশোধিত।",
                ),
                SAVE_REPORT: t(
                  "Class report draft saved.",
                  "ক্লাস রিপোর্টের খসড়া সংরক্ষিত।",
                ),
                SUBMIT_REPORT: t(
                  "Attendance and teaching report submitted for admin review.",
                  "উপস্থিতি ও পাঠদানের রিপোর্ট admin review-এর জন্য জমা হয়েছে।",
                ),
              }[payload.action]
            : r.message,
        );
        if (r.ok) {
          setClock(r.clock ?? null);
          setUncertain(false);
          attempt.current = null;
          if (payload.action === "SUBMIT_REPORT") {
            setSubmitted(true);
            setDirty(false);
          }
          if (payload.action === "SAVE_REPORT") setDirty(false);
          if (nextStep !== undefined) setStep(nextStep);
          router.refresh();
        } else {
          setUncertain(r.uncertain);
        }
      } catch {
        setUncertain(true);
        setMessage(
          t(
            "Result unconfirmed. Confirm the same request before continuing.",
            "ফল নিশ্চিত নয়। এগোনোর আগে একই অনুরোধ নিশ্চিত করুন।",
          ),
        );
      }
    });
  }
  function command(action: ClassCommand["action"]): ClassCommand {
    return {
      action,
      session_id: data.session.id,
      request_id: crypto.randomUUID(),
      reason: t(
        "Confirmed actual class activity and recorded teaching evidence",
        "বাস্তব ক্লাসের কাজ ও পাঠদানের তথ্য নিশ্চিত করেছি",
      ),
    };
  }
  function navigate(event: React.MouseEvent<HTMLButtonElement>, value: number) {
    guardWorkspaceNavigation(event, locale);
    if (!event.defaultPrevented) setStep(value);
  }
  const steps = [
    t("Start class", "ক্লাস শুরু"),
    t("Student attendance", "শিক্ষার্থীর উপস্থিতি"),
    t("Today’s topics", "আজকের পাঠ"),
    t("Homework & finish", "বাড়ির কাজ ও ক্লাস শেষ"),
    t("Review & submit", "যাচাই ও জমা"),
  ];
  if (!clock && last)
    return (
      <div className="space-y-4">
        <p className="rounded-lg border p-4">
          {t(
            "This class already has teaching evidence. Continue the saved report; do not start a second clock.",
            "এই ক্লাসে পাঠদানের record আছে। সংরক্ষিত রিপোর্ট চালিয়ে যান; দ্বিতীয়বার Start করবেন না।",
          )}
        </p>
        <ClassStudentAttendance data={data} onSaved={() => router.refresh()} />
        {attendance?.status === "DRAFT" && (
          <AcademicForm
            defaults={{
              action: "SUBMIT_ATTENDANCE",
              session_id: data.session.id,
              attendance_id: attendance.id,
            }}
            fields={[]}
            label={t(
              "Submit saved student attendance",
              "সংরক্ষিত শিক্ষার্থীর উপস্থিতি জমা দিন",
            )}
            description={t(
              "Continue the existing attendance revision for admin review.",
              "বর্তমান উপস্থিতির revision admin review-এর জন্য জমা দিন।",
            )}
          />
        )}
        <ClassLogForm sessionId={data.session.id} workspace={logs} />
        <ClassPreparation reminders={flow.reminders} />
      </div>
    );
  return (
    <div className="space-y-4">
      <section
        className="space-y-4 rounded-xl border p-4"
        data-busy={pending || uncertain ? "true" : "false"}
      >
        <h2 className="text-lg font-semibold">
          {t("My class workspace", "আমার ক্লাসের কাজ")}
        </h2>
        {clock && (
          <p className="text-sm">
            {t("Actual start", "বাস্তব শুরু")}: {format(clock.started_at)}
            {clock.ended_at && (
              <>
                {" "}
                · {t("Actual end", "বাস্তব শেষ")}: {format(clock.ended_at)} ·{" "}
                {Math.round(
                  (Date.parse(clock.ended_at) - Date.parse(clock.started_at)) /
                    60000,
                )}{" "}
                {t("teaching minutes", "পাঠদানের মিনিট")}
              </>
            )}
          </p>
        )}
        <nav
          className="flex flex-wrap gap-2"
          aria-label={t("Class steps", "ক্লাসের ধাপ")}
        >
          {steps.map((label, i) => (
            <Button
              key={i}
              type="button"
              variant={step === i ? "default" : "outline"}
              aria-current={step === i ? "step" : undefined}
              disabled={
                pending ||
                uncertain ||
                locked ||
                (i > 0 && !clock) ||
                (i > 1 && !attendance) ||
                (i === 4 && !clock?.ended_at)
              }
              onClick={(e) => navigate(e, i)}
            >
              {i + 1}. {label}
            </Button>
          ))}
        </nav>
        {message && (
          <p role="status" className="rounded-lg border p-3">
            {message}
          </p>
        )}
        {uncertain && (
          <Button
            type="button"
            loading={pending}
            onClick={() => attempt.current && send(attempt.current)}
          >
            {t("Confirm previous request", "আগের অনুরোধ নিশ্চিত করুন")}
          </Button>
        )}
        {locked ? (
          <p role="status">
            {t(
              "Report submitted. Admin reviews student attendance and actual teaching before finalizing hours.",
              "রিপোর্ট জমা হয়েছে। সময় চূড়ান্ত করার আগে admin শিক্ষার্থীর উপস্থিতি ও বাস্তব পাঠদান যাচাই করবেন।",
            )}
          </p>
        ) : (
          <>
            {step === 0 && (
              <div className="space-y-3">
                <p>
                  {t(
                    "Are you starting your scheduled class now? The server records the actual start; no sentence needs typing.",
                    "এখন কি নির্ধারিত ক্লাস শুরু করছেন? System প্রকৃত সময় নেবে; কোনো বাক্য লিখতে হবে না।",
                  )}
                </p>
                <Button
                  loading={pending}
                  disabled={
                    pending ||
                    uncertain ||
                    !data.session.canRecordNow ||
                    data.session.date !==
                      new Intl.DateTimeFormat("en-CA", {
                        timeZone: "Asia/Dhaka",
                      }).format(new Date())
                  }
                  onClick={() => send(command("START"), 1)}
                >
                  {t("Yes — start my class", "হ্যাঁ — ক্লাস শুরু করুন")}
                </Button>
                {!data.session.canRecordNow && (
                  <p>
                    {t(
                      "Starting opens at the scheduled time.",
                      "নির্ধারিত সময়ে Start চালু হবে।",
                    )}
                  </p>
                )}
              </div>
            )}
            {step === 1 && (
              <ClassStudentAttendance
                key={attendance?.id ?? "first"}
                data={data}
                onSaved={() => {
                  setMessage(
                    t(
                      "Student attendance saved. Continue with today’s topics.",
                      "শিক্ষার্থীর উপস্থিতি সংরক্ষিত। আজকের পাঠে এগিয়ে যান।",
                    ),
                  );
                  setStep(clock?.ended_at ? 4 : 2);
                }}
              />
            )}
            {clock && attendance && (
              <TeachingReport
                data={data}
                clock={clock}
                step={step}
                pending={pending}
                uncertain={uncertain}
                details={details}
                command={command}
                send={send}
                setStep={setStep}
              />
            )}
            {clock && (
              <ClockCorrection
                clock={clock}
                sessionDate={data.session.date}
                disabled={pending || uncertain}
                onCorrect={(started_at, ended_at, reason) =>
                  send(
                    {
                      ...command("CORRECT_CLOCK"),
                      started_at,
                      ended_at,
                      reason,
                    },
                    4,
                  )
                }
              />
            )}
          </>
        )}
      </section>
      {last?.status === "APPROVED" && (
        <details className="rounded-xl border p-4">
          <summary className="cursor-pointer">
            {t("Create a correction report", "সংশোধিত রিপোর্ট তৈরি করুন")}
          </summary>
          <ClassLogForm sessionId={data.session.id} workspace={logs} />
        </details>
      )}
      <ClassPreparation reminders={flow.reminders} />
    </div>
  );
}
function format(value: string) {
  return new Date(value).toLocaleTimeString("en-GB", {
    timeZone: "Asia/Dhaka",
    hour: "2-digit",
    minute: "2-digit",
  });
}
