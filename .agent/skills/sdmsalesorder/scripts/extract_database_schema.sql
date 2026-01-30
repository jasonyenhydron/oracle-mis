-- ========================================
-- SDM 資料庫結構抓取腳本
-- 執行環境: Oracle SQL Developer
-- 用途: 抓取 SDM 相關表的結構資訊
-- ========================================

-- 設定輸出格式
   SET LINESIZE 200
SET PAGESIZE 1000
SET LONG 10000

-- ========================================
-- 1. 查詢所有 SDM_SO_ 開頭的表
-- ========================================
pro    ========================================
pro    1. SDM 相關表列表
pro    ========================================

select table_name,
       num_rows,
       last_analyzed,
       tablespace_name
  from user_tables
 where table_name like 'SDM_SO_%'
    or table_name like 'SDM_SHIP_%'
    or table_name like 'CMM_CUSTOMER%'
 order by table_name;

-- ========================================
-- 2. 查詢表的欄位資訊
-- ========================================
pro   
pro    ========================================
pro    2. 表欄位詳細資訊
pro    ========================================

select t.table_name,
       t.column_name,
       t.data_type,
       t.data_length,
       t.data_precision,
       t.data_scale,
       t.nullable,
       t.data_default,
       c.comments
  from user_tab_columns t
  left join user_col_comments c
on t.table_name = c.table_name
   and t.column_name = c.column_name
 where t.table_name like 'SDM_SO_%'
    or t.table_name like 'SDM_SHIP_%'
    or t.table_name like 'CMM_CUSTOMER%'
 order by t.table_name,
          t.column_id;

-- ========================================
-- 3. 查詢主鍵資訊
-- ========================================
pro   
pro    ========================================
pro    3. 主鍵資訊
pro    ========================================

select c.table_name,
       c.constraint_name,
       c.constraint_type,
       cc.column_name,
       cc.position
  from user_constraints c
  join user_cons_columns cc
on c.constraint_name = cc.constraint_name
 where c.constraint_type = 'P'
   and ( c.table_name like 'SDM_SO_%'
    or c.table_name like 'SDM_SHIP_%'
    or c.table_name like 'CMM_CUSTOMER%' )
 order by c.table_name,
          cc.position;

-- ========================================
-- 4. 查詢外鍵資訊
-- ========================================
pro   
pro    ========================================
pro    4. 外鍵資訊
pro    ========================================

select c.table_name,
       c.constraint_name,
       cc.column_name,
       r.table_name as referenced_table,
       rc.column_name as referenced_column
  from user_constraints c
  join user_cons_columns cc
on c.constraint_name = cc.constraint_name
  join user_constraints r
on c.r_constraint_name = r.constraint_name
  join user_cons_columns rc
on r.constraint_name = rc.constraint_name
 where c.constraint_type = 'R'
   and ( c.table_name like 'SDM_SO_%'
    or c.table_name like 'SDM_SHIP_%'
    or c.table_name like 'CMM_CUSTOMER%' )
 order by c.table_name,
          cc.position;

-- ========================================
-- 5. 查詢索引資訊
-- ========================================
pro   
pro    ========================================
pro    5. 索引資訊
pro    ========================================

select i.table_name,
       i.index_name,
       i.index_type,
       i.uniqueness,
       ic.column_name,
       ic.column_position
  from user_indexes i
  join user_ind_columns ic
on i.index_name = ic.index_name
 where i.table_name like 'SDM_SO_%'
    or i.table_name like 'SDM_SHIP_%'
    or i.table_name like 'CMM_CUSTOMER%'
 order by i.table_name,
          i.index_name,
          ic.column_position;

-- ========================================
-- 6. 查詢存儲過程列表
-- ========================================
pro   
pro    ========================================
pro    6. 存儲過程列表
pro    ========================================

select object_name,
       object_type,
       status,
       created,
       last_ddl_time
  from user_objects
 where object_type in ( 'PROCEDURE',
                        'FUNCTION',
                        'PACKAGE' )
   and ( object_name like '%SDM%'
    or object_name like '%SALE%'
    or object_name like '%ORDER%'
    or object_name like '%CART%' )
 order by object_type,
          object_name;

-- ========================================
-- 7. 查詢存儲過程參數
-- ========================================
pro   
pro    ========================================
pro    7. 存儲過程參數
pro    ========================================

select object_name,
       argument_name,
       position,
       data_type,
       in_out,
       data_length,
       data_precision,
       data_scale
  from user_arguments
 where object_name like '%SDM%'
    or object_name like '%SALE%'
    or object_name like '%ORDER%'
    or object_name like '%CART%'
 order by object_name,
          position;

-- ========================================
-- 8. 查詢視圖資訊
-- ========================================
pro   
pro    ========================================
pro    8. 視圖資訊
pro    ========================================

select view_name,
       text_length,
       text
  from user_views
 where view_name like '%SDM%'
    or view_name like '%CUSTOMER%'
    or view_name like '%ORDER%'
 order by view_name;

-- ========================================
-- 9. 查詢觸發器資訊
-- ========================================
pro   
pro    ========================================
pro    9. 觸發器資訊
pro    ========================================

select trigger_name,
       trigger_type,
       triggering_event,
       table_name,
       status,
       trigger_body
  from user_triggers
 where table_name like 'SDM_SO_%'
    or table_name like 'SDM_SHIP_%'
 order by table_name,
          trigger_name;

-- ========================================
-- 10. 查詢序列資訊
-- ========================================
pro   
pro    ========================================
pro    10. 序列資訊
pro    ========================================

select sequence_name,
       min_value,
       max_value,
       increment_by,
       last_number,
       cache_size,
       cycle_flag
  from user_sequences
 where sequence_name like '%SDM%'
    or sequence_name like '%SO_%'
 order by sequence_name;

-- ========================================
-- 11. 查詢表註解
-- ========================================
pro   
pro    ========================================
pro    11. 表註解
pro    ========================================

select table_name,
       table_type,
       comments
  from user_tab_comments
 where table_name like 'SDM_SO_%'
    or table_name like 'SDM_SHIP_%'
    or table_name like 'CMM_CUSTOMER%'
 order by table_name;

-- ========================================
-- 12. 查詢資料筆數統計
-- ========================================
pro   
pro    ========================================
pro    12. 資料筆數統計
pro    ========================================

select 'SDM_SO_MEMBER' as table_name,
       count(*) as row_count
  from sdm_so_member
union all
select 'SDM_SO_SHOPPING_CART',
       count(*)
  from sdm_so_shopping_cart
union all
select 'SDM_SHIP_ANNOUNCE',
       count(*)
  from sdm_ship_announce
union all
select 'SDM_SO_FUNC_W',
       count(*)
  from sdm_so_func_w;

-- ========================================
-- 13. 查詢會員狀態分布
-- ========================================
pro   
pro    ========================================
pro    13. 會員狀態分布
pro    ========================================

select so_member_status,
       count(*) as count
  from sdm_so_member
 group by so_member_status
 order by so_member_status;

-- ========================================
-- 14. 查詢購物車統計
-- ========================================
pro   
pro    ========================================
pro    14. 購物車統計
pro    ========================================

select count(distinct so_member_id) as member_count,
       count(*) as cart_item_count,
       sum(qty) as total_qty
  from sdm_so_shopping_cart;

pro   
pro    ========================================
pro    腳本執行完成
pro    ========================================