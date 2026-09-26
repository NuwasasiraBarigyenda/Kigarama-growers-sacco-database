-- =====================================================================
-- Kigarama Growers SACCO — MySQL Schema (reference / manual setup)
-- =====================================================================
-- NOTE: The Spring Boot application auto-creates and updates these
-- tables on startup via Hibernate (spring.jpa.hibernate.ddl-auto=update),
-- so running this file manually is OPTIONAL. It is provided for teams
-- that prefer to review/run DDL themselves, for production deployments,
-- or for setting up the database ahead of time.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS kigarama_sacco
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE kigarama_sacco;

-- ---------------------------------------------------------------------
-- Users: Super Admin, Admin, Cashier, Receptionist, Member
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(60) NOT NULL UNIQUE,
    email VARCHAR(120) UNIQUE,
    password VARCHAR(255) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    phone VARCHAR(30),
    profile_pic_url VARCHAR(255),
    role ENUM('SUPER_ADMIN','ADMIN','CASHIER','RECEPTIONIST','MEMBER') NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(60)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Member savings accounts (PIN-protected balance)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL UNIQUE,
    account_number VARCHAR(20) NOT NULL UNIQUE,
    pin_hash VARCHAR(255) NOT NULL,
    balance DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_accounts_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Coffee price history (kg, fluctuating world market price)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coffee_prices (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    price_per_kg DECIMAL(12,2) NOT NULL,
    effective_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    set_by VARCHAR(60),
    note VARCHAR(255)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Matooke price history (per bunch, by size)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS matooke_prices (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    size ENUM('SMALL','MEDIUM','LARGE') NOT NULL,
    price_per_bunch DECIMAL(12,2) NOT NULL,
    effective_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    set_by VARCHAR(60)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Coffee intake logs
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS coffee_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    kilograms DECIMAL(12,2) NOT NULL,
    price_per_kg_at_sale DECIMAL(12,2) NOT NULL,
    total_value DECIMAL(14,2) NOT NULL,
    recorded_by VARCHAR(60),
    recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    credited_to_account BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_coffee_logs_member FOREIGN KEY (member_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Matooke intake logs
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS matooke_logs (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    size ENUM('SMALL','MEDIUM','LARGE') NOT NULL,
    quantity INT NOT NULL,
    price_per_bunch_at_sale DECIMAL(12,2) NOT NULL,
    total_value DECIMAL(14,2) NOT NULL,
    recorded_by VARCHAR(60),
    recorded_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    credited_to_account BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_matooke_logs_member FOREIGN KEY (member_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Transactions: deposits, withdrawals, produce-sale credits
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS transactions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    type ENUM('DEPOSIT','WITHDRAWAL','COFFEE_SALE_CREDIT','MATOOKE_SALE_CREDIT',
              'MOBILE_MONEY_DEPOSIT','LOAN_DISBURSEMENT','LOAN_REPAYMENT') NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    balance_after DECIMAL(14,2) NOT NULL,
    description VARCHAR(255),
    performed_by VARCHAR(60),
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_transactions_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Chat messages: strictly Member <-> Receptionist only (app-layer enforced)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chat_messages (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    sender_id BIGINT NOT NULL,
    receiver_id BIGINT NOT NULL,
    message TEXT NOT NULL,
    attachment_url VARCHAR(255),
    attachment_name VARCHAR(120),
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_chat_sender FOREIGN KEY (sender_id) REFERENCES users(id),
    CONSTRAINT fk_chat_receiver FOREIGN KEY (receiver_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Password reset codes emailed to members/staff (forgot-password flow)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    code VARCHAR(10) NOT NULL,
    expires_at DATETIME NOT NULL,
    used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reset_user FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Loans: member applications, manager decision, cashier disbursement
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS loans (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    amount_requested DECIMAL(14,2) NOT NULL,
    purpose VARCHAR(500) NOT NULL,
    status ENUM('PENDING','APPROVED','REJECTED','DISBURSED','CLOSED') NOT NULL DEFAULT 'PENDING',
    outstanding_balance DECIMAL(14,2) NOT NULL DEFAULT 0.00,
    applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(60),
    decided_at DATETIME,
    decision_notes VARCHAR(500),
    disbursed_by VARCHAR(60),
    disbursed_at DATETIME,
    account_id BIGINT,
    CONSTRAINT fk_loans_member FOREIGN KEY (member_id) REFERENCES users(id),
    CONSTRAINT fk_loans_account FOREIGN KEY (account_id) REFERENCES accounts(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Mobile money deposit requests (verify-and-approve workflow)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS mobile_money_requests (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    member_id BIGINT NOT NULL,
    provider ENUM('MTN_MOMO','AIRTEL_MONEY') NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    amount DECIMAL(14,2) NOT NULL,
    reference VARCHAR(60),
    status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    decided_by VARCHAR(60),
    decided_at DATETIME,
    decision_notes VARCHAR(255),
    CONSTRAINT fk_mm_member FOREIGN KEY (member_id) REFERENCES users(id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- Seed data: default Super Admin (username: superadmin / password: SuperAdmin@123)
-- Password hash below is a bcrypt hash of "SuperAdmin@123" — the running
-- application also creates this automatically if it is missing, so this
-- INSERT is only needed if you are bootstrapping the schema by hand.
-- ---------------------------------------------------------------------
INSERT INTO users (username, email, password, full_name, phone, role, active, created_by)
SELECT 'superadmin', 'superadmin@kigaramasacco.co.ug', '$2b$10$Hwo67t4ob4WCeF3FI/435uDOEugHTlNEOC6b6O8iVgopvmgHmgm3u', 'System Super Administrator', '0700000000', 'SUPER_ADMIN', TRUE, 'SYSTEM'
WHERE NOT EXISTS (SELECT 1 FROM users WHERE role = 'SUPER_ADMIN');

INSERT INTO coffee_prices (price_per_kg, set_by, note)
SELECT 9500.00, 'SYSTEM', 'Initial seeded world-market price'
WHERE NOT EXISTS (SELECT 1 FROM coffee_prices);

INSERT INTO matooke_prices (size, price_per_bunch, set_by)
SELECT 'SMALL', 8000.00, 'SYSTEM' WHERE NOT EXISTS (SELECT 1 FROM matooke_prices WHERE size='SMALL');
INSERT INTO matooke_prices (size, price_per_bunch, set_by)
SELECT 'MEDIUM', 12000.00, 'SYSTEM' WHERE NOT EXISTS (SELECT 1 FROM matooke_prices WHERE size='MEDIUM');
INSERT INTO matooke_prices (size, price_per_bunch, set_by)
SELECT 'LARGE', 18000.00, 'SYSTEM' WHERE NOT EXISTS (SELECT 1 FROM matooke_prices WHERE size='LARGE');
