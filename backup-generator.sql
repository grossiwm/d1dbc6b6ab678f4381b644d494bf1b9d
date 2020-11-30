CREATE OR REPLACE FUNCTION fun() RETURNS SETOF TEXT AS $block$
DECLARE

	cursor_colunas cursor for select tabela.tablename as tabela, 
	jsonb_agg(json_build_object('nome', atributo.attname, 'tipo', tipo.typname, 'tamanho_maximo', atributo.atttypmod,'not null', atributo.attnotnull)) as colunas,
	count(atributo.attrelid) as numero_colunas
	from pg_tables tabela inner join
		pg_class classe on tabela.tablename = classe.relname inner join 
		pg_attribute atributo on atributo.attrelid = classe.oid inner join
		pg_type tipo on tipo."oid" = atributo.atttypid
	where tabela.schemaname = 'public'
		and atributo.attnum > 0
	group by tabela.tablename;

	cursor_pks cursor for select tabela.relname as tabela, cons.conname as pk, array_agg(distinct coluna.attname) as cols,
	count(coluna.attrelid) as numero_cols
	from
	pg_constraint cons inner join 
	pg_class tabela on tabela.oid = cons.conrelid inner join
	pg_attribute coluna on tabela.oid = coluna.attrelid and coluna.attnum = any(cons.conkey)
	where coluna.attnum > 0
	and cons.contype = 'p'
	group by cons.conname, cons.contype, tabela.relname;
	
	cursor_fks cursor for select tabela.relname as tabela,
	cons.conname as fk, 
	tabela_refer.relname as tabela_refer,
	array_agg(distinct coluna_refer.attname) as cols_refer,
	array_agg(distinct coluna.attname) as cols,
		count(coluna.attrelid) as numero_cols,
		count(coluna_refer.attrelid) as numero_cols_refer
		from
		pg_constraint cons inner join 
		pg_class tabela on tabela.oid = cons.conrelid inner join
		pg_class tabela_refer on tabela_refer.oid = cons.confrelid inner join
		pg_attribute coluna on tabela.oid = coluna.attrelid and coluna.attnum = any(cons.conkey) inner join
		pg_attribute coluna_refer on tabela_refer.oid = coluna_refer.attrelid and coluna_refer.attnum = any(cons.confkey)
		where coluna.attnum > 0
		and cons.contype = 'f'
		group by cons.conname, cons.contype, tabela.relname, tabela_refer.relname;
	
	json_cols jsonb;
	json_col jsonb;

	nome_col varchar;
	tipo_col varchar;
	especs_col varchar;
	especs_cols varchar;
	
	especs_tabela varchar;
	
	json_pks jsonb;
	json_pk jsonb;
	especs_pk varchar;
	cols varchar;
	cols_array varchar[];
	
	refer_cols_array varchar[];
	especs_fk varchar;
	refer_cols varchar;

BEGIN
	for rec in cursor_colunas loop
	
		especs_cols = '';
		json_cols := rec.colunas;
	
		for counter in 0..rec.numero_colunas-1 loop
		
			json_col := json_cols->counter;
			
			nome_col := json_col->>'nome';
			tipo_col := json_col->> 'tipo';
			
			if cast(json_col->'tamanho_maximo' as int) > 0 then
   				
				tipo_col := tipo_col || '(' || (json_col->>'tamanho_maximo') || ')';
				
			end if;
			
			especs_col := quote_ident(nome_col) || ' ' || tipo_col;
			
			if json_col->'not null' then
			
   				especs_col := especs_col || ' NOT NULL';
			
			end if;
			
			if counter < rec.numero_colunas-1 then
			
   				especs_col := especs_col || ',';
			
			end if;
			
			especs_cols := especs_cols || especs_col;
			
		end loop;
		
		especs_tabela := 'CREATE TABLE ' || quote_ident(rec.tabela) || ' (' || especs_cols || ');';
	
		return next especs_tabela;
	end loop;
	
	for rec in cursor_pks loop  
	
		cols_array := rec.cols;
		cols = '';
		
		for i in array_lower(cols_array, 1)..array_upper(cols_array, 1) loop
		
			cols := cols || quote_ident(cols_array[i]);
			
			if i < rec.numero_cols then
				cols := cols || ', ';
			end if;
			
		end loop;

  		especs_pk := 'ALTER TABLE ' || quote_ident(rec.tabela) || ' ADD PRIMARY KEY (' || cols || ');';
  		return next especs_pk;
		
	end loop;
	
	for rec in cursor_fks loop  
	
		cols_array := rec.cols;
		refer_cols_array := rec.cols_refer;
		cols = '';
		
		for i in array_lower(cols_array, 1)..array_upper(cols_array, 1) loop
		
			cols := cols || quote_ident(cols_array[i]);
			
			if i < rec.numero_cols then
				cols := cols || ', ';
			end if;
			
		end loop;
		
		refer_cols = '';
		
		for i in array_lower(refer_cols_array, 1)..array_upper(refer_cols_array, 1) loop
		
			refer_cols := refer_cols || quote_ident(refer_cols_array[i]);
			
			if i < rec.numero_cols_refer then
				refer_cols := refer_cols || ', ';
			end if;
			
		end loop;
		
		especs_fk := 'ALTER TABLE ' || quote_ident(rec.tabela) || ' ADD CONSTRAINT ' || quote_ident(rec.fk) ||
		' FOREIGN KEY (' || cols || ')' || ' REFERENCES ' || quote_ident(rec.tabela_refer) || '(' || refer_cols || ');';

		return next (especs_fk::text);
	end loop;
	
end
$block$ LANGUAGE plpgsql;