# PL/SQL 註解語法完整指南

## 📝 基本註解類型

### 1. 單行註解 (Single-Line Comments)

使用 `--` 開頭，從 `--` 開始到該行結束都是註解。

```sql
-- 這是單行註解
SELECT * FROM employees;  -- 查詢所有員工資料

DECLARE
  v_count NUMBER;  -- 計數器變數
BEGIN
  -- 執行查詢
  SELECT COUNT(*) INTO v_count FROM employees;
END;
```

### 2. 多行註解 (Multi-Line Comments)

使用 `/* ... */` 包圍，可以跨越多行。

```sql
/*
  這是多行註解
  可以寫很多行
  用於詳細說明
*/
SELECT * FROM employees;

/* 單行的多行註解也可以 */
SELECT * FROM departments;

DECLARE
  v_salary NUMBER;
BEGIN
  /*
    計算平均薪資
    並儲存到變數中
  */
  SELECT AVG(salary) INTO v_salary FROM employees;
END;
```

### 3. 文件註解 (Documentation Comments)

使用 `/** ... */` 格式，通常用於 Package、Procedure、Function 的說明文件。

```sql
/**
 * Package: employee_pkg
 * 功能: 員工管理相關功能
 * 作者: Jason Yen
 * 日期: 2026-01-26
 * 版本: 1.0
 */
CREATE OR REPLACE PACKAGE employee_pkg AS
  /**
   * 取得員工姓名
   * @param p_employee_id 員工ID
   * @return 員工姓名
   */
  FUNCTION get_employee_name(p_employee_id IN NUMBER) RETURN VARCHAR2;
END employee_pkg;
```

---

## 🎯 資料庫物件註解 (COMMENT 語法)

### 1. 表格註解 (Table Comments)

```sql
-- 基本語法
COMMENT ON TABLE table_name IS 'table_description';

-- 範例
COMMENT ON TABLE prm_purchase_head IS '採購單主檔';
COMMENT ON TABLE ivm_part IS '料件主檔';
COMMENT ON TABLE cmm_vendor IS '廠商主檔';
```

### 2. 欄位註解 (Column Comments)

```sql
-- 基本語法
COMMENT ON COLUMN table_name.column_name IS 'column_description';

-- 範例
COMMENT ON COLUMN prm_purchase_head.purchase_head_id IS '採購單主檔ID';
COMMENT ON COLUMN prm_purchase_head.purchase_no IS '採購單號';
COMMENT ON COLUMN prm_purchase_head.vendor_id IS '廠商ID';
COMMENT ON COLUMN prm_purchase_head.purchase_date IS '採購日期';
COMMENT ON COLUMN prm_purchase_head.purchase_head_status IS '採購單狀態(00:建立, 95:核准, 99:作廢)';
```

### 3. 視圖註解 (View Comments)

```sql
-- 表格註解
COMMENT ON TABLE view_name IS 'view_description';

-- 欄位註解
COMMENT ON COLUMN view_name.column_name IS 'column_description';

-- 範例
COMMENT ON TABLE prm_purchase_head_v IS '採購單主檔視圖';
COMMENT ON COLUMN prm_purchase_head_v.vendor_name IS '廠商名稱';
```

### 4. 序列註解 (Sequence Comments)

```sql
-- Oracle 12c 以後支援
COMMENT ON SEQUENCE sequence_name IS 'sequence_description';

-- 範例
COMMENT ON SEQUENCE prm_purchase_head_id IS '採購單主檔序號';
```

### 5. 索引註解 (Index Comments)

```sql
-- Oracle 12c 以後支援
COMMENT ON INDEX index_name IS 'index_description';

-- 範例
COMMENT ON INDEX prm_purchase_head_idx1 IS '採購單號索引';
```

---

## 📚 PL/SQL 程式碼註解最佳實踐

### 1. Package Specification 註解

