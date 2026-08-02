# Rise Pals Repository Instructions

ไฟล์นี้เป็นข้อกำหนดสำหรับ Codex หรือ coding agent ทุกตัวที่ทำงานใน repository นี้

## Product context

Rise Pals เป็น AI-era career resilience and upskilling platform สำหรับคนทำงานออฟฟิศไทย ไม่ใช่เว็บรวมคอร์สทั่วไป Product loop หลักคือ:

> Diagnose → Prioritize → Learn → Practice → Prove → Opportunity

ก่อนทำงาน ให้เริ่มอ่านไฟล์ต่อไปนี้:

1. `README.md`
2. `PROJECT_STATUS.md`
3. `docs/01_PRODUCT_VISION.md`
4. `docs/02_SKILL_FRAMEWORK.md`
5. `docs/03_MVP_SCOPE.md`
6. Brief ของ turn ปัจจุบัน

## Turn discipline

- ทำเฉพาะ scope ของ turn ที่ได้รับอนุมัติ
- ห้ามเริ่ม feature ของ turn ถัดไปเอง แม้จะเห็นว่าเกี่ยวข้องกัน
- ตรวจไฟล์เดิมก่อนแก้ และรักษางานของผู้ใช้หรือ agent อื่น
- หากมีสมมติฐานที่ไม่กระทบทิศทางหลัก ให้เดินหน้าต่อและบันทึกไว้ใน handoff
- หากการตัดสินใจจะเปลี่ยน product scope, architecture, data model หรือสร้าง external cost ให้หยุดและขอคำตัดสิน
- ห้าม deploy, ซื้อบริการ, สร้าง production resource หรือเปลี่ยน external account หาก brief ไม่ได้อนุญาตชัดเจน

## Engineering quality

- ใช้ TypeScript แบบ strict เมื่อ stack รองรับ
- ให้ความสำคัญกับ accessibility, responsive behavior, performance และ secure defaults
- ห้าม hardcode secrets หรือเก็บข้อมูลส่วนบุคคลเกินความจำเป็น
- Assessment และ career data ถือเป็น sensitive user data ต้องมีการจำกัดการเข้าถึงและอธิบายการใช้งานอย่างโปร่งใส
- เพิ่ม dependency เมื่อจำเป็นจริง และบันทึกเหตุผล
- ทุก implementation turn ต้องมีการ verify ที่เหมาะสม เช่น typecheck, lint, unit test, build หรือ browser test
- ห้ามรายงานว่าทดสอบผ่านหากไม่ได้รันจริง

## Product and content quality

- ใช้ 8+2 Skill Framework เป็นแกนของ assessment และ learning model
- อย่าลดผลิตภัณฑ์ให้เหลือเพียงการสอนใช้ AI tools หรือ prompt engineering
- Lesson ต้องมีการลงมือทำ feedback และ proof of skill ไม่ใช่ passive video completion อย่างเดียว
- ข้อมูลสถิติที่ใช้สร้าง urgency ต้องระบุแหล่งที่มา วันที่เผยแพร่ ขอบเขต และวันที่ตรวจสอบ
- ห้ามสร้างตัวเลข คาดการณ์การตกงานรายบุคคล หรือใช้ dark pattern เพื่อบังคับซื้อ
- Copy ต้องตรงไปตรงมา กระตุ้นให้ลงมือทำ และรักษาศักดิ์ศรีของผู้ใช้

## Visual asset policy

- ภาพ raster หรือ illustration ใหม่ที่ใช้ในผลิตภัณฑ์และงานการตลาดของ Rise Pals ต้องสร้างด้วย GPT-Image-2 ตามข้อกำหนดของ Jeff
- Functional UI เช่น layout, charts, CSS effects และ icons ควรเป็น code-native หรือ vector system เพื่อความคมชัดและ accessibility ไม่ถือเป็น generated illustration
- ห้ามนำ stock image หรือ generated image จากโมเดลอื่นมาใช้แทนโดยไม่ขออนุมัติ
- ทุก asset ต้องมีที่มา prompt/version และสิทธิ์ใช้งานที่ติดตามได้

## Required handoff

เมื่อจบทุก turn ให้ตอบตาม `prompts/VS_CODE_HANDOFF_TEMPLATE.md` และต้องมีอย่างน้อย:

- สิ่งที่ทำสำเร็จ
- รายชื่อไฟล์ที่เปลี่ยน
- คำสั่งทดสอบและผลจริง
- assumptions / decisions / known issues
- สิ่งที่ยังไม่ได้ทำ
- copy block สำหรับส่งให้ Project Codex review

อัปเดต `PROJECT_STATUS.md` เฉพาะข้อเท็จจริงที่เปลี่ยนใน turn นั้น

