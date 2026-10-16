-- =====================================================================
--  Ai_end : Shop / Stock App + AI Assistant
--  MySQL 8.0+  (สร้างตาม ERD_App_9)
--  รันได้ทั้งไฟล์: mysql -u root -p < ai_end_schema.sql
-- =====================================================================

CREATE DATABASE IF NOT EXISTS ai_end
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;   -- utf8mb4 = รองรับภาษาไทย + อีโมจิ
USE ai_end;

SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS ai_action_log, message_box, conversation, ai,
  bill_item, bill, promotions, storage_equipment, storage_product,
  equipment, product, employee, store_number, business_model, `user`;
SET FOREIGN_KEY_CHECKS = 1;

-- ---------------------------------------------------------------------
-- 1) ผู้ใช้ / เจ้าของธุรกิจ
-- ---------------------------------------------------------------------
CREATE TABLE `user` (
  id_user     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL,
  email       VARCHAR(150) NOT NULL,
  created_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_email (email)
) ENGINE=InnoDB;

CREATE TABLE business_model (
  id_business  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_user      INT UNSIGNED NOT NULL,                 -- เจ้าของธุรกิจ
  name_model   VARCHAR(100) NOT NULL,
  name_brand   VARCHAR(100) NOT NULL,
  logo_brand   VARCHAR(255) NULL,                     -- path / URL ของรูป
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_business_user FOREIGN KEY (id_user) REFERENCES `user`(id_user)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2) สาขา / พนักงาน
-- ---------------------------------------------------------------------
CREATE TABLE store_number (
  id_stor_branch_number INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business           INT UNSIGNED NOT NULL,
  branch_name           VARCHAR(100) NOT NULL,
  location              VARCHAR(255) NULL,
  CONSTRAINT fk_store_business FOREIGN KEY (id_business) REFERENCES business_model(id_business)
) ENGINE=InnoDB;

CREATE TABLE employee (
  id_employee           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business           INT UNSIGNED NOT NULL,
  id_stor_branch_number INT UNSIGNED NOT NULL,
  name                  VARCHAR(100) NOT NULL,
  position              VARCHAR(50)  NULL,
  id_login              VARCHAR(50)  NOT NULL,
  password_login        VARCHAR(255) NOT NULL,        -- เก็บค่า hash (bcrypt) เท่านั้น ห้ามเก็บรหัสตรงๆ
  is_active             BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE KEY uq_employee_login (id_login),
  CONSTRAINT fk_employee_business FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  CONSTRAINT fk_employee_store    FOREIGN KEY (id_stor_branch_number) REFERENCES store_number(id_stor_branch_number)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3) สินค้า / อุปกรณ์
-- ---------------------------------------------------------------------
CREATE TABLE product (
  id_product    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business   INT UNSIGNED NOT NULL,
  name_product  VARCHAR(150) NOT NULL,
  image         VARCHAR(255) NULL,
  price         DECIMAL(10,2) NOT NULL,
  type          VARCHAR(50)  NULL,
  details       TEXT NULL,
  input_date    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,        -- ปิดขายแทนการลบ (บิลเก่ายังอ้างถึง)
  CONSTRAINT chk_product_price CHECK (price >= 0),
  CONSTRAINT fk_product_business FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  KEY idx_product_name (id_business, name_product)    -- ให้ AI ค้นสินค้าจากชื่อได้เร็ว
) ENGINE=InnoDB;

CREATE TABLE equipment (
  id_equipment    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business     INT UNSIGNED NOT NULL,
  name_equipment  VARCHAR(150) NOT NULL,
  image           VARCHAR(255) NULL,
  price           DECIMAL(10,2) NOT NULL,
  type            VARCHAR(50)  NULL,
  details         TEXT NULL,
  input_date      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,
  CONSTRAINT chk_equipment_price CHECK (price >= 0),
  CONSTRAINT fk_equipment_business FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  KEY idx_equipment_name (id_business, name_equipment)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4) สต็อกแต่ละสาขา
-- ---------------------------------------------------------------------
CREATE TABLE storage_product (
  id_storage_product    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business           INT UNSIGNED NOT NULL,
  id_stor_branch_number INT UNSIGNED NOT NULL,
  id_product            INT UNSIGNED NOT NULL,
  quantity              INT NOT NULL DEFAULT 0,
  input_date            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP,   -- อัปเดตเวลาอัตโนมัติเมื่อแก้จำนวน
  UNIQUE KEY uq_storage_product (id_stor_branch_number, id_product),  -- สาขาเดียว สินค้าเดียว = แถวเดียว
  CONSTRAINT chk_storage_product_qty CHECK (quantity >= 0),
  CONSTRAINT fk_sp_business FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  CONSTRAINT fk_sp_store    FOREIGN KEY (id_stor_branch_number) REFERENCES store_number(id_stor_branch_number),
  CONSTRAINT fk_sp_product  FOREIGN KEY (id_product) REFERENCES product(id_product)
) ENGINE=InnoDB;

