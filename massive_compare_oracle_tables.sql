/*
	TODO!
	escupir salida tanto a stdout como a una tabla (flag booleano, esquema tabla salida, nombre tabla salida)
	TODO! especificar un orden en las tablas
*/



/*
	compare_massive_oracle_tables_v0.7.sql
	2016/04/21, v0.5
	Daniel González Marcos
	dagonzalezm@indra.es
	@glezo1
	Avenida de Bruselas, Rojo 2, 124 [As of 2016/04/21]

	USO:
		Este script compara diferencias entre N parejas de tablas, tanto cambios estructurales como de contenido.
		Mostrará:
			-Existencia y permisos de lectura de todas las ambas tablas.
			-Conteo de registros en la tabla A, en la tabla B, en A\B, en B\A y en A INNER B, para todo par de tablas A-B.
			-Columnas no comunes (cuyo nombre difiere entre ambas tablas o cuyo nombre es igual pero difiere en su tipo) para todo par de tablsa A-B.
			-Para los registros pertenecientes a la intersección entre ambas tablas, indicará cuántos registros difieren en qué columnas, para todo par de tablas A-B.
--		Reemplazar las constantes del bloque inmediatamente inferior ownerA, ownerB, tableA, tableB, cross_condition, A_not_B_condition and B_not_A_condition and columns_to_be_checked.
--		ownerA:					Esquema de la primera de las tablas que se desesa comparar.
--		tableA:					Nombre de la primera de las tablas que se desea comparar.
--		ownerB:					Esquema de la segunda de las tablas que se desesa comparar.
--		tableB:					Nombre de la segunda de las tablas que se desea comparar.
--		cross_condition:		Condición de cruce entre ambas tablas, tal que A.column1=B.column1 AND A.column2=B.column2 AND ... [Condición de inner join, típicamente PK]
--		A_not_B_condition:		Condición de no pertenencia a B, tal que B.column1 IS NULL [La condición que se impondría para conseguir A\B usando un LEFT JOIN]
--		B_not_A_condition:		Condición de no pertenencia a A, tal que A.column1 IS NULL [La condición que se impondría para conseguir B\A usando un LEFT JOIN]
--		columns_to_be_checked:	Especificar '%' para comparar todas las columnas, o una lista de columnas tal que ' ''column_1'' , ''column_2'' , ...'
--		Requiere el acceso a lectura a la tabla all_tab_cols.
--		
--	USE:
--		This plsql compares two specified tables, both structural and content differences.
--		It will display:
--			-Existence and read-privileges for both tables.
--			-Count of records in table A, in table B, in A\B, in B\A and in A INNER B.
--			-Non common columns (Those columns whose name is different, or whose name is the same but differ in their column type).
--			-For the records belonging to A INNER B, it will display how many rows differ per column, for each and every column.
--		Replace the below constants ownerA, ownerB, tableA, tableB, cross_condition, A_not_B_condition, B_not_A_condition and columns_to_be_checked.
--		ownerA:					The schema of the first table to be compared.
--		tableA:					The name of the first table to be compared.
--		ownerB:					The schema of the second table to be compared.
--		tableB:					The name of the second table to be compared.
--		cross_condition:		shall be in the shape of A.column1=B.column1 AND A.column2=B.column2 AND ... [inner join condition, typically primary key]
--		A_not_B_condition:		shall be in the shape of B.column1 IS NULL [the way you would achieve A\B by means of a LEFT JOIN]
--		B_not_A_condition:		shall be in the shape of A.column1 IS NULL [the way you would achieve B\A by means of a LEFT JOIN]
--		columns_to_be_checked:	shall be '%' (for all columns) or ' ''column_1'' , ''column_2'' , ...'
--		It requires read access to the table all_tab_cols.
	Feel free to send any request for change.
	VERSION_TRACK:
		0.6
			Two separate metadata table, in order to allow concurrent different tests by different users
		0.7
			dblink supported
			
	DROP TABLE pre_webfocus.massive_compare_metadata_prof;
	DROP TABLE pre_webfocus.massive_compare_metadata_cross;
	CREATE TABLE pre_webfocus.massive_compare_metadata_cross
	(
		id						VARCHAR2(50) NOT NULL
		,ownerA					VARCHAR(512)
		,ownerB					VARCHAR(512)
		,tableA					VARCHAR(512)
		,tableB					VARCHAR(512)
		,cross_condition		VARCHAR(512)
		,A_not_B_condition		VARCHAR(512)
		,B_not_A_condition		VARCHAR(512)
		,CONSTRAINT mas_compare_met_cross_pk PRIMARY KEY (id)
	);
	-- pre_webfocus.TBDEP% vs webfocus
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('300_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP300_HIST_SOLICITUDES','TBDEP300_HIST_SOLICITUDES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('302_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP302_HIST_VALORACIONES','TBDEP302_HIST_VALORACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_VALORACION=B.ID_VALORACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('303_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP303_HIST_DICTAMENES','TBDEP303_HIST_DICTAMENES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_DICTAMEN=B.ID_DICTAMEN','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('304_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP304_HIST_ASIG_GRADO','TBDEP304_HIST_ASIG_GRADO','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_ASIGNACION_GRADO=B.ID_ASIGNACION_GRADO','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('305_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP305_HIST_REC_PIA','TBDEP305_HIST_REC_PIA','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PIA_RESOLUCION=B.ID_PIA_RESOLUCION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('306_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP306_HIST_PRESTACIONES','TBDEP306_HIST_PRESTACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PIA_RESOLUCION=B.ID_PIA_RESOLUCION AND A.ID_PRESTACION=B.ID_PRESTACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('307_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP307_HIST_ARCHIVADOS','TBDEP307_HIST_ARCHIVADOS','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_ARCHIVADO=B.ID_ARCHIVADO','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('308_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP308_HIST_TRASLADOS','TBDEP308_HIST_TRASLADOS','A.ID_EXPEDIENTE_ORIGEN=B.ID_EXPEDIENTE_ORIGEN AND A.ID_EXPEDIENTE_TRASLADO=B.ID_EXPEDIENTE_TRASLADO','B.ID_EXPEDIENTE_ORIGEN IS NULL','A.ID_EXPEDIENTE_ORIGEN IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('350_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP350_REGISTRO_EXPEDIENTE','TBDEP350_REGISTRO_EXPEDIENTE','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('351_prewebfocus_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','TBDEP351_PRESTACIONES','TBDEP351_PRESTACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PRESTACION=B.ID_PRESTACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	-- pre_webfocus.AINI% vs webfocus
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('300_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI300_HIST_SOLICITUDES','TBDEP300_HIST_SOLICITUDES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('302_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI302_HIST_VALORACIONES','TBDEP302_HIST_VALORACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_VALORACION=B.ID_VALORACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('303_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI303_HIST_DICTAMENES','TBDEP303_HIST_DICTAMENES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_DICTAMEN=B.ID_DICTAMEN','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('304_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI304_HIST_ASIG_GRADO','TBDEP304_HIST_ASIG_GRADO','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_ASIGNACION_GRADO=B.ID_ASIGNACION_GRADO','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('305_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI305_HIST_REC_PIA','TBDEP305_HIST_REC_PIA','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PIA_RESOLUCION=B.ID_PIA_RESOLUCION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('306_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI306_HIST_PRESTACIONES','TBDEP306_HIST_PRESTACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PIA_RESOLUCION=B.ID_PIA_RESOLUCION AND A.ID_PRESTACION=B.ID_PRESTACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('307_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI307_HIST_ARCHIVADOS','TBDEP307_HIST_ARCHIVADOS','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_ARCHIVADO=B.ID_ARCHIVADO','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('308_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI308_HIST_TRASLADOS','TBDEP308_HIST_TRASLADOS','A.ID_EXPEDIENTE_ORIGEN=B.ID_EXPEDIENTE_ORIGEN AND A.ID_EXPEDIENTE_TRASLADO=B.ID_EXPEDIENTE_TRASLADO','B.ID_EXPEDIENTE_ORIGEN IS NULL','A.ID_EXPEDIENTE_ORIGEN IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('350_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI350_REGISTRO_EXPEDIENTE','TBDEP350_REGISTRO_EXPEDIENTE','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('351_prewebfocus.aini_vs_webfocus','PRE_WEBFOCUS','WEBFOCUS','AINI351_PRESTACIONES','TBDEP351_PRESTACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PRESTACION=B.ID_PRESTACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	-- pre_webfocus.AINI% vs pre_webfocus.AINC
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('300_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI300_HIST_SOLICITUDES',	'AINC300_HIST_SOLICITUDES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('302_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI302_HIST_VALORACIONES',	'AINC302_HIST_VALORACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_VALORACION=B.ID_VALORACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('303_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI303_HIST_DICTAMENES',	'AINC303_HIST_DICTAMENES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_DICTAMEN=B.ID_DICTAMEN','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('304_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI304_HIST_ASIG_GRADO',	'AINC304_HIST_ASIG_GRADO','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_ASIGNACION_GRADO=B.ID_ASIGNACION_GRADO','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('305_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI305_HIST_REC_PIA',		'AINC305_HIST_REC_PIA','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PIA_RESOLUCION=B.ID_PIA_RESOLUCION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('306_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI306_HIST_PRESTACIONES',	'AINC306_HIST_PRESTACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PIA_RESOLUCION=B.ID_PIA_RESOLUCION AND A.ID_PRESTACION=B.ID_PRESTACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('307_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI307_HIST_ARCHIVADOS',	'AINC307_HIST_ARCHIVADOS','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_ARCHIVADO=B.ID_ARCHIVADO','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('308_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI308_HIST_TRASLADOS',		'AINC308_HIST_TRASLADOS','A.ID_EXPEDIENTE_ORIGEN=B.ID_EXPEDIENTE_ORIGEN AND A.ID_EXPEDIENTE_TRASLADO=B.ID_EXPEDIENTE_TRASLADO','B.ID_EXPEDIENTE_ORIGEN IS NULL','A.ID_EXPEDIENTE_ORIGEN IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('350_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI350_REGISTRO_EXPEDIENTE','AINC350_REGISTRO_EXPEDIENTE','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');
	INSERT INTO pre_webfocus.massive_compare_metadata_cross(id,ownerA,ownerB,tableA,tableB,cross_condition,A_not_B_condition,B_not_A_condition) VALUES
	('351_prewebfocus.aini_vs_prewebfocus.ainc','PRE_WEBFOCUS','PRE_WEBFOCUS','AINI351_PRESTACIONES',		'AINC351_PRESTACIONES','A.ID_EXPEDIENTE=B.ID_EXPEDIENTE AND A.ID_PRESTACION=B.ID_PRESTACION','B.ID_EXPEDIENTE IS NULL','A.ID_EXPEDIENTE IS NULL');


	CREATE TABLE pre_webfocus.massive_compare_metadata_prof
	(
		id						INT NOT NULL
		,profile_alias			VARCHAR(512)
		,table_pair_id			VARCHAR2(50) NOT NULL
		,columns_to_be_checked	VARCHAR(512)
		,CONSTRAINT mas_compare_met_prof_pk PRIMARY KEY (id,table_pair_id)
		,CONSTRAINT mas_compare_met_prof_fk FOREIGN KEY (table_pair_id) REFERENCES massive_compare_metadata_cross(id)
	);
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','300_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','302_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','303_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','304_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','305_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','306_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','307_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','308_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','350_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(1,'prewebfocus_vs_webfocus:Todo','351_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(2,'prewebfocus_vs_webfocus:Histórico','300_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(2,'prewebfocus_vs_webfocus:Histórico','302_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(2,'prewebfocus_vs_webfocus:Histórico','303_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(2,'prewebfocus_vs_webfocus:Histórico','304_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(2,'prewebfocus_vs_webfocus:Histórico','305_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(2,'prewebfocus_vs_webfocus:Histórico','306_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(2,'prewebfocus_vs_webfocus:Histórico','307_prewebfocus_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(2,'prewebfocus_vs_webfocus:Histórico','308_prewebfocus_vs_webfocus','%');
	-- pre_webfocus.AINI vs webfocus.TBDEP
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','300_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','302_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','303_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','304_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','305_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','306_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','307_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','308_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','350_prewebfocus.aini_vs_webfocus','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(3,'prewebfocus.AINI_vs_webfocus:Todo','351_prewebfocus.aini_vs_webfocus','%');
	-- pre_webfocus.AINI vs pre_webfocus.AINC
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','300_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','302_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','303_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','304_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','305_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','306_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','307_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','308_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','350_prewebfocus.aini_vs_prewebfocus.ainc','%');
	INSERT INTO pre_webfocus.massive_compare_metadata_prof(id,profile_alias,table_pair_id,columns_to_be_checked) VALUES
	(4,'prewebfocus.AINI_vs_prewebfocus:Todo','351_prewebfocus.aini_vs_prewebfocus.ainc','%');

*/

