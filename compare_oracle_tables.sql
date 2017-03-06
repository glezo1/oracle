
SET SERVEROUTPUT ON
DECLARE
	TYPE EmpCurTyp IS REF CURSOR;
	emp_cv_compare   EmpCurTyp;
	this_script_version VARCHAR2(50):='0.9';
	/*CONSTANT-DEFINITION**********************************************************************************************************/
	ownerA					VARCHAR2(32767)	:= 'PRE_WEBFOCUS';
	ownerB					VARCHAR2(32767)	:= 'EXPLOTACION';
	tableA					VARCHAR2(32767)	:= 'TBDEP353_FALLECIDOS';
	tableB					VARCHAR2(32767)	:= 'TBDEP353_FALLECIDOS';
	dblinkA					VARCHAR2(32767)	:= '';
	dblinkB					VARCHAR2(32767)	:= '';													-- in the shape of '@dblink_name'
	cross_condition			VARCHAR2(32767)	:='A.ID_EXPEDIENTE=B.ID_EXPEDIENTE';					-- in the shape of 'A.col1=B.col1 AND A.col2=B.col2'
	A_not_B_condition		VARCHAR2(32767)	:='B.ID_EXPEDIENTE IS NULL';							--B.<first_column_of_PK> IS NULL
	B_not_A_condition		VARCHAR2(32767)	:='A.ID_EXPEDIENTE IS NULL';							--A.<first_column_of_PK> IS NULL
	columns_to_be_checked	VARCHAR2(32767)	:='%';
	check_only_structure	BOOLEAN			:=TRUE;
	/*END*CONSTANT-DEFINITION******************************************************************************************************/



	start_sysdate_string			VARCHAR(20)		:='';
	end_sysdate_string				VARCHAR(20)		:='';
	time_elapsed_in_seconds			NUMBER;
	time_elapsed_in_seconds_str		VARCHAR(50) 	:='';
	time_elapsed					VARCHAR(50) 	:='';
	count_A							NUMBER;
	count_B							NUMBER;
	count_A_INNER_B					NUMBER;
	count_A_NOT_B					NUMBER;
	count_B_NOT_A					NUMBER;
	-- variables for non-common constraint
	where_is_present				VARCHAR(50)		:='';
	constraint_name_source			VARCHAR(32767)	:='';
	constraint_type_verbose_source	VARCHAR(32767)	:='';
	constraint_table_source			VARCHAR(32767)	:='';
	search_condition				VARCHAR(32767)	:='';
	separator						VARCHAR(32767)	:='';
	constraint_name_destiny			VARCHAR(32767)	:='';
	constraint_type_verbose_destin	VARCHAR(32767)	:='';
	constraint_table_destiny		VARCHAR(32767)	:='';
	--variables for non-common index
	table_name						VARCHAR(32767)	:='';
	index_name						VARCHAR(32767)	:='';
	column_name						VARCHAR(32767)	:='';
	index_type						VARCHAR(32767)	:='';
	uniqueness 						VARCHAR(32767)	:='';
	--variables for non-common columns
	data_type						VARCHAR(32767)	:='';
	nullable						VARCHAR(32767)	:='';

	
	
	blank_suffix			VARCHAR2(32767)	:= '';
	blank_type_suffix		VARCHAR2(32767)	:= '';
	num_different_rows		NUMBER			:= 0;
	there_is_error			NUMBER(1,0)		:= 0;
	int_table_exists		NUMBER			:= 0;
	croos_condition_is_ko	NUMBER			:= 0;
	A_not_B_condition_is_ko	NUMBER			:= 0;
	B_not_A_condition_is_ko	NUMBER			:= 0;
	query_string			VARCHAR2(32767)	:='';   -- shall contain, in runtime, the text of the query to be performed
	query_length_string		VARCHAR2(32767)	:='';   -- query to retrieve max length of the common columns
	query_date_string		VARCHAR2(32767)	:='';   -- query to retrieve sysdate formatted as of yyyy/mm/dd hh:mm:ss
	TYPE cur_type			IS REF CURSOR;
	dynamic_cursor			cur_type;
	current_column_number	NUMBER			:=0;
	max_column_length		NUMBER			:=0;
