select 
        con.conname as chave_estrangeira, t.relname as tabela, ft.relname as tabela_referenciada, att.attname as coluna, fatt.attname as coluna_na_tabela_referenciada
from 
        pg_constraint con,
        pg_class t,
        pg_class ft,
        pg_attribute att,
        pg_attribute fatt
where 
        contype = 'f'
        and con.conrelid = t.oid
        and con.confrelid = ft.oid
        and att.attrelid = t.oid
        and att.attnum = ANY(con.conkey)
        and fatt.attrelid = ft.oid
        and fatt.attnum = ANY(con.confkey);
