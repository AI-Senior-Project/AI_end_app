-- =====================================================================
-- โครงฐานข้อมูลแอปผู้ช่วย AI (ตาม ERD_App รอบล่าสุด)
-- ฐานข้อมูล: MySQL 8.0.16 ขึ้นไป หรือ MariaDB 10.2.1 ขึ้นไป (เช่นใน XAMPP)
-- แก้จาก ERD 2 จุด: ชื่อตาราง Peoduct -> Product และ id_user เป็น primary key
-- =====================================================================

-- utf8mb4 จำเป็นสำหรับเก็บภาษาไทย
CREATE DATABASE IF NOT EXISTS shop_ai
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE shop_ai;

-- ---------- ผู้ใช้ ----------
CREATE TABLE IF NOT EXISTS `User` (
    id_user     INT          NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    email       VARCHAR(190) NOT NULL,
    PRIMARY KEY (id_user),
    UNIQUE KEY uq_user_email (email)
) ENGINE = InnoDB;

-- ---------- ร้าน / แบรนด์ ----------
CREATE TABLE IF NOT EXISTS Business_Model (
    id_business INT          NOT NULL AUTO_INCREMENT,
    id_user     INT          NOT NULL,
    name_model  VARCHAR(100),
    name_brand  VARCHAR(100) NOT NULL,
    logo_brand  VARCHAR(255),               -- เก็บที่อยู่ไฟล์รูป ไม่ได้เก็บตัวรูป
    PRIMARY KEY (id_business),
    CONSTRAINT fk_business_user FOREIGN KEY (id_user) REFERENCES `User` (id_user)
) ENGINE = InnoDB;

-- ---------- สินค้าที่ขาย ----------
CREATE TABLE IF NOT EXISTS Product (
    id_product  INT            NOT NULL AUTO_INCREMENT,
    id_business INT            NOT NULL,
    name        VARCHAR(150)   NOT NULL,
    image       VARCHAR(255),
    quantity    INT            NOT NULL DEFAULT 0,
    price       DECIMAL(10, 2) NOT NULL,
    type        VARCHAR(50),
    input_date  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_product),
    UNIQUE KEY uq_product_name (id_business, name),   -- ร้านเดียวกันห้ามมีสินค้าชื่อซ้ำ
    CONSTRAINT fk_product_business FOREIGN KEY (id_business) REFERENCES Business_Model (id_business),
    CONSTRAINT chk_product_quantity CHECK (quantity >= 0),
    CONSTRAINT chk_product_price    CHECK (price >= 0)
) ENGINE = InnoDB;

-- ---------- อุปกรณ์ / ของที่ร้านใช้เอง ----------
CREATE TABLE IF NOT EXISTS Equipment (
    id_equipment INT            NOT NULL AUTO_INCREMENT,
    id_business  INT            NOT NULL,
    name         VARCHAR(150)   NOT NULL,
    image        VARCHAR(255),
    quantity     INT            NOT NULL DEFAULT 0,
    price        DECIMAL(10, 2),
    type         VARCHAR(50),
    input_date   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_equipment),
    UNIQUE KEY uq_equipment_name (id_business, name),
    CONSTRAINT fk_equipment_business FOREIGN KEY (id_business) REFERENCES Business_Model (id_business),
    CONSTRAINT chk_equipment_quantity CHECK (quantity >= 0),
    CONSTRAINT chk_equipment_price    CHECK (price >= 0)
) ENGINE = InnoDB;

