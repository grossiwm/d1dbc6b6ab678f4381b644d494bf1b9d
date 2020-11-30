select
        i.relname as nome_indice,
        t.relname as nome_tabela,
        a.attname as name_coluna
from
        pg_class t,
        pg_class i,
        pg_index ix,
        pg_attribute a
where
        t.oid = ix.indrelid
        and i.oid = ix.indexrelid
        and a.attrelid = t.oid
        and a.attnum = ANY(ix.indkey)
order by i.relname;