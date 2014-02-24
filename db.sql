CREATE TABLE perl_functions (
    id integer primary key,
    description varchar2(30),
    grp varchar2(15),
    url varchar2(2000)
);

delete from perl_functions;
insert into perl_functions values (1, 'Business Analysis Report', 'accounts', 'reports.pl?nextsub=business_analysis');
insert into perl_functions values (2, 'Officer / Entertainment Report', 'fb', 'reports.pl?nextsub=entlist');
insert into perl_functions values (3, 'Category wise Issues Summary', 'inventory', 'reports.pl?nextsub=store_dept_cat_issues');
insert into perl_functions values (4, 'Inhouse Summary Report', 'fo', 'reports.pl?nextsub=inhouse_summary');
insert into perl_functions values (5, 'Billing Instructions Report', 'fo', 'reports.pl?nextsub=billing_ins');
insert into perl_functions values (6, 'Expected Arrivals VIP', 'fo', 'reports.pl?nextsub=expected_arrivals');
insert into perl_functions values (7, 'Day use Guests', 'cashier', 'reports.pl?nextsub=dayuse_guests');
insert into perl_functions values (8, 'Inventory Onhand Report', 'inventory', 'reports.pl?nextsub=onhand');
insert into perl_functions values (9, 'Linking Journal Report', 'accounts', 'reports.pl?nextsub=journal');
insert into perl_functions values (10, 'Room Revenue Summary', 'accounts', 'reports.pl?nextsub=revenue_summary');
insert into perl_functions values (11, 'Direct Purchases Summary', 'inventory', 'reports.pl?nextsub=store_dept_cat_issues_dp');
insert into perl_functions values (12, 'Direct Purchases Detail', 'inventory', 'reports.pl?nextsub=store_dept_cat_issues_dp_detail');

alter table a$sec_users add loc_id varchar2(10) default 'NA';

alter table hr_emp add id integer;
create sequence hr_emp_seq start with 1 nocache order;
create or replace trigger hr_emp_trg
before insert
on hr_emp
for each row
begin
   select hr_emp_seq.nextval into :new.id from dual;
end;
/

alter table po add terms varchar2(4000);


--
-- comment card
--
create table ccard (
    id      integer,
    name    varchar2(50),
    address varchar2(200),
    email   varchar2(200),
    dob     date,
    mobile  varchar2(50)
);

ALTER TABLE ccard ADD anniversary DATE;

create sequence ccard_seq start with 1 nocache order;
create or replace trigger ccard_trg
before insert
on ccard
for each row
begin
    select ccard_seq.nextval into :new.id from dual;
end;
/


alter table hc_fb_items add recipe_outlet_id varchar2(10) default 'NA';
alter table hc_fb_items add recipe_item varchar2(10) default 'NA';

-----------------------------------------

alter table banquet_header add cnic varchar2(100);
alter table banquet_header add ntn varchar2(100);

ALTER TABLE hc_fb_sale_lines ADD kot_print VARCHAR2(1) DEFAULT 'N';

