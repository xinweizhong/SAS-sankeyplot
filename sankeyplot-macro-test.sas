Options notes nomprint nosymbolgen nomlogic nofmterr nosource nosource2 missing=' ' noquotelenmax linesize=max noBYLINE;
dm "output;clear;log;clear;odsresult;clear;";
proc delete data=_all_; run;
%macro rootpath;
%global program_path program_name;
%if %symexist(_SASPROGRAMFILE) %then %let _fpath=%qsysfunc(compress(&_SASPROGRAMFILE,"'"));
	%else %let _fpath=%sysget(SAS_EXECFILEPATH);
%let program_path=%sysfunc(prxchange(s/(.*)\\.*/\1/,-1,%upcase(&_fpath.)));
%let program_name=%scan(&_fpath., -2, .\);
%put NOTE: ----[program_path = &program_path.]----;
%put NOTE: ----[program_name = &program_name.]----;
%mend rootpath;
%rootpath;


%inc "&program_path.\sankeyplot-macro.sas";
%inc "&program_path.\to_sankeyplotdata.sas";

/*Output styles settings*/
options nodate nonumber nobyline;
ods path work.testtemp(update) sasuser.templat(update) sashelp.tmplmst(read);

Proc template;
  define style trial;
    parent=styles.rtf;
    style table from output /
    background=_undef_
    rules=groups
    frame=void
    cellpadding=1pt;
  style header from header /
    background=_undef_
    protectspecialchars=off;
  style rowheader from rowheader /
    background=_undef_;

  replace fonts /
    'titlefont5' = ("courier new",9pt)
    'titlefont4' = ("courier new",9pt)
    'titlefont3' = ("courier new",9pt)
    'titlefont2' = ("courier new",9pt)
    'titlefont'  = ("courier new",9pt)
    'strongfont' = ("courier new",9pt)
    'emphasisfont' = ("courier new",9pt)
    'fixedemphasisfont' = ("courier new",9pt)
    'fixedstrongfont' = ("courier new",9pt)
    'fixedheadingfont' = ("courier new",9pt)
    'batchfixedfont' = ("courier new",9pt)
    'fixedfont' = ("courier new",9pt)
    'headingemphasisfont' = ("courier new",9pt)
    'headingfont' = ("courier new",9pt)
    'docfont' = ("courier new",9pt);

  style body from body /
    leftmargin=0.1in
    rightmargin=0.1in
    topmargin=0.1in
    bottommargin=0.1in;

  class graphwalls / 
            frameborder=off;
   end;
run;

options source source2;
*************test data01******;
proc import datafile="&program_path.\sankeybarchart-test.xlsx"
  out=nodes
  dbms=excel replace;
  sheet ='nodes1';
  getnames=yes;
quit;

proc import datafile="&program_path.\sankeybarchart-test.xlsx"
  out=links
  dbms=excel replace;
  sheet ='links1';
  getnames=yes;
quit;
*************test data02******;
proc import datafile="&program_path.\sankeybarchart-test.xlsx"
  out=nodes1
  dbms=excel replace;
  sheet ='nodes2';
  getnames=yes;
quit;

proc import datafile="&program_path.\sankeybarchart-test.xlsx"
  out=links1
  dbms=excel replace;
  sheet ='links2';
  getnames=yes;
quit;

ods _all_ close;
title;footnote;
ods results on;
goption device=pdf;
options topmargin=0.1in bottommargin=0.1in leftmargin=0.1in rightmargin=0.1in;
options orientation=landscape nodate nonumber;
ods pdf file="&program_path.\sankeyplot-macro-test.pdf"  style=trial nogtitle nogfoot ;

ods graphics on; 
ods graphics /reset  noborder maxlegendarea=55  outputfmt =pdf height = 7.2 in width = 10.6in  attrpriority=none;
ods escapechar='^';

%sankeyplot(nodes_data=nodes
					,links_data=links
					,barwidth=
					,interpol=
					,ybystep=
					,node_transparency=
					,graphics_options=
					,plotyn=
					,debug=zxw);