```sql
/**
 * =====================================================================
 * Package Name: moci_dssrm_etl
 * Description: DSSRM 系統資料交換 ETL 處理
 * Author: Jason Yen
 * Created Date: 2026-01-26
 * Version: 1.0
 * =====================================================================
 * Modification History:
 * Date         Author      Version    Description
 * ----------   ----------  ---------  ---------------------------------
 * 2026-01-26   Jason Yen   1.0        初版建立
 * =====================================================================
 */
CREATE OR REPLACE PACKAGE moci_dssrm_etl IS

  /**
   * 執行所有交換資料
   *
   * @param i_system_no        系統代號
   * @param i_transfer_table   傳輸表格名稱 (可選)
   *
   * @exception NO_DATA_FOUND  查無資料
   * @exception OTHERS         其他錯誤
   *
   * @example
   *   BEGIN
   *     moci_dssrm_etl.transfer_all('DSSRM');
   *   END;
   */
  PROCEDURE transfer_all(
    i_system_no IN VARCHAR2,
    i_transfer_table IN VARCHAR2 DEFAULT NULL
  );

  /**
   * 取得預設倉別
   *
   * @param i_purchase_detail_id  採購明細ID
   * @return VARCHAR2             倉別代號
   *
   * @description
   *   根據採購明細的部門決定預設倉別
   *   - NUF08 部門 -> 3900 (液品製造部)
   *   - 其他部門   -> 1900 (預設倉別)
   */
  FUNCTION f_get_default_warehouse(
    i_purchase_detail_id IN NUMBER
  ) RETURN VARCHAR2;

END moci_dssrm_etl;
/
```

### 2. Package Body 註解

```sql
CREATE OR REPLACE PACKAGE BODY moci_dssrm_etl IS

  -- ===================================================================
  -- 私有常數定義
  -- ===================================================================
  c_default_warehouse CONSTANT VARCHAR2(10) := '1900';  -- 預設倉別
  c_liquid_warehouse  CONSTANT VARCHAR2(10) := '3900';  -- 液品倉別

  -- ===================================================================
  -- 私有變數定義
  -- ===================================================================
  g_debug_mode BOOLEAN := FALSE;  -- 除錯模式

  -- ===================================================================
  -- 私有程序：寫入交易控制資訊
  -- ===================================================================
  PROCEDURE in_trans_control(
    i_system_no IN VARCHAR2 DEFAULT NULL,
    i_transfer_table IN VARCHAR2 DEFAULT NULL,
    i_task_id IN VARCHAR2 DEFAULT NULL,
    i_transaction_date IN DATE DEFAULT SYSDATE,
    i_rowcount IN NUMBER DEFAULT 0,
    i_error_msg IN VARCHAR2 DEFAULT NULL,
    i_flag IN VARCHAR2 DEFAULT NULL
  ) IS
    v_para_value VARCHAR2(4000);
    v_flag VARCHAR2(100) := i_flag;
  BEGIN
    -- 組合參數資訊
    v_para_value := 'TRANSACTION_DATE=' || TO_CHAR(i_transaction_date, 'YYYY-MM-DD HH24:MI:SS')
                 || '; ROWCOUNT=' || TO_CHAR(i_rowcount);

    -- 寫入 LOG
    INSERT INTO moci_ds_exe_log(
      function_name, flag, para_name, para_value,
      err_message, tr_id, tr_date
    ) VALUES (
      i_task_id, v_flag, i_system_no, v_para_value,
      i_error_msg, USER, SYSDATE
    );

    COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('❌ 錯誤訊息: ' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE('❌ 錯誤行號: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
      ROLLBACK;
  END in_trans_control;

  -- ===================================================================
  -- 公開程序：執行所有交換資料
  -- ===================================================================
  PROCEDURE transfer_all(
    i_system_no IN VARCHAR2,
    i_transfer_table IN VARCHAR2 DEFAULT NULL
  ) AS
    -- 變數宣告
    n_minute NUMBER := TO_NUMBER(TO_CHAR(SYSDATE, 'MI'));
    n_hour NUMBER := TO_NUMBER(TO_CHAR(SYSDATE, 'HH24'));
    v_sql VARCHAR2(4000);

    -- Cursor 定義
    CURSOR cur_data IS
      SELECT system_no, transfer_table, procedure_name,
             byhour, NVL(byminute, 0) AS byminute
        FROM moci_ds_ctrl_table
       WHERE ds_ctrl_table_status = '00'
         AND (i_system_no IS NULL OR system_no = i_system_no)
       ORDER BY byhour, byminute;

    row_data cur_data%ROWTYPE;

  BEGIN
    /*
     * ===============================================================
     * 主要處理流程
     * ===============================================================
     */

    -- Step 1: 開啟 Cursor
    OPEN cur_data;

    -- Step 2: 迴圈處理每筆資料
    LOOP
      FETCH cur_data INTO row_data;
      EXIT WHEN cur_data%NOTFOUND;

      -- 檢查執行時間
      IF INSTR(',' || row_data.byhour || ',', ',' || n_hour || ',') > 0 THEN
        -- 執行動態 SQL
        v_sql := 'BEGIN ' || row_data.procedure_name ||
                 '(i_system_no => :1); END;';
        EXECUTE IMMEDIATE v_sql USING IN row_data.system_no;
      END IF;
    END LOOP;

    -- Step 3: 關閉 Cursor
    CLOSE cur_data;

  EXCEPTION
    WHEN OTHERS THEN
      -- 確保 Cursor 關閉
      IF cur_data%ISOPEN THEN
        CLOSE cur_data;
      END IF;

      -- 記錄錯誤
      DBMS_OUTPUT.PUT_LINE('❌ 錯誤: ' || SQLERRM);
      RAISE;
  END transfer_all;

  -- ===================================================================
  -- 公開函數：取得預設倉別
  -- ===================================================================
  FUNCTION f_get_default_warehouse(
    i_purchase_detail_id IN NUMBER
  ) RETURN VARCHAR2 IS
    v_department_no cmm_department.department_no%TYPE;
    v_warehouse_no ivm_warehouse.warehouse_no%TYPE;
  BEGIN
    -- [Step 1] 取得部門代號
    SELECT d.department_no
      INTO v_department_no
      FROM prm_purchase_detail pd,
           prm_purchase_head ph,
           cmm_department d
     WHERE pd.purchase_detail_id = i_purchase_detail_id
       AND ph.purchase_head_id = pd.purchase_head_id
       AND d.department_id = ph.department_id;

    -- [Step 2] 決定預設倉別
    IF v_department_no = 'NUF08' THEN
      v_warehouse_no := c_liquid_warehouse;  -- 液品製造部
    ELSE
      v_warehouse_no := c_default_warehouse; -- 其他部門
    END IF;

    RETURN v_warehouse_no;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- 查無資料時返回預設倉別
      RETURN c_default_warehouse;
    WHEN OTHERS THEN
      -- 發生錯誤時記錄並返回預設倉別
      DBMS_OUTPUT.PUT_LINE('❌ 錯誤函數: f_get_default_warehouse');
      DBMS_OUTPUT.PUT_LINE('❌ 錯誤訊息: ' || SQLERRM);
      RETURN c_default_warehouse;
  END f_get_default_warehouse;

END moci_dssrm_etl;
/
```