CREATE TABLE storage_equipment (
  id_storage_equipment  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business           INT UNSIGNED NOT NULL,
  id_stor_branch_number INT UNSIGNED NOT NULL,
  id_equipment          INT UNSIGNED NOT NULL,
  quantity              INT NOT NULL DEFAULT 0,
  input_date            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
                        ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_storage_equipment (id_stor_branch_number, id_equipment),
  CONSTRAINT chk_storage_equipment_qty CHECK (quantity >= 0),
  CONSTRAINT fk_se_business  FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  CONSTRAINT fk_se_store     FOREIGN KEY (id_stor_branch_number) REFERENCES store_number(id_stor_branch_number),
  CONSTRAINT fk_se_equipment FOREIGN KEY (id_equipment) REFERENCES equipment(id_equipment)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5) โปรโมชัน
-- ---------------------------------------------------------------------
CREATE TABLE promotions (
  id_promotions         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business           INT UNSIGNED NOT NULL,
  id_product            INT UNSIGNED NOT NULL,
  id_stor_branch_number INT UNSIGNED NULL,            -- NULL = ใช้ได้ทุกสาขา
  name                  VARCHAR(150) NOT NULL,
  discount_type         ENUM('percent','amount') NOT NULL,  -- ลดเป็น % หรือ ลดเป็นบาท
  discount_value        DECIMAL(10,2) NOT NULL,
  start_date            DATETIME NOT NULL,
  end_date              DATETIME NOT NULL,
  status                ENUM('draft','active','inactive','expired') NOT NULL DEFAULT 'draft',
  CONSTRAINT chk_promo_value CHECK (discount_value > 0),
  CONSTRAINT chk_promo_percent CHECK (discount_type <> 'percent' OR discount_value <= 100),
  CONSTRAINT chk_promo_dates CHECK (end_date > start_date),
  CONSTRAINT fk_promo_business FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  CONSTRAINT fk_promo_product  FOREIGN KEY (id_product) REFERENCES product(id_product),
  CONSTRAINT fk_promo_store    FOREIGN KEY (id_stor_branch_number) REFERENCES store_number(id_stor_branch_number),
  KEY idx_promo_active (status, start_date, end_date)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6) บิล / รายการในบิล
-- ---------------------------------------------------------------------
CREATE TABLE bill (
  id_bill               INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_stor_branch_number INT UNSIGNED NOT NULL,
  id_user               INT UNSIGNED NULL,            -- ลูกค้า/ผู้ใช้ (ถ้ามี)
  id_employee           INT UNSIGNED NULL,            -- พนักงานที่ขาย
  total_price           DECIMAL(12,2) NOT NULL DEFAULT 0,
  type_pay              ENUM('cash','transfer','qr','card','other') NOT NULL DEFAULT 'cash',
  sell_date             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_bill_store    FOREIGN KEY (id_stor_branch_number) REFERENCES store_number(id_stor_branch_number),
  CONSTRAINT fk_bill_user     FOREIGN KEY (id_user) REFERENCES `user`(id_user),
  CONSTRAINT fk_bill_employee FOREIGN KEY (id_employee) REFERENCES employee(id_employee),
  KEY idx_bill_date (id_stor_branch_number, sell_date)
) ENGINE=InnoDB;

CREATE TABLE bill_item (
  id_bill_item        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_bill             INT UNSIGNED NOT NULL,
  id_storage_product  INT UNSIGNED NOT NULL,
  id_promotions       INT UNSIGNED NULL,              -- NULL = ไม่ได้ใช้โปร
  volume              INT NOT NULL,                   -- จำนวนที่ขาย
  price               DECIMAL(10,2) NOT NULL,         -- ราคาต่อชิ้น ณ ตอนขาย
  discount            DECIMAL(10,2) NOT NULL DEFAULT 0,
  CONSTRAINT chk_bill_item_volume CHECK (volume > 0),
  CONSTRAINT fk_bi_bill    FOREIGN KEY (id_bill) REFERENCES bill(id_bill) ON DELETE CASCADE,
  CONSTRAINT fk_bi_storage FOREIGN KEY (id_storage_product) REFERENCES storage_product(id_storage_product),
  CONSTRAINT fk_bi_promo   FOREIGN KEY (id_promotions) REFERENCES promotions(id_promotions)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7) AI / แชท / log
-- ---------------------------------------------------------------------
CREATE TABLE ai (
  id_ai_model  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  model_name   VARCHAR(100) NOT NULL,                 -- เช่น 'qwen2.5:7b'
  prompt       TEXT NOT NULL,                         -- system prompt
  version      VARCHAR(20) NOT NULL,
  UNIQUE KEY uq_ai_version (model_name, version)
) ENGINE=InnoDB;

