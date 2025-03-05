/*************************************************************************************************
File name:      to_sankeyplotdata.sas
 
Study:         
 
SAS version:    9.4
 
Purpose:        
 
Macros called:  %to_sankeyplotdata
 
Notes:
 
Parameters:
 
Sample:
 
Date started:    28FEB2025
Date completed:  
 
Mod     Date            Name            Description
---     -----------     ------------    -----------------------------------------------
1.0     28FEB2025       Xinwei.Zhong    Created.
 
 
************************************ Prepared by Xinwei************************************/

*%backup_program;
%macro varlsexist(data=,varls=);
    %let dsid = %sysfunc(open(&data)); 
	%let _dsn=%eval(%sysfunc(count(&varls.,|))+1);
	%let noexistvar=;
    %if &dsid %then %do; 
	   %do _i_v=1 %to &_dsn.;
	   	   %let _var=%scan(&varls.,&_i_v.,|);
		   %global typ_&_var.;
	       %let varnum = %sysfunc(varnum(&dsid,&_var.));
	       %if &varnum.=0 %then %let noexistvar=%str(&noexistvar. &_var.);
		   	%else %let typ_&_var. = %sysfunc(vartype(&dsid., &varnum.));
	   %end;
	   %let rc = %sysfunc(close(&dsid));
    %end;%else %do;
       %put ERR%str()OR: Dataset[&data.] not exist, please check!!;
       %abort cancel;
    %end;
    %if %length(&noexistvar.)>0 %then %do;
       %put ERR%str()OR: Variable[&noexistvar.] not exist in dataset[&data.], please check!!;
       %abort cancel;
    %end;
%mend varlsexist;

%macro to_sankeyplotdata(indat=
					,casevar=
					,nodesvar=
					,nodesvarinfmt=
					,nodesvarn=
					,nodeslabel=
					,colorlist=
					,links_transparency=
					,node_cat_gapwidth=
					,debug=);

%put NOTE: -------------------- Macro[&SYSMACRONAME.] Start --------------------;
*****parameter control****;
%if %length(&indat.)=0 or %length(&nodesvar.)=0 %then %do;
	%put ERR%str()OR: Parameter[indat] or [nodesvar] uninitialized, please check!!;
	%return;
%end;
%if %sysfunc(exist(&indat.))=0 %then %do;
	%put ERR%str()OR: DataSet[indat = &indat.] no exist, please check!!;
	%return;
%end;
%if %length(&casevar.)=0 %then %let casevar=usubjid;
%if %length(&links_transparency.)=0 %then %let links_transparency=0.6;
%if %length(&node_cat_gapwidth.)=0 %then %let node_cat_gapwidth=2;