%sankeyplot(nodes_data=nodes1
					,links_data=links1
					,barwidth=
					,interpol=
					,ybystep=
					,node_transparency=
					,graphics_options=
					,plotyn=
					,debug=);
ods pdf close;
ods listing;


**********************************************************************************************;

data myfmt;
	length fmtname start label $200.; 
	do noden=1 to 6;
		fmtname=cats('cycgr',noden,'_');  
		do catn=1 to 10;
		    start=cats(catn);   
		    label=cats('Node',put(noden,z2.),'_Cat',put(catn,z2.));  
			output;
		end;
		
		do catn=31.1,41.1,51.1,61.1;   
		    start=cats(catn);   
		    label="EOT01";  
			if int(catn/10)=noden then output;
		end;
		do catn=41.2,51.2,61.2;   
		    start=cats(catn);   
		    label="EOT02";  
			if int(catn/10)=noden then output;
		end;
		do catn=51.3,61.3;   
		    start=cats(catn);   
		    label="DEATH";  
			if int(catn/10)=noden then output;
		end;
		do catn=61.4;   
		    start=cats(catn);   
		    label="EOS";  
			if int(catn/10)=noden then output;
		end;
	end;
	keep start fmtname label;
run;
data myfmt;
	set myfmt;
	fmtname=cats('@',fmtname);
	label_=label;
	label=start;
	start=label_;
run;
proc sort ;
	by fmtname;
run;
proc format cntlin=myfmt; run;
/*proc sql;*/
/*	create table CATALOGS as select **/
/*		from DICTIONARY.CATALOGS*/
/*			where libname='WORK';*/
/*quit;*/
proc import datafile="&program_path.\sankey-rawdata.xlsx"
  out=sankeyrawdata
  dbms=excel replace;
  sheet ='rawdata2';
  getnames=yes;
quit;

%to_sankeyplotdata(indat=sankeyrawdata
					,casevar=subjid
					,nodesvar=%str(cycstt01|cycstt02|cycstt03|cycstt04|cycstt05|cycstt06)
					,nodesvarinfmt=%str(cycgr1_.|cycgr2_.|cycgr3_.|cycgr4_.|cycgr5_.|cycgr6_.)
					,nodesvarn=
					,nodeslabel=%str(Node 01| |Node 03)
					,colorlist=
					,links_transparency=
					,node_cat_gapwidth=
					,debug=);

ods _all_ close;
title;footnote;
ods results on;
goption device=pdf;
options topmargin=0.1in bottommargin=0.1in leftmargin=0.1in rightmargin=0.1in;
options orientation=landscape nodate nonumber;
ods pdf file="&program_path.\sankeyplot-macro-test1.pdf"  style=trial nogtitle nogfoot ;

ods graphics on; 
ods graphics /reset  noborder maxlegendarea=55  outputfmt =pdf height = 7.2 in width = 10.6in  attrpriority=none;
ods escapechar='^';

data Sankey_nodes1;
	set Sankey_nodes;
	if (node=4 and node_cat=41.1) or (node=5 and node_cat=51.1) then do; 
		node_cat_label='';
		node_cat_color='BLANK';
	end;
	if (node=5 and node_cat=51.2) then do; 
		node_cat_label='';
		node_cat_color='BLANK';
	end;
	if node=6 and node_cat=61.3 then do; 
		node_cat_label='';
		node_cat_color='BLANK';
	end;
run;
data Sankey_links1;
	set Sankey_links;
	if node=3 and node_cat=31.1 then do; 
		next_node=6;
		next_node_cat=61.1;
	end;
	if node=4 and node_cat=41.2 then do; 
		next_node=6;
		next_node_cat=61.2;
	end;
	if (node=4 and node_cat=41.1) or (node=5 and node_cat=51.1) or (node=5 and node_cat=51.2) then delete;
run;

%sankeyplot(nodes_data=Sankey_nodes1
					,links_data=Sankey_links1
					,barwidth=
					,interpol=
					,ybystep=
					,node_transparency=
					,graphics_options=
					,plotyn=
					,debug=);
ods pdf close;
ods listing;