BEGIN
	ownerA:=UPPER(ownerA);
	ownerB:=UPPER(ownerB);
	tableA:=UPPER(tableA);
	tableB:=UPPER(tableB);


	dbms_output.put_line('compare_oracle_tables.sql v'||this_script_version);
	query_date_string := 'SELECT TO_CHAR(SYSDATE,''yyyy/mm/dd HH24:MI:ss'') FROM DUAL';
	EXECUTE IMMEDIATE query_date_string INTO start_sysdate_string;
	dbms_output.put_line('Starts at ' || start_sysdate_string);
	dbms_output.put_line('Comparing tables:');
	dbms_output.put_line('A                    : '||ownerA||'.'||tableA||dblinkA);
	dbms_output.put_line('B                    : '||ownerB||'.'||tableB||dblinkB);
	dbms_output.put_line('cross_condition      : '||cross_condition);
	dbms_output.put_line('A_not_B_condition    : '||A_not_B_condition);
	dbms_output.put_line('B_not_A_condition    : '||B_not_A_condition);
	dbms_output.put_line('columns_to_be_checked: '||columns_to_be_checked);
	IF check_only_structure=TRUE THEN 
	dbms_output.put_line('check_only_structure : TRUE');
	ELSE
	dbms_output.put_line('check_only_structure : FALSE');
	END IF;
	dbms_output.put_line('');

	dbms_output.put_line('------------------------------------------------------------------------------');
	dbms_output.put_line('--CHECK EXISTANCE AND PRIVILEGES-----------------------------------------------');
	dbms_output.put_line('------------------------------------------------------------------------------');
	there_is_error:=0;
	int_table_exists:=1;
	
	query_string := 'SELECT COUNT(*) FROM all_tables'||dblinkA;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_tables'||dblinkA|| ' does''nt exist or we don''t have privileges!');					there_is_error:=1;	END IF;
	
	query_string := 'SELECT COUNT(*) FROM all_tables'||dblinkB;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_tables'||dblinkB|| ' does''nt exist or we don''t have privileges!');					there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_tab_cols'||dblinkA;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_tab_cols'||dblinkA|| ' does''nt exist or we don''t have privileges!');				there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_tab_cols'||dblinkB;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_tab_cols'||dblinkB|| ' does''nt exist or we don''t have privileges!');				there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_indexes'||dblinkA;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_indexes'||dblinkA|| ' does''nt exist or we don''t have privileges!');					there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_indexes'||dblinkB;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_indexes'||dblinkB|| ' does''nt exist or we don''t have privileges!');					there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_constraints'||dblinkA;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_constraints'||dblinkA|| ' does''nt exist or we don''t have privileges!');				there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_constraints'||dblinkB;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_constraints'||dblinkB|| ' does''nt exist or we don''t have privileges!');				there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_cons_columns'||dblinkA;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_cons_columns'||dblinkA|| ' does''nt exist or we don''t have privileges!');			there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_cons_columns'||dblinkB;
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('all_cons_columns'||dblinkB|| ' does''nt exist or we don''t have privileges!');			there_is_error:=1;	END IF;
	
	query_string := 'SELECT COUNT(*) FROM all_tab_cols'||dblinkA||' WHERE TABLE_NAME='''||tableA||''' AND OWNER='''||ownerA||''' ';
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('A: '||ownerA||'.'||tableA||dblinkA|| ' does''nt exist or we don''t have privileges!!!');	there_is_error:=1;	END IF;

	query_string := 'SELECT COUNT(*) FROM all_tab_cols'||dblinkB||' WHERE TABLE_NAME='''||tableB||''' AND OWNER='''||ownerB||''' ';
	EXECUTE IMMEDIATE query_string INTO int_table_exists;
	IF int_table_exists=0 THEN	dbms_output.put_line('B: '||ownerB||'.'||tableB||dblinkB|| ' does''nt exist or we don''t have privileges!!!');	there_is_error:=1;	END IF;

	IF there_is_error=1 THEN
		dbms_output.put_line('Aborting execution...');
	ELSE
		dbms_output.put_line('OK');
		dbms_output.put_line('');
		dbms_output.put_line('');
		IF check_only_structure=FALSE THEN 
			-- COUNTS -------------------------------------------------------------------------------------------
			dbms_output.put_line('------------------------------------------------------------------------------');
			dbms_output.put_line('--COUNTS----------------------------------------------------------------------');
			dbms_output.put_line('------------------------------------------------------------------------------');
			EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM '||ownerA||'.'||tableA||dblinkA INTO count_A;
			EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM '||ownerB||'.'||tableB||dblinkB INTO count_B;
			BEGIN
				EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM '||ownerA||'.'||tableA||dblinkA||' A INNER JOIN '||ownerB||'.'||tableB||dblinkB||' B ON '||cross_condition INTO count_A_INNER_B;
				EXCEPTION
					WHEN OTHERS THEN
						dbms_output.put_line('Cross condition is wrong! [wrong field names?]');
						dbms_output.put_line('Aborting execution');
						croos_condition_is_ko:=1;
						there_is_error:=1;
			END;
			IF croos_condition_is_ko=0 THEN
				BEGIN
					EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM '||ownerA||'.'||tableA||dblinkA||' A LEFT JOIN  '||ownerB||'.'||tableB||dblinkB||' B ON '||cross_condition ||' WHERE '||A_not_B_condition INTO count_A_NOT_B;
					EXCEPTION WHEN OTHERS THEN
						dbms_output.put_line('A_NOT_B condition is wrong! [wrong field names?]');
						dbms_output.put_line('Aborting execution');
						A_not_B_condition_is_ko:=1;
						there_is_error:=1;
				END;
				IF A_not_B_condition_is_ko=0 THEN
					BEGIN
						EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM '||ownerB||'.'||tableB||dblinkB||' B LEFT JOIN  '||ownerA||'.'||tableA||dblinkA||' A ON '||cross_condition ||' WHERE '||B_not_A_condition INTO count_B_NOT_A;
						EXCEPTION WHEN OTHERS THEN
							dbms_output.put_line('B_NOT_A condition is wrong! [wrong field names?]');
							dbms_output.put_line('Aborting execution');
							B_not_A_condition_is_ko:=1;
							there_is_error:=1;
					END;
					IF B_not_A_condition_is_ko=0 THEN
						dbms_output.put_line('#A        :'||TO_CHAR(count_A			,'999G999G999'));
						dbms_output.put_line('#B        :'||TO_CHAR(count_B			,'999G999G999'));
						dbms_output.put_line('#A_INNER_B:'||TO_CHAR(count_A_INNER_B	,'999G999G999'));
						dbms_output.put_line('#A_NOT_B  :'||TO_CHAR(count_A_NOT_B	,'999G999G999'));
						dbms_output.put_line('#B_NOT_A  :'||TO_CHAR(count_B_NOT_A	,'999G999G999'));
						dbms_output.put_line('');
						dbms_output.put_line('');
					END IF;
				END IF;
			END IF;
		END IF;
		
		
		IF there_is_error=0 THEN	
			dbms_output.put_line('------------------------------------------------------------------------------');
			dbms_output.put_line('--NOT COMMON INDEX LIST-------------------------------------------------------');
			dbms_output.put_line('------------------------------------------------------------------------------');
			query_string:=
			'
				with A_INDEXES AS
				(
					select  	A.owner,A.index_name
								,LISTAGG(B.column_name,'', '') WITHIN GROUP (ORDER BY B.column_name ASC) AS column_names
								,A.table_name,A.index_type,A.uniqueness,A.tablespace_name
					from    	all_indexes'||dblinkA||' A
								INNER JOIN all_ind_columns'||dblinkA||' B
								ON		A.owner=B.INDEX_OWNER
									AND A.INDEX_NAME=B.INDEX_NAME
					where		A.table_name='''||tableA||'''
								and A.table_owner='''||ownerA||'''
					GROUP BY	A.owner,A.index_name,A.table_name,A.index_type,A.uniqueness,A.tablespace_name
				),
				B_INDEXES AS
				(
					select		A.owner,A.index_name
								,LISTAGG(B.column_name,'', '') WITHIN GROUP (ORDER BY B.column_name ASC) AS column_names
								,A.table_name,A.index_type,A.uniqueness,A.tablespace_name
					from		all_indexes'||dblinkB||' A
								INNER JOIN all_ind_columns'||dblinkB||' B
								ON		A.owner=B.INDEX_OWNER
									AND A.INDEX_NAME=B.INDEX_NAME
					where		A.table_name='''||tableB||'''
								and A.table_owner='''||ownerB||'''
					GROUP BY	A.owner,A.index_name,A.table_name,A.index_type,A.uniqueness,A.tablespace_name
				)
				SELECT  ''A_NOT_B'',A.index_name,A.column_names,A.table_name,A.index_type,A.uniqueness 
				FROM    A_INDEXES A
						LEFT JOIN B_INDEXES B
						ON      A.index_name	=B.index_name 
							AND A.index_type	=B.index_type 
							AND A.uniqueness	=B.uniqueness 
							AND A.column_names	=B.column_names
				WHERE   B.index_name IS NULL
					UNION ALL
					SELECT  ''B_NOT_A'',B.index_name,B.column_names,B.table_name,B.index_type,B.uniqueness 
				FROM    B_INDEXES B
						LEFT JOIN A_INDEXES A
						ON      A.index_name	=B.index_name 
							AND A.index_type	=B.index_type 
							AND A.uniqueness	=B.uniqueness 
							AND A.column_names	=B.column_names 
				WHERE   A.index_name IS NULL
			';
			OPEN emp_cv_compare FOR query_string;
			dbms_output.put_line('          INDEX_NAME                      COLUMN_NAME                     INDEX_TYPE   UNIQUENESS');
			LOOP
				FETCH emp_cv_compare INTO where_is_present,index_name,column_name,table_name,index_type,uniqueness;
				EXIT WHEN emp_cv_compare%NOTFOUND;
				FOR i IN LENGTH(index_name)..31 LOOP	index_name := index_name || ' ';		END LOOP;
				FOR i IN LENGTH(column_name)..31 LOOP	column_name := column_name || ' ';		END LOOP;
				FOR i IN LENGTH(index_type)..12 LOOP	index_type := index_type || ' ';		END LOOP;
				FOR i IN LENGTH(uniqueness)..12 LOOP	uniqueness := uniqueness || ' ';		END LOOP;
				dbms_output.put_line(where_is_present||' : '||index_name||column_name||index_type||uniqueness);
			END LOOP;
			CLOSE emp_cv_compare; 	
			dbms_output.put_line('');
			-- END NOT COMMON INDEX LIST
		END IF;






		IF there_is_error=0 THEN	
			dbms_output.put_line('------------------------------------------------------------------------------');
			dbms_output.put_line('--NOT COMMON CONSTRAINT LIST--------------------------------------------------');
			dbms_output.put_line('------------------------------------------------------------------------------');
			query_string:=
			'
				WITH A_CONSTRAINT AS 
				(
					SELECT 
						A.constraint_name									AS CONSTRAINT_NAME_SOURCE
						,A.CONSTRAINT_TYPE_VERBOSE							AS CONSTRAINT_TYPE_VERBOSE_SOURCE
						,A.table_name||'':''||A.TABLE_COLUMN				AS CONSTRAINT_TABLE_SOURCE
						-- shame on your LONG types, oracle
						--,A.SEARCH_CONDITION 								AS SEARCH_CONDITION
						,''-->''											AS SEPARATOR
						,B.constraint_name									AS CONSTRAINT_NAME_DESTINY
						,B.CONSTRAINT_TYPE_VERBOSE							AS CONSTRAINT_TYPE_VERBOSE_DESTIN
						,CASE	WHEN(	B.owner IS NOT NULL 
										OR B.table_name IS NOT NULL 
										OR B.TABLE_COLUMN IS NOT NULL
									) THEN B.table_name||'':''||B.TABLE_COLUMN
								ELSE NULL 
						END													AS CONSTRAINT_TABLE_DESTINY
					FROM
						(
							--source constraint. Types O,P,R,U,V  
							SELECT		A.constraint_name
										,CASE	WHEN MIN(A.CONSTRAINT_TYPE)=''C'' THEN ''Check''
												WHEN MIN(A.CONSTRAINT_TYPE)=''O'' THEN ''Read only on a view''
												WHEN MIN(A.CONSTRAINT_TYPE)=''P'' THEN ''Primary key''
												WHEN MIN(A.CONSTRAINT_TYPE)=''R'' THEN ''Foreign key''
												WHEN MIN(A.CONSTRAINT_TYPE)=''U'' THEN ''Unique''
												WHEN MIN(A.CONSTRAINT_TYPE)=''V'' THEN ''Check option on a view''		END	AS CONSTRAINT_TYPE_VERBOSE
										,A.owner
										,A.table_name
										,LISTAGG(B.column_name,'','') WITHIN GROUP (ORDER BY B.column_name ASC)				AS TABLE_COLUMN
										-- shame on your LONG types, oracle
										--,NULL																			AS SEARCH_CONDITION
										,MIN(A.r_constraint_name)														AS R_CONSTRAINT_NAME
										,MIN(A.r_owner)																	AS R_OWNER
							FROM		all_constraints'||dblinkA||' A
										-- retrieve the constraints column name
										INNER JOIN all_cons_columns'||dblinkA||' B
										ON A.owner=B.owner AND A.constraint_name=B.constraint_name
							GROUP BY	A.constraint_name,A.owner,A.table_name
							--Shame on you, Oracle... You use a LONG type, non MINinimizable, non MAXimizable, non VARCHAR2-convertible... 
							--So we cannot take those rows
							HAVING		MIN(A.CONSTRAINT_TYPE) NOT IN (''C'')
									
							UNION ALL
							
							--source constraint. Type C  
							SELECT	A.constraint_name
									,CASE	WHEN A.CONSTRAINT_TYPE=''C'' THEN ''Check''
											WHEN A.CONSTRAINT_TYPE=''O'' THEN ''Read only on a view''
											WHEN A.CONSTRAINT_TYPE=''P'' THEN ''Primary key''
											WHEN A.CONSTRAINT_TYPE=''R'' THEN ''Foreign key''
											WHEN A.CONSTRAINT_TYPE=''U'' THEN ''Unique''
											WHEN A.CONSTRAINT_TYPE=''V'' THEN ''Check option on a view''   END		AS CONSTRAINT_TYPE_VERBOSE
									,A.owner
									,A.table_name
									,B.column_name																	AS TABLE_COLUMN
									-- shame on your LONG types, oracle
									--,A.SEARCH_CONDITION
									,A.r_constraint_name
									,A.r_owner
							FROM	all_constraints'||dblinkA||' A
									-- retrieve the constraints column name
									INNER JOIN all_cons_columns'||dblinkA||' B
									ON A.owner=B.owner AND A.constraint_name=B.constraint_name
							WHERE	A.CONSTRAINT_TYPE IN (''C'')		
						) A
						LEFT JOIN
						(
							--destiny constraint  
							SELECT	A.constraint_name
									,CASE	WHEN MIN(A.CONSTRAINT_TYPE)=''C'' THEN ''Check''
											WHEN MIN(A.CONSTRAINT_TYPE)=''O'' THEN ''Read only on a view''
											WHEN MIN(A.CONSTRAINT_TYPE)=''P'' THEN ''Primary key''
											WHEN MIN(A.CONSTRAINT_TYPE)=''R'' THEN ''Foreign key''
											WHEN MIN(A.CONSTRAINT_TYPE)=''U'' THEN ''Unique''
											WHEN MIN(A.CONSTRAINT_TYPE)=''V'' THEN ''Check option on a view''   END AS CONSTRAINT_TYPE_VERBOSE
									,A.owner
									,A.table_name
									,LISTAGG(B.column_name,'','') WITHIN GROUP (ORDER BY B.column_name) AS TABLE_COLUMN
							FROM	all_constraints'||dblinkA||' A
									-- retrieve the constraints column name
									INNER JOIN all_cons_columns'||dblinkA||' B
									ON A.owner=B.owner AND A.constraint_name=B.constraint_name
							GROUP BY
									A.constraint_name,A.owner,A.table_name
						) B
						ON A.R_CONSTRAINT_NAME=B.CONSTRAINT_NAME  AND A.R_OWNER=B.OWNER
					WHERE
						A.owner				='''||ownerA||'''
						and A.table_name	='''||tableA||'''
				),
				B_CONSTRAINT AS 
				(
					SELECT 
						A.constraint_name									AS CONSTRAINT_NAME_SOURCE
						,A.CONSTRAINT_TYPE_VERBOSE							AS CONSTRAINT_TYPE_VERBOSE_SOURCE
						,A.table_name||'':''||A.TABLE_COLUMN				AS CONSTRAINT_TABLE_SOURCE
						-- shame on your LONG types, oracle
						--,A.SEARCH_CONDITION 								AS SEARCH_CONDITION
						,''-->''											AS SEPARATOR
						,B.constraint_name									AS CONSTRAINT_NAME_DESTINY
						,B.CONSTRAINT_TYPE_VERBOSE							AS CONSTRAINT_TYPE_VERBOSE_DESTIN
						,CASE	WHEN(	B.owner IS NOT NULL 
										OR B.table_name IS NOT NULL 
										OR B.TABLE_COLUMN IS NOT NULL
									) THEN B.table_name||'':''||B.TABLE_COLUMN
								ELSE NULL 
						END													AS CONSTRAINT_TABLE_DESTINY
					FROM
						(
							--source constraint. Types O,P,R,U,V  
							SELECT		A.constraint_name
										,CASE	WHEN MIN(A.CONSTRAINT_TYPE)=''C'' THEN ''Check''
												WHEN MIN(A.CONSTRAINT_TYPE)=''O'' THEN ''Read only on a view''
												WHEN MIN(A.CONSTRAINT_TYPE)=''P'' THEN ''Primary key''
												WHEN MIN(A.CONSTRAINT_TYPE)=''R'' THEN ''Foreign key''
												WHEN MIN(A.CONSTRAINT_TYPE)=''U'' THEN ''Unique''
												WHEN MIN(A.CONSTRAINT_TYPE)=''V'' THEN ''Check option on a view''		END	AS CONSTRAINT_TYPE_VERBOSE
										,A.owner
										,A.table_name
										,LISTAGG(B.column_name,'','') WITHIN GROUP (ORDER BY B.column_name ASC)				AS TABLE_COLUMN
										-- shame on your LONG types, oracle
										--,NULL																				AS SEARCH_CONDITION
										,MIN(A.r_constraint_name)															AS R_CONSTRAINT_NAME
										,MIN(A.r_owner)																		AS R_OWNER
							FROM		all_constraints'||dblinkB||' A
										-- retrieve the constraints column name
										INNER JOIN all_cons_columns'||dblinkB||' B
										ON A.owner=B.owner AND A.constraint_name=B.constraint_name
							GROUP BY	A.constraint_name,A.owner,A.table_name
							--Shame on you, Oracle... You use a LONG type, non MINinimizable, non MAXimizable, non VARCHAR2-convertible... 
							--So we cannot take those rows
							HAVING		MIN(A.CONSTRAINT_TYPE) NOT IN (''C'')
									
							UNION ALL
							
							--source constraint. Type C  
							SELECT	A.constraint_name
									,CASE	WHEN A.CONSTRAINT_TYPE=''C'' THEN ''Check''
											WHEN A.CONSTRAINT_TYPE=''O'' THEN ''Read only on a view''
											WHEN A.CONSTRAINT_TYPE=''P'' THEN ''Primary key''
											WHEN A.CONSTRAINT_TYPE=''R'' THEN ''Foreign key''
											WHEN A.CONSTRAINT_TYPE=''U'' THEN ''Unique''
											WHEN A.CONSTRAINT_TYPE=''V'' THEN ''Check option on a view''   END		AS CONSTRAINT_TYPE_VERBOSE
									,A.owner
									,A.table_name
									,B.column_name																	AS TABLE_COLUMN
									-- shame on your LONG types, oracle
									--,A.SEARCH_CONDITION
									,A.r_constraint_name
									,A.r_owner
							FROM	all_constraints'||dblinkB||' A
									-- retrieve the constraints column name
									INNER JOIN all_cons_columns'||dblinkB||' B
									ON A.owner=B.owner AND A.constraint_name=B.constraint_name
							WHERE	A.CONSTRAINT_TYPE IN (''C'')		
						) A
						LEFT JOIN
						(
							--destiny constraint  
							SELECT	A.constraint_name
									,CASE	WHEN MIN(A.CONSTRAINT_TYPE)=''C'' THEN ''Check''
											WHEN MIN(A.CONSTRAINT_TYPE)=''O'' THEN ''Read only on a view''
											WHEN MIN(A.CONSTRAINT_TYPE)=''P'' THEN ''Primary key''
											WHEN MIN(A.CONSTRAINT_TYPE)=''R'' THEN ''Foreign key''
											WHEN MIN(A.CONSTRAINT_TYPE)=''U'' THEN ''Unique''
											WHEN MIN(A.CONSTRAINT_TYPE)=''V'' THEN ''Check option on a view''   END AS CONSTRAINT_TYPE_VERBOSE
									,A.owner
									,A.table_name
									,LISTAGG(B.column_name,'','') WITHIN GROUP (ORDER BY B.column_name) AS TABLE_COLUMN
							FROM	all_constraints'||dblinkB||' A
									-- retrieve the constraints column name
									INNER JOIN all_cons_columns'||dblinkB||' B
									ON A.owner=B.owner AND A.constraint_name=B.constraint_name
							GROUP BY
									A.constraint_name,A.owner,A.table_name
						) B
						ON A.R_CONSTRAINT_NAME=B.CONSTRAINT_NAME  AND A.R_OWNER=B.OWNER
					WHERE
						A.owner				='''||ownerB||'''
						and A.table_name	='''||tableB||'''
				)
				SELECT	''A_NOT_B'' AS SOURCE,A.*
				FROM	A_CONSTRAINT A
						LEFT JOIN B_CONSTRAINT B
						ON		A.CONSTRAINT_NAME_SOURCE			=	B.CONSTRAINT_NAME_SOURCE		
							AND	A.CONSTRAINT_TYPE_VERBOSE_SOURCE	=	B.CONSTRAINT_TYPE_VERBOSE_SOURCE
							AND	A.CONSTRAINT_TABLE_SOURCE			=	B.CONSTRAINT_TABLE_SOURCE		
							AND	A.SEPARATOR							=	B.SEPARATOR						
							--lets consider constraints alpha,beta from tables A,B as equals even if they point to constraints gamma,pi, in table X,Y, even if gamma and pi differ in their names
							--AND	((A.CONSTRAINT_NAME_DESTINY			=	B.CONSTRAINT_NAME_DESTINY)			OR (A.CONSTRAINT_NAME_DESTINY IS NULL			AND B.CONSTRAINT_NAME_DESTINY IS NULL)			)
							AND	((A.CONSTRAINT_TYPE_VERBOSE_DESTIN	=	B.CONSTRAINT_TYPE_VERBOSE_DESTIN)	OR (A.CONSTRAINT_TYPE_VERBOSE_DESTIN IS NULL	AND	B.CONSTRAINT_TYPE_VERBOSE_DESTIN IS NULL)	)
							AND	((A.CONSTRAINT_TABLE_DESTINY		=	B.CONSTRAINT_TABLE_DESTINY)			OR (A.CONSTRAINT_TABLE_DESTINY IS NULL			AND	B.CONSTRAINT_TABLE_DESTINY IS NULL)			)			
							--shame on your LONG type, oracle
							--AND (A.SEARCH_CONDITION=B.SEARCH_CONDITION OR A.SEARCH_CONDITION IS NULL AND B.SEARCH_CONDITION IS NULL)
				WHERE	B.CONSTRAINT_NAME_SOURCE IS NULL
				
				UNION ALL
				
				SELECT	''B_NOT_A'' AS SOURCE,B.*
				FROM	B_CONSTRAINT B
						LEFT JOIN A_CONSTRAINT A
						ON		A.CONSTRAINT_NAME_SOURCE			=	B.CONSTRAINT_NAME_SOURCE		
							AND	A.CONSTRAINT_TYPE_VERBOSE_SOURCE	=	B.CONSTRAINT_TYPE_VERBOSE_SOURCE
							AND	A.CONSTRAINT_TABLE_SOURCE			=	B.CONSTRAINT_TABLE_SOURCE		
							AND	A.SEPARATOR							=	B.SEPARATOR						
							--lets consider constraints alpha,beta from tables A,B as equals even if they point to constraints gamma,pi, in table X,Y, even if gamma and pi differ in their names
							--AND	((A.CONSTRAINT_NAME_DESTINY			=	B.CONSTRAINT_NAME_DESTINY)			OR (A.CONSTRAINT_NAME_DESTINY IS NULL			AND B.CONSTRAINT_NAME_DESTINY IS NULL)			)
							AND	((A.CONSTRAINT_TYPE_VERBOSE_DESTIN	=	B.CONSTRAINT_TYPE_VERBOSE_DESTIN)	OR (A.CONSTRAINT_TYPE_VERBOSE_DESTIN IS NULL	AND	B.CONSTRAINT_TYPE_VERBOSE_DESTIN IS NULL)	)
							AND	((A.CONSTRAINT_TABLE_DESTINY		=	B.CONSTRAINT_TABLE_DESTINY)			OR (A.CONSTRAINT_TABLE_DESTINY IS NULL			AND	B.CONSTRAINT_TABLE_DESTINY IS NULL)			)			
							--shame on your LONG type, oracle
							--AND (A.SEARCH_CONDITION=B.SEARCH_CONDITION OR A.SEARCH_CONDITION IS NULL AND B.SEARCH_CONDITION IS NULL)
				WHERE	A.CONSTRAINT_NAME_SOURCE IS NULL
				ORDER BY 4,1
			';
			--TODO! habria que hacer una primera pasada o una subquery para obtener las máximas longitudes. dividir query_string en dos mitades?
			OPEN emp_cv_compare FOR query_string;
			LOOP
				FETCH emp_cv_compare INTO where_is_present,constraint_name_source,constraint_type_verbose_source,constraint_table_source,separator,constraint_name_destiny,constraint_type_verbose_destin,constraint_table_destiny;
				EXIT WHEN emp_cv_compare%NOTFOUND;
				FOR i IN LENGTH(constraint_name_source)..32 		LOOP	constraint_name_source			:= constraint_name_source || ' ';			END LOOP;
				FOR i IN LENGTH(constraint_type_verbose_source)..20 LOOP	constraint_type_verbose_source	:= constraint_type_verbose_source || ' ';	END LOOP;
				FOR i IN LENGTH(constraint_table_source)..80 		LOOP	constraint_table_source			:= constraint_table_source || ' ';			END LOOP;
				IF constraint_name_destiny IS NOT NULL THEN
					FOR i IN LENGTH(constraint_name_destiny)..32		LOOP	constraint_name_destiny			:= constraint_name_destiny || ' ';			END LOOP;
				END IF;
				IF constraint_type_verbose_destin IS NOT NULL THEN
					FOR i IN LENGTH(constraint_type_verbose_destin)..20 LOOP	constraint_type_verbose_destin	:= constraint_type_verbose_destin || ' ';	END LOOP;
				END IF;
				IF constraint_table_destiny IS NOT NULL THEN
					FOR i IN LENGTH(constraint_table_destiny)..40 		LOOP	constraint_table_destiny		:= constraint_table_destiny || ' ';			END LOOP;
				END IF;
				dbms_output.put_line(where_is_present||': '||constraint_name_source||constraint_type_verbose_source||constraint_table_source||separator||constraint_name_destiny||constraint_type_verbose_destin||constraint_table_destiny);
			END LOOP;
			CLOSE emp_cv_compare;
			dbms_output.put_line('');
			-- END NOT COMMON CONSTRAINT LIST
		END IF;
		





		
		IF there_is_error=0 THEN	
			dbms_output.put_line('------------------------------------------------------------------------------');
			dbms_output.put_line('--NOT COMMON COLUMNS LIST-----------------------------------------------------');
			dbms_output.put_line('------------------------------------------------------------------------------');
			-- in oracle this is fixed to 30, but not in other dbms
			query_length_string := '
										SELECT MAX(LENGTH(COLUMN_NAME)) AS MAX_COLUMN_LENGTH
										FROM
										(
											(SELECT COLUMN_NAME,DATA_TYPE,DATA_LENGTH FROM	 all_tab_cols'||dblinkA||' WHERE	 TABLE_NAME='''||tableA||''' AND OWNER='''||ownerA||''' AND VIRTUAL_COLUMN=''NO'')
											UNION ALL
											(SELECT COLUMN_NAME,DATA_TYPE,DATA_LENGTH FROM	 all_tab_cols'||dblinkB||' WHERE	 TABLE_NAME='''||tableB||''' AND OWNER='''||ownerB||''' AND VIRTUAL_COLUMN=''NO'')
										)';
			EXECUTE IMMEDIATE query_length_string INTO max_column_length;
			query_string:=
			'
				WITH A_COLUMNS AS
				(
					SELECT	COLUMN_NAME
							,COLUMN_ID
							,CASE 	WHEN DATA_TYPE LIKE ''TIMESTAMP(6)''                                        THEN ''TIMESTAMP''
									WHEN DATA_TYPE LIKE ''TIMESTAMP%''                                          THEN DATA_TYPE
									WHEN DATA_TYPE LIKE ''%CHAR%''                                              THEN DATA_TYPE||''(''||DATA_LENGTH||'')''
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NULL AND DATA_SCALE IS NULL THEN DATA_TYPE
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NOT NULL AND DATA_SCALE=0   THEN DATA_TYPE||''(''||DATA_PRECISION||'')''
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NOT NULL AND DATA_SCALE<>0  THEN DATA_TYPE||''(''||DATA_PRECISION||'',''||DATA_SCALE||'')''
									WHEN DATA_TYPE=''FLOAT''  AND DATA_PRECISION=126                            THEN DATA_TYPE
									WHEN DATA_TYPE=''FLOAT''  AND DATA_PRECISION<>126                           THEN DATA_TYPE||''(''||DATA_PRECISION||'')''
									ELSE                                                                           DATA_TYPE END AS DATA_TYPE
							,NULLABLE
							-- ,DEFAULT_VALUE sadly, it has LONG type
					FROM	all_tab_cols'||dblinkA||' 
					WHERE	TABLE_NAME='''||tableA||''' 
							AND OWNER='''||ownerA||''' 
							AND VIRTUAL_COLUMN=''NO''
							AND COLUMN_ID IS NOT NULL
				),
				B_COLUMNS AS
				(
					SELECT	COLUMN_NAME
							,COLUMN_ID
							,CASE 	WHEN DATA_TYPE LIKE ''TIMESTAMP(6)''                                        THEN ''TIMESTAMP''
									WHEN DATA_TYPE LIKE ''TIMESTAMP%''                                          THEN DATA_TYPE
									WHEN DATA_TYPE LIKE ''%CHAR%''                                              THEN DATA_TYPE||''(''||DATA_LENGTH||'')''
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NULL AND DATA_SCALE IS NULL THEN DATA_TYPE
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NOT NULL AND DATA_SCALE=0   THEN DATA_TYPE||''(''||DATA_PRECISION||'')''
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NOT NULL AND DATA_SCALE<>0  THEN DATA_TYPE||''(''||DATA_PRECISION||'',''||DATA_SCALE||'')''
									WHEN DATA_TYPE=''FLOAT''  AND DATA_PRECISION=126                            THEN DATA_TYPE
									WHEN DATA_TYPE=''FLOAT''  AND DATA_PRECISION<>126                           THEN DATA_TYPE||''(''||DATA_PRECISION||'')''
									ELSE                                                                           DATA_TYPE END AS DATA_TYPE
							,NULLABLE
							-- ,DEFAULT_VALUE sadly, it has LONG type
					FROM	all_tab_cols'||dblinkB||' 
					WHERE	TABLE_NAME='''||tableB||''' 
							AND OWNER='''||ownerB||''' 
							AND VIRTUAL_COLUMN=''NO''
							AND COLUMN_ID IS NOT NULL
				)
				SELECT	COLUMN_NAME,DATA_TYPE,NULLABLE
				FROM
				(
					SELECT	''A:''||A.COLUMN_NAME AS COLUMN_NAME,A.DATA_TYPE,A.NULLABLE
					FROM	A_COLUMNS A
							LEFT JOIN B_COLUMNS B
							ON A.COLUMN_NAME=B.COLUMN_NAME AND A.DATA_TYPE=B.DATA_TYPE AND A.NULLABLE=B.NULLABLE
					WHERE	B.COLUMN_NAME IS NULL
					
					UNION ALL
					
					SELECT	''B:''||B.COLUMN_NAME AS COLUMN_NAME,B.DATA_TYPE,B.NULLABLE
					FROM	B_COLUMNS B
							LEFT JOIN A_COLUMNS A
							ON A.COLUMN_NAME=B.COLUMN_NAME AND A.DATA_TYPE=B.DATA_TYPE AND A.NULLABLE=B.NULLABLE
					WHERE	A.COLUMN_NAME IS NULL
				)
				ORDER BY SUBSTR(COLUMN_NAME,3,LENGTH(COLUMN_NAME)) ASC,SUBSTR(COLUMN_NAME,1,2) ASC
			';
			OPEN emp_cv_compare FOR query_string;
			LOOP
				FETCH emp_cv_compare INTO column_name,data_type,nullable;
				EXIT WHEN emp_cv_compare%NOTFOUND;
				FOR i IN LENGTH(column_name)..33 LOOP	column_name := column_name || ' ';		END LOOP;
				FOR i IN LENGTH(data_type)..15 LOOP		data_type := data_type || ' ';			END LOOP;
				FOR i IN LENGTH(nullable)..4 LOOP		nullable := nullable || ' ';			END LOOP;
				dbms_output.put_line(column_name||' : '||data_type||' NULLABLE: '||nullable);
			END LOOP;
			CLOSE emp_cv_compare;
			dbms_output.put_line('');
			-- END NOT COMMON COLUMN LIST
		END IF;	



		
		
		
		IF there_is_error=0 AND check_only_structure=FALSE THEN	
			dbms_output.put_line('------------------------------------------------------------------------------');
			dbms_output.put_line('--COMMON COLUMNS ANALYSIS (FOR COMMON ROWS)-----------------------------------');
			dbms_output.put_line('------------------------------------------------------------------------------');
			query_length_string := '
										SELECT MAX(LENGTH(A.COLUMN_NAME)) AS MAX_COMMON_COLUMN_LENGTH
										FROM
										(
											(SELECT COLUMN_NAME,DATA_TYPE,DATA_LENGTH FROM	 all_tab_cols'||dblinkA||' WHERE	 TABLE_NAME='''||tableA||''' AND OWNER='''||ownerA||''' AND VIRTUAL_COLUMN=''NO'') A
											INNER JOIN
											(SELECT COLUMN_NAME,DATA_TYPE,DATA_LENGTH FROM	 all_tab_cols'||dblinkB||' WHERE	 TABLE_NAME='''||tableB||''' AND OWNER='''||ownerB||''' AND VIRTUAL_COLUMN=''NO'') B
											ON A.COLUMN_NAME=B.COLUMN_NAME AND A.DATA_TYPE=B.DATA_TYPE AND A.DATA_LENGTH=B.DATA_LENGTH
										)';
			EXECUTE IMMEDIATE query_length_string INTO max_column_length;
			query_string:=
			'
				WITH A_COLUMNS AS
				(
					SELECT	COLUMN_NAME
							,COLUMN_ID
							,CASE 	WHEN DATA_TYPE LIKE ''TIMESTAMP(6)''                                        THEN ''TIMESTAMP''
									WHEN DATA_TYPE LIKE ''TIMESTAMP%''                                          THEN DATA_TYPE
									WHEN DATA_TYPE LIKE ''%CHAR%''                                              THEN DATA_TYPE||''(''||DATA_LENGTH||'')''
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NULL AND DATA_SCALE IS NULL THEN DATA_TYPE
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NOT NULL AND DATA_SCALE=0   THEN DATA_TYPE||''(''||DATA_PRECISION||'')''
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NOT NULL AND DATA_SCALE<>0  THEN DATA_TYPE||''(''||DATA_PRECISION||'',''||DATA_SCALE||'')''
									WHEN DATA_TYPE=''FLOAT''  AND DATA_PRECISION=126                            THEN DATA_TYPE
									WHEN DATA_TYPE=''FLOAT''  AND DATA_PRECISION<>126                           THEN DATA_TYPE||''(''||DATA_PRECISION||'')''
									ELSE                                                                           DATA_TYPE END AS DATA_TYPE
							,NULLABLE
							-- ,DEFAULT_VALUE sadly, it has LONG type
					FROM	all_tab_cols'||dblinkA||' 
					WHERE	TABLE_NAME='''||tableA||''' 
							AND OWNER='''||ownerA||''' 
							AND VIRTUAL_COLUMN=''NO''
							AND COLUMN_ID IS NOT NULL
				),
				B_COLUMNS AS
				(
					SELECT	COLUMN_NAME
							,COLUMN_ID
							,CASE 	WHEN DATA_TYPE LIKE ''TIMESTAMP(6)''                                        THEN ''TIMESTAMP''
									WHEN DATA_TYPE LIKE ''TIMESTAMP%''                                          THEN DATA_TYPE
									WHEN DATA_TYPE LIKE ''%CHAR%''                                              THEN DATA_TYPE||''(''||DATA_LENGTH||'')''
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NULL AND DATA_SCALE IS NULL THEN DATA_TYPE
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NOT NULL AND DATA_SCALE=0   THEN DATA_TYPE||''(''||DATA_PRECISION||'')''
									WHEN DATA_TYPE=''NUMBER'' AND DATA_PRECISION IS NOT NULL AND DATA_SCALE<>0  THEN DATA_TYPE||''(''||DATA_PRECISION||'',''||DATA_SCALE||'')''
									WHEN DATA_TYPE=''FLOAT''  AND DATA_PRECISION=126                            THEN DATA_TYPE
									WHEN DATA_TYPE=''FLOAT''  AND DATA_PRECISION<>126                           THEN DATA_TYPE||''(''||DATA_PRECISION||'')''
									ELSE                                                                           DATA_TYPE END AS DATA_TYPE
							,NULLABLE
							-- ,DEFAULT_VALUE sadly, it has LONG type
					FROM	all_tab_cols'||dblinkB||' 
					WHERE	TABLE_NAME='''||tableB||''' 
							AND OWNER='''||ownerB||''' 
							AND VIRTUAL_COLUMN=''NO''
							AND COLUMN_ID IS NOT NULL
				)
				SELECT	A.COLUMN_NAME
				FROM	A_COLUMNS A
						INNER JOIN B_COLUMNS B
						-- TODO! solo para poder usarlo en nuestro caso. habria que dejar el ON gordo
						-- ON A.COLUMN_NAME=B.COLUMN_NAME AND A.DATA_TYPE=B.DATA_TYPE AND A.NULLABLE=B.NULLABLE
						ON A.COLUMN_NAME=B.COLUMN_NAME
			';
			OPEN emp_cv_compare FOR query_string;
			LOOP
				FETCH emp_cv_compare INTO column_name;
				EXIT WHEN emp_cv_compare%NOTFOUND;
				--generate ident-blank-suffix:
				blank_suffix := '';
				FOR i IN LENGTH(column_name)..max_column_length LOOP	blank_suffix := blank_suffix || ' ';	END LOOP;
				IF columns_to_be_checked='%' OR INSTR(columns_to_be_checked,''''||column_name||'''',1)<>0 THEN
					query_string := 
					'
						SELECT	
								COUNT(*) 
						FROM	
								'||ownerA||'.'||tableA||dblinkA||' A 
								INNER JOIN 
								'||ownerB||'.'||tableB||dblinkB||' B 
								ON '||cross_condition||' 
						WHERE 
						(
							(A.'||column_name||' IS NULL		AND	B.'||column_name||' IS NOT NULL	)
							OR
							(A.'||column_name||' IS NOT NULL	AND	B.'||column_name||' IS NULL		)
							OR
							(A.'||column_name||'				<>	B.'||column_name||'				)
						)
					';
					--dbms_output.put_line(query_string);
					EXECUTE IMMEDIATE query_string INTO num_different_rows;
					dbms_output.put_line(column_name || blank_suffix || ':' || num_different_rows);
				END IF;
			END LOOP;
			CLOSE emp_cv_compare;
			dbms_output.put_line('');
			-- END COMMON COLUMNS ANALYSIS (FOR COMMON ROWS)
		END IF;


	END IF;
	
	
	-- print time elapsed stuff
	EXECUTE IMMEDIATE query_date_string INTO end_sysdate_string;
	dbms_output.put_line('Ends at ' || end_sysdate_string);
	
	EXECUTE IMMEDIATE 'SELECT (TO_DATE('''||end_sysdate_string||''',''yyyy/mm/dd HH24:MI:ss'')-TO_DATE('''||start_sysdate_string||''',''yyyy/mm/dd HH24:MI:ss''))*24*60*60 FROM DUAL' INTO time_elapsed_in_seconds;
	dbms_output.put_line('Time in seconds:' || time_elapsed_in_seconds);
	
	query_string:='select REPLACE('''||time_elapsed_in_seconds||''' ,  '',''  ,  ''.'') FROM DUAL';
	EXECUTE IMMEDIATE query_string INTO time_elapsed_in_seconds_str;
	
	query_string:='
					SELECT	TO_CHAR(TRUNC('||time_elapsed_in_seconds_str||'/3600),''FM9900'') || '':'' ||
							TO_CHAR(TRUNC(MOD(TRUNC('||time_elapsed_in_seconds_str||'),3600)/60),''FM00'') || '':'' ||
							TO_CHAR(MOD(TRUNC('||time_elapsed_in_seconds_str||'),60),''FM00'') 
					FROM DUAL';
	EXECUTE IMMEDIATE query_string INTO time_elapsed;                       
	dbms_output.put_line('Time elapsed   : ' || time_elapsed ||  ' hh:MM:ss');		
END;
/
