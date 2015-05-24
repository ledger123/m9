CREATE TABLE hc_res_copy AS
SELECT * FROM hc_res 
WHERE checked_in='Y' AND checked_out='N'
UNION
SELECT * FROM hc_res
WHERE res_status = 'Active';

CREATE TABLE hc_charges_copy AS
SELECT * FROM hc_charges
WHERE res_id IN (SELECT res_id FROM hc_res_copy);

DELETE FROM hc_charges_copy 
WHERE res_id = (
    SELECT res_id FROM hc_res_copy 
    WHERE room_num='NA' 
    AND checked_in = 'Y' 
    AND checked_out='N'
);