-- ---------- โปรโมชั่น ----------
CREATE TABLE IF NOT EXISTS Promotions (
    id_promotions  INT            NOT NULL AUTO_INCREMENT,
    id_business    INT            NOT NULL,
    id_product     INT            NOT NULL,
    name           VARCHAR(150)   NOT NULL,
    discount_type  ENUM('percent', 'amount') NOT NULL,
    discount_value DECIMAL(10, 2) NOT NULL,
    start_date     DATETIME       NOT NULL,
    end_date       DATETIME       NOT NULL,
    status         ENUM('draft', 'approved', 'cancelled') NOT NULL DEFAULT 'draft',
    PRIMARY KEY (id_promotions),
    KEY idx_promo_business (id_business),
    KEY idx_promo_product (id_product),
    CONSTRAINT fk_promo_business FOREIGN KEY (id_business) REFERENCES Business_Model (id_business),
    CONSTRAINT fk_promo_product  FOREIGN KEY (id_product)  REFERENCES Product (id_product),
    CONSTRAINT chk_promo_value   CHECK (discount_value >= 0),
    CONSTRAINT chk_promo_percent CHECK (discount_type <> 'percent' OR discount_value <= 100),
    CONSTRAINT chk_promo_dates   CHECK (end_date >= start_date)
) ENGINE = InnoDB;

-- ---------- รายการขาย ----------
CREATE TABLE IF NOT EXISTS Billing_Menu (
    id_billing_menu INT            NOT NULL AUTO_INCREMENT,
    id_business     INT            NOT NULL,
    id_product      INT            NOT NULL,
    id_promotions   INT            NULL,              -- ว่างได้ ถ้าขายแบบไม่มีโปร
    volume          INT            NOT NULL,
    price           DECIMAL(10, 2) NOT NULL,          -- ราคาตอนขายจริง
    sell_date       DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_billing_menu),
    KEY idx_bill_business (id_business, sell_date),
    KEY idx_bill_product (id_product),
    CONSTRAINT fk_bill_business FOREIGN KEY (id_business)   REFERENCES Business_Model (id_business),
    CONSTRAINT fk_bill_product  FOREIGN KEY (id_product)    REFERENCES Product (id_product),
    CONSTRAINT fk_bill_promo    FOREIGN KEY (id_promotions) REFERENCES Promotions (id_promotions),
    CONSTRAINT chk_bill_volume  CHECK (volume > 0),
    CONSTRAINT chk_bill_price   CHECK (price >= 0)
) ENGINE = InnoDB;

-- ---------- ข้อความในแชท ----------
CREATE TABLE IF NOT EXISTS Message_Box (
    id_message  INT      NOT NULL AUTO_INCREMENT,
    id_business INT      NOT NULL,
    id_user     INT      NOT NULL,
    role        ENUM('user', 'assistant', 'tool') NOT NULL,
    content     TEXT     NOT NULL,
    send_date   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_message),
    KEY idx_message_chat (id_business, send_date),
    CONSTRAINT fk_message_business FOREIGN KEY (id_business) REFERENCES Business_Model (id_business),
    CONSTRAINT fk_message_user     FOREIGN KEY (id_user)     REFERENCES `User` (id_user)
) ENGINE = InnoDB;

-- ---------- การตั้งค่าโมเดล AI ----------
CREATE TABLE IF NOT EXISTS AI (
    id_ai_model INT          NOT NULL AUTO_INCREMENT,
    model_name  VARCHAR(100) NOT NULL,
    prompt      TEXT,
    version     VARCHAR(50),
    PRIMARY KEY (id_ai_model)
) ENGINE = InnoDB;

-- ---------- ประวัติสิ่งที่ AI ทำ ----------
CREATE TABLE IF NOT EXISTS Ai_action_log (
    id_action    INT          NOT NULL AUTO_INCREMENT,
    id_message   INT          NOT NULL,
    id_user      INT          NOT NULL,
    id_ai_model  INT          NOT NULL,
    tool_name    VARCHAR(100) NOT NULL,     -- เช่น update_stock
    arguments    JSON         NOT NULL,     -- ค่าที่ส่งให้ฟังก์ชัน
    status       ENUM('pending', 'confirmed', 'rejected', 'failed') NOT NULL DEFAULT 'pending',
    created_date DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_action),
    CONSTRAINT fk_action_message FOREIGN KEY (id_message)  REFERENCES Message_Box (id_message),
    CONSTRAINT fk_action_user    FOREIGN KEY (id_user)     REFERENCES `User` (id_user),
    CONSTRAINT fk_action_model   FOREIGN KEY (id_ai_model) REFERENCES AI (id_ai_model)
) ENGINE = InnoDB;
