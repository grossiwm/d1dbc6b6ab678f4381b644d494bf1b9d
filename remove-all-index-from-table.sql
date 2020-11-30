CREATE OR REPLACE PROCEDURE "pg_catalog"."removeindexes" (table_name character varying) 
 LANGUAGE plpgsql
AS $body$
DECLARE
 sql text;
BEGIN
        sql:= 'delete from pg_class where oid in (
        select i.oid from pg_class t inner join pg_index ix on ix.indrelid = t.oid 
        inner join pg_class i on i.oid = ix.indexrelid where t.relname = '||table_name||')';
        
        execute sql;
END;
$body$