# Rise Pals

Rise Pals คือแพลตฟอร์มพัฒนาความพร้อมในการทำงานยุค AI สำหรับคนทำงานออฟฟิศไทย ช่วยให้ผู้ใช้รู้ว่าตนเองมีช่องว่างด้านทักษะอะไร ควรพัฒนาอะไรก่อน เรียนผ่านประสบการณ์แบบ gamified และสร้างหลักฐานความสามารถที่ต่อยอดไปสู่โอกาสทางอาชีพได้

**Brand:** Rise Pals  
**Digital wordmark:** `risepals`  
**Primary domain:** `risepals.com`  
**Project status:** Product foundation / pre-development  
**Last updated:** 2026-08-01

## Product thesis

AI ไม่ได้ทำให้ตำแหน่งงานทุกตำแหน่งหายไปทันที แต่มันกำลังเปลี่ยนสิ่งที่บริษัทคาดหวังจากคนในตำแหน่งเดิม งานที่เป็น routine execution ถูกลดมูลค่า ขณะที่ judgment, system thinking, governance, storytelling และความสามารถในการสร้างผลลัพธ์ทางธุรกิจมีมูลค่าสูงขึ้น

Rise Pals จึงไม่ใช่เพียง course marketplace แต่เป็นระบบที่พาผู้ใช้เดินครบวงจร:

> Diagnose → Prioritize → Learn → Practice → Prove → Opportunity

## กลุ่มผู้ใช้เริ่มต้น

- คนทำงานออฟฟิศไทยที่กังวลว่าทักษะเดิมกำลังถูก AI ลดมูลค่า
- Professionals ในสาย Administration, Business Support, Finance, Accounting, IT, Digital Transformation, Marketing และสายงานที่มี routine knowledge work สูง
- คนที่ต้องการเปลี่ยนจาก task executor เป็นคนที่สร้าง business impact ได้ชัดเจน
- ในอนาคต: บริษัท ผู้สอน HR และ hiring partners

## คุณค่าหลักของผลิตภัณฑ์

1. ประเมินความพร้อมตามกรอบทักษะ 8+2
2. แสดง skill gaps และลำดับการพัฒนาที่เหมาะกับผู้ใช้
3. เปลี่ยนการเรียนเป็นภารกิจสั้น ๆ ที่มี feedback, XP และ progression
4. ให้ผู้ใช้ลงมือทำและสะสมหลักฐาน ไม่ใช่เพียงดูวิดีโอจบ
5. เชื่อม skill proof กับคอร์ส mentorship และโอกาสงานในอนาคต
6. ใช้ข้อมูลจริงสร้างความเร่งด่วนโดยไม่หลอกหรือทำให้ผู้ใช้ตื่นกลัวเกินจริง

## Revenue model เบื้องต้น

- Free assessment และผลลัพธ์ระดับพื้นฐาน
- Monthly / yearly membership
- Package privileges สำหรับ online course, live cohort และ onsite learning
- Premium coaching, workshop และ skill certification
- B2B workforce assessment และ team upskilling
- Talent matching / hiring marketplace ในระยะถัดไป

## เอกสารสำคัญ

- [Product Vision](docs/01_PRODUCT_VISION.md)
- [8+2 Skill Framework](docs/02_SKILL_FRAMEWORK.md)
- [MVP Scope](docs/03_MVP_SCOPE.md)
- [Product Roadmap](docs/04_PRODUCT_ROADMAP.md)
- [Brand, Visual and Content Principles](docs/05_BRAND_VISUAL_CONTENT.md)
- [Codex Collaboration Workflow](docs/06_CODEX_COLLABORATION_WORKFLOW.md)
- [Decision Log](docs/DECISION_LOG.md)
- [Current Project Status](PROJECT_STATUS.md)

## วิธีทำงานของโปรเจกต์

โปรเจกต์นี้ใช้ Codex สองบริบทที่มีหน้าที่ต่างกัน:

- **Project Codex:** ช่วย Jeff คิด product strategy, แตกงาน, review, comment, audit และออกคำสั่งสำหรับ turn ถัดไป
- **VS Code Codex:** ลงมือแก้ repository ตาม brief ทีละ turn พร้อมทดสอบและส่ง handoff กลับมา

ทุก turn ต้องจบด้วย handoff ที่ตรวจสอบได้ จากนั้น Project Codex จะอ่านไฟล์และ diff จริงก่อนออก brief รอบถัดไป รายละเอียดอยู่ใน [Codex Collaboration Workflow](docs/06_CODEX_COLLABORATION_WORKFLOW.md)

## Next action

เริ่มด้วย [Turn 001 — Repository Foundation and Technical Architecture](prompts/TURN_001_REPO_FOUNDATION.md) โดยนำ copy block ในไฟล์ไปให้ Codex ใน VS Code ทำงาน