CREATE TABLE conversation (
  id_conversation INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business     INT UNSIGNED NOT NULL,
  id_user         INT UNSIGNED NULL,
  id_employee     INT UNSIGNED NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT chk_conv_owner CHECK (id_user IS NOT NULL OR id_employee IS NOT NULL), -- ต้องมีเจ้าของแชทอย่างน้อย 1 คน
  CONSTRAINT fk_conv_business FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  CONSTRAINT fk_conv_user     FOREIGN KEY (id_user) REFERENCES `user`(id_user),
  CONSTRAINT fk_conv_employee FOREIGN KEY (id_employee) REFERENCES employee(id_employee)
) ENGINE=InnoDB;

CREATE TABLE message_box (
  id_message            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_business           INT UNSIGNED NOT NULL,
  id_stor_branch_number INT UNSIGNED NULL,
  id_conversation       INT UNSIGNED NOT NULL,
  id_ai_model           INT UNSIGNED NULL,            -- ใส่เฉพาะข้อความที่ AI ตอบ
  role                  ENUM('user','assistant','system','tool') NOT NULL,
  content               TEXT NOT NULL,
  send_date             DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_msg_business     FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  CONSTRAINT fk_msg_store        FOREIGN KEY (id_stor_branch_number) REFERENCES store_number(id_stor_branch_number),
  CONSTRAINT fk_msg_conversation FOREIGN KEY (id_conversation) REFERENCES conversation(id_conversation) ON DELETE CASCADE,
  CONSTRAINT fk_msg_ai           FOREIGN KEY (id_ai_model) REFERENCES ai(id_ai_model),
  KEY idx_msg_history (id_conversation, send_date)    -- ดึงประวัติแชทส่งให้โมเดลได้เร็ว
) ENGINE=InnoDB;

CREATE TABLE ai_action_log (
  id_action      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_message     INT UNSIGNED NULL,
  id_user        INT UNSIGNED NULL,
  id_employee    INT UNSIGNED NULL,
  id_ai_model    INT UNSIGNED NOT NULL,
  id_business    INT UNSIGNED NOT NULL,
  tool_name      VARCHAR(100) NOT NULL,               -- เช่น 'update_stock', 'create_promotion'
  arguments      JSON NULL,                           -- argument ที่ AI ส่งมาเรียก tool
  result         TEXT NULL,
  error_message  TEXT NULL,
  target_table   VARCHAR(50) NULL,                    -- เช่น 'product', 'storage_product', 'promotions'
  target_id      INT UNSIGNED NULL,                   -- id ของแถวที่ AI ไปแก้
  status         ENUM('pending','success','failed') NOT NULL DEFAULT 'pending',
  created_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_log_message  FOREIGN KEY (id_message) REFERENCES message_box(id_message) ON DELETE SET NULL,
  CONSTRAINT fk_log_user     FOREIGN KEY (id_user) REFERENCES `user`(id_user),
  CONSTRAINT fk_log_employee FOREIGN KEY (id_employee) REFERENCES employee(id_employee),
  CONSTRAINT fk_log_ai       FOREIGN KEY (id_ai_model) REFERENCES ai(id_ai_model),
  CONSTRAINT fk_log_business FOREIGN KEY (id_business) REFERENCES business_model(id_business),
  KEY idx_log_target (target_table, target_id),
  KEY idx_log_date (id_business, created_date)
) ENGINE=InnoDB;


-- =====================================================================
--  ข้อมูลตัวอย่าง (ไว้ทดสอบ AI)  — ไม่ใช้ก็ลบส่วนนี้ทิ้งได้
-- =====================================================================
INSERT INTO `user` (name, email) VALUES ('เจ้าของร้าน', 'owner@example.com');
INSERT INTO business_model (id_user, name_model, name_brand) VALUES (1, 'ร้านกาแฟ', 'Ai Coffee');
INSERT INTO store_number (id_business, branch_name, location) VALUES
  (1, 'สาขาหลัก', 'กรุงเทพ'), (1, 'สาขา 2', 'นนทบุรี');
INSERT INTO employee (id_business, id_stor_branch_number, name, position, id_login, password_login) VALUES
  (1, 1, 'สมชาย', 'cashier', 'emp001', '$2b$10$REPLACE_WITH_REAL_BCRYPT_HASH');
INSERT INTO product (id_business, name_product, price, type) VALUES
  (1, 'ลาเต้เย็น', 55.00, 'drink'), (1, 'ครัวซองต์', 45.00, 'bakery');
INSERT INTO equipment (id_business, name_equipment, price, type) VALUES
  (1, 'แก้วพลาสติก 16oz', 2.50, 'packaging');
INSERT INTO storage_product (id_business, id_stor_branch_number, id_product, quantity) VALUES
  (1, 1, 1, 50), (1, 1, 2, 20), (1, 2, 1, 30);
INSERT INTO storage_equipment (id_business, id_stor_branch_number, id_equipment, quantity) VALUES
  (1, 1, 1, 500);
INSERT INTO ai (model_name, prompt, version) VALUES
  ('qwen2.5:7b', 'คุณคือผู้ช่วยจัดการสต็อก สินค้า และโปรโมชันของร้าน ...', '1.0');
