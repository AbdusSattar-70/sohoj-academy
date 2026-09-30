import type { ReactNode } from "react";
type PaperData = {
  discountPercent?: number;
  discountReason?: string | null;
  academyRoll?: string | null;
  additionalDetails?: Record<string, string | null>;
  number?: string;
  name?: string;
  nameBn?: string | null;
  dateOfBirth?: string | null;
  gender?: string | null;
  schoolName?: string | null;
  schoolRoll?: string | null;
  guardian?: string;
  guardianRelationship?: string | null;
  mobile?: string;
  alternateMobile?: string | null;
  guardianAddress?: string | null;
  offeringName?: string;
  className?: string;
  yearName?: string;
  batchName?: string;
  studentNo?: string | null;
  components?: { name: string; amount: number; recurrence: string }[];
  invoice?: { number: string; total: number; due: number; paid: number } | null;
  receipts?: {
    number: string;
    amount: number;
    method: string;
    postedAt: string;
    refunded: number;
  }[];
};
function Field({
  label,
  value,
  wide = false,
}: {
  label: string;
  value?: string | null;
  wide?: boolean;
}) {
  return (
    <div className={wide ? "paper-field paper-wide" : "paper-field"}>
      <span>{label}</span>
      <div>{value || "\u00a0"}</div>
    </div>
  );
}
function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <section className="paper-section">
      <h2>{title}</h2>
      {children}
    </section>
  );
}
export function AdmissionPaper({
  data: a = {},
  receiptOnly,
  academyName = "Sohoj Academy",
}: {
  data?: PaperData;
  receiptOnly?: string;
  academyName?: string;
}) {
  const receipt = a.receipts?.find((r) => r.number === receiptOnly);
  return (
    <>
      <style>{`
 .admission-paper{color:#111;background:#fff;max-width:210mm;margin:auto;font:10pt/1.4 Arial,sans-serif}
 .paper-page{min-height:275mm;padding:12mm 14mm;box-sizing:border-box;background:white;margin-bottom:16px;border:1px solid #ddd}
 .paper-header{display:flex;justify-content:space-between;align-items:start;border-bottom:2px solid #222;padding-bottom:4mm;margin-bottom:5mm}
 .paper-header h1{font-size:20pt;font-weight:700;margin:0}.paper-header p{margin:1mm 0;font-size:9pt}.paper-photo{border:1px solid #888;width:25mm;height:30mm;text-align:center;padding-top:10mm;font-size:8pt}
 .paper-title{font-size:14pt;font-weight:700;margin:0 0 4mm}.paper-section{margin:4mm 0;break-inside:avoid}.paper-section h2{font-size:10pt;font-weight:700;background:#eee;padding:2mm 3mm;margin-bottom:3mm}
 .paper-grid{display:grid;grid-template-columns:1fr 1fr;gap:3mm 6mm}.paper-field span{display:block;font-size:8pt;color:#444}.paper-field>div{min-height:7mm;border-bottom:1px solid #888;padding:1mm 0;overflow-wrap:anywhere}.paper-wide{grid-column:1/-1}
 .paper-note{font-size:8pt;margin-top:2mm}.paper-signatures{display:grid;grid-template-columns:1fr 1fr;gap:9mm;margin-top:10mm}.paper-signatures>div{border-top:1px solid #333;padding-top:2mm;font-size:8pt}
 .paper-page:last-child{font-size:9pt;line-height:1.3}.paper-page:last-child .paper-header h1{font-size:16pt}.paper-page:last-child .paper-section{margin:3mm 0}.paper-page:last-child .paper-field>div{min-height:5mm}.paper-page:last-child .paper-field span{font-size:7.5pt}.paper-page:last-child .paper-grid{gap:2mm 5mm}.paper-page:last-child .paper-signatures{margin-top:6mm}.paper-page:last-child .paper-receipt{margin-top:4mm;padding-top:3mm}
 .paper-table{width:100%;border-collapse:collapse;font-size:9pt}.paper-table th,.paper-table td{border:1px solid #aaa;padding:2mm;text-align:left}.paper-receipt{border-top:2px dashed #555;margin-top:6mm;padding-top:4mm;break-inside:avoid}.paper-receipt h2{font-size:12pt;font-weight:700;margin:0 0 2mm}
 @media print{body *{visibility:hidden}.admission-paper,.admission-paper *{visibility:visible}.admission-paper{position:absolute;left:0;top:0;width:100%;max-width:none}.paper-page{height:277mm;min-height:0;padding:0;border:0;margin:0;break-after:page;overflow:visible}.paper-page:last-child{break-after:auto}.paper-section{break-inside:avoid}@page{size:A4;margin:10mm 14mm}}
 `}</style>
      <article className="admission-paper">
        {!receiptOnly && (
          <section className="paper-page">
            <header className="paper-header">
              <div>
                <h1>{academyName}</h1>
                <p>সহজ একাডেমি · শিক্ষা হোক সহজ ও আনন্দময়</p>
                <p>Student admission application · Page 1 of 2</p>
                <p>Application reference: {a.number || "________________"}</p>
              </div>
              <div className="paper-photo">
                Student photo
                <br />
                (optional)
              </div>
            </header>
            <h2 className="paper-title">Student and guardian information</h2>
            <p className="paper-note">
              Please complete clearly. Programme choices are preferences until
              verified by the academy. Leave office-only fields blank.
            </p>
            <Section title="1 · Student information">
              <div className="paper-grid">
                <Field label="Full name (English)" value={a.name} wide />
                <Field label="Full name (Bangla)" value={a.nameBn} wide />
                <Field label="Date of birth" value={a.dateOfBirth} />
                <Field label="Gender (optional)" value={a.gender} />
                <Field
                  label="Birth registration number (optional)"
                  value={a.additionalDetails?.birth_registration}
                />
                <Field label="Current class / group" value={a.className} />
                <Field
                  label="Current school / college"
                  value={a.schoolName}
                  wide
                />
                <Field label="School roll" value={a.schoolRoll} />
                <Field
                  label="Previous examination / result (if relevant)"
                  value={a.additionalDetails?.previous_result}
                />
              </div>
            </Section>
            <Section title="2 · Family and contact">
              <div className="paper-grid">
                <Field
                  label="Father's name (optional)"
                  value={a.additionalDetails?.father_name}
                />
                <Field
                  label="Mother's name (optional)"
                  value={a.additionalDetails?.mother_name}
                />
                <Field label="Primary guardian name" value={a.guardian} />
                <Field
                  label="Relationship to student"
                  value={a.guardianRelationship}
                />
                <Field label="Primary mobile" value={a.mobile} />
                <Field label="Alternate mobile" value={a.alternateMobile} />
                <Field
                  label="Present / guardian address"
                  value={a.guardianAddress}
                  wide
                />
                <Field
                  label="Permanent address (if different)"
                  value={a.additionalDetails?.permanent_address}
                  wide
                />
                <Field
                  label="Emergency contact name and relationship"
                  value={a.additionalDetails?.emergency_contact}
                />
                <Field
                  label="Emergency contact mobile"
                  value={a.additionalDetails?.emergency_mobile}
                />
              </div>
            </Section>
            <Section title="3 · Learning preference and support">
              <div className="paper-grid">
                <Field
                  label="Requested programme"
                  value={a.offeringName}
                  wide
                />
                <Field label="Preferred days / class time" />
                <Field label="Subjects requiring support" />
                <Field
                  label="Relevant health, accessibility or learning needs (optional)"
                  value={a.additionalDetails?.learning_needs}
                  wide
                />
                <Field label="Referral: Organic / person's name" />
                <Field label="Referrer contact (if known)" />
              </div>
            </Section>
            <p className="paper-note">
              Please complete the guardian declaration on page 2. The Student ID
              and academy roll are assigned by the ERP, not by the applicant.
            </p>
          </section>
        )}
        <section className="paper-page">
          <header className="paper-header">
            <div>
              <h1>{academyName}</h1>
              <p>
                {receiptOnly
                  ? "Payment receipt"
                  : "Consent, office record and receipt · Page 2 of 2"}
              </p>
              <p>
                Application reference: {a.number || "________________"} ·
                Student: {a.name || "________________"}
              </p>
            </div>
          </header>
          {!receiptOnly && (
            <>
              <Section title="4 · Guardian declaration and consent">
                <p>
                  I confirm that the information supplied is accurate to the
                  best of my knowledge. I have reviewed the verified programme,
                  placement and fee terms recorded below. I consent to the
                  academy maintaining these records, contacting the family and
                  providing academic support. I understand the attendance and
                  conduct expectations. Fees billed remain due until paid or
                  adjusted through an authorized recorded correction.
                </p>
                <p className="paper-note">
                  আমি প্রদত্ত তথ্য ও ভর্তি সংক্রান্ত শর্ত যাচাই করেছি এবং
                  শিক্ষার্থীর শিক্ষা কার্যক্রম ও যোগাযোগের জন্য সম্মতি দিচ্ছি।
                </p>
                <div className="paper-signatures">
                  <div>Guardian signature and date (required)</div>
                  <div>Student signature and date (if able)</div>
                </div>
              </Section>
              <Section title="5 · Office use only — verified placement">
                <div className="paper-grid">
                  <Field label="Academic year" value={a.yearName} />
                  <Field label="Verified class / group" value={a.className} />
                  <Field label="Programme offering" value={a.offeringName} />
                  <Field label="Batch / time" value={a.batchName} />
                  <Field label="System Student ID" value={a.studentNo} />
                  <Field
                    label="Academy roll (assigned by system)"
                    value={a.academyRoll}
                  />
                </div>
                <p className="paper-note">
                  Checks: □ Identity and contact verified □ Placement verified □
                  Referral recorded □ Signed original filed
                </p>
              </Section>
              <Section title="6 · Fees, discount and collection — office use">
                <table className="paper-table">
                  <thead>
                    <tr>
                      <th>Charge</th>
                      <th>Billing frequency</th>
                      <th>Standard BDT</th>
                    </tr>
                  </thead>
                  <tbody>
                    {a.components?.length
                      ? a.components.slice(0, 3).map((c, i) => (
                          <tr key={i}>
                            <td>{c.name}</td>
                            <td>{c.recurrence.replaceAll("_", " ")}</td>
                            <td>{c.amount.toFixed(2)}</td>
                          </tr>
                        ))
                      : [
                          "Tuition",
                          "Admission / registration",
                          "Exam / materials",
                        ].map((c) => (
                          <tr key={c}>
                            <td>{c}</td>
                            <td>________________</td>
                            <td>________________</td>
                          </tr>
                        ))}
                  </tbody>
                </table>
                {a.components && a.components.length > 3 && (
                  <p className="paper-note">
                    Additional charges: BDT{" "}
                    {a.components
                      .slice(3)
                      .reduce((total, c) => total + c.amount, 0)
                      .toFixed(2)}
                    . See the full invoice for itemized charges.
                  </p>
                )}
                <p className="paper-note">
                  Tuition discount:{" "}
                  {[0, 5, 10, 15, 20, 25, 30]
                    .map(
                      (p) =>
                        `${a.discountPercent === p ? "☑" : "□"} ${p === 0 ? "None" : `${p}%`}`,
                    )
                    .join(" · ")}{" "}
                  (permitted offering policy only)
                </p>
                <p className="paper-note">
                  Reason:{" "}
                  {a.discountReason?.replaceAll("_", " ") ||
                    "□ Financial hardship □ Sibling □ Merit □ Launch offer □ Staff family □ Other: __________"}
                </p>
                <div className="paper-grid">
                  <Field label="Invoice reference" value={a.invoice?.number} />
                  <Field
                    label="Current amount due (BDT)"
                    value={a.invoice?.due.toFixed(2)}
                  />
                  <Field label="Received now (BDT) — write zero if unpaid" />
                  <Field label="Payment method / transaction reference" />
                  <Field label="Paper receipt number (if payment received)" />
                  <Field label="ERP entry completed by / date" />
                </div>
              </Section>
              <div className="paper-signatures">
                <div>Authorized staff signature and date</div>
                <div>Academy seal</div>
              </div>
            </>
          )}
          <section className="paper-receipt">
            <p className="paper-note">
              {receiptOnly
                ? "System-recorded money received"
                : "Detach along this line · Give to guardian only when money is received"}
            </p>
            <h2>{academyName} · MONEY RECEIPT / প্রাপ্তি স্বীকারপত্র</h2>
            <div className="paper-grid">
              <Field
                label="Receipt number / date"
                value={
                  receipt
                    ? `${receipt.number} · ${new Date(receipt.postedAt).toLocaleDateString("en-GB", { timeZone: "Asia/Dhaka" })}`
                    : undefined
                }
              />
              <Field
                label="Student / guardian"
                value={a.name ? `${a.name} / ${a.guardian ?? ""}` : undefined}
              />
              <Field
                label="Student ID / application reference"
                value={a.studentNo ?? a.number}
              />
              <Field
                label="Amount actually received (BDT)"
                value={receipt?.amount.toFixed(2)}
              />
              <Field
                label="Received for / payment method"
                value={receipt?.method}
              />
              <Field
                label="Remaining invoice due (BDT)"
                value={a.invoice?.due.toFixed(2)}
              />
            </div>
            <p className="paper-note">
              Amount in words:
              __________________________________________________________
            </p>
            <div className="paper-signatures">
              <div>Received by / signature / academy seal</div>
              <div>Guardian acknowledgement (optional)</div>
            </div>
            <p className="paper-note">
              {receipt
                ? `Original payment preserved. Subsequently refunded: BDT ${receipt.refunded.toFixed(2)}.`
                : "Manual receipt must be entered once in ERP using this paper reference. A blank or unpaid application is not a money receipt."}
            </p>
          </section>
        </section>
      </article>
    </>
  );
}
