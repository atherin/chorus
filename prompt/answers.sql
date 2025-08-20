-- 1. **Retrieve all active patients**
-- Write a query to return all patients who are active.
select p.id 
from "Patient" p
where p.active is True
;

-- 2. **Find encounters for a specific patient**
-- Given a patient_id, retrieve all encounters for that patient, including the status and encounter date.
select e.patient_id, e.id as encounter_id, e.status, e.encounter_date
from "Encounter" e
where true
  and e.patient_id = :patient_id
  -- and e.patient_id = '824ecc78-5fc4-4740-843c-c55e8092b1bb'
;

-- 3. **List all observations recorded for a patient**
-- Write a query to fetch all observations for a given patient_id, showing the observation type, value, unit, and recorded date.
select o.patient_id
     , o.id as observation_id
     , o."type" as observation_type
     , o.value
     , o.unit 
     , o.recorded_at
from "Observation" o 
where true
  and o.patient_id = :patient_id
  -- and o.patient_id = '824ecc78-5fc4-4740-843c-c55e8092b1bb'
;

-- 4. **Find the most recent encounter for each patient**
-- Retrieve each patient’s most recent encounter (based on encounter_date). Return the patient_id, encounter_date, and status.
-- explain
-- with cte as (
-- select *, row_number() over (partition by e.patient_id order by e.encounter_date desc) as row_num from "Encounter" e
-- )
-- select e.patient_id, e.encounter_date, e.status
-- from cte e
-- where true
--   and row_num = 1
-- order by e.patient_id, e.encounter_date desc
-- ;
-- explain
select distinct on (e.patient_id) e.patient_id, e.encounter_date, e.status
from "Encounter" e
where true
order by e.patient_id, e.encounter_date desc
;

-- 5. **Find patients who have had encounters with more than one practitioner**
-- Write a query to return a list of patient IDs who have had encounters with more than one distinct practitioner.
select e.patient_id
from "Encounter" e 
where true
group by 1
having count(distinct e.practitioner_id) > 1

-- 6. **Find the top 3 most prescribed medications**
-- Write a query to find the three most commonly prescribed medications from the MedicationRequest table, sorted by the number of prescriptions.
select mr.medication_name, count(mr.id) as number_of_prescriptions
from "MedicationRequest" mr 
group by 1
order by 2 desc
limit 3
;
-- 7. **Get practitioners who have never prescribed any medication**
-- Write a query to find all practitioners who do not appear in the MedicationRequest table as a prescribing practitioner.
-- explain
-- select p.id as practitioner_id
-- from "Practitioner" p 
-- 	 left join "MedicationRequest" mr on p.id = mr.practitioner_id 
-- where true 
--   and mr.practitioner_id  is null
-- ;
-- explain
select p.id as practitioner_id
from "Practitioner" p
where not exists (
	select 1
	from "MedicationRequest" mr
	where mr.practitioner_id = p.id 
)
;

-- 8. **Find the average number of encounters per patient**
-- Calculate the average number of encounters per patient, rounded to two decimal places.
with encounter_agg as (
select e.patient_id, count(e.id) as encounter_ct  
from "Encounter" e 
where true
group by 1
)
select e.patient_id, avg(encounter_ct)::decimal(19,2) as average_number_of_encounters
from encounter_agg e
group by 1
;

-- 9. **Identify patients who have never had an encounter but have a medication request**
-- Write a query to find patients who have a record in the MedicationRequest table but no associated encounters in the Encounter table.
select p.id as practitioner_id
from "Patient" p
where true 
  and not exists (
  	select 1
  	from "Encounter" e
  	where e.patient_id = p.id 
  )
  and exists (
  	select 1
  	from "MedicationRequest" mr
  	where mr.patient_id  = p.id 
  )
;
	
-- 10.	**Determine patient retention by cohort**
-- Write a query to count how many patients had their first encounter in each month (YYYY-MM format) and still had at least one encounter in the following six months.
with patient_agg as (
	select e.patient_id
		 , min(e.encounter_date) as min_encounter_dt
	from "Encounter" e 
	where true
	group by 1
), patient_filter as (
	select pa.patient_id
	     , to_char(pa.min_encounter_dt, 'YYYY-MM') as first_encounter_month  
	from patient_agg pa
	where true
	  and exists (
	  	select 1
	  	from "Encounter" e 
	  	where e.patient_id = pa.patient_id 
	  	  and e.encounter_date > pa.min_encounter_dt 
	  	  and e.encounter_date <= pa.min_encounter_dt + interval '6 months'
	  )
)
select pf.first_encounter_month, count(pf.patient_id) as patient_ct
from patient_filter pf
group by 1
;