SET SERVEROUTPUT ON
DECLARE
	TYPE EmpCurTyp IS REF CURSOR;
	emp_cv   EmpCurTyp;

	/*CONSTANT-DEFINITION[massive_compare_oracle_tables]***************************************************************************/
	owner_metatable_profile	VARCHAR2(32767)					:= 'PRE_SISAAD';
	name_metatable_profile	VARCHAR2(32767)					:= 'MASSIVE_COMPARE_METADATA_PROF';
	owner_metatable_cross	VARCHAR2(32767)					:= 'PRE_SISAAD';
	name_metatable_cross	VARCHAR2(32767)					:= 'MASSIVE_COMPARE_METADATA_CROSS';
	profile_to_be_executed	VARCHAR2(32767)					:= '14';
	/*END*CONSTANT-DEFINITION[massive_compare_oracle_tables]***********************************************************************/

	/*VARIABLE-DEFINITION[massive_compare_oracle_tables]***************************************************************************/
	global_start_sysdate_string		VARCHAR(20)	:='';
	global_end_sysdate_string		VARCHAR(20)	:='';
	global_t_elapsed_in_seconds		NUMBER;
	global_t_elapapsed_in_sec_str	VARCHAR(50) :='';
	global_t_elapsed				VARCHAR(50) :='';
	/*END*VARIABLE-DEFINITION[massive_compare_oracle_tables]***********************************************************************/

	
	/*VARIABLE-DEFINITION**********************************************************************************************************/
	ownerA VARCHAR2(32767)					:= '';
	ownerB VARCHAR2(32767)					:= '';
	tableA VARCHAR2(32767)					:= '';
	tableB VARCHAR2(32767)					:= '';
	dblinkA VARCHAR2(32767)					:= '';
	dblinkB VARCHAR2(32767)					:= '';
	cross_condition VARCHAR2(32767)			:='';
	A_not_B_condition VARCHAR2(32767)		:='';
	B_not_A_condition VARCHAR2(32767)		:='';
	columns_to_be_checked VARCHAR2(32767)	:='%';
	/*END*VARIABLE-DEFINITION******************************************************************************************************/
	
	
	
	start_sysdate_string		VARCHAR(20)	:='';
	end_sysdate_string			VARCHAR(20)	:='';
	time_elapsed_in_seconds		NUMBER;
	time_elapsed_in_seconds_str	VARCHAR(50) :='';
	time_elapsed				VARCHAR(50) :='';
	count_A						NUMBER;
	count_B						NUMBER;
	count_A_INNER_B				NUMBER;
	count_A_NOT_B				NUMBER;
	count_B_NOT_A				NUMBER;


	blank_suffix			VARCHAR2(32767)	:= '';
	blank_type_suffix		VARCHAR2(32767)	:= '';
	num_different_rows		NUMBER			:= 0;
	int_tableA_exists		NUMBER			:= 0;
	int_tableB_exists		NUMBER			:= 0;
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
	dbms_output.put_line('massive_compare_oracle_tables.sql v0.7');
	dbms_output.put_line('based on compare_oracle_tables.sql v0.8');
	query_date_string := 'SELECT TO_CHAR(SYSDATE,''yyyy/mm/dd HH24:MI:ss'') FROM DUAL';
	EXECUTE IMMEDIATE query_date_string INTO global_start_sysdate_string;
	dbms_output.put_line('Global process starts at ' || global_start_sysdate_string);

	-- Check wether if metadata tables exists
	query_string := 'SELECT COUNT(*) FROM all_tab_cols WHERE TABLE_NAME='''||name_metatable_profile||''' AND OWNER='''||owner_metatable_profile||''' ';
	EXECUTE IMMEDIATE query_string INTO int_tableA_exists;
	IF int_tableA_exists=0 THEN
		dbms_output.put_line('	Metadata table '||owner_metatable_profile||'.'||name_metatable_profile|| ' does''nt exist or we don''t have privileges!!!');
	END IF;
	query_string := 'SELECT COUNT(*) FROM all_tab_cols WHERE TABLE_NAME='''||name_metatable_cross||''' AND OWNER='''||owner_metatable_cross||''' ';
	EXECUTE IMMEDIATE query_string INTO int_tableB_exists;
	IF int_tableB_exists=0 THEN
		dbms_output.put_line('	Metadata table '||owner_metatable_cross||'.'||name_metatable_cross|| ' does''nt exist or we don''t have privileges!!!');
	END IF;
	IF int_tableA_exists=0 or int_tableB_exists=0 THEN
		dbms_output.put_line('	Aborting execution...');
	ELSE
		OPEN emp_cv FOR  
			'
				SELECT
						B.ownerA,B.ownerB,B.tableA,B.tableB,B.dblinkA,B.dblinkB,B.cross_condition,B.A_not_B_condition,B.B_not_A_condition,A.COLUMNS_TO_BE_CHECKED
				FROM
						'||owner_metatable_profile||'.'||name_metatable_profile||' A
						INNER JOIN
						'||owner_metatable_cross||'.'||name_metatable_cross||' B
						ON A.table_pair_id=B.id
				WHERE
						A.id='||profile_to_be_executed||'
			';
		
		LOOP
			FETCH emp_cv INTO ownerA,ownerB,tableA,tableB,dblinkA,dblinkB,cross_condition,A_not_B_condition,B_not_A_condition,columns_to_be_checked;
			EXIT WHEN emp_cv%NOTFOUND;

			-- -----------------------------------------------------------------------------------------
			-- -----------------------------------------------------------------------------------------
			-- -----------------------------------------------------------------------------------------
			-- CONTENT OF PLSQL SCRIPT compare_oracle_tables_v<X>.sql-----------------------------------
			-- -----------------------------------------------------------------------------------------
			-- -----------------------------------------------------------------------------------------
			-- -----------------------------------------------------------------------------------------
			
		END LOOP;
		CLOSE emp_cv;  
	END IF;
	
	query_date_string := 'SELECT TO_CHAR(SYSDATE,''yyyy/mm/dd HH24:MI:ss'') FROM DUAL';
	EXECUTE IMMEDIATE query_date_string INTO global_end_sysdate_string;
	dbms_output.put_line('Global process ends at ' || global_end_sysdate_string);
	
	EXECUTE IMMEDIATE 'SELECT (TO_DATE('''||global_end_sysdate_string||''',''yyyy/mm/dd HH24:MI:ss'')-TO_DATE('''||global_start_sysdate_string||''',''yyyy/mm/dd HH24:MI:ss''))*24*60*60 FROM DUAL' INTO global_t_elapsed_in_seconds;
	dbms_output.put_line('Time in seconds:' || global_t_elapsed_in_seconds);
	
	query_string:='select REPLACE('''||global_t_elapsed_in_seconds||''' ,  '',''  ,  ''.'') FROM DUAL';
	EXECUTE IMMEDIATE query_string INTO global_t_elapapsed_in_sec_str;
	
	query_string:='
					SELECT	TO_CHAR(TRUNC('||global_t_elapapsed_in_sec_str||'/3600),''FM9900'') || '':'' ||
							TO_CHAR(TRUNC(MOD(TRUNC('||global_t_elapapsed_in_sec_str||'),3600)/60),''FM00'') || '':'' ||
							TO_CHAR(MOD(TRUNC('||global_t_elapapsed_in_sec_str||'),60),''FM00'') 
					FROM DUAL';
	EXECUTE IMMEDIATE query_string INTO global_t_elapsed;                       
	dbms_output.put_line('Time elapsed   : ' || global_t_elapsed ||  ' hh:MM:ss');
END;
/
