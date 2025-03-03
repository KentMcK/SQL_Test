--------------- new updated version as of 2.20.25
with 
a as (
    select q.SerialNumber,q.DeviceCode,  q.Make, q.Model, q.[Owner], q.OwnerID,   e1.[Description], [TimeStamp], srcid, destid, fk_deviceid, eventcode 
    , rank() over(partition by e.barcodenumber order by e.[TimeStamp] asc) as eventRank
    , case 
        when q.DeviceType in ('Pump','Pump - Ambulatory','Pump - Enteral','Pump - Pole Mounted','Pump - Pole Mounted Infusion','Pump, Infusion','Pump - Syringe','Ventilator','DME-Ventilator',
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
    from dbo.Events e
    left join dbo.qryDevices q on e.FK_DeviceId = q.DeviceUID
    left join dbo.EventCodes e1 ON e1.Code = e.EventCode
    where 1=1 
    and q.Make like 'Breas%' -- when testing, insert specifics here to improve run time and computational efficiency 
    and eventcode= 4
    and e.SrcID  in ('00000', '00060', '00072', '00249', '00301', '00373', '00475', '00784', '00882', '00883', '00920', '01045', '01244',  '01666', '01672', '03107', '03807', '04362', '04896', 
        '05133', '05134', '05135', '05136', '05137', '05351', '05549', '05636', '06586', '06719', '06825', '08644', '10415', '11777', '11935', '12354', '12412', '12706', '12708', '14371', '14372', 
        '14394', '15454', '16545', '16890', '16891', '16892', '16894', '16898', '16901', '16904', '16907', '18376', '18441', '18644', '18645', '18685', '18885', '18941', '19054', '19057', '19112', 
        '19142', '19158', '19285', '19509', '19562', '19671', '20276', '26897')
    )
,b as (
    select 
    a.* ,ponum.PONumber, oem.PartNumber, 
    a.[TimeStamp] as placement_date, receiptdate,
    concat(year(a.[TimeStamp]) ,'-',month(a.[TimeStamp]) ) as placement_year_month, 
    DATENAME(month, a.[timestamp])  as placement_month, 
    year(a.[TimeStamp]) as placement_year,
    src.[Name] as source_name, dest.[name] as End_User_Name, dest.Address1, dest.Address2, dest.City, dest.State, dest.Zip, dest.E1_AccountNumber
    from a 
    left join dbo.EquipmentTypeOEMInfo oem 
        on oem.EquipmentTypeId = a.DeviceCode  
    left join dbo.Clients src
        on a.srcid = src.id
    left join dbo.Clients  dest
        on a.DestID = dest.id
    left join (
            select distinct e.PONumber, e.E1PurchaseOrderReceiptId,e.DeviceCode, imp.FK_DeviceId, e.ReceiptDate 
            from dbo.E1PurchaseOrderReceipt e 
            left join (
                select distinct e.E1PurchaseOrderReceiptId, e.FK_DeviceId, e.CreatedBy, e.CreatedDate 
                from dbo.E1ImportHistory e ) imp 
                on imp.E1PurchaseOrderReceiptId = e.E1PurchaseOrderReceiptId
                ) ponum 
            on ponum.fk_deviceid = a.FK_DeviceId 
    where 1=1 
    and eventrank = 1 
    and dest.Manufacturer = 0 
    and a.timestamp > isnull(receiptdate,0)
    )
select b.* 
 ,case 
    when b.SrcID in ('10415','00060','00373','00883','18441','18885','19112','19142','00301','05549','00882','04362') and b.eventcode = '4' 
      and destid not in ('10415','00060','00373','00883','18441','18885','19112','19142','00301','05549','00882','04362')  
      and ownerid not in ('10415','00060','00373','00883','18441','18885','19112','19142','00301','05549','00882','04362')  
    then 'Sale' 
    when b.SrcID in ('10415','00060','00373','00883','18441','18885','19112','19142','00301','05549','00882','04362') and b.eventcode = '4' 
      and destid not in ('10415','00060','00373','00883','18441','18885','19112','19142','00301','05549','00882','04362')  
      and ownerid in ('10415','00060','00373','00883','18441','18885','19112','19142','00301','05549','00882','04362')  
    then 'Rental'
    when b.SrcID in ('10415','00060','00373','00883','18441','18885','19112','19142','00301','05549','00882','04362') and b.eventcode = '8' 
      and destid in ('10415','00060','00373','00883','18441','18885','19112','19142','00301','05549','00882','04362')  
    then 'Transfer to McK'
else null end as sale_rental
from b 
where 1=1 
--    and make = 'Breas' 
    and b.placement_year > '2022'
    and b.placement_date >='2/1/2024' and b.placement_date <'3/1/2025' -- also when testing, insert date filters here to ensure rankings are inclusive of all events 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
----------------------------------------------------------------- testing ground:

with a as ( select q.SerialNumber,q.DeviceCode,  q.Make, q.Model, q.[Owner], q.OwnerID,   e1.[Description], [TimeStamp], srcid, destid, fk_deviceid, eventcode 
    , rank() over(partition by e.barcodenumber order by e.[TimeStamp] asc) as eventRank
    , case 
        when q.DeviceType in ('Pump','Pump - Ambulatory','Pump - Enteral','Pump - Pole Mounted','Pump - Pole Mounted Infusion','Pump, Infusion','Pump - Syringe','Ventilator','DME-Ventilator',
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
    from dbo.Events e
    left join dbo.qryDevices q on e.FK_DeviceId = q.DeviceUID
    left join dbo.EventCodes e1 ON e1.Code = e.EventCode
    where 1=1 
    and q.Make like 'Breas%' -- when testing, insert specifics here to improve run time and computational efficiency 
--    and eventcode= 4
--    and timestamp >='2/1/2024' and timestamp<'3/1/2025'
    and e.SrcID  in ('00000', '00060', '00072', '00249', '00301', '00373', '00475', '00784', '00882', '00883', '00920', '01045', '01244',  '01666', '01672', '03107', '03807', '04362', '04896', 
        '05133', '05134', '05135', '05136', '05137', '05351', '05549', '05636', '06586', '06719', '06825', '08644', '10415', '11777', '11935', '12354', '12412', '12706', '12708', '14371', '14372', 
        '14394', '15454', '16545', '16890', '16891', '16892', '16894', '16898', '16901', '16904', '16907', '18376', '18441', '18644', '18645', '18685', '18885', '18941', '19054', '19057', '19112', 
        '19142', '19158', '19285', '19509', '19562', '19671', '20276', '26897'))

    select 
    a.* ,ponum.PONumber, oem.PartNumber, 
    a.[TimeStamp] as placement_date, receiptdate,
    concat(year(a.[TimeStamp]) ,'-',month(a.[TimeStamp]) ) as placement_year_month, 
    DATENAME(month, a.[timestamp])  as placement_month, 
    year(a.[TimeStamp]) as placement_year,
    src.[Name] as source_name, dest.[name] as End_User_Name, dest.Address1, dest.Address2, dest.City, dest.State, dest.Zip, dest.E1_AccountNumber
    from a 
    left join dbo.EquipmentTypeOEMInfo oem 
        on oem.EquipmentTypeId = a.DeviceCode  
    left join dbo.Clients src
        on a.srcid = src.id
    left join dbo.Clients  dest
        on a.DestID = dest.id
    left join (
            select distinct e.PONumber, e.E1PurchaseOrderReceiptId,e.DeviceCode, imp.FK_DeviceId, e.ReceiptDate 
            from dbo.E1PurchaseOrderReceipt e 
            left join (
                select distinct e.E1PurchaseOrderReceiptId, e.FK_DeviceId, e.CreatedBy, e.CreatedDate 
                from dbo.E1ImportHistory e ) imp 
                on imp.E1PurchaseOrderReceiptId = e.E1PurchaseOrderReceiptId
                ) ponum 
            on ponum.fk_deviceid = a.FK_DeviceId 
    where 1=1 
--    and eventrank = 1 
    and dest.Manufacturer = 0 
    and a.timestamp > isnull(receiptdate,0)    
    and serialnumber = 'M240187'
