----------- WIP Summary new verison 
---------- using boilerplate PM and Rep query then add in duration calculations 
-- 
/*
what things do I need? 
- device events 
    - PM'd
        WHERE t.EventCode IN (3,33)
    - repaired
        where t.eventCode = 924
    - shipped 
        WHERE t.EventCode IN (4,6,8,66,301,508,666,903)
    - cleaned? do we care? 
        where eventcode = 2 
- probably durations 
    - avg pm days 
    - avg repair days 
- info on device 
    - where did it come from? 
        - source type as owner, mck, vendor, etc. 
    - where is it going? 
        - dest type as owner, mck, vendor, etc. 
    - owner type 
        - customer, mck, AMP Pool customer
        */
-------------------- by location and owner  - trying to include shipped and cleaned as well
with 
a as(select distinct q.DeviceCode, e.BarCodeNumber, q.Make, q.Model, q.[Owner], q.OwnerID
    , case when c.FK_ParentCompanyId = 108 then 'McKesson Owned' else 'Customer Owned' end as ownershipType 
    , case when q.DeviceCode in ('556','139','4863','5950','5958','10418','10653','10907','8667','4597','489','921','8225','510','4595','8226','2054','280','9009','6850','6267','7749','8890')
    then 1 else 0 end as top_device
    , case when q.DeviceType in ('Pump','Pump - Ambulatory','Pump - Enteral','Pump - Pole Mounted','Pump - Pole Mounted Infusion','Pump, Infusion','Pump - Syringe','Ventilator','DME-Ventilator',
        'Anesthesia Ventilator','Pulse Oximeter','Respiratory','Simulator, Pulse Oximeter','DME-Pulse Oximeter','Monitor, Video','Humidifier','DME-Humidifier','DME-Apnea Monitor','DME-In-Exsufflator',
                            'Nebulizer','DME-Hand Dynamometer','Pharmacy Compounders','Centrifuge','DME-CPAP') 
    then 'Device' else 'Accessory' end as deviceType_homemade
        , case 
        when q.DeviceType in ('Pump - Enteral') then q.devicetype 
        when q.devicetype in ('Pump - Ambulatory','Pump - Syringe','Pump - Pole Mounted','Pump - Pole Mounted Infusion','Pump, Infusion') then 'Pump - Infusion'
        when q.devicetype in ('Ventilator','DME-Ventilator','Anesthesia Ventilator') then 'Ventilator'
        when q.devicetype in ('Pulse Oximeter','Respiratory','Simulator, Pulse Oximeter','DME-Pulse Oximeter','Monitor, Video','Pump','Humidifier','DME-Humidifier','DME-Apnea Monitor','DME-In-Exsufflator',
                            'Nebulizer','DME-Hand Dynamometer','Pharmacy Compounders','Centrifuge','DME-CPAP') then 'Other'
    else 'Accessory' end as deviceType_homemade_lvl2
    , case 
        when e.EventCode = '924' then 'Repair' 
        when e.eventcode in ('3','33') then 'PM' 
        when (e.eventcode in ('4','6','8','66','301','508','666') and e.srcid in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441'))
            or (e.eventcode = '903' and e.srcid in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441') and e.destid not in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441'))
        then 'Shipped'
        when e.eventcode = '2' then 'Cleaned' else null 
        end as eventType --, e1.[Description]
    ,1 as rowcounter, a.[Name] techName, c1.[Name] LocationName, year(e.[TimeStamp]) eventYear, month(e.[TimeStamp]) eventMonth
    from dbo.Events e 
    join dbo.EventCodes e1 
        ON e1.Code = e.EventCode
    join dbo.qryDevices q 
        on e.BarCodeNumber = q.BarCodeNumber
    join dbo.Clients c 
        on c.id = q.OwnerID
    join dbo.Associates a 
        on e.FK_UserId = a.UserId
--        on e.AssociateID = a.id
    join dbo.Clients c1 
        ON c1.PK_ClientId = a.FK_ClientId 
    where 1=1 
        and e.EventCode in ('3','33','924','2','4','6','8','66','301','508','666','903')
        and e.[TimeStamp] >= '11/1/2024'
        and e.[TimeStamp] <'12/1/2024'
--        and a.Eid is not null 
        and c1.id in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441'))
select
--devicecode, make, model,deviceType_homemade_lvl2 device_type,top_device,
 eventYear, eventMonth,LocationName,  ownershiptype,
eventType
,sum(rowcounter) eventCount
from a
--where devicetype_homemade <> 'Accessory' 
group by eventYear, eventMonth, LocationName, ownershiptype,eventType
--order by  sum(rowcounter) desc ,devicecode asc 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
/* the following is a test to see how many time a device gets "manually relocated" to a pool location 
according to Mike , these should be counted as device shipped. I suspect these would have a subsequent shipment event, and thereby be counted as a device ship anyways.
if there is a shipment event FROM the pool location, then I may still need to include them since the other query only looks for ones coming FROM depot codes */
select distinct 
code, description, e.SrcID, e.DestID ,case 
        when e.EventCode = '924' then 'Repair' 
        when e.eventcode in ('3','33') then 'PM' 
        when e.eventcode in ('4','6','8','66','301','508','666') and e.srcid in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441') then 'Shipped'
        when e.eventcode = '2' then 'Cleaned' else null  end as eventType
        ,count(*)
from dbo.Events e
join dbo.EventCodes e1 
    ON e1.Code = e.EventCode
join dbo.Associates a 
    on e.FK_UserId = a.UserId
--        on e.AssociateID = a.id
join dbo.Clients c1 
    ON c1.PK_ClientId = a.FK_ClientId 
where 1=1 
--and e.EventCode = '903' -- in ('3','33','924','2','4','6','8','66','301','508','666','903')
    and e.EventCode in ('4','6','8','66','301','508','666')
    and c1.id in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441')
    and e.srcid in (select distinct c.ID from dbo.Clients c where c.[Name] like '%pool%')
-- and e.[TimeStamp] > '12/31/2023'
-- and e.srcid in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441')
-- and e.srcid in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441')
 
 group by code, description, e.SrcID, e.DestID ,case 
        when e.EventCode = '924' then 'Repair' 
        when e.eventcode in ('3','33') then 'PM' 
        when e.eventcode in ('4','6','8','66','301','508','666') and e.srcid in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441') then 'Shipped'
        when e.eventcode = '2' then 'Cleaned' else null  end 
;
select 
distinct e.SrcID, count(*)

from dbo.Events e
where e.EventCode in ('3','33','924','2','4','6','8','66','301','508','666')
and e.[TimeStamp] > '12/31/2022'
group by e.SrcID
;;;;;;;;;;;
select distinct c.ID, name from dbo.Clients c where c.[Name] like '%pool%'
;;;;;;;;;;;
select a.[Name], a.UserId, a.Eid, a.ClientID, c1.[Name]
from dbo.Associates a 
     
    join dbo.Clients c1 
        ON c1.PK_ClientId = a.FK_ClientId 
    where 1=1 
--        and e1.Code in ('3','33','924')
--        and e.[TimeStamp] >='1/1/2024'
--        and e.[TimeStamp] <getdate()
--        and a.Eid is not null 
        and c1.id in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441')
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
------------------------------------  repair duration query 
with 
checkIn as (select e.BarCodeNumber, e.EventCode, e1.[Description], e.[TimeStamp]  
    from dbo.Events e
    join dbo.EventCodes e1 ON e1.Code = e.EventCode
    left join clients c on c.id = e.DestID
    where e.EventCode = 1 and c.FK_ParentCompanyId = 108
    --and e.Destid in (select ID from clients where FK_ParentCompanyId = 108)
)

,reps as (select 
    r.BarCodeNumber, r.FK_DeviceId, r.Status, r.DateOpened, r.FK_RepairPerformedById , a.name techName, c.name locationName,a.FK_ClientId,c.PK_ClientId,c.id, r.PerformedAt, r.RepairTicketNo, r.PK_RepairTicketId, r.DateLastModified, 
    r7.PK_RMATrackerId, r.VendorRMANumber,repairedby, r.RepairType
    , max(r.DateRepairCompleted) DateRepairCompleted
    from dbo.RepairTickets r
    left join dbo.RMATracker r7 ON r7.FK_RepairTicketId = r.PK_RepairTicketId
    left join dbo.Associates a ON a.UserId = r.FK_RepairPerformedById 
    left join dbo.Clients c ON c.id =  r.PerformedAt
    where daterepaircompleted is not null
    and r.daterepaircompleted >'1/1/2022'
    and r.daterepaircompleted < getdate() 
    group by r.BarCodeNumber, r.FK_DeviceId, r.Status, r.DateOpened, r.FK_RepairPerformedById,a.name, c.name, a.FK_ClientId,c.PK_ClientId,c.id,r.PerformedAt, r.RepairTicketNo, r.PK_RepairTicketId, r.DateLastModified, r7.PK_RMATrackerId, r.VendorRMANumber,repairedby, r.RepairType)
---------------
,agg as (
select 
    q.BarCodeNumber, q.StatusDescription, q.StatusCode,
    month(checkin2.checkintime) checkIn_month, year(checkin2.checkintime) checkIn_year, 
    month(r.DateRepairCompleted) completed_month, year(r.DateRepairCompleted) completed_year, 
     r.FK_DeviceId, r.Status, r.DateOpened, r.FK_RepairPerformedById , techName, r.locationName,r.PerformedAt, r.RepairTicketNo, r.PK_RepairTicketId, r.DateLastModified, 
    r.PK_RMATrackerId, r.VendorRMANumber,repairedby, r.RepairType,r.daterepaircompleted
    ,ISNULL((DATEDIFF(dd, checkin2.checkintime, r.DateRepairCompleted)) 
                            - (DATEDIFF(wk, checkin2.checkintime, r.DateRepairCompleted) * 2) 
                            - (CASE WHEN DATENAME(dw, checkin2.checkintime) = 'Sunday' THEN 1 ELSE 0 END) 
                            - (CASE WHEN DATENAME(dw, checkin2.checkintime) = 'Saturday' THEN 1 ELSE 0 END) 
                            + (CASE WHEN CAST(r.DateRepairCompleted as time) > CAST(checkin2.checkintime as time) THEN 1 ELSE 0 END)
                    , 0) repairDays
    
from reps r

join (select ci.barcodenumber, max(ci.[timestamp]) checkInTime 
        from checkin ci group by ci.barcodenumber) checkIn2 
    on checkin2.barcodenumber = r.barcodenumber
    and checkin2.checkintime < r.daterepaircompleted 
join dbo.qryDevices q 
    on q.deviceuid = r.fk_deviceid
where 1=1 
    and r.daterepaircompleted >'1/1/2022'
    and r.daterepaircompleted < getdate() 
    )
select *
--agg.checkin_month, checkIn_year,
--completed_month,completed_year, locationname, performedat,avg(repairDays) repairDays_avg
from agg 
where performedat in ('00373','18885','04362','00882','10415','19142','19112','00883','00301', '18441')
--group by completed_month,completed_year, locationname, performedat
--order by r.daterepaircompleted asc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
select top 100 c.PK_ClientId, * from dbo.Clients c
where c.ID = '00883' or c.PK_ClientId = '00883'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
select top 100 a.ID, a.ClientID, a.FK_ClientId, * from dbo.Associates a
where a.clientid = '00883'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;
------------------------------------ PM duration query 
with 
checkIn as (select e.BarCodeNumber, e.EventCode, e1.[Description], e.[TimeStamp]  
    from dbo.Events e
    join dbo.EventCodes e1 ON e1.Code = e.EventCode
    left join clients c on c.id = e.DestID
    where e.EventCode in (1) and c.FK_ParentCompanyId = 108)
,checkIn2  as (select ci.barcodenumber, max(ci.[timestamp]) checkInTime from checkin ci group by ci.barcodenumber) 
, pm_complete as (select e.BarCodeNumber, e.EventCode, e1.[Description], e.[TimeStamp] pmCompletedDate,c.name as techLocationName
    from dbo.Events e
    join dbo.Associates a on e.FK_UserId = a.UserId
    join dbo.Clients c ON c.PK_ClientId = a.FK_ClientId
    join dbo.EventCodes e1 ON e1.Code = e.EventCode
    where 1=1 
    and month(timestamp) = '12' and year(timestamp) = '2024'
    and c.id in ('19142','19112','00883','00301') 
    and e1.Code in ('3','33')
    )

,reps as (select 
r.BarCodeNumber, r.FK_DeviceId, r.Status, r.DateRepairCompleted, r.DateOpened, r.PMPerformedBy, r.PerformedAt, r.RepairTicketNo, r.PK_RepairTicketId, r.DateLastModified
from dbo.RepairTickets r)
---------------
select completed_month, completed_year, techLocationName, count(*) from (
select
--q.BarCodeNumber, q.StatusDescription, q.StatusCode,
 checkin2.checkintime, p.pmCompletedDate,techLocationName,
month(p.pmCompletedDate) completed_month, year(p.pmCompletedDate) completed_year
,ISNULL((DATEDIFF(dd, checkin2.checkintime, p.pmCompletedDate)) 
                        - (DATEDIFF(wk, checkin2.checkintime, p.pmCompletedDate) * 2) 
                        - (CASE WHEN DATENAME(dw, checkin2.checkintime) = 'Sunday' THEN 1 ELSE 0 END) 
                        - (CASE WHEN DATENAME(dw, checkin2.checkintime) = 'Saturday' THEN 1 ELSE 0 END) 
                        + (CASE WHEN CAST(p.pmCompletedDate as time) > CAST(checkin2.checkintime as time) THEN 1 ELSE 0 END)
                , 0) PmDays
from pm_complete p

join checkIn2 
    on checkin2.barcodenumber = p.barcodenumber
    and checkin2.checkintime < p.pmCompletedDate
join dbo.qryDevices q 
    on q.barcodenumber = p.barcodenumber
where 1=1 
    and  p.pmCompletedDate >'1/1/2022'
    and  p.pmCompletedDate < getdate() 
    and month(p.pmCompletedDate) = '12'
    and year(p.pmCompletedDate) = '2024') tbl
    group by completed_month, completed_year, techLocationName
--order by p.pmCompletedDate desc
;;;;;;;;;;;;;;;;;;;; 
------------ devices clean, shipped, etc. testing relationship between src, dest, location of person, etc. 
/*
- shipped 
    WHERE t.EventCode IN (4,6,8,66,301,508,666,903)
- cleaned? do we care? 
    where eventcode = 2 
    */
select distinct e.SrcID, csrc.name
--, e.DestID,  e1.[Description], e1.code 
from dbo.Events e 
join dbo.EventCodes e1 ON e1.Code = e.EventCode
join dbo.Clients csrc on csrc.id = e.srcid 
where e.EventCode IN (2,4,6,8,66,301,508,666)
and e.[TimeStamp] >='12/1/2024'
and e.[TimeStamp] <'1/1/2025'
and csrc.FK_ParentCompanyId = 108 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