### 3. Procedure 註解範例

```sql
/**
 * =====================================================================
 * Procedure: process_purchase_order
 * Description: 處理採購單審核流程
 * =====================================================================
 * Parameters:
 *   IN:
 *     i_purchase_head_id   NUMBER      採購單主檔ID
 *     i_approve_status     VARCHAR2    審核狀態 (Y:核准, N:拒絕, R:退回)
 *     i_approve_comment    VARCHAR2    審核意見 (可選)
 *   OUT:
 *     o_error_message      VARCHAR2    錯誤訊息
 * =====================================================================
 * Return: 無
 * =====================================================================
 * Exception:
 *   NO_DATA_FOUND    查無採購單資料
 *   INVALID_STATUS   無效的審核狀態
 *   OTHERS           其他未預期錯誤
 * =====================================================================
 * Example:
 *   DECLARE
 *     v_error_msg VARCHAR2(4000);
 *   BEGIN
 *     process_purchase_order(
 *       i_purchase_head_id => 12345,
 *       i_approve_status => 'Y',
 *       i_approve_comment => '核准通過',
 *       o_error_message => v_error_msg
 *     );
 *   END;
 * =====================================================================
 * Modification History:
 *   Date         Author      Version    Description
 *   ----------   ----------  ---------  ------------------------------
 *   2026-01-26   Jason Yen   1.0        初版建立
 *   2026-02-01   李四        1.1        新增審核意見欄位
 * =====================================================================
 */
PROCEDURE process_purchase_order(
  i_purchase_head_id IN NUMBER,
  i_approve_status IN VARCHAR2,
  i_approve_comment IN VARCHAR2 DEFAULT NULL,
  o_error_message OUT VARCHAR2
) AS
  -- 變數宣告
  v_current_status VARCHAR2(2);
  v_purchase_no VARCHAR2(30);

BEGIN
  /*
   * ================================================================
   * 主要處理流程
   * ================================================================
   */

  -- [Step 1] 驗證輸入參數
  IF i_purchase_head_id IS NULL THEN
    o_error_message := '採購單ID不可為空';
    RETURN;
  END IF;

  IF i_approve_status NOT IN ('Y', 'N', 'R') THEN
    o_error_message := '無效的審核狀態';
    RETURN;
  END IF;

  -- [Step 2] 查詢採購單資料
  BEGIN
    SELECT purchase_head_status, purchase_no
      INTO v_current_status, v_purchase_no
      FROM prm_purchase_head
     WHERE purchase_head_id = i_purchase_head_id;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      o_error_message := '查無採購單資料';
      RETURN;
  END;

  -- [Step 3] 檢查狀態是否可審核
  IF v_current_status NOT IN ('00', '10') THEN
    o_error_message := '採購單狀態不可審核';
    RETURN;
  END IF;

  -- [Step 4] 更新審核狀態
  UPDATE prm_purchase_head
     SET purchase_head_status = CASE i_approve_status
                                  WHEN 'Y' THEN '95'  -- 核准
                                  WHEN 'N' THEN '99'  -- 拒絕
                                  WHEN 'R' THEN '10'  -- 退回
                                END,
         approve_comment = i_approve_comment,
         approve_date = SYSDATE,
         approve_id = USER,
         tr_id = USER,
         tr_date = SYSDATE
   WHERE purchase_head_id = i_purchase_head_id;

  -- [Step 5] 記錄審核歷程
  INSERT INTO prm_purchase_approve_log(
    purchase_head_id, approve_status, approve_comment,
    approve_id, approve_date
  ) VALUES (
    i_purchase_head_id, i_approve_status, i_approve_comment,
    USER, SYSDATE
  );

  COMMIT;

  -- 成功訊息
  DBMS_OUTPUT.PUT_LINE('✅ 採購單 ' || v_purchase_no || ' 審核完成');

EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    o_error_message := '處理失敗: ' || SQLERRM;
    DBMS_OUTPUT.PUT_LINE('❌ 錯誤訊息: ' || SQLERRM);
    DBMS_OUTPUT.PUT_LINE('❌ 錯誤行號: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
END process_purchase_order;
```

