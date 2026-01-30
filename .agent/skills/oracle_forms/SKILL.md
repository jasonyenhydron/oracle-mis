---
name: Oracle Forms 開發技能
description: Oracle Forms 6i/10g/11g 開發最佳實踐與標準規範（繁體中文）
version: 1.0
language: zh-TW
---
# Oracle Forms 開發技能指南

本技能文件提供 Oracle Forms 開發的完整指南，涵蓋 FMB 表單開發、PL/SQL 程式設計、以及與後端資料庫的整合。

## 目錄

1. [開發環境設定](#開發環境設定)
2. [專案結構規範](#專案結構規範)
3. [表單開發標準](#表單開發標準)
4. [PL/SQL 開發規範](#plsql-開發規範)
5. [資料庫設計原則](#資料庫設計原則)
6. [錯誤處理機制](#錯誤處理機制)
7. [效能優化技巧](#效能優化技巧)
8. [常用程式碼範例](#常用程式碼範例)

---

## 開發環境設定

### 必要工具

- **Oracle Forms Builder** 6i/10g/11g
- **Oracle SQL Developer** 或 **PL/SQL Developer**
- **版本控制**: SVN 或 Git
- **文字編輯器**: Notepad++, VS Code

### 目錄結構

```
專案根目錄/
├── src/              # 原始碼目錄 (.fmb, .rdf)
├── fmx/              # 編譯後檔案 (.fmx, .rep)
├── sql/              # SQL 腳本與 Package
├── lib/              # 共用函式庫 (.pll, .plx)
├── olb/              # 物件函式庫 (.olb)
└── doc/              # 文件
```

---

## 專案結構規範

### 模組命名規則

#### 表單檔案命名 (FMB)

```
[系統代碼][功能代碼][序號].fmb

範例:
- hbmpd11.fmb    # HBM 系統，PD 功能，序號 11
- prmpr01.fmb    # PRM 系統，PR 功能，序號 01
- ivmgd12.fmb    # IVM 系統，GD 功能，序號 12
```

#### 報表檔案命名 (RDF)

```
[系統代碼][功能代碼][序號].rdf

範例:
- hbmpr11.rdf
- prmpr012.rdf
```

#### Package 命名規則

```
[系統代碼]_[模組名稱]_[類型]

範例:
- moci_dssrm_etl          # MOCI 系統 DSSRM ETL Package
- moci_srm_api            # MOCI 系統 SRM API Package
- ufm_fnd                 # UFM 系統基礎函式
```

---

## 表單開發標準

### 1. 表單架構

#### 基本 Block 設計

```sql
-- Data Block 屬性設定
Block Name: [TABLE_NAME]_BLOCK
Database Data Block: Yes
Query Data Source Type: Table
Query Data Source Name: [TABLE_NAME]
DML Data Target Type: Table
DML Data Target Name: [TABLE_NAME]
```

#### Canvas 設計原則

- **主畫面 (Content Canvas)**: 顯示主要資料
- **分頁 (Tab Canvas)**: 用於多頁籤介面
- **堆疊 (Stacked Canvas)**: 用於彈出視窗或詳細資訊

### 2. Trigger 開發規範

#### 常用 Triggers

**WHEN-NEW-FORM-INSTANCE**

```plsql
-- 表單初始化
PROCEDURE WHEN_NEW_FORM_INSTANCE IS
BEGIN
  -- 設定視窗標題
  SET_WINDOW_PROPERTY('MAIN_WINDOW', TITLE, '採購單維護');

  -- 初始化全域變數
  :GLOBAL.ORGANIZATION_ID := '4811';
  :GLOBAL.LANGUAGE_ID := '1';

  -- 執行查詢
  GO_BLOCK('PURCHASE_HEAD');
  EXECUTE_QUERY;

EXCEPTION
  WHEN OTHERS THEN
    MESSAGE('表單初始化錯誤: ' || SQLERRM);
    RAISE FORM_TRIGGER_FAILURE;
END;
```

**PRE-QUERY**

```plsql
-- 查詢前處理
PROCEDURE PRE_QUERY IS
BEGIN
  -- 設定查詢條件
  IF :SEARCH_BLOCK.PURCHASE_NO IS NOT NULL THEN
    SET_BLOCK_PROPERTY('PURCHASE_HEAD', DEFAULT_WHERE,
      'PURCHASE_NO LIKE ''' || :SEARCH_BLOCK.PURCHASE_NO || '%''');
  END IF;

  -- 設定組織條件
  IF :GLOBAL.ORGANIZATION_ID IS NOT NULL THEN
    SET_BLOCK_PROPERTY('PURCHASE_HEAD', DEFAULT_WHERE,
      'ORGANIZATION_ID = ' || :GLOBAL.ORGANIZATION_ID);
  END IF;
END;
```

**POST-QUERY**

```plsql
-- 查詢後處理
PROCEDURE POST_QUERY IS
  v_vendor_name VARCHAR2(200);
BEGIN
  -- 取得廠商名稱
  SELECT vendor_name
    INTO v_vendor_name
    FROM cmm_vendor_v
   WHERE vendor_id = :PURCHASE_HEAD.VENDOR_ID
     AND language_id = :GLOBAL.LANGUAGE_ID;

  :PURCHASE_HEAD.VENDOR_NAME := v_vendor_name;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    :PURCHASE_HEAD.VENDOR_NAME := NULL;
  WHEN OTHERS THEN
    MESSAGE('取得廠商名稱錯誤: ' || SQLERRM);
END;
```

**WHEN-VALIDATE-RECORD**

```plsql
-- 記錄驗證
PROCEDURE WHEN_VALIDATE_RECORD IS
BEGIN
  -- 必填欄位檢查
  IF :PURCHASE_HEAD.VENDOR_ID IS NULL THEN
    MESSAGE('請選擇廠商！');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;

  IF :PURCHASE_HEAD.PURCHASE_DATE IS NULL THEN
    MESSAGE('請輸入採購日期！');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;

  -- 資料合理性檢查
  IF :PURCHASE_DETAIL.PURCHASE_QTY <= 0 THEN
    MESSAGE('採購數量必須大於 0！');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;
END;
```

**PRE-INSERT / PRE-UPDATE**

```plsql
-- 新增/更新前處理
PROCEDURE PRE_INSERT IS
BEGIN
  -- 設定系統欄位
  :PURCHASE_HEAD.ENTRY_ID := :GLOBAL.USER_ID;
  :PURCHASE_HEAD.ENTRY_DATE := SYSDATE;
  :PURCHASE_HEAD.TR_ID := :GLOBAL.USER_ID;
  :PURCHASE_HEAD.TR_DATE := SYSDATE;

  -- 產生序號
  IF :PURCHASE_HEAD.PURCHASE_HEAD_ID IS NULL THEN
    SELECT prm_purchase_head_id.NEXTVAL
      INTO :PURCHASE_HEAD.PURCHASE_HEAD_ID
      FROM DUAL;
  END IF;

  -- 產生單號
  IF :PURCHASE_HEAD.PURCHASE_NO IS NULL THEN
    :PURCHASE_HEAD.PURCHASE_NO := ufm_fnd.get_sequence_no(
      i_table_name => 'prm_purchase_head',
      i_sequence_no => 'PURCHASE_NO',
      i_base_date => TRUNC(:PURCHASE_HEAD.PURCHASE_DATE),
      i_parameter1 => :GLOBAL.COMPANY_ID
    );
  END IF;
END;
```

**ON-ERROR**

```plsql
-- 錯誤處理
PROCEDURE ON_ERROR IS
  v_error_code NUMBER := ERROR_CODE;
  v_error_text VARCHAR2(200) := ERROR_TEXT;
  v_error_type VARCHAR2(10) := ERROR_TYPE;
BEGIN
  -- 自訂錯誤訊息
  IF v_error_code = 40508 THEN
    MESSAGE('無法更新記錄，請檢查資料狀態！');
  ELSIF v_error_code = 40509 THEN
    MESSAGE('無法刪除記錄，請檢查是否有相關資料！');
  ELSE
    MESSAGE('錯誤代碼: ' || v_error_code || ', 訊息: ' || v_error_text);
  END IF;
END;
```

### 3. LOV (List of Values) 設計

```plsql
-- LOV Record Group 建立
PROCEDURE CREATE_VENDOR_LOV IS
  rg_id RECORDGROUP;
  rg_name VARCHAR2(40) := 'VENDOR_RG';
BEGIN
  -- 刪除舊的 Record Group
  rg_id := FIND_GROUP(rg_name);
  IF NOT ID_NULL(rg_id) THEN
    DELETE_GROUP(rg_id);
  END IF;

  -- 建立新的 Record Group
  rg_id := CREATE_GROUP_FROM_QUERY(rg_name,
    'SELECT vendor_id, vendor_no, vendor_name ' ||
    'FROM cmm_vendor_v ' ||
    'WHERE organization_id = ' || :GLOBAL.ORGANIZATION_ID ||
    ' AND language_id = ' || :GLOBAL.LANGUAGE_ID ||
    ' ORDER BY vendor_no');

  -- 執行查詢
  IF POPULATE_GROUP(rg_id) = 0 THEN
    MESSAGE('查無廠商資料！');
  END IF;
END;
```

---

## PL/SQL 開發規範

### 1. Package 結構

#### Package Specification (規格)

```sql
CREATE OR REPLACE PACKAGE moci_dssrm_etl IS
  /**
   * Package: moci_dssrm_etl
   * 功能: DSSRM 系統資料交換 ETL 處理
   * 作者: [開發者名稱]
   * 日期: 2025-01-26
   */

  -- 執行所有交換資料
  PROCEDURE transfer_all(
    i_system_no IN VARCHAR2,
    i_transfer_table IN VARCHAR2 DEFAULT NULL
  );

  -- 部門資料同步
  PROCEDURE cmm_department(
    i_system_no IN VARCHAR2 DEFAULT 'DSSRM',
    i_transfer_table IN VARCHAR2,
    i_last_transfer_date IN DATE
  );

  -- 員工資料同步
  PROCEDURE hrm_employee(
    i_system_no IN VARCHAR2 DEFAULT 'DSSRM',
    i_transfer_table IN VARCHAR2,
    i_last_transfer_date IN DATE
  );

  -- 取得預設倉別
  FUNCTION f_get_default_warehouse(
    i_purchase_detail_id IN NUMBER
  ) RETURN VARCHAR2;

END moci_dssrm_etl;
/
```

#### Package Body (主體)

```sql
CREATE OR REPLACE PACKAGE BODY moci_dssrm_etl IS

  -- 私有變數
  g_debug_mode BOOLEAN := FALSE;

  -- 私有程序：寫入交易控制資訊
  PROCEDURE in_trans_control(
    i_system_no IN VARCHAR2 DEFAULT NULL,
    i_mis_table_name IN VARCHAR2 DEFAULT NULL,
    i_transfer_table IN VARCHAR2 DEFAULT NULL,
    i_task_id IN VARCHAR2 DEFAULT NULL,
    i_transaction_date IN DATE DEFAULT SYSDATE,
    i_rowcount IN NUMBER DEFAULT 0,
    i_error_msg IN VARCHAR2 DEFAULT NULL,
    i_sql_statement IN VARCHAR2 DEFAULT NULL,
    i_flag IN VARCHAR2 DEFAULT NULL
  ) IS
    v_para_value VARCHAR2(4000);
    v_flag VARCHAR2(100) := i_flag;
  BEGIN
    -- 組合參數資訊
    v_para_value := 'TRANSACTION_DATE=' || TO_CHAR(i_transaction_date, 'YYYY-MM-DD HH24:MI:SS')
                 || '; ROWCOUNT=' || TO_CHAR(i_rowcount)
                 || '; SQL=' || i_sql_statement;

    -- 寫入 LOG
    INSERT INTO moci_ds_exe_log(
      function_name, flag, para_name, para_value,
      err_message, sql_statement, tr_id, tr_date
    ) VALUES (
      i_task_id, v_flag, i_system_no, v_para_value,
      i_error_msg, i_sql_statement, USER, SYSDATE
    );

    -- 更新控制表
    IF i_error_msg IS NULL THEN
      v_flag := '00';
    ELSE
      v_flag := '99';
    END IF;

    UPDATE moci_ds_ctrl_table
       SET last_transfer_date = i_transaction_date,
           ds_ctrl_table_status = v_flag,
           tr_id = USER,
           tr_date = SYSDATE
     WHERE system_no = i_system_no
       AND (transfer_table = i_transfer_table
            OR mis_table_name = i_transfer_table);

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('錯誤訊息: ' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE('錯誤行號: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      ROLLBACK;
  END in_trans_control;

  -- 公開程序實作
  PROCEDURE transfer_all(
    i_system_no IN VARCHAR2,
    i_transfer_table IN VARCHAR2 DEFAULT NULL
  ) AS
    n_minute NUMBER := TO_NUMBER(TO_CHAR(SYSDATE, 'MI'));
    n_hour NUMBER := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24'));
    v_sql VARCHAR2(4000);
    r_log moci_ds_exe_log%ROWTYPE;

    CURSOR cur_data IS
      SELECT system_no, mis_table_name, transfer_table,
             last_transfer_date, procedure_name,
             byhour, NVL(byminute, 0) AS byminute
        FROM moci_ds_ctrl_table
       WHERE ds_ctrl_table_status = '00'
         AND (i_system_no IS NULL OR system_no = i_system_no)
         AND (i_transfer_table IS NULL OR transfer_table = i_transfer_table)
       ORDER BY byhour, byminute;

    row_data cur_data%ROWTYPE;
  BEGIN
    r_log.function_name := 'moci_dssrm_etl.transfer_all';
    r_log.flag := 'begin';
    r_log.err_message := 'i_system_no=' || i_system_no ||
                         ',i_transfer_table=' || i_transfer_table;

    DBMS_OUTPUT.PUT_LINE('nMinute=' || n_minute);
    DBMS_OUTPUT.PUT_LINE('nHour=' || n_hour);

    OPEN cur_data;
    LOOP
      FETCH cur_data INTO row_data;
      EXIT WHEN cur_data%NOTFOUND;

      -- 檢查執行時間
      IF INSTR(',' || row_data.byhour || ',', ',' || n_hour || ',') > 0
         AND INSTR(',' || row_data.byminute || ',', ',' || n_minute || ',') > 0 THEN

        v_sql := 'BEGIN ' || row_data.procedure_name ||
                 '(i_system_no => :1, i_transfer_table => :2, ' ||
                 'i_last_transfer_date => :3); END;';

        EXECUTE IMMEDIATE v_sql
          USING IN row_data.system_no,
                IN row_data.transfer_table,
                IN row_data.last_transfer_date;

        r_log.flag := 'sub-finish';
        r_log.err_message := v_sql;
        in_trans_control(
          i_task_id => r_log.function_name,
          i_flag => r_log.flag,
          i_error_msg => r_log.err_message
        );
      END IF;
    END LOOP;
    CLOSE cur_data;

    r_log.flag := 'finish';

  EXCEPTION
    WHEN OTHERS THEN
      r_log.flag := 'error';
      r_log.err_message := 'SQLERRM=' || SQLERRM ||
                           ', 錯誤行號: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
      DBMS_OUTPUT.PUT_LINE(r_log.err_message);
  END transfer_all;

  -- Function 實作
  FUNCTION f_get_default_warehouse(
    i_purchase_detail_id IN NUMBER
  ) RETURN VARCHAR2 IS
    v_department_no cmm_department.department_no%TYPE;
    v_default_warehouse_no ivm_warehouse.warehouse_no%TYPE;
  BEGIN
    -- 取得部門代號
    SELECT d.department_no
      INTO v_department_no
      FROM prm_purchase_detail pd,
           prm_purchase_head ph,
           cmm_department d
     WHERE pd.purchase_detail_id = i_purchase_detail_id
       AND ph.purchase_head_id = pd.purchase_head_id
       AND d.department_id = ph.department_id;

    -- 決定預設倉別
    IF v_department_no = 'NUF08' THEN
      v_default_warehouse_no := '3900'; -- 液品製造部
    ELSE
      v_default_warehouse_no := '1900'; -- 其他部門
    END IF;

    RETURN v_default_warehouse_no;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN '1900'; -- 預設倉別
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('❌ 錯誤函數: f_get_default_warehouse');
      DBMS_OUTPUT.PUT_LINE('錯誤訊息: ' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE('錯誤行號: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      RETURN '1900';
  END f_get_default_warehouse;

END moci_dssrm_etl;
/
```

### 2. 標準化程式碼模板

#### Cursor 處理模板

```sql
PROCEDURE process_purchase_data(
  i_organization_id IN NUMBER,
  i_company_id IN NUMBER
) AS
  v_row_count NUMBER := 0;
  v_error_msg VARCHAR2(4000);

  CURSOR cur_purchase IS
    SELECT ph.purchase_head_id,
           ph.purchase_no,
           ph.vendor_id,
           pd.purchase_detail_id,
           pd.part_id,
           pd.purchase_qty
      FROM prm_purchase_head ph
      JOIN prm_purchase_detail pd
        ON ph.purchase_head_id = pd.purchase_head_id
     WHERE ph.organization_id = i_organization_id
       AND ph.company_id = i_company_id
       AND ph.purchase_head_status = '95'
     ORDER BY ph.purchase_no;

  row_purchase cur_purchase%ROWTYPE;

BEGIN
  OPEN cur_purchase;
  LOOP
    FETCH cur_purchase INTO row_purchase;
    EXIT WHEN cur_purchase%NOTFOUND;

    BEGIN
      -- 處理每筆資料
      DBMS_OUTPUT.PUT_LINE('處理採購單: ' || row_purchase.purchase_no);

      -- 您的處理邏輯

      v_row_count := v_row_count + 1;

    EXCEPTION
      WHEN OTHERS THEN
        v_error_msg := '處理採購單 ' || row_purchase.purchase_no ||
                       ' 發生錯誤: ' || SQLERRM;
        DBMS_OUTPUT.PUT_LINE(v_error_msg);
        -- 記錄錯誤但繼續處理
    END;
  END LOOP;
  CLOSE cur_purchase;

  COMMIT;

  DBMS_OUTPUT.PUT_LINE('處理完成，共處理 ' || v_row_count || ' 筆資料');

EXCEPTION
  WHEN OTHERS THEN
    IF cur_purchase%ISOPEN THEN
      CLOSE cur_purchase;
    END IF;
    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('錯誤訊息: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('錯誤行號: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    RAISE;
END process_purchase_data;
```

#### Bulk Collect 高效能處理

```sql
PROCEDURE bulk_update_inventory AS
  TYPE t_part_id IS TABLE OF ivm_part.part_id%TYPE;
  TYPE t_stock_qty IS TABLE OF ivm_part.stock_qty%TYPE;

  v_part_ids t_part_id;
  v_stock_qtys t_stock_qty;

  CURSOR cur_parts IS
    SELECT part_id, stock_qty
      FROM ivm_part
     WHERE organization_id = 4811
       AND part_type = 'PI';

BEGIN
  OPEN cur_parts;
  LOOP
    FETCH cur_parts BULK COLLECT INTO v_part_ids, v_stock_qtys LIMIT 1000;
    EXIT WHEN v_part_ids.COUNT = 0;

    FORALL i IN 1..v_part_ids.COUNT
      UPDATE ivm_part_stock
         SET stock_qty = v_stock_qtys(i),
             tr_date = SYSDATE
       WHERE part_id = v_part_ids(i);

    COMMIT;
  END LOOP;
  CLOSE cur_parts;

EXCEPTION
  WHEN OTHERS THEN
    IF cur_parts%ISOPEN THEN
      CLOSE cur_parts;
    END IF;
    ROLLBACK;
    RAISE;
END bulk_update_inventory;
```

---

## 資料庫設計原則

### 1. 表格命名規範

```sql
-- 主檔表格
[系統代碼]_[功能名稱]
範例: prm_purchase_head, ivm_part, cmm_vendor

-- 明細表格
[系統代碼]_[功能名稱]_detail
範例: prm_purchase_detail, ivm_part_stock_detail

-- 多語系表格
[主表名稱]_l
範例: ivm_part_l, cmm_vendor_l

-- 視圖
[主表名稱]_v
範例: prm_purchase_head_v, ivm_part_v

-- 暫存表
[主表名稱]_w
範例: moci_purchase_receipt_w
```

### 2. 標準欄位

每個表格應包含以下標準欄位：

```sql
CREATE TABLE prm_purchase_head (
  -- 主鍵
  purchase_head_id NUMBER NOT NULL,

  -- 組織與公司
  organization_id NUMBER NOT NULL,
  company_id NUMBER,

  -- 業務欄位
  purchase_no VARCHAR2(30) NOT NULL,
  purchase_date DATE NOT NULL,
  vendor_id NUMBER NOT NULL,
  -- ... 其他業務欄位

  -- 狀態欄位
  purchase_head_status VARCHAR2(2) DEFAULT '00',

  -- 系統欄位
  entry_id NUMBER,           -- 建立者 ID
  entry_date DATE,           -- 建立日期
  tr_id NUMBER,              -- 異動者 ID
  tr_date DATE,              -- 異動日期
  sys_tr_date DATE,          -- 系統異動日期（觸發器自動更新）
  moci_tr_date DATE,         -- MOCI 異動日期

  -- 主鍵約束
  CONSTRAINT prm_purchase_head_pk PRIMARY KEY (purchase_head_id)
);

-- 建立索引
CREATE INDEX prm_purchase_head_idx1 ON prm_purchase_head(organization_id, purchase_no);
CREATE INDEX prm_purchase_head_idx2 ON prm_purchase_head(vendor_id);
CREATE INDEX prm_purchase_head_idx3 ON prm_purchase_head(sys_tr_date);

-- 建立觸發器自動更新 sys_tr_date
CREATE OR REPLACE TRIGGER prm_purchase_head_tr
BEFORE INSERT OR UPDATE ON prm_purchase_head
FOR EACH ROW
BEGIN
  :NEW.sys_tr_date := SYSDATE;
END;
/
```

### 3. 序號管理

```sql
-- 建立序號
CREATE SEQUENCE prm_purchase_head_id
  START WITH 1
  INCREMENT BY 1
  NOCACHE
  NOCYCLE;

-- 在 Trigger 中使用
CREATE OR REPLACE TRIGGER prm_purchase_head_bi
BEFORE INSERT ON prm_purchase_head
FOR EACH ROW
BEGIN
  IF :NEW.purchase_head_id IS NULL THEN
    SELECT prm_purchase_head_id.NEXTVAL
      INTO :NEW.purchase_head_id
      FROM DUAL;
  END IF;
END;
/
```

---

## 錯誤處理機制

### 1. 標準錯誤處理模板

```plsql
PROCEDURE standard_error_handling_example AS
  v_error_code NUMBER;
  v_error_msg VARCHAR2(4000);
  v_error_stack VARCHAR2(4000);
BEGIN
  -- 您的程式邏輯

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    v_error_msg := '查無資料';
    DBMS_OUTPUT.PUT_LINE(v_error_msg);
    -- 記錄錯誤

  WHEN TOO_MANY_ROWS THEN
    v_error_msg := '查詢結果超過一筆';
    DBMS_OUTPUT.PUT_LINE(v_error_msg);

  WHEN DUP_VAL_ON_INDEX THEN
    v_error_msg := '資料重複，違反唯一性約束';
    DBMS_OUTPUT.PUT_LINE(v_error_msg);

  WHEN OTHERS THEN
    v_error_code := SQLCODE;
    v_error_msg := SQLERRM;
    v_error_stack := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;

    DBMS_OUTPUT.PUT_LINE('❌ 錯誤代碼: ' || v_error_code);
    DBMS_OUTPUT.PUT_LINE('❌ 錯誤訊息: ' || v_error_msg);
    DBMS_OUTPUT.PUT_LINE('❌ 錯誤堆疊: ' || v_error_stack);

    -- 記錄到錯誤表
    INSERT INTO moci_ds_exe_log(
      function_name, flag, err_message, tr_date
    ) VALUES (
      'standard_error_handling_example',
      'ERROR',
      v_error_msg || ' | ' || v_error_stack,
      SYSDATE
    );
    COMMIT;

    RAISE;
END;
```

### 2. Forms 錯誤處理

```plsql
-- ON-ERROR Trigger
PROCEDURE ON_ERROR IS
  v_error_code NUMBER := ERROR_CODE;
  v_error_text VARCHAR2(200) := ERROR_TEXT;
  v_error_type VARCHAR2(10) := ERROR_TYPE;
  v_custom_msg VARCHAR2(500);
BEGIN
  -- 自訂錯誤訊息對照
  CASE v_error_code
    WHEN 40508 THEN
      v_custom_msg := '無法更新記錄，記錄已被鎖定或已被其他使用者修改！';
    WHEN 40509 THEN
      v_custom_msg := '無法刪除記錄，此記錄可能有相關的子資料！';
    WHEN 40735 THEN
      v_custom_msg := '必須先儲存主檔資料才能新增明細！';
    WHEN 40202 THEN
      v_custom_msg := '欄位必須輸入！';
    ELSE
      v_custom_msg := '錯誤代碼: ' || v_error_code || CHR(10) ||
                      '錯誤訊息: ' || v_error_text;
  END CASE;

  MESSAGE(v_custom_msg);

  -- 記錄錯誤到資料庫
  BEGIN
    INSERT INTO form_error_log(
      form_name, error_code, error_text,
      user_id, error_date
    ) VALUES (
      :SYSTEM.CURRENT_FORM,
      v_error_code,
      v_error_text,
      :GLOBAL.USER_ID,
      SYSDATE
    );
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL; -- 避免錯誤處理本身產生錯誤
  END;
END;
```

---

## 效能優化技巧

### 1. SQL 優化原則

#### 使用 Bind Variables

```sql
-- ❌ 不好的寫法
v_sql := 'SELECT * FROM prm_purchase_head WHERE purchase_no = ''' || v_purchase_no || '''';

-- ✅ 好的寫法
v_sql := 'SELECT * FROM prm_purchase_head WHERE purchase_no = :1';
EXECUTE IMMEDIATE v_sql INTO v_record USING v_purchase_no;
```

#### 避免 SELECT *

```sql
-- ❌ 不好的寫法
SELECT * FROM prm_purchase_head WHERE purchase_head_id = 12345;

-- ✅ 好的寫法
SELECT purchase_head_id, purchase_no, vendor_id, purchase_date
  FROM prm_purchase_head
 WHERE purchase_head_id = 12345;
```

#### 使用 EXISTS 取代 IN

```sql
-- ❌ 效能較差
SELECT * FROM prm_purchase_head
 WHERE vendor_id IN (SELECT vendor_id FROM cmm_vendor WHERE vendor_type = 'A');

-- ✅ 效能較好
SELECT * FROM prm_purchase_head ph
 WHERE EXISTS (
   SELECT 1 FROM cmm_vendor v
    WHERE v.vendor_id = ph.vendor_id
      AND v.vendor_type = 'A'
 );
```

### 2. Forms 效能優化

#### 限制查詢筆數

```plsql
-- 設定最大查詢筆數
SET_BLOCK_PROPERTY('PURCHASE_HEAD', MAX_QUERY_HITS, 1000);
```

#### 使用 Array Processing

```plsql
-- 設定 Array Size 提升效能
SET_BLOCK_PROPERTY('PURCHASE_DETAIL', ARRAY_FETCH_SIZE, 100);
SET_BLOCK_PROPERTY('PURCHASE_DETAIL', ARRAY_DML_SIZE, 100);
```

---

## 常用程式碼範例

### 1. 動態 SQL 執行

```plsql
PROCEDURE execute_dynamic_sql(
  i_table_name IN VARCHAR2,
  i_where_clause IN VARCHAR2
) AS
  TYPE t_ref_cursor IS REF CURSOR;
  v_cursor t_ref_cursor;
  v_sql VARCHAR2(4000);
  v_count NUMBER;
BEGIN
  -- 組合 SQL
  v_sql := 'SELECT COUNT(*) FROM ' || i_table_name ||
           ' WHERE ' || i_where_clause;

  -- 執行動態 SQL
  EXECUTE IMMEDIATE v_sql INTO v_count;

  DBMS_OUTPUT.PUT_LINE('查詢結果筆數: ' || v_count);

  -- 使用 REF CURSOR
  v_sql := 'SELECT * FROM ' || i_table_name ||
           ' WHERE ' || i_where_clause;
  OPEN v_cursor FOR v_sql;

  -- 處理結果...

  CLOSE v_cursor;
END;
```

### 2. JSON 處理 (使用 PLJSON)

```plsql
PROCEDURE parse_json_data(i_json_string IN VARCHAR2) AS
  plj_object PLJSON;
  plj_array PLJSON_LIST;
  v_value VARCHAR2(4000);
BEGIN
  -- 解析 JSON
  plj_object := PLJSON(i_json_string);

  -- 取得單一值
  v_value := PLJSON_EXT.GET_STRING(plj_object, 'purchase_no');
  DBMS_OUTPUT.PUT_LINE('採購單號: ' || v_value);

  -- 取得陣列
  plj_array := PLJSON_EXT.GET_JSON_LIST(plj_object, 'details');

  -- 迴圈處理陣列
  FOR i IN 1..plj_array.COUNT LOOP
    v_value := JSON_EXT.GET_STRING(
      JSON(plj_array.GET(i).TO_CHAR()),
      'part_no'
    );
    DBMS_OUTPUT.PUT_LINE('料號: ' || v_value);
  END LOOP;

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('JSON 解析錯誤: ' || SQLERRM);
END;
```

### 3. 檔案處理 (UTL_FILE)

```plsql
PROCEDURE export_to_file(
  i_file_path IN VARCHAR2,
  i_file_name IN VARCHAR2
) AS
  v_file UTL_FILE.FILE_TYPE;

  CURSOR cur_data IS
    SELECT purchase_no, vendor_name, purchase_amt
      FROM prm_purchase_head_v
     WHERE purchase_date >= TRUNC(SYSDATE) - 30;

  row_data cur_data%ROWTYPE;
BEGIN
  -- 開啟檔案
  v_file := UTL_FILE.FOPEN(i_file_path, i_file_name, 'W', 32767);

  -- 寫入標題
  UTL_FILE.PUT_LINE(v_file, '採購單號,廠商名稱,採購金額');

  -- 寫入資料
  OPEN cur_data;
  LOOP
    FETCH cur_data INTO row_data;
    EXIT WHEN cur_data%NOTFOUND;

    UTL_FILE.PUT_LINE(v_file,
      row_data.purchase_no || ',' ||
      row_data.vendor_name || ',' ||
      row_data.purchase_amt
    );
  END LOOP;
  CLOSE cur_data;

  -- 關閉檔案
  UTL_FILE.FCLOSE(v_file);

  DBMS_OUTPUT.PUT_LINE('檔案匯出完成: ' || i_file_name);

EXCEPTION
  WHEN UTL_FILE.INVALID_PATH THEN
    DBMS_OUTPUT.PUT_LINE('錯誤: 無效的檔案路徑');
  WHEN UTL_FILE.WRITE_ERROR THEN
    DBMS_OUTPUT.PUT_LINE('錯誤: 檔案寫入失敗');
  WHEN OTHERS THEN
    IF UTL_FILE.IS_OPEN(v_file) THEN
      UTL_FILE.FCLOSE(v_file);
    END IF;
    DBMS_OUTPUT.PUT_LINE('錯誤: ' || SQLERRM);
END;
```

### 4. 郵件發送 (UTL_MAIL)

```plsql
PROCEDURE send_notification_email(
  i_recipient IN VARCHAR2,
  i_subject IN VARCHAR2,
  i_message IN VARCHAR2
) AS
BEGIN
  UTL_MAIL.SEND(
    sender => 'erp@company.com',
    recipients => i_recipient,
    subject => i_subject,
    message => i_message,
    mime_type => 'text/plain; charset=utf-8'
  );

  DBMS_OUTPUT.PUT_LINE('郵件已發送至: ' || i_recipient);

EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('郵件發送失敗: ' || SQLERRM);
END;
```

---

## 開發最佳實踐

### 1. 程式碼註解規範

```plsql
/**
 * 程序名稱: process_purchase_order
 * 功能說明: 處理採購單審核流程
 *
 * 參數說明:
 *   @param i_purchase_head_id  採購單主檔 ID
 *   @param i_approve_status    審核狀態 (Y/N/R)
 *   @param i_approve_comment   審核意見
 *   @param o_error_message     錯誤訊息
 *
 * 回傳值: 無
 *
 * 異常處理:
 *   - NO_DATA_FOUND: 查無採購單資料
 *   - OTHERS: 其他未預期錯誤
 *
 * 修改歷程:
 *   2025-01-26  張三  新建
 *   2025-02-01  李四  新增審核意見欄位
 */
PROCEDURE process_purchase_order(
  i_purchase_head_id IN NUMBER,
  i_approve_status IN VARCHAR2,
  i_approve_comment IN VARCHAR2 DEFAULT NULL,
  o_error_message OUT VARCHAR2
) AS
  -- 變數宣告
  v_current_status VARCHAR2(2);
BEGIN
  -- 程式邏輯
  NULL;
END process_purchase_order;
```

### 2. 版本控制建議

- 每次修改前先備份原始檔案
- 使用有意義的 commit 訊息
- 定期合併主分支的更新
- 重要功能開發使用分支

### 3. 測試建議

- 單元測試：測試個別 Procedure/Function
- 整合測試：測試完整業務流程
- 效能測試：大量資料測試
- 使用者驗收測試：實際使用者操作測試

---

## 常見問題與解決方案

### Q1: Forms 查詢速度慢

**解決方案:**

- 檢查 WHERE 條件是否使用索引欄位
- 限制查詢筆數 (MAX_QUERY_HITS)
- 使用 PRE-QUERY 設定適當的查詢條件
- 檢查資料庫統計資訊是否更新

### Q2: 資料無法儲存

**解決方案:**

- 檢查 Trigger 是否有 RAISE FORM_TRIGGER_FAILURE
- 檢查資料庫約束條件
- 檢查欄位長度是否足夠
- 查看 ON-ERROR Trigger 的錯誤訊息

### Q3: Package 編譯錯誤

**解決方案:**

- 使用 SHOW ERRORS 查看詳細錯誤
- 檢查相依物件是否存在
- 確認語法正確性
- 檢查權限是否足夠

---

## 參考資源

### 官方文件

#### Oracle Forms
- [Oracle Forms Developer's Guide 11g](https://docs.oracle.com/cd/E25178_01/dev.1111/e10470/toc.htm)
- [Oracle Forms Developer's Guide 10g](https://docs.oracle.com/cd/B25221_04/web.1013/b16496/toc.htm)
- [Oracle Forms Services Deployment Guide](https://docs.oracle.com/cd/E25178_01/deploy.1111/e10142/toc.htm)

#### Oracle PL/SQL
- [Oracle PL/SQL Language Reference 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/lnpls/index.html)
- [Oracle PL/SQL Language Reference 12c](https://docs.oracle.com/database/121/LNPLS/toc.htm)
- [Oracle PL/SQL Packages and Types Reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/index.html)

#### Oracle Database SQL
- [Oracle Database SQL Language Reference 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/index.html)
- [Oracle Database SQL Language Reference 12c](https://docs.oracle.com/database/121/SQLRF/toc.htm)
- [Oracle Database Performance Tuning Guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/tgdba/index.html)

#### 其他實用文件
- [Oracle Database Utilities (UTL_FILE, UTL_MAIL 等)](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/index.html)
- [Oracle Database Error Messages](https://docs.oracle.com/en/database/oracle/oracle-database/19/errmg/index.html)
- [Oracle Database Administrator's Guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/admin/index.html)

### 內部文件
- 專案開發規範文件
- 資料庫設計文件
- API 介面文件

---

**版本歷程:**

- v1.0 (2025-01-26): 初版發布

**維護者:** MIS JasonYen

**最後更新:** 2025-01-26
