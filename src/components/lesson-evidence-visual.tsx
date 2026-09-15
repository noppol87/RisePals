import type { SourceVerificationLessonView } from "@/modules/lesson/source-verification/types";

// This illustration belongs to the published fictional case v1, not learner data.
export const sourceCaseVisual = {
  lessonVersionId: "lesson-source-verification-practice-v1",
  version: "1.0.0",
  teams: [
    { name: "A", improvement: 30, cases: 12 },
    { name: "B", improvement: 8, cases: 40 },
    { name: "C", improvement: null, cases: null },
  ],
  days: 60,
  unresolved: 2,
} as const;

export function LessonEvidenceVisual({ view }: Readonly<{ view: SourceVerificationLessonView }>) {
  const th = view.lesson.locale === "th";
  const matches =
    view.lesson.versionId === sourceCaseVisual.lessonVersionId &&
    view.lesson.version === sourceCaseVisual.version;
  return (
    <div className="lesson-evidence-visual">
      {matches ? (
        <>
          <figure className="team-comparison">
            <figcaption>
              {th ? "แต่ละทีมปิดงานเร็วขึ้นแค่ไหน?" : "How much faster did each team finish?"}
            </figcaption>
            <div className="team-comparison__grid">
              {sourceCaseVisual.teams.map((team) => (
                <div
                  className="team-chart"
                  key={team.name}
                  data-missing={team.improvement === null}
                >
                  <span className="team-chart__name">
                    {th ? "ทีม" : "TEAM"} {team.name}
                  </span>
                  <svg viewBox="0 0 160 130" aria-hidden="true">
                    <path
                      d="M15 105H145 M15 65H145 M15 25H145"
                      stroke="currentColor"
                      opacity=".12"
                      strokeDasharray="3 5"
                    />
                    {team.improvement === null ? (
                      <>
                        <rect
                          x="52"
                          y="20"
                          width="56"
                          height="85"
                          rx="9"
                          fill="none"
                          stroke="currentColor"
                          strokeDasharray="5 5"
                        />
                        <text x="80" y="76" textAnchor="middle" fontSize="48" fill="currentColor">
                          ?
                        </text>
                      </>
                    ) : (
                      <rect
                        className="team-chart__bar"
                        x="52"
                        y={105 - team.improvement * 2.6}
                        width="56"
                        height={team.improvement * 2.6}
                        rx="9"
                        fill="currentColor"
                      />
                    )}
                    <path d="M15 106H145" stroke="currentColor" opacity=".4" />
                  </svg>
                  <strong>
                    {team.improvement === null
                      ? th
                        ? "ยังไม่รู้"
                        : "Unknown"
                      : `${team.improvement}%`}
                  </strong>
                  <span>
                    {team.cases === null
                      ? th
                        ? "ส่งออกข้อมูลไม่ครบ"
                        : "Incomplete data export"
                      : th
                        ? `${team.cases} กรณีสมมติ`
                        : `${team.cases} fictional cases`}
                  </span>
                </div>
              ))}
            </div>
            <p className="team-comparison__note">
              {th ? "ไม่มีข้อมูล ≠ ผลเป็นศูนย์" : "Missing data ≠ zero improvement"}
            </p>
          </figure>
          <div className="case-facts">
            <div>
              <span className="case-facts__icon" aria-hidden="true">
                ▦
              </span>
              <div>
                <strong>{th ? "ทดลอง 60 วัน" : "60-day pilot"}</strong>
                <span>{th ? "สรุปได้แค่กลุ่มทดลองนี้" : "Results apply only to this pilot"}</span>
              </div>
            </div>
            <div>
              <span className="case-facts__icon" aria-hidden="true">
                !
              </span>
              <div>
                <strong>{th ? "ทีม C ยังมีปัญหา 2 รายการ" : "Team C: 2 unresolved issues"}</strong>
                <span>{th ? "ปัญหาเร่งด่วนยังไม่ปิด" : "Escalations remain open"}</span>
              </div>
            </div>
          </div>
        </>
      ) : null}
      <details className="lesson-source-original">
        <summary>{th ? "อ่านเอกสารต้นฉบับสมมติ" : "Read the fictional source records"}</summary>
        <p>
          {th ? "ทีมปฏิบัติการไบรต์ริเวอร์" : view.scenario.organization} · {view.scenario.document}
        </p>
        {view.scenario.sourceRecords.map((record) => (
          <div key={record.id}>
            <h4>{record.label}</h4>
            <p>{record.detail}</p>
          </div>
        ))}
      </details>
    </div>
  );
}