---

## 🎨 註解風格建議

### 1. 區塊分隔線

```sql
-- =====================================================================
-- 主要區塊標題
-- =====================================================================

-- ===================================================================
-- 次要區塊標題
-- ===================================================================

-- -----------------------------------------------------------------
-- 小區塊標題
-- -----------------------------------------------------------------

/*
 * ================================================================
 * 多行註解區塊標題
 * ================================================================
 */
```

### 2. TODO / FIXME / NOTE 標記

```sql
-- TODO: 需要實作的功能
-- FIXME: 需要修正的錯誤
-- NOTE: 重要提醒
-- HACK: 暫時性的解決方案
-- OPTIMIZE: 需要優化的程式碼
-- DEPRECATED: 已棄用的功能

-- 範例
PROCEDURE old_function IS
BEGIN
  -- DEPRECATED: 此函數已棄用，請使用 new_function
  -- TODO: 2026-03-01 移除此函數
  NULL;
END;
```

### 3. 程式碼區塊註解

```sql
BEGIN
  /*
   * ================================================================
   * 區塊 1: 資料驗證
   * ================================================================
   */
  IF i_value IS NULL THEN
    RAISE_APPLICATION_ERROR(-20001, '參數不可為空');
  END IF;

  /*
   * ================================================================
   * 區塊 2: 資料處理
   * ================================================================
   */
  FOR rec IN cur_data LOOP
    -- 處理每筆資料
    process_record(rec);
  END LOOP;

  /*
   * ================================================================
   * 區塊 3: 結果輸出
   * ================================================================
   */
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('處理完成');
END;
```

---

## 📊 查詢註解資訊

### 1. 查詢表格註解

```sql
-- 查詢單一表格註解
SELECT comments
  FROM user_tab_comments
 WHERE table_name = 'PRM_PURCHASE_HEAD';

-- 查詢所有表格註解
SELECT table_name, comments
  FROM user_tab_comments
 WHERE comments IS NOT NULL
 ORDER BY table_name;
```

### 2. 查詢欄位註解

```sql
-- 查詢單一表格的所有欄位註解
SELECT column_name, comments
  FROM user_col_comments
 WHERE table_name = 'PRM_PURCHASE_HEAD'
 ORDER BY column_id;

-- 查詢特定欄位註解
SELECT comments
  FROM user_col_comments
 WHERE table_name = 'PRM_PURCHASE_HEAD'
   AND column_name = 'PURCHASE_NO';
```

### 3. 產生完整的 COMMENT 語法

