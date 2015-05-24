TRUNCATE TABLE gl_journal;
TRUNCATE TABLE hc_charges;
TRUNCATE TABLE gl_je_lines;
TRUNCATE TABLE hc_fb_sale_lines;
TRUNCATE TABLE ic_trans_lines_tmp;
TRUNCATE TABLE hc_receipts_detail;
TRUNCATE TABLE hc_receipts;
TRUNCATE TABLE hc_invoices_detail;

DELETE FROM ic_pr_approvals;
DELETE FROM ic_trans_header_tmp;

COMMIT;

DELETE FROM hc_hk_activity;
DELETE FROM hc_invoices;
DELETE FROM hc_night_posting_log;
DELETE FROM hc_occup;
DELETE FROM hc_receipts_deleted;
DELETE FROM hc_receipts_detail;

COMMIT;

DELETE FROM hc_room_change_log;
DELETE FROM hc_room_rate_change_log;
DELETE FROM hr_checklists;
DELETE FROM hr_depts;
DELETE FROM hr_emp;
DELETE FROM ic_pr;
DELETE FROM hc_advances_detail WHERE adv_ref <> 'NA';
DELETE FROM hc_advances WHERE adv_ref <> 'NA';
DELETE FROM hc_advances_deleted;
DELETE FROM hc_advances_detail_deleted;
DELETE FROM hc_auditlog;
DELETE FROM hc_avail;

COMMIT;

DELETE FROM hc_blacklist;
DELETE FROM hc_changelog;
DELETE FROM hc_charges_deleted;
DELETE FROM hc_checkin;
DELETE FROM hc_fb_credits;
DELETE FROM hc_fb_recipies;
DELETE FROM hc_fb_sale;
DELETE FROM hc_fb_sale_deleted;
DELETE FROM hc_fb_sale_lines_deleted;
DELETE FROM hc_res WHERE res_id NOT IN (SELECT res_id FROM hc_advances WHERE adv_ref='NA');

COMMIT;

DELETE FROM ap_check_accounts;
DELETE FROM ap_header;
DELETE FROM ap_lines;
DELETE FROM ap_payments;
DELETE FROM banquet_header;
DELETE FROM banquet_lines;
DELETE FROM fa_cats;
DELETE FROM fa_depts;
DELETE FROM fa_items;
DELETE FROM fa_trans;
DELETE FROM gl_je_header;
DELETE FROM po_header;

COMMIT;

/*
DELETE FROM ap_vendors;
DELETE FROM hc_rooms;
DELETE FROM hc_room_types;
DELETE FROM ic_items;
DELETE FROM ic_items_cats;
DELETE FROM ic_items_locs;
DELETE FROM hc_companies;
DELETE FROM hc_companies_rates;
DELETE FROM hc_companies_visits;
DELETE FROM hc_fb_items;
DELETE FROM hc_fb_outlets;
DELETE FROM hc_card;
DELETE FROM a$sessions;
DELETE FROM gl_budget;
DELETE FROM hc_budget;
*/

COMMIT;

/*
DELETE FROM ic_locs WHERE system_rec='N';
DELETE FROM hc_cc_types WHERE system_rec='N';
DELETE FROM hc_charge_codes WHERE system_rec='N';
DELETE FROM gl_accounts WHERE system_rec='N';
DELETE FROM gl_cost_codes WHERE system_rec='N';
DELETE FROM gl_je_categories WHERE system_rec='N';
DELETE FROM a$cols WHERE system_rec='N';
DELETE FROM a$extra_cols WHERE system_rec='N';
DELETE FROM a$forecast WHERE system_rec='N';
DELETE FROM a$lookup WHERE system_rec='N';
DELETE FROM a$menu WHERE system_rec='N';
DELETE FROM a$sec_menu_roles WHERE system_rec='N';
DELETE FROM a$sec_roles WHERE system_rec='N';
DELETE FROM a$sec_users WHERE system_rec='N';
DELETE FROM a$sec_users_priv WHERE system_rec='N';
DELETE FROM a$todo WHERE system_rec='N';
*/

