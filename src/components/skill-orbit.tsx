"use client";

import { useState, type CSSProperties } from "react";
import { SkillIcon } from "./brand-mark";
import { coreCompetencies, type LandingCatalog } from "@/lib/i18n/catalogs";
import type { Locale } from "@/lib/i18n/config";

export function SkillOrbit({
  locale,
  framework,
}: Readonly<{ locale: Locale; framework: LandingCatalog["framework"] }>) {
  const [selected, setSelected] = useState(0);
  const competency = coreCompetencies[selected] ?? coreCompetencies[0];
  const detail = framework.core[competency];
  return (
    <div
      className="skill-explorer"
      aria-label={locale === "th" ? "สำรวจแผนที่ทักษะ" : "Explore the skill map"}
    >
      <div className="skill-explorer__top">
        <span className="status-dot" />
        <span>{locale === "th" ? "เริ่มจากความเป็นไปได้ของคุณ" : "A world of possibility"}</span>
        <span className="skill-explorer__edition">01 / EXPLORE</span>
      </div>
      <div className="skill-orbit">
        <svg viewBox="0 0 400 400" className="skill-orbit__lines" aria-hidden="true">
          <circle cx="200" cy="200" r="150" />
          <circle cx="200" cy="200" r="106" />
          <circle cx="200" cy="200" r="65" />
          {coreCompetencies.map((key, index) => {
            const angle = ((index * 45 - 90) * Math.PI) / 180;
            return (
              <line
                key={key}
                x1="200"
                y1="200"
                x2={200 + 150 * Math.cos(angle)}
                y2={200 + 150 * Math.sin(angle)}
                className={selected === index ? "is-active" : ""}
              />
            );
          })}
        </svg>
        <div className="skill-orbit__center" aria-hidden="true">
          <span>
            8<span>+2</span>
          </span>
          <small>HUMAN SKILLS</small>
        </div>
        {coreCompetencies.map((key, index) => {
          const angle = ((index * 45 - 90) * Math.PI) / 180;
          const style = {
            "--node-x": `${50 + 37.5 * Math.cos(angle)}%`,
            "--node-y": `${50 + 37.5 * Math.sin(angle)}%`,
            "--node-order": index,
          } as CSSProperties;
          return (
            <button
              key={key}
              type="button"
              className="skill-orbit__node"
              style={style}
              aria-label={framework.core[key].name}
              aria-pressed={selected === index}
              aria-controls="skill-explorer-detail"
              onClick={() => setSelected(index)}
            >
              <SkillIcon index={index} />
              <span className="skill-orbit__label" aria-hidden="true">
                {String(index + 1).padStart(2, "0")}
              </span>
            </button>
          );
        })}
        <span className="skill-orbit__hint">
          {locale === "th" ? "แตะไอคอน แล้วลองสำรวจ" : "Pick a skill. See what opens up."}
        </span>
      </div>
      <div
        className="skill-explorer__detail"
        id="skill-explorer-detail"
        aria-live="polite"
        aria-atomic="true"
      >
        <span className="skill-explorer__number" aria-hidden="true">
          {String(selected + 1).padStart(2, "0")}
        </span>
        <div>
          <p className="skill-explorer__name">{detail.name}</p>
          <p>{detail.description}</p>
        </div>
      </div>
      <p className="skill-explorer__boundary">
        {locale === "th"
          ? "แผนที่กรอบทักษะ · ไม่ใช่ผลประเมินของคุณ"
          : "A framework to explore · not your assessment result"}
      </p>
    </div>
  );
}
