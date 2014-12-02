delete from ic_cats_locs;

truncate table ic_trans_lines_tmp;

truncate table ic_trans_header_tmp;

truncate table ic_items_locs;

delete from ic_items where item_id <> 'NA';


