---
name: Oracle Forms PL/SQL 開發技能
description: Oracle Forms PL/SQL 程式設計最佳實踐與標準規範（繁體中文）
version: 1.0
language: zh-TW
---

# Oracle Forms PL/SQL 開發技能指南

本技能文件專注於 Oracle Forms 環境中的 PL/SQL 程式設計，提供標準化的開發規範與最佳實踐。

## 目錄

1. [PL/SQL 基礎規範](#plsql-基礎規範)
2. [Package 開發標準](#package-開發標準)
3. [Trigger 程式設計](#trigger-程式設計)
4. [錯誤處理機制](#錯誤處理機制)
5. [效能優化技巧](#效能優化技巧)
6. [常用程式碼範例](#常用程式碼範例)

---

## PL/SQL 基礎規範

### 命名規則

```plsql
-- 變數命名
v_variable_name      -- 一般變數 (v_ 前綴)
c_constant_name      -- 常數 (c_ 前綴)
g_global_var         -- 全域變數 (g_ 前綴)
p_parameter_name     -- 參數 (p_ 前綴)
l_local_var          -- 區域變數 (l_ 前綴)

-- Cursor 命名
cur_cursor_name      -- Cursor (cur_ 前綴)
row_cursor_name      -- Cursor 記錄變數 (row_ 前綴)

-- Type 命名
t_type_name          -- 自訂類型 (t_ 前綴)

-- Exception 命名
e_exception_name     -- 自訂例外 (e_ 前綴)
```

### 程式碼格式化

```plsql
-- 標準格式範例
PROCEDURE process_purchase_order(
  p_purchase_head_id IN NUMBER,
  p_user_id IN NUMBER,
  p_result OUT VARCHAR2
) IS
  -- 變數宣告區
  v_purchase_no VARCHAR2(30);
  v_vendor_id NUMBER;
  v_total_amount NUMBER := 0;

  -- 常數宣告
  c_approved_status CONSTANT VARCHAR2(2) := '95';

  -- Cursor 宣告
  CURSOR cur_details IS
    SELECT purchase_detail_id, part_id, purchase_qty, unit_price
      FROM prm_purchase_detail
     WHERE purchase_head_id = p_purchase_head_id;

BEGIN
  -- 主要邏輯
  SELECT purchase_no, vendor_id
    INTO v_purchase_no, v_vendor_id
    FROM prm_purchase_head
   WHERE purchase_head_id = p_purchase_head_id;

  -- 處理明細
  FOR rec IN cur_details LOOP
    v_total_amount := v_total_amount + (rec.purchase_qty * rec.unit_price);
  END LOOP;

  -- 更新狀態
  UPDATE prm_purchase_head
     SET purchase_head_status = c_approved_status,
         total_amount = v_total_amount,
         tr_id = p_user_id,
         tr_date = SYSDATE
   WHERE purchase_head_id = p_purchase_head_id;

  COMMIT;

  p_result := 'SUCCESS';

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    p_result := 'ERROR: 查無採購單資料';
    ROLLBACK;
  WHEN OTHERS THEN
    p_result := 'ERROR: ' || SQLERRM;
    ROLLBACK;
    RAISE;
END process_purchase_order;
```

---

## Package 開發標準

### Package Specification 結構

```sql
CREATE OR REPLACE PACKAGE prm_purchase_api IS
  /**
   * Package: prm_purchase_api
   * 功能: 採購單處理 API
   * 作者: [開發者]
   * 日期: 2026-01-30
   * 版本: 1.0
   */

  -- 公開常數
  c_status_draft CONSTANT VARCHAR2(2) := '00';      -- 草稿
  c_status_submitted CONSTANT VARCHAR2(2) := '10';  -- 已送出
  c_status_approved CONSTANT VARCHAR2(2) := '95';   -- 已核准
  c_status_closed CONSTANT VARCHAR2(2) := '99';     -- 已結案

  -- 公開型別
  TYPE t_purchase_record IS RECORD (
    purchase_head_id NUMBER,
    purchase_no VARCHAR2(30),
    vendor_id NUMBER,
    purchase_date DATE,
    total_amount NUMBER
  );

  -- 建立採購單
  PROCEDURE create_purchase_order(
    p_organization_id IN NUMBER,
    p_vendor_id IN NUMBER,
    p_purchase_date IN DATE,
    p_user_id IN NUMBER,
    p_purchase_head_id OUT NUMBER,
    p_purchase_no OUT VARCHAR2,
    p_result OUT VARCHAR2
  );

  -- 新增採購明細
  PROCEDURE add_purchase_detail(
    p_purchase_head_id IN NUMBER,
    p_part_id IN NUMBER,
    p_purchase_qty IN NUMBER,
    p_unit_price IN NUMBER,
    p_user_id IN NUMBER,
    p_result OUT VARCHAR2
  );

  -- 送出採購單
  PROCEDURE submit_purchase_order(
    p_purchase_head_id IN NUMBER,
    p_user_id IN NUMBER,
    p_result OUT VARCHAR2
  );

  -- 核准採購單
  PROCEDURE approve_purchase_order(
    p_purchase_head_id IN NUMBER,
    p_user_id IN NUMBER,
    p_result OUT VARCHAR2
  );

  -- 取得採購單資訊
  FUNCTION get_purchase_info(
    p_purchase_head_id IN NUMBER
  ) RETURN t_purchase_record;

  -- 計算採購單總金額
  FUNCTION calculate_total_amount(
    p_purchase_head_id IN NUMBER
  ) RETURN NUMBER;

  -- 驗證採購單狀態
  FUNCTION validate_status(
    p_purchase_head_id IN NUMBER,
    p_expected_status IN VARCHAR2
  ) RETURN BOOLEAN;

END prm_purchase_api;
/
```

### Package Body 結構

```sql
CREATE OR REPLACE PACKAGE BODY prm_purchase_api IS

  -- 私有變數
  g_debug_mode BOOLEAN := FALSE;
  g_package_name CONSTANT VARCHAR2(50) := 'prm_purchase_api';

  -- 私有程序：記錄日誌
  PROCEDURE log_message(
    p_procedure_name IN VARCHAR2,
    p_message IN VARCHAR2,
    p_level IN VARCHAR2 DEFAULT 'INFO'
  ) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO system_log (
      package_name, procedure_name, log_level,
      log_message, log_date
    ) VALUES (
      g_package_name, p_procedure_name, p_level,
      p_message, SYSDATE
    );
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL; -- 避免日誌錯誤影響主流程
  END log_message;

  -- 私有函數：產生採購單號
  FUNCTION generate_purchase_no(
    p_organization_id IN NUMBER,
    p_purchase_date IN DATE
  ) RETURN VARCHAR2 IS
    v_purchase_no VARCHAR2(30);
    v_seq_no NUMBER;
  BEGIN
    -- 取得當日序號
    SELECT NVL(MAX(TO_NUMBER(SUBSTR(purchase_no, -4))), 0) + 1
      INTO v_seq_no
      FROM prm_purchase_head
     WHERE organization_id = p_organization_id
       AND TRUNC(purchase_date) = TRUNC(p_purchase_date);

    -- 組合單號: PO + 日期(YYYYMMDD) + 序號(4碼)
    v_purchase_no := 'PO' ||
                     TO_CHAR(p_purchase_date, 'YYYYMMDD') ||
                     LPAD(v_seq_no, 4, '0');

    RETURN v_purchase_no;
  END generate_purchase_no;

  -- 公開程序實作
  PROCEDURE create_purchase_order(
    p_organization_id IN NUMBER,
    p_vendor_id IN NUMBER,
    p_purchase_date IN DATE,
    p_user_id IN NUMBER,
    p_purchase_head_id OUT NUMBER,
    p_purchase_no OUT VARCHAR2,
    p_result OUT VARCHAR2
  ) IS
    v_procedure_name CONSTANT VARCHAR2(50) := 'create_purchase_order';
  BEGIN
    -- 參數驗證
    IF p_organization_id IS NULL THEN
      p_result := 'ERROR: 組織代碼不可為空';
      RETURN;
    END IF;

    IF p_vendor_id IS NULL THEN
      p_result := 'ERROR: 廠商代碼不可為空';
      RETURN;
    END IF;

    -- 產生主鍵
    SELECT prm_purchase_head_id.NEXTVAL
      INTO p_purchase_head_id
      FROM DUAL;

    -- 產生單號
    p_purchase_no := generate_purchase_no(p_organization_id, p_purchase_date);

    -- 新增採購單主檔
    INSERT INTO prm_purchase_head (
      purchase_head_id, organization_id, purchase_no,
      vendor_id, purchase_date, purchase_head_status,
      total_amount, entry_id, entry_date, tr_id, tr_date
    ) VALUES (
      p_purchase_head_id, p_organization_id, p_purchase_no,
      p_vendor_id, p_purchase_date, c_status_draft,
      0, p_user_id, SYSDATE, p_user_id, SYSDATE
    );

    COMMIT;

    p_result := 'SUCCESS';
    log_message(v_procedure_name, '建立採購單: ' || p_purchase_no);

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      p_result := 'ERROR: ' || SQLERRM;
      log_message(v_procedure_name, p_result, 'ERROR');
      RAISE;
  END create_purchase_order;

  -- Function 實作
  FUNCTION calculate_total_amount(
    p_purchase_head_id IN NUMBER
  ) RETURN NUMBER IS
    v_total_amount NUMBER := 0;
  BEGIN
    SELECT NVL(SUM(purchase_qty * unit_price), 0)
      INTO v_total_amount
      FROM prm_purchase_detail
     WHERE purchase_head_id = p_purchase_head_id;

    RETURN v_total_amount;

  EXCEPTION
    WHEN OTHERS THEN
      log_message('calculate_total_amount',
                  'ERROR: ' || SQLERRM, 'ERROR');
      RETURN 0;
  END calculate_total_amount;

  FUNCTION validate_status(
    p_purchase_head_id IN NUMBER,
    p_expected_status IN VARCHAR2
  ) RETURN BOOLEAN IS
    v_current_status VARCHAR2(2);
  BEGIN
    SELECT purchase_head_status
      INTO v_current_status
      FROM prm_purchase_head
     WHERE purchase_head_id = p_purchase_head_id;

    RETURN v_current_status = p_expected_status;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN FALSE;
    WHEN OTHERS THEN
      RETURN FALSE;
  END validate_status;

END prm_purchase_api;
/
```

---

## Trigger 程式設計

### Form-Level Triggers

#### WHEN-NEW-FORM-INSTANCE

```plsql
PROCEDURE when_new_form_instance IS
  v_form_title VARCHAR2(100);
BEGIN
  -- 設定表單標題
  v_form_title := '採購單維護作業 - ' || :GLOBAL.USER_NAME;
  SET_WINDOW_PROPERTY('MAIN_WINDOW', TITLE, v_form_title);

  -- 初始化全域變數
  :GLOBAL.ORGANIZATION_ID := '4811';
  :GLOBAL.COMPANY_ID := '1';
  :GLOBAL.LANGUAGE_ID := '1';

  -- 設定日期格式
  SET_APPLICATION_PROPERTY(DATE_FORMAT, 'YYYY/MM/DD');

  -- 移至查詢區塊
  GO_BLOCK('SEARCH_BLOCK');

EXCEPTION
  WHEN OTHERS THEN
    MESSAGE('表單初始化失敗: ' || SQLERRM);
    RAISE FORM_TRIGGER_FAILURE;
END;
```

### Block-Level Triggers

#### PRE-QUERY

```plsql
PROCEDURE pre_query IS
  v_where_clause VARCHAR2(4000);
BEGIN
  v_where_clause := '1=1';

  -- 組織條件
  IF :GLOBAL.ORGANIZATION_ID IS NOT NULL THEN
    v_where_clause := v_where_clause ||
      ' AND organization_id = ' || :GLOBAL.ORGANIZATION_ID;
  END IF;

  -- 採購單號條件
  IF :SEARCH_BLOCK.PURCHASE_NO IS NOT NULL THEN
    v_where_clause := v_where_clause ||
      ' AND purchase_no LIKE ''' || :SEARCH_BLOCK.PURCHASE_NO || '%''';
  END IF;

  -- 日期區間條件
  IF :SEARCH_BLOCK.DATE_FROM IS NOT NULL THEN
    v_where_clause := v_where_clause ||
      ' AND purchase_date >= TO_DATE(''' ||
      TO_CHAR(:SEARCH_BLOCK.DATE_FROM, 'YYYY/MM/DD') ||
      ''', ''YYYY/MM/DD'')';
  END IF;

  IF :SEARCH_BLOCK.DATE_TO IS NOT NULL THEN
    v_where_clause := v_where_clause ||
      ' AND purchase_date <= TO_DATE(''' ||
      TO_CHAR(:SEARCH_BLOCK.DATE_TO, 'YYYY/MM/DD') ||
      ''', ''YYYY/MM/DD'')';
  END IF;

  -- 狀態條件
  IF :SEARCH_BLOCK.STATUS IS NOT NULL THEN
    v_where_clause := v_where_clause ||
      ' AND purchase_head_status = ''' || :SEARCH_BLOCK.STATUS || '''';
  END IF;

  SET_BLOCK_PROPERTY('PURCHASE_HEAD', DEFAULT_WHERE, v_where_clause);

EXCEPTION
  WHEN OTHERS THEN
    MESSAGE('查詢條件設定錯誤: ' || SQLERRM);
    RAISE FORM_TRIGGER_FAILURE;
END;
```

#### POST-QUERY

```plsql
PROCEDURE post_query IS
  v_vendor_name VARCHAR2(200);
  v_department_name VARCHAR2(200);
  v_status_name VARCHAR2(100);
BEGIN
  -- 取得廠商名稱
  BEGIN
    SELECT vendor_name
      INTO v_vendor_name
      FROM cmm_vendor_v
     WHERE vendor_id = :PURCHASE_HEAD.VENDOR_ID
       AND language_id = :GLOBAL.LANGUAGE_ID;
    :PURCHASE_HEAD.VENDOR_NAME := v_vendor_name;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      :PURCHASE_HEAD.VENDOR_NAME := NULL;
  END;

  -- 取得部門名稱
  BEGIN
    SELECT department_name
      INTO v_department_name
      FROM cmm_department_v
     WHERE department_id = :PURCHASE_HEAD.DEPARTMENT_ID
       AND language_id = :GLOBAL.LANGUAGE_ID;
    :PURCHASE_HEAD.DEPARTMENT_NAME := v_department_name;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      :PURCHASE_HEAD.DEPARTMENT_NAME := NULL;
  END;

  -- 取得狀態名稱
  :PURCHASE_HEAD.STATUS_NAME :=
    ufm_fnd.get_code_name('PURCHASE_STATUS',
                          :PURCHASE_HEAD.PURCHASE_HEAD_STATUS);

  -- 計算總金額
  :PURCHASE_HEAD.TOTAL_AMOUNT :=
    prm_purchase_api.calculate_total_amount(:PURCHASE_HEAD.PURCHASE_HEAD_ID);

EXCEPTION
  WHEN OTHERS THEN
    MESSAGE('POST-QUERY 錯誤: ' || SQLERRM);
END;
```

#### WHEN-VALIDATE-RECORD

```plsql
PROCEDURE when_validate_record IS
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

  IF :PURCHASE_HEAD.DEPARTMENT_ID IS NULL THEN
    MESSAGE('請選擇請購部門！');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;

  -- 日期合理性檢查
  IF :PURCHASE_HEAD.PURCHASE_DATE > SYSDATE THEN
    MESSAGE('採購日期不可大於今日！');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;

  -- 狀態檢查
  IF :PURCHASE_HEAD.PURCHASE_HEAD_STATUS NOT IN ('00', '10', '95', '99') THEN
    MESSAGE('採購單狀態代碼錯誤！');
    RAISE FORM_TRIGGER_FAILURE;
  END IF;

END;
```

### Item-Level Triggers

#### WHEN-VALIDATE-ITEM

```plsql
-- 採購數量驗證
PROCEDURE when_validate_item IS
BEGIN
  IF :PURCHASE_DETAIL.PURCHASE_QTY IS NOT NULL THEN
    IF :PURCHASE_DETAIL.PURCHASE_QTY <= 0 THEN
      MESSAGE('採購數量必須大於 0！');
      RAISE FORM_TRIGGER_FAILURE;
    END IF;

    -- 計算小計
    IF :PURCHASE_DETAIL.UNIT_PRICE IS NOT NULL THEN
      :PURCHASE_DETAIL.AMOUNT :=
        :PURCHASE_DETAIL.PURCHASE_QTY * :PURCHASE_DETAIL.UNIT_PRICE;
    END IF;
  END IF;
END;
```

#### WHEN-LIST-CHANGED

```plsql
-- 下拉選單變更處理
PROCEDURE when_list_changed IS
  v_warehouse_name VARCHAR2(200);
BEGIN
  IF :PURCHASE_DETAIL.WAREHOUSE_ID IS NOT NULL THEN
    -- 取得倉庫名稱
    SELECT warehouse_name
      INTO v_warehouse_name
      FROM ivm_warehouse_v
     WHERE warehouse_id = :PURCHASE_DETAIL.WAREHOUSE_ID
       AND language_id = :GLOBAL.LANGUAGE_ID;

    :PURCHASE_DETAIL.WAREHOUSE_NAME := v_warehouse_name;
  END IF;

EXCEPTION
  WHEN NO_DATA_FOUND THEN
    :PURCHASE_DETAIL.WAREHOUSE_NAME := NULL;
  WHEN OTHERS THEN
    MESSAGE('取得倉庫資料錯誤: ' || SQLERRM);
END;
```

---

## 錯誤處理機制

### 標準錯誤處理模板

```plsql
PROCEDURE standard_error_handler(
  p_procedure_name IN VARCHAR2,
  p_error_location IN VARCHAR2 DEFAULT NULL
) IS
  v_error_code NUMBER := SQLCODE;
  v_error_msg VARCHAR2(4000) := SQLERRM;
  v_error_stack VARCHAR2(4000) := DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
  v_full_message VARCHAR2(4000);
BEGIN
  -- 組合完整錯誤訊息
  v_full_message := '程序: ' || p_procedure_name;

  IF p_error_location IS NOT NULL THEN
    v_full_message := v_full_message || CHR(10) ||
                      '位置: ' || p_error_location;
  END IF;

  v_full_message := v_full_message || CHR(10) ||
                    '錯誤代碼: ' || v_error_code || CHR(10) ||
                    '錯誤訊息: ' || v_error_msg || CHR(10) ||
                    '錯誤堆疊: ' || v_error_stack;

  -- 記錄到資料庫
  INSERT INTO system_error_log (
    procedure_name, error_code, error_message,
    error_stack, error_date, user_id
  ) VALUES (
    p_procedure_name, v_error_code, v_error_msg,
    v_error_stack, SYSDATE, USER
  );
  COMMIT;

  -- 顯示訊息
  DBMS_OUTPUT.PUT_LINE(v_full_message);

EXCEPTION
  WHEN OTHERS THEN
    NULL; -- 避免錯誤處理本身發生錯誤
END standard_error_handler;
```

### Forms ON-ERROR Trigger

```plsql
PROCEDURE on_error IS
  v_error_code NUMBER := ERROR_CODE;
  v_error_text VARCHAR2(200) := ERROR_TEXT;
  v_error_type VARCHAR2(10) := ERROR_TYPE;
  v_custom_msg VARCHAR2(500);
BEGIN
  -- Oracle Forms 標準錯誤代碼對照
  CASE v_error_code
    WHEN 40202 THEN
      v_custom_msg := '此欄位為必填欄位，請輸入資料！';
    WHEN 40508 THEN
      v_custom_msg := '無法更新記錄，記錄可能已被其他使用者修改！';
    WHEN 40509 THEN
      v_custom_msg := '無法刪除記錄，此記錄可能有相關的明細資料！';
    WHEN 40735 THEN
      v_custom_msg := '請先儲存主檔資料，才能新增明細資料！';
    WHEN 41003 THEN
      v_custom_msg := '查詢未返回任何記錄！';
    WHEN 41026 THEN
      v_custom_msg := '此欄位不允許輸入重複值！';
    ELSE
      v_custom_msg := '系統錯誤 (' || v_error_code || '): ' || v_error_text;
  END CASE;

  MESSAGE(v_custom_msg);
  BELL;

  -- 記錄錯誤
  BEGIN
    INSERT INTO form_error_log (
      form_name, block_name, item_name,
      error_code, error_text, error_date, user_id
    ) VALUES (
      :SYSTEM.CURRENT_FORM,
      :SYSTEM.CURSOR_BLOCK,
      :SYSTEM.CURSOR_ITEM,
      v_error_code,
      v_error_text,
      SYSDATE,
      :GLOBAL.USER_ID
    );
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

END;
```

---

## 效能優化技巧

### 1. Bulk Collect 批次處理

```plsql
PROCEDURE bulk_process_inventory IS
  TYPE t_part_id IS TABLE OF ivm_part.part_id%TYPE;
  TYPE t_stock_qty IS TABLE OF ivm_part.stock_qty%TYPE;

  v_part_ids t_part_id;
  v_stock_qtys t_stock_qty;

  c_batch_size CONSTANT PLS_INTEGER := 1000;

  CURSOR cur_parts IS
    SELECT part_id, stock_qty
      FROM ivm_part
     WHERE organization_id = 4811
       AND part_type = 'PI';

BEGIN
  OPEN cur_parts;
  LOOP
    FETCH cur_parts BULK COLLECT
      INTO v_part_ids, v_stock_qtys
      LIMIT c_batch_size;

    EXIT WHEN v_part_ids.COUNT = 0;

    -- 批次更新
    FORALL i IN 1..v_part_ids.COUNT
      UPDATE ivm_part_stock
         SET stock_qty = v_stock_qtys(i),
             tr_date = SYSDATE
       WHERE part_id = v_part_ids(i);

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('已處理 ' || v_part_ids.COUNT || ' 筆資料');

  END LOOP;
  CLOSE cur_parts;

EXCEPTION
  WHEN OTHERS THEN
    IF cur_parts%ISOPEN THEN
      CLOSE cur_parts;
    END IF;
    ROLLBACK;
    RAISE;
END bulk_process_inventory;
```

### 2. 使用 RETURNING Clause

```plsql
PROCEDURE insert_with_returning(
  p_purchase_no IN VARCHAR2,
  p_vendor_id IN NUMBER,
  p_purchase_head_id OUT NUMBER
) IS
BEGIN
  INSERT INTO prm_purchase_head (
    purchase_head_id, purchase_no, vendor_id,
    entry_date, tr_date
  ) VALUES (
    prm_purchase_head_id.NEXTVAL, p_purchase_no, p_vendor_id,
    SYSDATE, SYSDATE
  ) RETURNING purchase_head_id INTO p_purchase_head_id;

  COMMIT;
END;
```

### 3. 避免隱式轉換

```plsql
-- ❌ 不好的寫法（隱式轉換）
SELECT * FROM prm_purchase_head
 WHERE purchase_date = '2026-01-30';  -- 字串會被轉換為日期

-- ✅ 好的寫法（明確轉換）
SELECT * FROM prm_purchase_head
 WHERE purchase_date = TO_DATE('2026-01-30', 'YYYY-MM-DD');

-- ❌ 不好的寫法
SELECT * FROM prm_purchase_head
 WHERE organization_id = '4811';  -- 字串會被轉換為數字

-- ✅ 好的寫法
SELECT * FROM prm_purchase_head
 WHERE organization_id = 4811;
```

### 4. 使用 EXISTS 取代 IN

```plsql
-- ❌ 效能較差
SELECT * FROM prm_purchase_head ph
 WHERE ph.vendor_id IN (
   SELECT vendor_id FROM cmm_vendor WHERE vendor_type = 'A'
 );

-- ✅ 效能較好
SELECT * FROM prm_purchase_head ph
 WHERE EXISTS (
   SELECT 1 FROM cmm_vendor v
    WHERE v.vendor_id = ph.vendor_id
      AND v.vendor_type = 'A'
 );
```

---

## 常用程式碼範例

### 動態 SQL 執行

```plsql
PROCEDURE execute_dynamic_sql(
  p_table_name IN VARCHAR2,
  p_where_clause IN VARCHAR2,
  p_result OUT SYS_REFCURSOR
) IS
  v_sql VARCHAR2(4000);
BEGIN
  v_sql := 'SELECT * FROM ' || p_table_name;

  IF p_where_clause IS NOT NULL THEN
    v_sql := v_sql || ' WHERE ' || p_where_clause;
  END IF;

  OPEN p_result FOR v_sql;

EXCEPTION
  WHEN OTHERS THEN
    IF p_result%ISOPEN THEN
      CLOSE p_result;
    END IF;
    RAISE;
END execute_dynamic_sql;
```

### Record Group 動態建立

```plsql
PROCEDURE create_dynamic_lov(
  p_lov_name IN VARCHAR2,
  p_sql_query IN VARCHAR2
) IS
  rg_id RECORDGROUP;
  v_result NUMBER;
BEGIN
  -- 刪除舊的 Record Group
  rg_id := FIND_GROUP(p_lov_name || '_RG');
  IF NOT ID_NULL(rg_id) THEN
    DELETE_GROUP(rg_id);
  END IF;

  -- 建立新的 Record Group
  rg_id := CREATE_GROUP_FROM_QUERY(p_lov_name || '_RG', p_sql_query);

  -- 執行查詢
  v_result := POPULATE_GROUP(rg_id);

  IF v_result = 0 THEN
    MESSAGE('查無資料！');
  ELSE
    MESSAGE('已載入 ' || TO_CHAR(v_result) || ' 筆資料');
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    MESSAGE('建立 LOV 失敗: ' || SQLERRM);
    RAISE FORM_TRIGGER_FAILURE;
END create_dynamic_lov;
```

### 交易控制範例

```plsql
PROCEDURE process_with_savepoint IS
  v_savepoint_name VARCHAR2(30) := 'SP_MAIN';
BEGIN
  SAVEPOINT SP_MAIN;

  -- 第一階段處理
  UPDATE prm_purchase_head
     SET purchase_head_status = '10'
   WHERE purchase_head_status = '00';

  -- 第二階段處理
  BEGIN
    UPDATE prm_purchase_detail
       SET detail_status = '10'
     WHERE purchase_head_id IN (
       SELECT purchase_head_id FROM prm_purchase_head
        WHERE purchase_head_status = '10'
     );
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO SP_MAIN;
      RAISE;
  END;

  COMMIT;

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK TO SP_MAIN;
    RAISE;
END process_with_savepoint;
```

---

## 最佳實踐總結

### DO（應該做的）

✅ 使用有意義的變數命名
✅ 加入適當的註解說明
✅ 實作完整的錯誤處理
✅ 使用 Bulk Collect 處理大量資料
✅ 明確宣告變數型別
✅ 使用常數取代魔術數字
✅ 適當使用 COMMIT 和 ROLLBACK
✅ 記錄重要操作日誌

### DON'T（不應該做的）

❌ 不要使用 SELECT * FROM
❌ 不要在迴圈中執行 COMMIT
❌ 不要忽略例外處理
❌ 不要使用隱式游標處理多筆資料
❌ 不要在生產環境使用 DBMS_OUTPUT
❌ 不要硬編碼組織或公司代碼
❌ 不要在 Trigger 中使用 DDL 語句
❌ 不要忘記關閉 Cursor

---

**版本歷史**
- v1.0 (2026-01-30): 初始版本發布