*******check dataset variable *********;
%let _chkvarls=%str(&casevar.);
%let nodesvar=%sysfunc(tranwrd(&nodesvar.,#,|));
%let nodesvarn=%sysfunc(tranwrd(&nodesvarn.,#,|));
%let nodesvarinfmt=%sysfunc(tranwrd(&nodesvarinfmt.,#,|));
%let nodeslabel=%sysfunc(tranwrd(&nodeslabel.,#,|));
%if "%substr(&nodesvar.,%length(&nodesvar.),1)"="|" %then %let nodesvar=%substr(&nodesvar.,1,%eval(%length(&nodesvar.)-1));


%let nodesvar_n=%sysfunc(count(&nodesvar.,|));
%if &nodesvar_n.<2 %then %do;
	%put ERR%str()OR: The number of variables must be greater than 1, please check!!;
	%return;
%end;
%if %length(&nodesvarn.)>0 %then %do;
	%let nodesvarn_n=%sysfunc(count(&nodesvarn.,|));
	%if &nodesvar_n.^=&nodesvarn_n. %then %do;
		%put ERR%str()OR: Some variables do not specify corresponding numeric variables, please check!!;
		%return;
	%end;
%end;%else %do;
	%let nodesvarinfmt_n=%sysfunc(count(&nodesvarinfmt.,|));
	%if &nodesvar_n.^=&nodesvarinfmt_n. %then %do;
		%put ERR%str()OR: Some variables do not specify corresponding variables informat, please check!!;
		%return;
	%end;
%end;
%let _chkvarls=%str(&_chkvarls.|&nodesvar.|&nodesvarn.);
%if "%substr(&_chkvarls.,%length(&_chkvarls.),1)"="|" %then %let _chkvarls=%substr(&_chkvarls.,1,%eval(%length(&_chkvarls.)-1));

%varlsexist(data=&indat.,varls=%str(&casevar.|&nodesvar.));


%let _colorlist=%str(CXA6CEE3#CX1F78B4#CXB2DF8A#CX33A02C#CXFB9A99#CXE31A1C#CXFDBF6F#CXFF7F00#CXCAB2D6#CX6A3D9A#CXFFFF00#CXB15928);

%if %length(&debug.)=0 %then %let debug=0;
%if "&debug."^="zxw" %then %let debug=0;

%let nodesvar_n=%eval(&nodesvar_n.+1);
*******************************************************************************;
data __sankeyrawdata;
	set &indat.;
	%do _i=1 %to &nodesvar_n.;
		%if %length(&nodesvarn.)>0 %then %do;
			%let _varn=%scan(&nodesvarn.,&_i.,|);
			__varn&_i.=&_varn.;
		%end;%else %do;
			%let _varifmt=%scan(&nodesvarinfmt.,&_i.,|);
			%let _var=%scan(&nodesvar.,&_i.,|);
			__varn&_i.=input(&_var.,&_varifmt.);
		%end;
		if missing(__varn&_i.) then put "ERR" "OR: " &_var.= __varn&_i.= "Character variable values correspond to numeric type missing, please check!!";
	%end;
	attrib _all_ label='';
run;

data __sankeyrawdata1;
	length node_cat_label nextnode_cat_label $300.;
	set %do _i=1 %to %eval(&nodesvar_n.-1);
		%let _var=%scan(&nodesvar.,&_i.,|);
		%let _nextvar=%scan(&nodesvar.,%eval(&_i.+1),|);
		%let _ii=%eval(&_i.+1);
		__sankeyrawdata(in=a&_i. keep=&casevar. &_var. __varn&_i. &_nextvar. __varn&_ii. 
			rename=( &_var.=node_cat_label __varn&_i.=node_cat &_nextvar.=nextnode_cat_label __varn&_ii.=next_node_cat ))
	%end; ;
	%do _i=1 %to %eval(&nodesvar_n.-1);
		%let _ii=%eval(&_i.+1);
		if a&_i. then do; node=&_i.; next_node=&_ii.; end;
	%end;
run;

proc sql noprint;
	select count(distinct &casevar.) into: subjn trimmed from __sankeyrawdata;
	%do _i=1 %to &nodesvar_n.;
		%let _var=%scan(&nodesvar.,&_i.,|);
		create table __nodes&_i. as select distinct &_i. as node,"%scan(&nodeslabel.,&_i.,|)" as node_label length=200
				,__varn&_i. as node_cat,&_var. as node_cat_label,count(distinct &casevar.) as node_n 
			from __sankeyrawdata group by __varn&_i.,&_var.;
	%end;

	create table __links1 as select distinct node,node_cat,next_node
		,next_node_cat,count(distinct &casevar.) as node_n 
		from __sankeyrawdata1 group by node,node_cat,next_node,next_node_cat;
quit;

data sankey_nodes;
	length node_label node_cat_label $400.;
	set %do _i=1 %to &nodesvar_n.;
		__nodes&_i.(in=a&_i.)
	%end; ;
	node_pct=node_n/&subjn.*100;
	node_cat_gapwidth=&node_cat_gapwidth.;
	output;
run;
proc sort data=sankey_nodes;
	by node node_cat;
run;
data sankey_nodes;
	set sankey_nodes;
	by node node_cat;
	retain order_n ;
	if first.node then order_n=0;
		order_n+1;
	length node_cat_color node_cat_color_REF $50.;
	%do _i=1 %to &nodesvar_n.;
		%let colorlist_=%scan(&colorlist.,&_i.,|);
		if node=&_i. then node_cat_color=strip(scan("&colorlist_.",order_n,"#"));
	%end; 
	node_cat_color_REF=strip(scan("&_colorlist.",order_n,"#"));
	if missing(node_cat_color) then node_cat_color=node_cat_color_REF;
	drop node_cat_color_REF;
run;
data sankey_nodes;
	retain node node_label node_cat node_cat_label node_n node_pct node_cat_gapwidth order_n;
	set sankey_nodes;
run;

data sankey_links;
	set __links1;
	to_next_node_pct=node_n/&subjn.*100;
	length link_next_node_cat_color $50.;
	link_next_node_cat_color='';
	transparency=&links_transparency.;
run;
proc sort data=sankey_links;
	by node node_cat next_node next_node_cat ;
run;

%if "&debug."="0" %then %do;
proc datasets nolist;
	delete __sankeyrawdata: __nodes: __links:; 
	;
quit;
%end;
%put NOTE: -------------------- Macro[&SYSMACRONAME.] End --------------------;
%mend to_sankeyplotdata;
