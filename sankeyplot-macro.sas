/*************************************************************************************************
File name:      sankeyplot-macro.sas
 
Study:         
 
SAS version:    9.4
 
Purpose:        
 
Macros called:  %sankeyplot
 
Notes:
 
Parameters:
 
Sample:
 
Date started:    27FEB2025
Date completed:  
 
Mod     Date            Name            Description
---     -----------     ------------    -----------------------------------------------
1.0     27FEB2025       Xinwei.Zhong    Created.
 
 
************************************ Prepared by xinwei************************************/

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


%macro split_attrib(attrib_info=,info_ds=);
options noquotelenmax;
%if %length(%nrbquote(&attrib_info.))=0 %then %do;
	%put ERR%str()OR: Parameter[attrib_info] uninitialized, please check!!;
	%abort cancel;
%end;
%if %length(&info_ds.)=0 %then %let info_ds=%str(__split_attrib);
data &info_ds.(drop=_id1 _id2);
	length __info $2000. subcol $500. class attrib $32. attribval $200.;
	__info=tranwrd(tranwrd(tranwrd(tranwrd("%nrbquote(&attrib_info.)",'%/','$#@'),'%\','$##@'),'%|','*#@'),'%=','*##@');
	__info=tranwrd(tranwrd(__info,'%[','$###@'),'%]','$####@');
	if substr(__info,lengthn(__info),1)='|' then __info=substr(__info,1,lengthn(__info)-1);
	do classn=1 to (count(__info,'|')+1);
		_id1=prxparse('/(\w+)=\[([^\[\]]+)\]/');
		subcol=strip(scan(__info,classn,'|'));
		if prxmatch(_id1,subcol) then do;
			class=strip(upcase(prxposn(_id1, 1, subcol)));
			subcol=prxposn(_id1, 2, subcol);
		end; 
		if substr(subcol,lengthn(subcol),1)='/' then subcol=substr(subcol,1,lengthn(subcol)-1);
		start = 1; 
	    finish = length(subcol);
		_id2=prxparse('/(\w+)=([^\/\\]+)/');
	    do ord = 1 by 1 until(start > finish); 
	        call prxnext(_id2, start, finish, subcol, position, length); 
	        if position > 0 then do;
	            attrib = strip(upcase(prxposn(_id2, 1, subcol))); 
	            attribval = prxposn(_id2, 2, subcol); 
				attribval=tranwrd(tranwrd(tranwrd(tranwrd(tranwrd(tranwrd(attribval,'$#@','/'),'$##@','\'),'*#@','|'),'*##@','='),'$###@','['),'$####@',']');
	            output;
	        end;
	        else leave;
	    end;
	end;
run;
%mend split_attrib;

%macro attrib_vmacro(default_attrib=,set_attrib_info=,vmacro_prestr=,debug=);
%if %length(%nrbquote(&default_attrib.))=0 or %length(%nrbquote(&set_attrib_info.))=0 %then %do;
	%put ERR%str()OR: Parameter[default_attrib/set_attrib_info] uninitialized, please check!!;
	%abort cancel;
%end;
%split_attrib(attrib_info=%nrbquote(&default_attrib.),info_ds=%str(__default_attrib));
%split_attrib(attrib_info=%nrbquote(&set_attrib_info.),info_ds=%str(__split_attrib));
%if %length(&debug.)=0 %then %let debug=0;

proc sql undo_policy=none;
	create table __attribval as select a.class,b.class as class0,a.ord,b.ord as ord0
		,a.attrib,b.attrib as attrib0,a.attribval as defaultval,b.attribval
		from __default_attrib as a
		left join __split_attrib as b on a.class=b.class and a.attrib=b.attrib
		order by a.classn,a.class,a.ord;
quit; 
data __attribval;
	set __attribval;
	if attribval='' then do;
		attribval=defaultval; impute=1;
	end;
	length vmacroname $50.;
	vmacroname=cats(class,"_&vmacro_prestr.",attrib);
	if lengthn(vmacroname)>32 then put "ERR" "OR:" vmacroname= "macro variable is too long!";
	call symputx(vmacroname,attribval,'g');
run;
%if "&debug."="0" %then %do;
	proc datasets nolist;
		delete __split_attrib: __default_attrib:;
	quit;
%end;
%mend attrib_vmacro;


%macro sankeyplot(nodes_data=
					,links_data=
					,barwidth=
					,interpol=
					,ybystep=
					,node_transparency=
					,graphics_options=
					,xaxisopts=
					,yaxisopts=
					,node_catlabel_opts=
					,add_annods=
					,plotyn=
					,debug=);

%put NOTE: -------------------- Macro[&SYSMACRONAME.] Start --------------------;
*****parameter control****;
%if %length(&nodes_data.)=0 or %length(&links_data.)=0 %then %do;
	%put ERR%str()OR: Parameter[nodes_data] or [links_data] uninitialized, please check!!;
	%return;
%end;
%if %sysfunc(exist(&nodes_data.))=0 or %sysfunc(exist(&links_data.))=0 %then %do;
	%put ERR%str()OR: DataSet[nodes_data = &nodes_data.] or [nodes_data = &links_data.] no exist, please check!!;
	%return;
%end;
%if %length(&barwidth.)=0 %then %let barwidth=0.05;

%if %length(&interpol.)=0 %then %let interpol=%str(COSINE);
%let interpol=%upcase(&interpol.);
%if "&interpol."^="LINEAR" and "&interpol."^="COSINE" %then %do;
	%put WARN%str()ING: The Macro variable value of [interpol] not in (LINEAR , COSINE), please check!!;
%end;

%if %length(&add_annods.)>0 %then %do;
	%if %sysfunc(exist(&add_annods.))=0 %then %do;
		%put ERR%str()OR: DataSet[add_annods = &add_annods.] no exist, please check!!;
		%return;
	%end;
%end;

%if %length(&ybystep.)=0 %then %let ybystep=5;
%if %length(&node_transparency.)=0 %then %let node_transparency=0;
%if %length(&graphics_options.)=0 %then %let graphics_options=%str(antialiasmax=4200 discretemax=2400);
%if %length(&plotyn.)=0 %then %let plotyn=1; 
%let plotyn=%upcase(&plotyn.);
%if "&plotyn."^="0" and "&plotyn."^="N" and "&plotyn."^="NO" %then %let plotyn=1; 
	%else %let plotyn=0; 
%if %length(&debug.)=0 %then %let debug=0;
%if "&debug."^="zxw" %then %let debug=0;

********** xaxisopts ***********;
%attrib_vmacro(vmacro_prestr=%str(xopt_),set_attrib_info=%nrbquote(X=[&xaxisopts.]),
default_attrib=%nrbquote(X=[display=(tickvalues)/OFFSETMIN=0.03/OFFSETMAX=0.03/TICKFT=Arial/TICKFS=9pt/TICKFW=bold]));
data __attribval_all;
	set __attribval(keep=attrib vmacroname attribval IMPUTE);
run;

********** Yaxisopts ***********;
%attrib_vmacro(vmacro_prestr=%str(xopt_),set_attrib_info=%nrbquote(Y=[&Yaxisopts.]),
default_attrib=%nrbquote(Y=[display=NONE/OFFSETMIN=0.03/OFFSETMAX=0.03/TICKFT=Arial/TICKFS=9pt/TICKFW=bold]));
data __attribval_all;
	set __attribval_all __attribval(keep=attrib vmacroname attribval IMPUTE);
run;

*******check dataset variable *********;
%varlsexist(data=&nodes_data.,varls=%str(node|node_cat|node_pct|node_cat_color));
%varlsexist(data=&links_data.,varls=%str(node|node_cat|next_node|next_node_cat|to_next_node_pct));

*******************************************************************************;
proc sort data=&nodes_data. out=__nodes;
	by node node_cat;
run;
proc sort data=&links_data. out=__links;
	by node node_cat next_node next_node_cat ;
run;

********** node_catlabel_opts ***********;
%attrib_vmacro(vmacro_prestr=%str(ncopt_),set_attrib_info=%nrbquote(L=[&node_catlabel_opts.]),
default_attrib=%nrbquote(L=[display=Y/ANCHOR=ANCHOR/JUST=JUST/BORDER=FALSE/WIDTH=50/TEXTCOLOR=black/TEXTFONT=Arial%/SimSun/TEXTSIZE=9/TEXTWEIGHT=bold/FSTYLE=NORMAL]));
data __attribval_all;
	set __attribval_all __attribval(keep=attrib vmacroname attribval IMPUTE);
run;

proc sort data=__nodes out=__nodes_NC(keep=node) nodupkey;
	where node>.;
	by node;
run;

data __nodes_NC;
	set __nodes_NC end=last;
	by node;
	length _anchor _just anchor just $50.;
	_anchor=strip(upcase(scan("&L_ncopt_ANCHOR.",_n_,"#")));
	_just=strip(upcase(scan("&L_ncopt_JUST.",_n_,"#")));
	anchor="left"; just="right";
	if _n_=1 then do; anchor="left"; just="right"; end;
	if last then do; 
		anchor="right"; just="left";
	end;
	if strip(_anchor) in ('C','R','L','CENTER','RIGHT','LEFT') then anchor=_anchor;
	if strip(_just) in ('C','R','L','CENTER','RIGHT','LEFT') then just=_just;
run;
proc sql noprint;
	select anchor,just into: L_ncopt_ANCHOR separated by "#",: L_ncopt_JUST separated by "#" from __nodes_NC;
quit;

data __attribval_all;
	set __attribval_all;
	if upcase(attrib)='ANCHOR' then attribval="&L_ncopt_ANCHOR.";
	if upcase(attrib)='JUST' then attribval="&L_ncopt_JUST.";
run;

******************************************************************;
 
data __nodes;
	length node_cat_color $500. __node_cat_gr $50.;
	format node_cat_color $500.;
	set __nodes;
	by node node_cat;
	if _n_<1 then do; node_cat_color=''; node_cat_gapwidth=.; node_label=''; node_cat_label=''; end;
	node_label=strip(tranwrd(node_label,"'","''"));
	if first.node then call missing(node_cat_gapwidth);
	if strip(upcase(node_cat_color)) in ('BLANK','#FFFFFF','CXFFFFFF','WHITE') then do;
		node_cat_color='CXFFFFFF';
		blank_node_cat=1;
	end;
	retain low high;
	if first.node then do;
		low=0; high=node_pct;
	end;else do;
		low=sum(high,node_cat_gapwidth); high=sum(low,node_pct);
	end;
	__node_cat_gr=strip(put(node*10000+node_cat*100,best.));
run;

proc sql undo_policy=none;
	create table __links1 as select a.*
		,b.node_pct,b.node_cat_color,b.low,b.high,c.low as next_low,c.high as next_high
		,c.node_cat_color as link_node_cat_color_,c.blank_node_cat
		from __links as a
		left join __nodes as b on a.node=b.node and a.node_cat=b.node_cat
		left join __nodes as c on a.next_node=c.node and a.next_node_cat=c.node_cat
		order by a.node,a.node_cat,a.next_node,a.next_node_cat
	;

	create table __nodes1 as select *,sum(node_pct) as node_pctsum
		from __nodes group by node
		order by node,node_cat;
quit;

data __nodes1;
	set __nodes1;
	by node node_cat;
	if node_pctsum>100 then put "ERR" "OR: " node= node_cat= "the sum of node >100, please check!";
run;

data __links1;
	length link_next_node_cat_color $500. __link_cat_gr $50.;
	format link_next_node_cat_color $500.;
	set __links1;
	by node node_cat next_node next_node_cat ;
	if _n_<1 then do; link_next_node_cat_color=''; transparency=.; end;
	if missing(transparency) then transparency=0.6;
	if missing(link_next_node_cat_color) then link_next_node_cat_color=strip(node_cat_color);
	__link_cat_gr=cats(put(node*10000+node_cat*100,best.),put(next_node_cat*100,best.));

	retain yblow1 ybhigh1 ;
	if first.node_cat then do;
		yblow1=low; ybhigh1=sum(yblow1,to_next_node_pct);
	end;else do;
		yblow1=ybhigh1; ybhigh1=sum(yblow1,to_next_node_pct);
	end;
run;

proc sort data=__links1 out=__links2;
	by next_node next_node_cat descending node node_cat;
run;

data __links2;
	set __links2;
	by next_node next_node_cat descending node node_cat;
	retain yblow2 ybhigh2 ;
	if first.next_node_cat then do;
		yblow2=next_low; ybhigh2=sum(yblow2,to_next_node_pct);
	end;else do;
		yblow2=ybhigh2; ybhigh2=sum(yblow2,to_next_node_pct);
	end;
run;



data __links3;
	set __links2;
	where blank_node_cat^=1;
	xt1alt = node + &barwidth.*0.5;
    xt2alt = next_node - &barwidth.*0.5;
	do xt = xt1alt to xt2alt by 0.01;
	%if "&interpol."="LINEAR" %then %do;
		*--- low ---;
		mlow = (yblow2 - yblow1) / (xt2alt - xt1alt);
		blow = yblow1 - mlow*xt1alt;
		yblow = mlow*xt + blow;
		*--- high ---;
		mhigh = (ybhigh2 - ybhigh1) / (xt2alt - xt1alt);
		bhigh = ybhigh1 - mhigh*xt1alt;
		ybhigh = mhigh*xt + bhigh;
	%end;
	%if "&interpol."="COSINE" %then %do;
		pi = constant('pi')/(xt2alt-xt1alt);
		c = xt1alt;
		*--- low ---;
		alow = (yblow1 - yblow2) / 2;
		dlow = yblow1 - ( (yblow1 - yblow2) / 2 );
		yblow = alow * cos( pi*(xt-c) ) + dlow;
		*--- high ---;
		ahigh = (ybhigh1 - ybhigh2) / 2;
		dhigh = ybhigh1 - ( (ybhigh1 - ybhigh2) / 2 );
		ybhigh = ahigh * cos( pi*(xt-c) ) + dhigh;
	%end;
		output;
	end;
run;
proc sort data=__links3;
	by node node_cat next_node next_node_cat ;
run;

data __sankey_plotdata;
	set __nodes1 __links3(in=b);
	if b then call missing(high,low);
run;

****************************************************************************;
proc sql noprint;
	select node,"'"||strip(node_label)||"'" into: xaxisls separated by " " 
		,:xaxislsc separated by " "
		from (select distinct node,node_label from __nodes);
	select ceil(max(high)/&ybystep.)*&ybystep. into: __ymax trimmed from __nodes;
quit;
/*%put &=xaxisls.;*/
/*%put &=xaxislsc.;*/
/*%put &=__ymax.;*/

data __myattmap;
	set __nodes1(in=a keep=__node_cat_gr node_cat_color) 
		__links1(in=b keep=__link_cat_gr link_next_node_cat_color transparency);
	length id linecolor fillcolor markercolor $20. value $200.;
	if a then do;
		id="_node_gr"; value=strip(vvalue(__node_cat_gr));
		linecolor=strip(node_cat_color); fillcolor=linecolor; markercolor=linecolor; 
		filltransparency=&node_transparency.;
	end;
	if b then do;
		id="_link_gr"; value=strip(vvalue(__link_cat_gr));
		linecolor=strip(link_next_node_cat_color); fillcolor=linecolor; markercolor=linecolor; 
		filltransparency=transparency;
	end;
run;

data __anno;
	length function $50.;
	function='text'; delete;
run;
%if "%upcase(%substr(&L_ncopt_DISPLAY.,1,1))"="Y" or "%upcase(&L_ncopt_DISPLAY.)"="1" %then %do;
data __anno_catlabel;
	set __nodes1;
	length function id x1space y1space ANCHOR JUSTIFY TEXTCOLOR TEXTFONT TEXTSTYLE TEXTWEIGHT $50. label $500.;
    function="text"; id="myid"; x1space="datavalue"; y1space="datavalue";
    ANCHOR=strip(upcase(scan("&L_ncopt_ANCHOR.",node,'#'))); 
	JUSTIFY=scan("&L_ncopt_JUST.",node,'#'); 
	BORDER="&L_ncopt_BORDER."; WIDTH=&L_ncopt_WIDTH.;
	TEXTCOLOR="&L_ncopt_TEXTCOLOR."; TEXTSIZE=&L_ncopt_TEXTSIZE.;
	TEXTFONT="&L_ncopt_TEXTFONT."; TEXTSTYLE="&L_ncopt_FSTYLE."; TEXTWEIGHT="&L_ncopt_TEXTWEIGHT.";
	if strip(ANCHOR) in ('C','CENTER') then x1=node;
	if strip(ANCHOR) in ('R','RIGHT') then x1=node-&barwidth.*0.5;
	if strip(ANCHOR) in ('L','LEFT') then x1=node+&barwidth.*0.5;
	y1=mean(low,high);
	label=strip(vvalue(node_cat_label));
run;
data __anno;
	set __anno __anno_catlabel;
run;
%end;
data __anno;
	set __anno &add_annods.;
run;

proc template;
define statgraph sankey_plot;
	begingraph;
		discreteattrvar attrvar=_node_gr var=__node_cat_gr attrmap="_node_gr";
		discreteattrvar attrvar=_link_gr var=__link_cat_gr attrmap="_link_gr";
		layout overlay / walldisplay=none 
			xaxisopts=( display=&x_xopt_display. offsetmin=&x_xopt_offsetmin. offsetmax=&x_xopt_offsetmax.
				tickvalueattrs=(family="&x_xopt_tickft." size=&x_xopt_tickfs. weight=&x_xopt_tickfw.)
				linearopts=( tickvaluelist=(&xaxisls.) tickdisplaylist=(&xaxislsc.) ) ) 
			yaxisopts=( display=&y_xopt_display. offsetmin=&y_xopt_offsetmin. offsetmax=&y_xopt_offsetmax.
				tickvalueattrs=(family="&y_xopt_tickft." size=&y_xopt_tickfs. weight=&y_xopt_tickfw.)
				linearopts =(viewmin=0 viewmax=&__ymax. TickValueSequence=(start=0 end=&__ymax. increment =&ybystep.) ) ) 
			;
			highlowplot x=node high=high low=low / display=(fill) group=_node_gr type=bar barwidth=&barwidth.;

			bandplot x=xt LIMITUPPER=ybhigh LIMITLOWER=yblow / group=_link_gr;
					
			annotate /id='myid';
		endlayout;
	endgraph;
end;
run;
%if %length(&graphics_options.)>0 %then %do;
ods graphics/ &graphics_options.;
%end;

%if "&plotyn."="1" %then %do;
proc sgrender data=__sankey_plotdata template=sankey_plot dattrmap=__myattmap sganno=__anno;
run;
%end; %else %do;
%put %*************************************************************************************************%;
%put %str(proc sgrender data=__sankey_plotdata template=sankey_plot dattrmap=__myattmap sganno=__anno; run; );
%put %*************************************************************************************************%;
%end;

%if "&debug."="0" %then %do;
proc datasets nolist;
	delete __nodes: __links: __attribval: __anno_catlabel 
	%if "&plotyn."="1" %then %do; __myattmap __sankey_plotdata __anno %end; 
	;
quit;
%end;
%put NOTE: -------------------- Macro[&SYSMACRONAME.] End --------------------;
%mend sankeyplot;
