------ latest as of 12.20.24 
------ this is to be used for the biomed specialist report, OEM revenue, and OEM fees predictive model 
create or replace view prd_sbx_mms_db.OPS.BIOMED_SALES_QUERY AS (
WITH 
BIOMED_REP AS -- PRIMARY CARE BIOMED SPECIALIST AND EXTENDED CARE BIOMED SPECIALIST
        (SELECT DISTINCT
          C.BILL_TO_CUST_NUM,
          A.ACCT_MGR_EMPLY_ID,
          A.ACCT_MGR_NAME
        FROM "PRD_PL_MMS_DATALAKE_DB"."MMSDM910"."SRC_E1_MMS_F42140" M                  -- MULTI REP SOURCE
        INNER JOIN "PRD_PL_MMS_EDW_DB"."EDWRPT"."V_DIM_CUST_E1_CURR" C               -- Link by Ship To at E1 source
              ON C.CUST_E1_NUM = M.CMAN8
        INNER JOIN "PRD_PL_MMS_EDW_DB"."EDWRPT"."V_DIM_ACCT_MGR_CURR" A              -- Link by E1 Territory number 
              ON M.CMSLSM = A.ACCT_MGR_TERR_E1_NUM
        WHERE
          A.ACCT_MGR_TYPE_CD IN ('EBO','PBO')
          AND C.BILL_TO_CUST_NUM = C.CUST_E1_NUM
          AND M.CMSTMEDT > CURRENT_DATE)
, cus as (SELECT DISTINCT
                    CB.DIM_CUST_CURR_ID, 
                    CB.CUST_E1_NUM,
                    CB.CUST_NAME, cb.mstr_grp_name,
                    CB.BIOMED_ACCT_FLG,
                    CB.BILL_TO_CUST_E1_NUM AS BILL_TO_CUST_NUM
                    ,CASE  WHEN cb.MMS_SUB_CLASS_CD = '06' THEN 'HME'           
                            WHEN cb.MMS_SUB_CLASS_CD = '10' THEN 'PAC'           
                            WHEN cb.MMS_SUB_CLASS_CD = '45' THEN 'HIT'
                            WHEN cb.MMS_SUB_CLASS_CD = '36' THEN 'SIMPLY MED'
                            Else 'other' END New_E1_Div
                    , BILL_TO.CUST_NAME AS BILL_TO_CUST_NAME
                    FROM PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_CUST_E1_BLEND_CURR as CB
                    LEFT JOIN PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_CUST_E1_BLEND_CURR as BILL_TO
                      ON CB.DIM_BILL_TO_CUST_CURR_ID = BILL_TO.DIM_CUST_CURR_ID)           
,TRANSACTIONS AS 
        (SELECT DISTINCT
        S.BIOMED_FLG, S.ORDR_NUM, --BMD.REPAIR_TKT_NUM, 
        bmd.REF_NUM as OtOrderNum, --- when ot order number is null, the biomed_flag is N -- the deal originated elsewhere -- e1 order number exists but is not back transmitted to OT so it is MIA 
        BMD.DEVICE_CD, 
        i.PARNT_SUPLR_NAME,
        i.ITEM_E1_NUM , I.ITEM_DSC,
        DI.TYPE, i.prmry_uom, --BMD.ASSET_ID,  
        CUS.BIOMED_ACCT_FLG, S.DIM_ACCT_MGR_CURR_ID,
        CUS.BILL_TO_CUST_NUM, cus.mstr_grp_name,REPLACE(REPLACE(REPLACE(cus.mstr_grp_name, 'BIO-', ''),'BIO - ',''),'BIO ','') AS mstr_grp_name_trim,
        CUS.DIM_CUST_CURR_ID, 
        CUS.BILL_TO_CUST_NAME, s.inv_num,bmd.repair_tkt_num, bmd.ref_num,
        cus.CUST_NAME, cus.New_E1_Div,
        cal.FISC_YR_NUM, 
        cal.FISC_MTH_NUM,cal.FISC_YR_MTH_NUM, cal.cal_yr_num, cal.cal_mth_num, cal.cal_yr_mth_num, cal.cal_wk_num, cal.fisc_wk_num
          ,case when rentcal.fisc_yr_mth_num is not null then rentcal.fisc_yr_mth_num 
        else CAL.FISC_YR_MTH_NUM end as adj_FISC_YR_MTH_NUM
        --CUS.DIM_ACCT_MGR_CURR_ID,
        ,case when CUS.BILL_TO_CUST_NUM in ('66050515') then 'Y'
            when i.ITEM_E1_NUM IN ('1167556') then 'Y'
        else 'N' end as PPPM_or_Fleet_Flag
        , case when di.device_group_lvl_1 is null then 'Other' else di.device_group_lvl_1 end as device_group_lvl_1
        , case when di.device_group_lvl_2 is null then 'Other' else di.device_group_lvl_2 end as device_group_lvl_2
        ,PROD_SUB_CTGRY_LVL4_DSC
        ,CASE 
                when I.ITEM_E1_NUM IN ('1167563','1066182','307728')                 THEN 'Freight' 
                WHEN I.ITEM_E1_NUM in ('1151926','1151927')                 Then 'Verbal Care'
                WHEN I.ITEM_E1_NUM in ('1167552','1167881','1167883','1167555')                 Then 'OneTrack'
                when cus.cust_e1_num in ('65296447')                 then 'Service' --AMEDA correction
                when TT.LINE_TYPE_CD in ('B4') 
                        or I.PROD_SUB_CTGRY_LVL4_DSC IN ('Feeding Pumps- New', 'Infusion Pumps- New', 'Vents - New'  )
                           or I.PROD_SUB_CTGRY_LVL4_DSC  like 'Infusion Pumps - New%' then 'New Equipment'
                when (TT.LINE_TYPE_CD in ('B5') or (I.PROD_SUB_CTGRY_LVL4_DSC IN ('Infusion Pumps- Used','Vents - Used','Feeding Pumps- Used','Nebulizer Compressor (equipment) USED','Apnea Monitors, Used',
                'Accessories, Ventilators, Used','Breast Pumps & Accessories, USED','Pulse Oximeter, Respiratory, Used','Re-Supply, Circuit Assembly, USED','Other Iv Therapy, N/S Accessories, Used',
                'Humidifiers, Used','Feeding Pump Components, Used','Infusion Pump Accessories- Used','All Other Office Supplies, Tech, Used','Vent Humidifiers- Used',
                'Miscellaneous Respiratory, Used','Instrument Batteries, Used') 
                or I.item_e1_num in ('1163161','1163164','1170554','1163361','1163469','1163620','1163163','1163389','1163390','1162608','1168187','1168186') )
                or I.PROD_SUB_CTGRY_LVL4_DSC like 'Infusion Pumps - Used%')
                then 'Used Equipment'
                when I.ITEM_E1_NUM IN ('1167556')                 then 'Service' 
                WHEN TT.LINE_TYPE_CD in ('B3')                     
                    OR I.ITEM_E1_NUM IN ('1167548', '1167546', '1170550', '1170555','1200820','1200868','1200902','1200926') 
                    OR I.PROD_SUB_CTGRY_LVL4_DSC IN ('Feeding Pumps - Rentals', 'Infusion Pumps - Rentals', 'Vents - Rentals', 'Rental Fee Other','Rental Iv Pumps, Other','Infusion Pumps - Rentals AMB','Infusion Pumps - Rentals SYRINGE','Infusion Pumps - Rentals LVP') 
                THEN 'Rental'
                ELSE 'Service'
        END SALES_TYPE,
        CASE 
                when I.ITEM_E1_NUM IN ('1167563','1066182','307728','1151926','1151927')                 THEN 'Other' 
                WHEN I.ITEM_E1_NUM in ('1167552','1167881','1167883','1167555')                 Then 'OneTrack'
                when cus.cust_e1_num in ('65296447') or I.ITEM_E1_NUM IN ('1167556')                 then 'Service' --AMEDA correction
                when TT.LINE_TYPE_CD in ('B4','B5') 
                    or I.PROD_SUB_CTGRY_LVL4_DSC IN ('Feeding Pumps- New', 'Infusion Pumps- New', 'Vents - New','Infusion Pumps- Used','Vents - Used','Feeding Pumps- Used',
                'Nebulizer Compressor (equipment) USED','Apnea Monitors, Used','Accessories, Ventilators, Used','Breast Pumps & Accessories, USED','Pulse Oximeter, Respiratory, Used','Re-Supply, Circuit Assembly, USED',
                'Other Iv Therapy, N/S Accessories, Used','Humidifiers, Used','Feeding Pump Components, Used','Infusion Pump Accessories- Used','All Other Office Supplies, Tech, Used','Vent Humidifiers- Used',
                'Miscellaneous Respiratory, Used','Instrument Batteries, Used'  ) 
                    or I.item_e1_num in ('1163161','1163164','1170554','1163361','1163469','1163620','1163163','1163389','1163390','1162608','1168187','1168186')
                    or I.PROD_SUB_CTGRY_LVL4_DSC  like 'Infusion Pumps - New%' or I.PROD_SUB_CTGRY_LVL4_DSC like 'Infusion Pumps - Used%'
                then 'Equipment'
                WHEN TT.LINE_TYPE_CD in ('B3')                     OR I.ITEM_E1_NUM IN ('1167548', '1167546', '1170550', '1170555','1200820','1200868','1200902','1200926') 
                    OR I.PROD_SUB_CTGRY_LVL4_DSC IN ('Feeding Pumps - Rentals', 'Infusion Pumps - Rentals', 'Vents - Rentals', 'Rental Fee Other','Rental Iv Pumps, Other','Infusion Pumps - Rentals AMB','Infusion Pumps - Rentals SYRINGE','Infusion Pumps - Rentals LVP') 
                THEN 'Rental'
                ELSE 'Service'
            END CONSOL_SALES_TYPE,
      TT.LINE_TYPE_CD ,TT.LINE_TYPE_dsc,
        TT.ORDR_TYPE_CD,   TT.ORDR_TYPE_DSC
        ,count(BMD.ASSET_ID) as ttl_device_qty
        ,sum(i.stndrd_cost_amt) as stndrd_cost_amt
        , sum(case when I.ITEM_E1_NUM IN ('1167566') then S.EXT_NET_SLS_AMT else 0 end) OEM_Fees
        , sum(case when I.ITEM_E1_NUM IN ('1167556', '1167564', '1167565', '1167545', '1167541', '1167562') then S.EXT_NET_SLS_AMT else 0 end) Service_Fees
        , sum(S.EXT_NET_SLS_AMT - (case when GLS.OBJ_ACCT_CD in ('411010') then EXT_NET_SLS_AMT - EXT_SELL_GP_FIN_AMT
                                    when GLS.OBJ_ACCT_CD in ('414021') then EXT_COGS_ACQ_AMT 
                                    else 0 end)
                                    ) as GL_SELL_GP   
        , sum(case when GLS.OBJ_ACCT_CD in ('411010') then EXT_NET_SLS_AMT - EXT_SELL_GP_FIN_AMT
                    when GLS.OBJ_ACCT_CD in ('414021') then EXT_COGS_ACQ_AMT 
                    else 0 end
                    ) as GL_COGS
         , sum(case when I.ITEM_E1_NUM ='1167566' then S.EXT_NET_SLS_AMT else 0 end) as sls_oem_fees 
        , sum(case when I.ITEM_E1_NUM <> '1167566' then S.EXT_NET_SLS_AMT else 0 end) as SLS_excl_OEM_Fees ----- something about 1167566 gives OEM fees
        , sum((case when I.ITEM_E1_NUM <> '1167566' then s.EXT_NET_SLS_AMT else 0 end) 
                - (case when GLS.OBJ_ACCT_CD = '411010' then EXT_NET_SLS_AMT - EXT_SELL_GP_FIN_AMT
                        when GLS.OBJ_ACCT_CD = '414021' then EXT_COGS_ACQ_AMT 
                        else 0 end) ) as GL_Sell_GP_excl_OEM_Fees            
        ,SUM(S.EXT_NET_SLS_AMT) AS NET_SLS
               
        FROM "PRD_PL_MMS_EDW_DB"."EDWRPT"."V_FACT_SLS" S
        LEFT JOIN cus
            ON  CUS.DIM_CUST_CURR_ID = S.DIM_CUST_CURR_ID
        INNER JOIN "PRD_PL_MMS_EDW_DB"."EDWRPT"."V_DIM_PERIOD" as P
            ON S.DIM_GL_DT_ID = P.DIM_PERIOD_ID
        INNER JOIN "PRD_PL_MMS_EDW_DB"."EDWRPT"."V_DIM_ITEM_E1_CURR" as I
            ON I.DIM_ITEM_E1_CURR_ID = S.DIM_ITEM_E1_CURR_ID
        LEFT JOIN PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_BIOMED_SLS as BMD 
            ON BMD.DIM_BIOMED_SLS_ID = S.SLS_ID
        LEFT JOIN PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_GL_ACCT as GLS 
            ON S.DIM_SLS_GL_ACCT_ID = GLS.DIM_GL_ACCT_ID
        LEFT JOIN PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_GL_ACCT as GLC 
            ON S.DIM_COGS_GL_ACCT_ID = GLC.DIM_GL_ACCT_ID
        left join PRD_PL_MMS_DATALAKE_DB.MMSDM910.SRC_E1_MMS_F55413PL as tpl 
            on tpl.ply553plitm = bmd.device_cd 
            and tpl.pltorg = 'OT'
        LEFT JOIN PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_TRANS_TYPE as TT 
            ON S.DIM_TRANS_TYPE_ID = TT.DIM_TRANS_TYPE_ID
        LEFT JOIN PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_ACCT_MGR_CURR as AE 
            ON AE.DIM_ACCT_MGR_CURR_ID = s.DIM_ACCT_MGR_CURR_ID
        LEFT JOIN PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_PERIOD as CAL 
            ON CAL.DIM_PERIOD_ID = S.DIM_GL_DT_ID
        left join prd_sbx_mms_db.fpasls.mr_device_index as DI 
            on di.device_code = bmd.device_cd
        left join PRD_PL_MMS_EDW_DB.EDWRPT.V_DIM_PERIOD as rentcal 
            on rentcal.dt = (to_date(case when bmd.BILL_START_END = '*' then null 
                                        when charindex('-',bmd.BILL_START_END) = 0 then bmd.BILL_START_END 
                                        else left(bmd.BILL_START_END,charindex('-',bmd.BILL_START_END)-2) end,'mm/dd/yyyy'))
        WHERE 1=1 
            and CAL.FISC_YR_MTH_NUM >= '202400' 
--            and CAL.FISC_YR_MTH_NUM <'202510' 
            --CAL.FISC_YR_MTH_NUM BETWEEN '202301' AND '202405'
            AND (S.BIOMED_FLG = 'Y' OR CUS.BIOMED_ACCT_FLG = 'Y')
--            and "MSTR_GRP_NAME" like 'BIO - %'
        GROUP BY 
          S.BIOMED_FLG, S.ORDR_NUM,
        OtOrderNum, 
        BMD.DEVICE_CD, 
        i.PARNT_SUPLR_NAME,
        i.ITEM_E1_NUM ,I.ITEM_DSC,
        DI.TYPE, i.prmry_uom, 
        CUS.BIOMED_ACCT_FLG, S.DIM_ACCT_MGR_CURR_ID,
        CUS.BILL_TO_CUST_NUM, cus.mstr_grp_name,
        CUS.DIM_CUST_CURR_ID, 
        CUS.BILL_TO_CUST_NAME,s.inv_num,bmd.repair_tkt_num, bmd.ref_num,
        cus.CUST_NAME, cus.New_E1_Div,
        cal.FISC_YR_NUM, 
        cal.FISC_MTH_NUM,cal.FISC_YR_MTH_NUM, cal.cal_yr_num, cal.cal_mth_num, cal.cal_yr_mth_num , cal.cal_wk_num, cal.fisc_wk_num,adj_FISC_YR_MTH_NUM,
        PPPM_or_Fleet_Flag,
        device_group_lvl_1,
        device_group_lvl_2,
        PROD_SUB_CTGRY_LVL4_DSC,
        SALES_TYPE,
        CONSOL_SALES_TYPE,  TT.LINE_TYPE_CD ,TT.LINE_TYPE_dsc,
        TT.ORDR_TYPE_CD,   TT.ORDR_TYPE_DSC 
)
select t.*, 
br.ACCT_MGR_NAME as biomed_specialist_name 

from transactions t 
left join BIOMED_REP as br 
    on br.BILL_TO_CUST_NUM = t.BILL_TO_CUST_NUM
--left join VP_DATA as vp     on vp.bill_to_cust_num = t.bill_to_cust_num
where 1=1  
--and lower(PROD_SUB_CTGRY_LVL4_DSC) like '%rental%'
--and sales_type <> 'Rental' 
)
--and SALES_TYPE in ('Rental','New Equipment','Used Equipment','Service','OneTrack')