```sql
-- 產生表格 COMMENT 語法
SELECT 'COMMENT ON TABLE ' || table_name || ' IS ''' || comments || ''';'
  FROM user_tab_comments
 WHERE table_name = 'PRM_PURCHASE_HEAD';

-- 產生欄位 COMMENT 語法
SELECT 'COMMENT ON COLUMN ' || table_name || '.' || column_name ||
       ' IS ''' || comments || ''';'
  FROM user_col_comments
 WHERE table_name = 'PRM_PURCHASE_HEAD'
   AND comments IS NOT NULL
 ORDER BY column_id;
```

---

## ⚠️ 注意事項

1. **註解長度限制**
   - 表格/欄位註解最長 4000 字元
   - 建議保持簡潔明瞭

2. **特殊字元處理**
   ```sql
   -- 單引號需要用兩個單引號表示
   COMMENT ON COLUMN table_name.column_name IS '這是''單引號''範例';
   ```

3. **註解的維護**
   - 程式碼修改時，記得同步更新註解
   - 定期檢查註解的正確性

4. **多語系註解**
   - 建議使用繁體中文或英文
   - 保持一致的語言風格

---

## 📚 參考範例

完整的表格建立範例（含註解）：

```sql
-- =====================================================================
-- 表格: prm_purchase_head
-- 說明: 採購單主檔
-- 建立日期: 2026-01-26
-- =====================================================================

-- 建立序列
DROP SEQUENCE prm_purchase_head_id;
CREATE SEQUENCE prm_purchase_head_id START WITH 1 INCREMENT BY 1;
CREATE PUBLIC SYNONYM prm_purchase_head_id FOR prm_purchase_head_id;
GRANT ALL ON prm_purchase_head_id TO PUBLIC;

-- 建立表格
DROP TABLE prm_purchase_head;
CREATE TABLE prm_purchase_head(
  purchase_head_id NUMBER,              -- 採購單主檔ID
  organization_id NUMBER NOT NULL,      -- 組織ID
  company_id NUMBER,                    -- 公司ID
  purchase_no VARCHAR2(30) NOT NULL,    -- 採購單號
  purchase_date DATE NOT NULL,          -- 採購日期
  vendor_id NUMBER NOT NULL,            -- 廠商ID
  purchase_head_status VARCHAR2(2) DEFAULT '00',  -- 狀態
  entry_id VARCHAR2(30) DEFAULT USER,   -- 建立人員
  entry_date DATE DEFAULT SYSDATE,      -- 建立日期
  tr_id VARCHAR2(30) DEFAULT USER,      -- 異動人員
  tr_date DATE DEFAULT SYSDATE,         -- 異動日期
  CONSTRAINT prm_purchase_head_pk PRIMARY KEY (purchase_head_id)
);

-- 建立索引
CREATE INDEX prm_purchase_head_idx1 ON prm_purchase_head(organization_id, purchase_no);
CREATE INDEX prm_purchase_head_idx2 ON prm_purchase_head(vendor_id);

-- 建立註解
COMMENT ON TABLE prm_purchase_head IS '採購單主檔';
COMMENT ON COLUMN prm_purchase_head.purchase_head_id IS '採購單主檔ID';
COMMENT ON COLUMN prm_purchase_head.organization_id IS '組織ID';
COMMENT ON COLUMN prm_purchase_head.company_id IS '公司ID';
COMMENT ON COLUMN prm_purchase_head.purchase_no IS '採購單號';
COMMENT ON COLUMN prm_purchase_head.purchase_date IS '採購日期';
COMMENT ON COLUMN prm_purchase_head.vendor_id IS '廠商ID';
COMMENT ON COLUMN prm_purchase_head.purchase_head_status IS '採購單狀態(00:建立, 95:核准, 99:作廢)';
COMMENT ON COLUMN prm_purchase_head.entry_id IS '建立人員';
COMMENT ON COLUMN prm_purchase_head.entry_date IS '建立日期';
COMMENT ON COLUMN prm_purchase_head.tr_id IS '異動人員';
COMMENT ON COLUMN prm_purchase_head.tr_date IS '異動日期';

-- 建立 Synonym
DROP PUBLIC SYNONYM prm_purchase_head;
CREATE PUBLIC SYNONYM prm_purchase_head FOR prm_purchase_head;
GRANT ALL ON prm_purchase_head TO PUBLIC;

-- 分析表格
ANALYZE TABLE prm_purchase_head COMPUTE STATISTICS;
```

---

**文件版本:** 1.0
**建立日期:** 2026-01-26
**最後更新:** 2026-01-26
