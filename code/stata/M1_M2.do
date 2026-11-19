clear all
version 18.0
set more off
set linesize 255
capture log close _all

args project_root
if `"`project_root'"' == "" local project_root "."
cd `"`project_root'"'



global DATA "data/analysis/Regression_Analysis_Data.dta"
global OUT  "outputs/stata"
capture mkdir "$OUT"
log using "$OUT/M1_M2_run.log", text replace

use "$DATA", clear


keep if gsem_city_sample == 1
keep if !missing(pattern, province_id, ln_GDPpc, ln_CEI, admin_level, ///
    economic_region, S_PC_goal, S_PC_instrument, S_PC_actor, S_PC_temporal)

assert _N == 103
quietly levelsof province_id, local(provs)
local Nprov : word count `provs'
assert `Nprov' == 27
assert inlist(pattern,1,2,3,4)
assert inlist(admin_level,4,5,6)
assert inlist(economic_region,1,2,3,4)

label define pattern_final 1 "Implementation_weakening" 2 "Cross_element_weakening" ///
    3 "Non_weakening" 4 "Commitment_weakening", replace
label values pattern pattern_final
label define admin_final 4 "Provincial capital" 5 "Sub-provincial city" 6 "Ordinary prefecture-level city", replace
label values admin_level admin_final
label define econ_final 1 "Eastern region" 2 "Central region" 3 "Western region" 4 "Northeastern region", replace
label values economic_region econ_final

fvset base 6 admin_level
fvset base 4 economic_region
xtset province_id

local xvars "c.ln_GDPpc c.ln_CEI ib6.admin_level ib4.economic_region c.S_PC_goal c.S_PC_instrument c.S_PC_actor c.S_PC_temporal"
local mvars "ln_GDPpc ln_CEI i.admin_level i.economic_region S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal"

* Province-level cluster sizes.
quietly bysort province_id: generate byte __nprov = _N
quietly summarize __nprov, detail
local cl_min = r(min)
local cl_med = r(p50)
local cl_max = r(max)
drop __nprov
* ====================================================================
* I. Descriptive statistics and correlations


matrix DESC_C = J(2,6,.)
matrix rownames DESC_C = ln_GDPpc ln_CEI
matrix colnames DESC_C = N Mean SD Median Min Max
local rr=0
foreach v in ln_GDPpc ln_CEI {
    local ++rr
    quietly summarize `v', detail
    matrix DESC_C[`rr',1]=r(N)
    matrix DESC_C[`rr',2]=r(mean)
    matrix DESC_C[`rr',3]=r(sd)
    matrix DESC_C[`rr',4]=r(p50)
    matrix DESC_C[`rr',5]=r(min)
    matrix DESC_C[`rr',6]=r(max)
}

matrix FREQ_Y = J(4,3,.)
matrix rownames FREQ_Y = Pattern1 Pattern2 Pattern3 Pattern4
matrix colnames FREQ_Y = Count Percent Provinces
forvalues k=1/4 {
    quietly count if pattern==`k'
    matrix FREQ_Y[`k',1]=r(N)
    matrix FREQ_Y[`k',2]=100*r(N)/_N
    quietly levelsof province_id if pattern==`k', local(pk)
    local npk : word count `pk'
    matrix FREQ_Y[`k',3]=`npk'
}

matrix FREQ_A = J(3,2,.)
matrix rownames FREQ_A = Capital Subprovincial Ordinary
matrix colnames FREQ_A = Count Percent
local rr=0
foreach a in 4 5 6 {
    local ++rr
    quietly count if admin_level==`a'
    matrix FREQ_A[`rr',1]=r(N)
    matrix FREQ_A[`rr',2]=100*r(N)/_N
}

matrix FREQ_R = J(4,2,.)
matrix rownames FREQ_R = East Central West Northeast
matrix colnames FREQ_R = Count Percent
forvalues g=1/4 {
    quietly count if economic_region==`g'
    matrix FREQ_R[`g',1]=r(N)
    matrix FREQ_R[`g',2]=100*r(N)/_N
}

quietly tabulate admin_level pattern, matcell(CROSS_A)
quietly tabulate economic_region pattern, matcell(CROSS_R)

quietly correlate ln_GDPpc ln_CEI S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal
matrix CORR_CITY = r(C)

preserve
    keep province_id S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal economic_region
    duplicates drop province_id, force
    assert _N==27
    matrix DESC_P=J(4,8,.)
    matrix rownames DESC_P = Goal Instrument Actor Temporal
    matrix colnames DESC_P = N Mean SD P25 Median P75 Min Max
    local rr=0
    foreach v in S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal {
        local ++rr
        quietly summarize `v', detail
        matrix DESC_P[`rr',1]=r(N)
        matrix DESC_P[`rr',2]=r(mean)
        matrix DESC_P[`rr',3]=r(sd)
        matrix DESC_P[`rr',4]=r(p25)
        matrix DESC_P[`rr',5]=r(p50)
        matrix DESC_P[`rr',6]=r(p75)
        matrix DESC_P[`rr',7]=r(min)
        matrix DESC_P[`rr',8]=r(max)
    }
    quietly correlate S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal
    matrix CORR_PROV=r(C)
restore

* II. Programs for storing average marginal effects


capture program drop save_ames_full
program define save_ames_full
    syntax, Prefix(name)
    forvalues k=1/4 {
        quietly margins, dydx(ln_GDPpc ln_CEI i.admin_level i.economic_region ///
            S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal) ///
            predict(pr outcome(`k'))
        matrix __R=r(table)
        local c1=colnumb(__R,"ln_GDPpc")
        local c2=colnumb(__R,"ln_CEI")
        local c3=colnumb(__R,"4.admin_level")
        local c4=colnumb(__R,"5.admin_level")
        local c5=colnumb(__R,"1.economic_region")
        local c6=colnumb(__R,"2.economic_region")
        local c7=colnumb(__R,"3.economic_region")
        local c8=colnumb(__R,"S_PC_goal")
        local c9=colnumb(__R,"S_PC_instrument")
        local c10=colnumb(__R,"S_PC_actor")
        local c11=colnumb(__R,"S_PC_temporal")
        matrix `prefix'`k'=__R[1...,`c1'],__R[1...,`c2'],__R[1...,`c3'], ///
            __R[1...,`c4'],__R[1...,`c5'],__R[1...,`c6'],__R[1...,`c7'], ///
            __R[1...,`c8'],__R[1...,`c9'],__R[1...,`c10'],__R[1...,`c11']
        assert colsof(`prefix'`k')==11
    }
end

capture program drop fill_global_tests
program define fill_global_tests
    syntax, Matrix(name)
    matrix `matrix'=J(8,3,.)
    matrix rownames `matrix'=lnGDP lnCEI Admin Region Goal Instrument Actor Temporal
    matrix colnames `matrix'=Chi2 df p
    local rr=0
    foreach term in "ln_GDPpc" "ln_CEI" "i.admin_level" "i.economic_region" ///
        "S_PC_goal" "S_PC_instrument" "S_PC_actor" "S_PC_temporal" {
        local ++rr
        quietly testparm `term'
        matrix `matrix'[`rr',1]=r(chi2)
        matrix `matrix'[`rr',2]=r(df)
        matrix `matrix'[`rr',3]=r(p)
    }
end

capture program drop fill_global_tests_xt
program define fill_global_tests_xt
    syntax, Matrix(name)
    matrix `matrix'=J(8,3,.)
    matrix rownames `matrix'=lnGDP lnCEI Admin Region Goal Instrument Actor Temporal
    matrix colnames `matrix'=Chi2 df p

    quietly test [Cross_element_weakening]ln_GDPpc [Non_weakening]ln_GDPpc [Commitment_weakening]ln_GDPpc
    matrix `matrix'[1,1]=r(chi2)
    matrix `matrix'[1,2]=r(df)
    matrix `matrix'[1,3]=r(p)

    quietly test [Cross_element_weakening]ln_CEI [Non_weakening]ln_CEI [Commitment_weakening]ln_CEI
    matrix `matrix'[2,1]=r(chi2)
    matrix `matrix'[2,2]=r(df)
    matrix `matrix'[2,3]=r(p)

    quietly test [Cross_element_weakening]4.admin_level [Cross_element_weakening]5.admin_level ///
        [Non_weakening]4.admin_level [Non_weakening]5.admin_level ///
        [Commitment_weakening]4.admin_level [Commitment_weakening]5.admin_level
    matrix `matrix'[3,1]=r(chi2)
    matrix `matrix'[3,2]=r(df)
    matrix `matrix'[3,3]=r(p)

    quietly test [Cross_element_weakening]1.economic_region [Cross_element_weakening]2.economic_region ///
        [Cross_element_weakening]3.economic_region [Non_weakening]1.economic_region ///
        [Non_weakening]2.economic_region [Non_weakening]3.economic_region ///
        [Commitment_weakening]1.economic_region [Commitment_weakening]2.economic_region ///
        [Commitment_weakening]3.economic_region
    matrix `matrix'[4,1]=r(chi2)
    matrix `matrix'[4,2]=r(df)
    matrix `matrix'[4,3]=r(p)

    local rr=4
    foreach v in S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal {
        local ++rr
        quietly test [Cross_element_weakening]`v' [Non_weakening]`v' [Commitment_weakening]`v'
        matrix `matrix'[`rr',1]=r(chi2)
        matrix `matrix'[`rr',2]=r(df)
        matrix `matrix'[`rr',3]=r(p)
    }
end


* III. Model estimation


matrix FIT=J(2,17,.)
matrix rownames FIT=M1 M2
matrix colnames FIT=N Groups LL K AIC BIC ModelChi2 ModelDF ModelP ///
    RE_LR RE_P Tau2 Tau_L Tau_U ICC MOR DeltaLL


quietly mlogit pattern `xvars', baseoutcome(1) nolog
assert e(N)==103
estimates store M1
local ll1=e(ll)
local k1=e(rank)
local conv1=e(converged)
matrix FIT[1,1]=e(N)
matrix FIT[1,2]=`Nprov'
matrix FIT[1,3]=`ll1'
matrix FIT[1,4]=`k1'
matrix FIT[1,5]=-2*`ll1'+2*`k1'
matrix FIT[1,6]=-2*`ll1'+`k1'*ln(e(N))
matrix FIT[1,7]=e(chi2)
matrix FIT[1,8]=e(df_m)
matrix FIT[1,9]=e(p)
quietly fill_global_tests, matrix(GLOB1)
quietly save_ames_full, prefix(A1)

quietly xtmlogit pattern `xvars', re baseoutcome(1) covariance(identity) ///
    intpoints(3) difficult iterate(1000) nolog
local ll23=e(ll)
quietly xtmlogit pattern `xvars', re baseoutcome(1) covariance(identity) ///
    intpoints(7) difficult iterate(1000) nolog
assert e(N)==103
assert e(N_g)==27
estimates store M2
local ll2=e(ll)
local k2=e(rank)
local conv2=e(converged)
local lr_re=e(chi2_c)
local p_re=e(p_c)
local tau2=_b[/var(u2)]
local setau2=_se[/var(u2)]
local tauL=.
local tauU=.
if `tau2'>0 & `setau2'<. {
    local selog=`setau2'/`tau2'
    local tauL=`tau2'*exp(-invnormal(.975)*`selog')
    local tauU=`tau2'*exp( invnormal(.975)*`selog')
}
local icc=`tau2'/(`tau2'+(_pi^2/3))
local mor=exp(invnormal(.75)*sqrt(2*`tau2'))
local dLL=abs(`ll2'-`ll23')

matrix FIT[2,1]=e(N)
matrix FIT[2,2]=e(N_g)
matrix FIT[2,3]=`ll2'
matrix FIT[2,4]=`k2'
matrix FIT[2,5]=-2*`ll2'+2*`k2'
matrix FIT[2,6]=-2*`ll2'+`k2'*ln(e(N))
matrix FIT[2,7]=e(chi2)
matrix FIT[2,8]=e(df_m)
matrix FIT[2,9]=e(p)
matrix FIT[2,10]=`lr_re'
matrix FIT[2,11]=`p_re'
matrix FIT[2,12]=`tau2'
matrix FIT[2,13]=`tauL'
matrix FIT[2,14]=`tauU'
matrix FIT[2,15]=`icc'
matrix FIT[2,16]=`mor'
matrix FIT[2,17]=`dLL'
matrix GLOB2=J(8,3,.)
matrix rownames GLOB2=lnGDP lnCEI Admin Region Goal Instrument Actor Temporal
matrix colnames GLOB2=Chi2 df p
quietly test [Cross_element_weakening]ln_GDPpc [Non_weakening]ln_GDPpc [Commitment_weakening]ln_GDPpc
matrix GLOB2[1,1]=r(chi2)
matrix GLOB2[1,2]=r(df)
matrix GLOB2[1,3]=r(p)
quietly test [Cross_element_weakening]ln_CEI [Non_weakening]ln_CEI [Commitment_weakening]ln_CEI
matrix GLOB2[2,1]=r(chi2)
matrix GLOB2[2,2]=r(df)
matrix GLOB2[2,3]=r(p)
quietly test [Cross_element_weakening]4.admin_level [Cross_element_weakening]5.admin_level ///
    [Non_weakening]4.admin_level [Non_weakening]5.admin_level ///
    [Commitment_weakening]4.admin_level [Commitment_weakening]5.admin_level
matrix GLOB2[3,1]=r(chi2)
matrix GLOB2[3,2]=r(df)
matrix GLOB2[3,3]=r(p)
quietly test [Cross_element_weakening]1.economic_region [Cross_element_weakening]2.economic_region ///
    [Cross_element_weakening]3.economic_region [Non_weakening]1.economic_region ///
    [Non_weakening]2.economic_region [Non_weakening]3.economic_region ///
    [Commitment_weakening]1.economic_region [Commitment_weakening]2.economic_region ///
    [Commitment_weakening]3.economic_region
matrix GLOB2[4,1]=r(chi2)
matrix GLOB2[4,2]=r(df)
matrix GLOB2[4,3]=r(p)
local rr=4
foreach v in S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal {
    local ++rr
    quietly test [Cross_element_weakening]`v' [Non_weakening]`v' [Commitment_weakening]`v'
    matrix GLOB2[`rr',1]=r(chi2)
    matrix GLOB2[`rr',2]=r(df)
    matrix GLOB2[`rr',3]=r(p)
}
quietly save_ames_full, prefix(A2)


forvalues m=1/2 {
    forvalues k=1/4 {
        assert colsof(A`m'`k')==11
    }
}


local ll1t : display %9.3f FIT[1,3]
local ll2t : display %9.3f FIT[2,3]
local aic1 : display %9.3f FIT[1,5]
local aic2 : display %9.3f FIT[2,5]
local bic1 : display %9.3f FIT[1,6]
local bic2 : display %9.3f FIT[2,6]
local lrt  : display %8.3f `lr_re'
local lrp  : display %7.4f `p_re'
local taut : display %8.3f `tau2'
local tauLt: display %8.3f `tauL'
local tauUt: display %8.3f `tauU'
local icct : display %7.3f `icc'
local mort : display %7.3f `mor'
local dllt : display %8.4f `dLL'
foreach __m in ll1t ll2t aic1 aic2 bic1 bic2 lrt lrp taut tauLt tauUt icct mort dllt {
    local `__m' = strtrim("``__m''")
}



capture program drop table_three_lines
program define table_three_lines
    args tbl nrow
    putdocx table `tbl'(.,.), border(all,nil)
    putdocx table `tbl'(1,.), border(top,single,"000000") ///
        border(bottom,single,"000000") bold halign(center)
    putdocx table `tbl'(`nrow',.), border(bottom,single,"000000")
end

capture program drop write_ame_table
program define write_ame_table
    args tbl title prefix modelno
    putdocx paragraph, style(Heading2)
    putdocx text ("`title'"), bold
    putdocx table `tbl'=(16,5), border(all,nil)
    * Allocate additional width to the predictor column.
    putdocx table `tbl'(.,1), width(1.55)
    forvalues __c=2/5 {
        putdocx table `tbl'(.,`__c'), width(1.24)
    }
    putdocx table `tbl'(1,1)=("Predictor")
    putdocx table `tbl'(1,2)=("Implementation-design weakening")
    putdocx table `tbl'(1,3)=("Cross-element weakening")
    putdocx table `tbl'(1,4)=("Non-weakening")
    putdocx table `tbl'(1,5)=("Commitment-side weakening")
    putdocx table `tbl'(1,.), bold halign(center) ///
        border(top,single,"000000") border(bottom,single,"000000")

    local row=2
    putdocx table `tbl'(`row',1)=("City economic and emissions conditions"), bold italic shading("F2F2F2")
    putdocx table `tbl'(`row',2/5), shading("F2F2F2")
    local ++row
    forvalues j=1/2 {
        if `j'==1 local lab "ln(GDP per capita)"
        if `j'==2 local lab "ln(carbon-emission intensity)"
        putdocx table `tbl'(`row',1)=("`lab'")
        forvalues k=1/4 {
            matrix __A=`prefix'`k'
            scalar __scale=100*ln(1.1)
            scalar __b=__A[1,`j']*__scale
            scalar __se=__A[2,`j']*__scale
            scalar __p=__A[4,`j']
            local st ""
            if __p<.10 local st "*"
            if __p<.05 local st "**"
            if __p<.01 local st "***"
            local bt : display %6.2f __b
            local se : display %6.2f __se
            local col=`k'+1
            putdocx table `tbl'(`row',`col')=("`bt'`st' (`se')")
        }
        local ++row
    }

    putdocx table `tbl'(`row',1)=("Administrative level"), bold italic shading("F2F2F2")
    putdocx table `tbl'(`row',2/5), shading("F2F2F2")
    local ++row
    forvalues j=3/4 {
        if `j'==3 local lab "Provincial capital"
        if `j'==4 local lab "Sub-provincial city"
        putdocx table `tbl'(`row',1)=("`lab'")
        forvalues k=1/4 {
            matrix __A=`prefix'`k'
            scalar __b=100*__A[1,`j']
            scalar __se=100*__A[2,`j']
            scalar __p=__A[4,`j']
            local st ""
            if __p<.10 local st "*"
            if __p<.05 local st "**"
            if __p<.01 local st "***"
            local bt : display %6.2f __b
            local se : display %6.2f __se
            local col=`k'+1
            putdocx table `tbl'(`row',`col')=("`bt'`st' (`se')")
        }
        local ++row
    }

    putdocx table `tbl'(`row',1)=("Economic region"), bold italic shading("F2F2F2")
    putdocx table `tbl'(`row',2/5), shading("F2F2F2")
    local ++row
    forvalues j=5/7 {
        if `j'==5 local lab "Eastern region"
        if `j'==6 local lab "Central region"
        if `j'==7 local lab "Western region"
        putdocx table `tbl'(`row',1)=("`lab'")
        forvalues k=1/4 {
            matrix __A=`prefix'`k'
            scalar __b=100*__A[1,`j']
            scalar __se=100*__A[2,`j']
            scalar __p=__A[4,`j']
            local st ""
            if __p<.10 local st "*"
            if __p<.05 local st "**"
            if __p<.01 local st "***"
            local bt : display %6.2f __b
            local se : display %6.2f __se
            local col=`k'+1
            putdocx table `tbl'(`row',`col')=("`bt'`st' (`se')")
        }
        local ++row
    }

    putdocx table `tbl'(`row',1)=("Province-level net translation direction"), bold italic shading("F2F2F2")
    putdocx table `tbl'(`row',2/5), shading("F2F2F2")
    local ++row
    forvalues j=8/11 {
        if `j'==8 local lab "Goal dimension"
        if `j'==9 local lab "Instrument dimension"
        if `j'==10 local lab "Actor dimension"
        if `j'==11 local lab "Temporal dimension"
        putdocx table `tbl'(`row',1)=("`lab'")
        forvalues k=1/4 {
            matrix __A=`prefix'`k'
            scalar __b=10*__A[1,`j']
            scalar __se=10*__A[2,`j']
            scalar __p=__A[4,`j']
            local st ""
            if __p<.10 local st "*"
            if __p<.05 local st "**"
            if __p<.01 local st "***"
            local bt : display %6.2f __b
            local se : display %6.2f __se
            local col=`k'+1
            putdocx table `tbl'(`row',`col')=("`bt'`st' (`se')")
        }
        local ++row
    }
    putdocx table `tbl'(16,.), border(bottom,single,"000000")
    putdocx table `tbl'(2/16,2/5), halign(center)
    putdocx paragraph
    if `modelno'==1 {
        putdocx text ("Notes: Cells report average marginal effects (standard errors) in percentage points. Effects for logged variables are scaled to a 10% increase in the original measure; effects for province-level net translation direction are scaled to a 0.1-unit increase. Ordinary prefecture-level cities and the Northeastern region are the reference categories. M1 uses conventional maximum-likelihood standard errors without province-level clustering. Stars are based on unadjusted two-sided P values: * P<0.10, ** P<0.05, *** P<0.01.")
    }
    if `modelno'==2 {
        putdocx text ("Notes: Cells report average marginal effects (standard errors) in percentage points. Effects for logged variables are scaled to a 10% increase in the original measure; effects for province-level net translation direction are scaled to a 0.1-unit increase. Ordinary prefecture-level cities and the Northeastern region are the reference categories. M2 includes three category-specific province-level random intercepts that are independent and constrained to share one variance. Stars are based on unadjusted two-sided P values: * P<0.10, ** P<0.05, *** P<0.01.")
    }
end

capture program drop write_model_details
program define write_model_details
    args prefix modeltitle
    putdocx paragraph, style(Heading2)
    putdocx text ("`modeltitle'"), bold
    forvalues j=1/11 {
        if `j'==1 local lab "ln(GDP per capita), 10% increase in original measure"
        if `j'==2 local lab "ln(carbon-emission intensity), 10% increase in original measure"
        if `j'==3 local lab "Provincial capital versus ordinary prefecture-level city"
        if `j'==4 local lab "Sub-provincial city versus ordinary prefecture-level city"
        if `j'==5 local lab "Eastern versus Northeastern region"
        if `j'==6 local lab "Central versus Northeastern region"
        if `j'==7 local lab "Western versus Northeastern region"
        if `j'==8 local lab "Province-level goal dimension, 0.1-unit increase"
        if `j'==9 local lab "Province-level instrument dimension, 0.1-unit increase"
        if `j'==10 local lab "Province-level actor dimension, 0.1-unit increase"
        if `j'==11 local lab "Province-level temporal dimension, 0.1-unit increase"
        putdocx paragraph
        putdocx text ("`lab'："), bold
        forvalues k=1/4 {
            matrix __A=`prefix'`k'
            scalar __scale=100
            if inlist(`j',1,2) scalar __scale=100*ln(1.1)
            if `j'>=8 scalar __scale=10
            scalar __b=__A[1,`j']*__scale
            scalar __se=__A[2,`j']*__scale
            scalar __p=__A[4,`j']
            local bt : display %6.2f __b
            local ab : display %6.2f abs(__b)
            local se : display %6.2f __se
            local pt : display %6.4f __p
            if `k'==1 local klab "implementation-design weakening"
            if `k'==2 local klab "cross-element weakening"
            if `k'==3 local klab "non-weakening"
            if `k'==4 local klab "commitment-side weakening"
            local direction "increased"
            if __b<0 local direction "decreased"
            putdocx text ("The predicted probability of `klab' `direction' by `ab' percentage points on average (SE=`se', P=`pt').")
            if `k'<4 putdocx text ("；")
            if `k'==4 putdocx text ("。")
        }
    }
end



putdocx clear
putdocx begin, pagesize(letter) font("Microsoft YaHei",9.5)
putdocx paragraph, halign(center)
putdocx text ("Multinomial logistic regression results for city policy-translation configurations"), bold font("Arial",18)
putdocx paragraph
putdocx text ("Average marginal effects summarize the conditional associations between the predictors and the probabilities of the four city policy-translation configurations. Scaling and reference categories are reported in the table notes.")
quietly write_ame_table T1 "Table 1. Average marginal effects from M1: ordinary multinomial logit" A1 1
putdocx pagebreak
quietly write_ame_table T2 "Table 2. Average marginal effects from M2: province-level random-intercept multilevel multinomial logit" A2 2
putdocx paragraph
putdocx text ("Common sample: 103 cities nested within 27 province-level units. Pattern 1 is the reference outcome for coefficient estimation, but average marginal effects are calculated for all four outcome probabilities.")
putdocx save "$OUT/M1_M2_Average_Marginal_Effects.docx", replace



putdocx clear
putdocx begin, pagesize(letter) landscape margin(top,0.55) margin(bottom,0.55) margin(left,0.55) margin(right,0.55) font("Microsoft YaHei",9.5)
putdocx paragraph, halign(center)
putdocx text ("Supplementary Table 1. Model fit and random effects"), bold font("Arial",18)

putdocx paragraph, style(Heading2)
putdocx text ("Panel A. Model fit and comparison"), bold
putdocx table S1A=(3,10), border(all,nil)
local heads "Model N Provinces Log-likelihood Parameters AIC BIC Model-chi2 df P-value"
forvalues c=1/10 {
    local h : word `c' of `heads'
    putdocx table S1A(1,`c')=("`h'")
}
forvalues m=1/2 {
    local row=`m'+1
    putdocx table S1A(`row',1)=("M`m'")
    forvalues c=1/9 {
        scalar __v=FIT[`m',`c']
        local txt : display %9.3f __v
        if inlist(`c',1,2,4,8) local txt : display %9.0f __v
        local txt = strtrim("`txt'")
        putdocx table S1A(`row',`=`c'+1')=("`txt'")
    }
}
quietly table_three_lines S1A 3

putdocx paragraph, style(Heading2)
putdocx text ("Panel B. M2 random effects and numerical stability"), bold
putdocx table S1B=(2,9), border(all,nil)
local heads "Province-variance 95%-CI ICC MOR Boundary-LR P-value Integration-difference Cluster-size Converged"
forvalues c=1/9 {
    local h : word `c' of `heads'
    putdocx table S1B(1,`c')=("`h'")
}
putdocx table S1B(2,1)=("`taut'")
putdocx table S1B(2,2)=("[`tauLt', `tauUt']")
putdocx table S1B(2,3)=("`icct'")
putdocx table S1B(2,4)=("`mort'")
putdocx table S1B(2,5)=("`lrt'")
putdocx table S1B(2,6)=("`lrp'")
putdocx table S1B(2,7)=("`dllt'")
putdocx table S1B(2,8)=("`cl_min'-`cl_max' (median `cl_med')")
putdocx table S1B(2,9)=("`conv2'")
quietly table_three_lines S1B 2
putdocx paragraph
putdocx text ("Notes: M1 is an ordinary multinomial logit model. M2 has the same fixed component and adds three category-specific, mutually independent province-level random intercepts with a shared variance. The boundary likelihood-ratio test evaluates the null hypothesis that the random-intercept variance equals zero. The 95% confidence interval for the variance uses the delta method on the log scale and, because the variance is constrained to be non-negative, does not replace the boundary test. The integration difference is the absolute log-likelihood difference between seven- and three-point adaptive Gauss-Hermite quadrature. ICC=tau2/(tau2+pi2/3). MOR denotes the median odds ratio. Lower AIC and BIC values indicate a better trade-off between fit and complexity.")

putdocx pagebreak
putdocx paragraph, style(Heading2)
putdocx text ("Panel C. Joint cross-equation Wald tests"), bold
putdocx table S1C=(9,7), border(all,nil)
putdocx table S1C(1,1)=("Predictor group")
putdocx table S1C(1,2)=("M1 chi²")
putdocx table S1C(1,3)=("df")
putdocx table S1C(1,4)=("P")
putdocx table S1C(1,5)=("M2 chi²")
putdocx table S1C(1,6)=("df")
putdocx table S1C(1,7)=("P")
forvalues r=1/8 {
    if `r'==1 local lab "ln(GDP per capita)"
    if `r'==2 local lab "ln(carbon-emission intensity)"
    if `r'==3 local lab "Administrative level"
    if `r'==4 local lab "Economic region"
    if `r'==5 local lab "Province-level goal dimension"
    if `r'==6 local lab "Province-level instrument dimension"
    if `r'==7 local lab "Province-level actor dimension"
    if `r'==8 local lab "Province-level temporal dimension"
    local row=`r'+1
    putdocx table S1C(`row',1)=("`lab'")
    forvalues m=1/2 {
        matrix __G=GLOB`m'
        local offset=1
        if `m'==2 local offset=4
        local ct : display %7.3f __G[`r',1]
        local dt : display %5.0f __G[`r',2]
        local pt : display %7.4f __G[`r',3]
        local ct = strtrim("`ct'")
        local dt = strtrim("`dt'")
        local pt = strtrim("`pt'")
        putdocx table S1C(`row',`=`offset'+1')=("`ct'")
        putdocx table S1C(`row',`=`offset'+2')=("`dt'")
        putdocx table S1C(`row',`=`offset'+3')=("`pt'")
    }
}
quietly table_three_lines S1C 9
putdocx paragraph
putdocx text ("Notes: Each test jointly evaluates whether the coefficients for the corresponding predictor equal zero across the Pattern 2, Pattern 3, and Pattern 4 equations relative to Pattern 1. Tests of categorical predictors include all non-reference levels. P values are not adjusted for multiple testing.")
putdocx save "$OUT/Supplementary_Table_1_Model_Fit_and_Random_Effects.docx", replace



putdocx clear
putdocx begin, pagesize(letter) font("Microsoft YaHei",9.5)
putdocx paragraph, halign(center)
putdocx text ("Descriptive statistics and correlations among predictors"), bold font("Arial",18)
putdocx paragraph
putdocx text ("The analytical sample comprises 103 cities nested within 27 province-level units. The four municipalities are excluded because province-level net translation measures are not defined for them.")

putdocx paragraph, style(Heading2)
putdocx text ("Table 1. Distribution of city policy-translation configurations"), bold
putdocx table D1=(5,4), border(all,nil)
putdocx table D1(1,1)=("Configuration")
putdocx table D1(1,2)=("Cities")
putdocx table D1(1,3)=("Percent")
putdocx table D1(1,4)=("Provinces represented")
forvalues k=1/4 {
    local row=`k'+1
    if `k'==1 local lab "Implementation-design weakening"
    if `k'==2 local lab "Cross-element weakening"
    if `k'==3 local lab "Non-weakening"
    if `k'==4 local lab "Commitment-side weakening"
    putdocx table D1(`row',1)=("`lab'")
    forvalues c=1/3 {
        scalar __v=FREQ_Y[`k',`c']
        local txt : display %7.2f __v
        if inlist(`c',1,3) local txt : display %6.0f __v
        putdocx table D1(`row',`=`c'+1')=("`txt'")
    }
}
quietly table_three_lines D1 5

putdocx paragraph, style(Heading2)
putdocx text ("Table 2. Descriptive statistics for continuous predictors"), bold
putdocx table D2=(7,8), border(all,nil)
local heads "Variable Level N Mean SD Median Minimum Maximum"
forvalues c=1/8 {
    local h : word `c' of `heads'
    putdocx table D2(1,`c')=("`h'")
}
forvalues r=1/2 {
    local row=`r'+1
    if `r'==1 local lab "ln(GDP per capita)"
    if `r'==2 local lab "ln(carbon-emission intensity)"
    putdocx table D2(`row',1)=("`lab'")
    putdocx table D2(`row',2)=("City")
    forvalues c=1/6 {
        scalar __v=DESC_C[`r',`c']
        local txt : display %8.3f __v
        if `c'==1 local txt : display %6.0f __v
        putdocx table D2(`row',`=`c'+2')=("`txt'")
    }
}
forvalues r=1/4 {
    local row=`r'+3
    if `r'==1 local lab "Province-level goal dimension"
    if `r'==2 local lab "Province-level instrument dimension"
    if `r'==3 local lab "Province-level actor dimension"
    if `r'==4 local lab "Province-level temporal dimension"
    putdocx table D2(`row',1)=("`lab'")
    putdocx table D2(`row',2)=("Province")
    foreach pair in "1 1" "2 2" "3 3" "4 5" "5 7" "6 8" {
        local out : word 1 of `pair'
        local src : word 2 of `pair'
        scalar __v=DESC_P[`r',`src']
        local txt : display %8.3f __v
        if `out'==1 local txt : display %6.0f __v
        putdocx table D2(`row',`=`out'+2')=("`txt'")
    }
}
quietly table_three_lines D2 7
putdocx paragraph
putdocx text ("Notes: City-level variables use 103 cities as the units of analysis. Province-level variables are deduplicated by province_id, yielding 27 province-level units without weighting by the number of sampled cities per province.")

putdocx pagebreak
putdocx paragraph, style(Heading2)
putdocx text ("Table 3. Distribution of categorical predictors"), bold
putdocx table D3=(8,3), border(all,nil)
putdocx table D3(1,1)=("Variable and category")
putdocx table D3(1,2)=("Cities")
putdocx table D3(1,3)=("Percent")
local row=2
forvalues r=1/3 {
    if `r'==1 local lab "Provincial capital"
    if `r'==2 local lab "Sub-provincial city"
    if `r'==3 local lab "Ordinary prefecture-level city"
    putdocx table D3(`row',1)=("`lab'")
    forvalues c=1/2 {
        scalar __v=FREQ_A[`r',`c']
        local txt : display %7.2f __v
        if `c'==1 local txt : display %6.0f __v
        putdocx table D3(`row',`=`c'+1')=("`txt'")
    }
    local ++row
}
forvalues r=1/4 {
    if `r'==1 local lab "Eastern region"
    if `r'==2 local lab "Central region"
    if `r'==3 local lab "Western region"
    if `r'==4 local lab "Northeastern region"
    putdocx table D3(`row',1)=("`lab'")
    forvalues c=1/2 {
        scalar __v=FREQ_R[`r',`c']
        local txt : display %7.2f __v
        if `c'==1 local txt : display %6.0f __v
        putdocx table D3(`row',`=`c'+1')=("`txt'")
    }
    local ++row
}
quietly table_three_lines D3 8

putdocx paragraph, style(Heading2)
putdocx text ("Table 4. Correlations among continuous predictors in the city-level sample"), bold
putdocx table D4=(7,7), border(all,nil)
local labs `""Variable" "lnGDPpc" "lnCEI" "Goal" "Instrument" "Actor" "Temporal""' 
forvalues c=1/7 {
    local h : word `c' of `labs'
    putdocx table D4(1,`c')=("`h'")
}
forvalues r=1/6 {
    if `r'==1 local lab "ln(GDP per capita)"
    if `r'==2 local lab "ln(carbon-emission intensity)"
    if `r'==3 local lab "Province-level goal dimension"
    if `r'==4 local lab "Province-level instrument dimension"
    if `r'==5 local lab "Province-level actor dimension"
    if `r'==6 local lab "Province-level temporal dimension"
    putdocx table D4(`=`r'+1',1)=("`lab'")
    forvalues c=1/6 {
        local txt ""
        if `c'<=`r' {
            scalar __v=CORR_CITY[`r',`c']
            local txt : display %6.3f __v
        }
        putdocx table D4(`=`r'+1',`=`c'+1')=("`txt'")
    }
}
quietly table_three_lines D4 7
putdocx paragraph
putdocx text ("Notes: This matrix describes relationships among predictors in the 103-city estimation sample; province-level values are therefore repeated for each sampled city within a province.")

putdocx pagebreak
putdocx paragraph, style(Heading2)
putdocx text ("Table 5. Correlations among the four province-level net translation directions"), bold
putdocx table D5=(5,5), border(all,nil)
local labs `""Variable" "Goal" "Instrument" "Actor" "Temporal""' 
forvalues c=1/5 {
    local h : word `c' of `labs'
    putdocx table D5(1,`c')=("`h'")
}
forvalues r=1/4 {
    if `r'==1 local lab "Goal dimension"
    if `r'==2 local lab "Instrument dimension"
    if `r'==3 local lab "Actor dimension"
    if `r'==4 local lab "Temporal dimension"
    putdocx table D5(`=`r'+1',1)=("`lab'")
    forvalues c=1/4 {
        local txt ""
        if `c'<=`r' {
            scalar __v=CORR_PROV[`r',`c']
            local txt : display %6.3f __v
        }
        putdocx table D5(`=`r'+1',`=`c'+1')=("`txt'")
    }
}
quietly table_three_lines D5 5
putdocx paragraph
putdocx text ("Notes: This matrix uses 27 province-level units. Correlations among the province-level measures are moderate and do not indicate near-perfect linear dependence.")

putdocx paragraph, style(Heading2)
putdocx text ("Sparse-cell warning"), bold
putdocx paragraph
putdocx text ("Only five sub-provincial cities are observed, with no such cities in Pattern 1 or Pattern 2; Pattern 1 contains only eight cities overall. The cross-tabulation of economic region and outcome contains no zero cells. Estimates for administrative level, especially those for sub-provincial cities, should be interpreted with reference to their standard errors, confidence intervals, and model convergence.")
putdocx save "$OUT/M1_M2_Descriptive_Statistics_and_Correlations.docx", replace



putdocx clear
putdocx begin, pagesize(letter) font("Microsoft YaHei",10)
putdocx paragraph, halign(center)
putdocx text ("Specification of the ordinary and multilevel multinomial logistic regression models"), bold font("Arial",18)
putdocx paragraph
putdocx text ("The outcome is an unordered four-category policy-translation configuration for 103 cities, with Pattern 1 as the reference outcome. The two models use the same fixed predictors and common sample; they differ only in whether M2 includes province-level random intercepts.")

putdocx paragraph, style(Heading1)
putdocx text ("M1: ordinary multinomial logit"), bold
putdocx paragraph, halign(center)
putdocx text ("ln{Pr(Yij=k)/Pr(Yij=1)} = αk + β1k lnGDPpcij + β2k lnCEIij + γk′Aij + δk′Rj + θGkSGj + θIkSIj + θAkSAj + θTkSTj,  k=2,3,4")
putdocx paragraph
putdocx text ("Here, i indexes cities and j indexes provinces. A denotes administrative-level indicators, with ordinary prefecture-level cities as the reference; R denotes economic-region indicators, with the Northeastern region as the reference; and SG, SI, SA, and ST denote the province-level net translation directions for the goal, instrument, actor, and temporal dimensions. M1 assumes conditional independence across cities and uses conventional maximum-likelihood standard errors without province-level clustering.")
putdocx paragraph
putdocx text ("MathType linear code:"), bold
putdocx paragraph
putdocx text ("\\ln\\left[\\frac{\\Pr(Y_{ij}=k)}{\\Pr(Y_{ij}=1)}\\right]=\\alpha_k+\\beta_{1k}\\ln(GDPpc_{ij})+\\beta_{2k}\\ln(CEI_{ij})+\\boldsymbol{\\gamma}_k^{T}\\mathbf{A}_{ij}+\\boldsymbol{\\delta}_k^{T}\\mathbf{R}_{j}+\\theta_{Gk}S_{Gj}+\\theta_{Ik}S_{Ij}+\\theta_{Ak}S_{Aj}+\\theta_{Tk}S_{Tj},\\quad k=2,3,4"), font("Consolas",8)

putdocx paragraph, style(Heading1)
putdocx text ("M2: multilevel multinomial logit with province-level random intercepts"), bold
putdocx paragraph, halign(center)
putdocx text ("ln{Pr(Yij=k)/Pr(Yij=1)} = fixed component + ujk,  k=2,3,4")
putdocx paragraph, halign(center)
putdocx text ("uj = (uj2, uj3, uj4)′ ~ N(0, tau² I3)")
putdocx paragraph
putdocx text ("M2 specifies a province-level random intercept for each of the three non-reference equations. The three random intercepts are independent and constrained to share one variance, tau2. This specification allows unobserved provincial heterogeneity in the propensity to enter each configuration while avoiding estimation of three variances and three covariances from only 27 province-level units.")
putdocx paragraph
putdocx text ("MathType linear code:"), bold
putdocx paragraph
putdocx text ("\\ln\\left[\\frac{\\Pr(Y_{ij}=k)}{\\Pr(Y_{ij}=1)}\\right]=\\alpha_k+\\mathbf{X}_{ij}^{T}\\boldsymbol{\\beta}_k+u_{jk},\\quad k=2,3,4"), font("Consolas",8)
putdocx text ("    \\mathbf{u}_j=(u_{j2},u_{j3},u_{j4})^{T}\\sim N(\\mathbf{0},\\tau^2\\mathbf{I}_3)"), font("Consolas",8)

putdocx paragraph, style(Heading1)
putdocx text ("Average marginal effects"), bold
putdocx paragraph, halign(center)
putdocx text ("AMErk = (1/N) sum_i [partial Pr(Yi=k)/partial xir]")
putdocx paragraph
putdocx text ("Average marginal effects describe the sample-average change in the probability of each configuration after a change in a predictor. Effects for logged variables are scaled to a 10% increase in the original measure; effects for province-level net translation direction are scaled to a 0.1-unit increase; and categorical predictors are reported as average discrete changes relative to the reference category. The four outcome-specific marginal effects sum to approximately zero because an increase in one probability must be offset by decreases in other probabilities.")
putdocx paragraph
putdocx text ("MathType linear code:"), bold
putdocx paragraph
putdocx text ("AME_{rk}=\\frac{1}{N}\\sum_{i=1}^{N}\\frac{\\partial\\Pr(Y_i=k)}{\\partial x_{ir}}"), font("Consolas",8)

putdocx paragraph, style(Heading1)
putdocx text ("Quantities used to evaluate the multilevel specification"), bold
putdocx table F1=(7,3), border(all,nil)
putdocx table F1(1,1)=("Quantity")
putdocx table F1(1,2)=("Question addressed")
putdocx table F1(1,3)=("Interpretation")
putdocx table F1(2,1)=("Province-level variance tau2")
putdocx table F1(2,2)=("Is residual heterogeneity present across provinces?")
putdocx table F1(2,3)=("Values closer to zero indicate weaker province-level heterogeneity; also inspect the 95% CI.")
putdocx table F1(3,1)=("ICC")
putdocx table F1(3,2)=("What proportion of latent-scale variation is at the province level?")
putdocx table F1(3,3)=("Calculated as tau2/(tau2+pi2/3), a latent-variable approximation.")
putdocx table F1(4,1)=("Boundary likelihood-ratio test")
putdocx table F1(4,2)=("Does adding the random intercept improve model fit?")
putdocx table F1(4,3)=("Null hypothesis: tau2=0; a mixture chi-square P value is used because the variance is on the boundary.")
putdocx table F1(5,1)=("AIC and BIC")
putdocx table F1(5,2)=("Does improved fit offset the additional model complexity?")
putdocx table F1(5,3)=("Lower values are preferred for models with the same sample and outcome; BIC penalizes complexity more strongly.")
putdocx table F1(6,1)=("MOR")
putdocx table F1(6,2)=("How large is a typical between-province contrast on the odds-ratio scale?")
putdocx table F1(6,3)=("Values closer to one indicate less between-province heterogeneity.")
putdocx table F1(7,1)=("Integration sensitivity")
putdocx table F1(7,2)=("Is numerical integration stable?")
putdocx table F1(7,3)=("The log-likelihood difference between three- and seven-point integration should be close to zero.")
quietly table_three_lines F1 7

putdocx paragraph, style(Heading1)
putdocx text ("Interpretive boundary"), bold
putdocx paragraph
putdocx text ("The study uses cross-sectional city-level data. Regression coefficients and average marginal effects describe conditional associations between city economic and emissions conditions, administrative level, regional context, province-level net translation direction, and city configurations; they do not independently identify causal effects or policy mechanisms. Economic region does not vary within provinces, so its association is identified primarily from between-province or between-region comparisons.")
putdocx save "$OUT/M1_M2_Model_Equations_and_Parameter_Interpretation.docx", replace

*==============================================================================*
* IX. Word output 5: detailed interpretation of results
*==============================================================================*

putdocx clear
putdocx begin, pagesize(letter) font("Microsoft YaHei",10)
putdocx paragraph, halign(center)
putdocx text ("Detailed interpretation of M1 and M2 results"), bold font("Arial",18)
putdocx paragraph
putdocx text ("This document first explains the reported quantities and then interprets the average marginal effects for the 103-city sample. All statements describe conditional associations and avoid causal language.")

putdocx paragraph, style(Heading1)
putdocx text ("1. Reading the average marginal effects tables"), bold
putdocx paragraph
putdocx text ("Average marginal effects are not the raw multinomial-logit coefficients. They are sample averages of changes in predicted probabilities following a change in a predictor. Values are reported in percentage points; for example, 5.00 indicates an average increase of 5 percentage points, not 5%. Standard errors in parentheses quantify estimation uncertainty. P values test whether an average marginal effect equals zero, but statistical significance does not imply substantive importance, stability, or causality.")
putdocx paragraph
putdocx text ("Effects for logged variables are scaled to a 10% increase in the original measure, and effects for the four province-level measures are scaled to a 0.1-unit increase. For administrative level and economic region, marginal effects are average probability differences relative to the reference category. The four outcome-specific marginal effects should be read together because they sum to approximately zero.")

putdocx paragraph, style(Heading1)
putdocx text ("2. Comparison of M1 and M2"), bold
putdocx paragraph
putdocx text ("M1 has a log likelihood of `ll1t', AIC of `aic1', and BIC of `bic1'. M2 has a log likelihood of `ll2t', AIC of `aic2', and BIC of `bic2'. The shared province-level random-intercept variance estimated by M2 is `taut', with a 95% CI of [`tauLt', `tauUt']; the ICC is `icct' and the MOR is `mort'. The boundary likelihood-ratio statistic is `lrt' (P=`lrp'). The log-likelihood difference between seven- and three-point integration is `dllt'.")
putdocx paragraph
if `p_re'<.05 {
    putdocx text ("The boundary likelihood-ratio test rejects the null hypothesis of zero province-level variance at the 5% level, indicating an identifiable improvement in fit from adding province-level random intercepts to the same fixed component. If AIC and BIC also decline, these criteria jointly support M2 as the main model.")
}
else if `p_re'<.10 {
    putdocx text ("The boundary likelihood-ratio test reaches only the 10% level, providing suggestive rather than conclusive evidence of province-level random effects. Selection of M2 should also consider AIC, BIC, the ICC, the variance interval, the nesting of cities within provinces, and numerical stability.")
}
else {
    putdocx text ("The boundary likelihood-ratio test does not reject the null hypothesis of zero province-level variance, so the sample does not provide strong evidence that the random intercept improves fit. The log-scale delta-method interval cannot overturn this conclusion because the non-negativity constraint prevents it from including zero. M2 may be retained to represent the theoretically nested structure, but the data do not show that a multilevel model is statistically indispensable; M1 remains an important comparator.")
}
putdocx paragraph
if FIT[2,5]<FIT[1,5] & FIT[2,6]<FIT[1,6] {
    putdocx text ("Both AIC and BIC are lower for M2 than for M1, indicating that the improvement in fit exceeds the penalty for additional complexity.")
}
else if FIT[2,5]>FIT[1,5] & FIT[2,6]>FIT[1,6] {
    putdocx text ("Both AIC and BIC are higher for M2 than for M1, indicating that the random intercept does not improve fit enough to offset the additional complexity.")
}
else {
    putdocx text ("AIC and BIC rank M1 and M2 differently, so model-selection evidence is inconsistent and should be interpreted together with the random-effects test and the theoretical structure.")
}

putdocx paragraph, style(Heading1)
putdocx text ("3. Average marginal effects of the predictors"), bold
quietly write_model_details A1 "M1: ordinary multinomial logit"
quietly write_model_details A2 "M2: multilevel multinomial logit with province-level random intercepts"

putdocx paragraph, style(Heading1)
putdocx text ("4. Use of joint Wald tests"), bold
putdocx paragraph
putdocx text ("An outcome-specific marginal effect evaluates whether the probability of one configuration changes, whereas a joint Wald test evaluates whether a predictor contributes information across the three non-reference equations. Tests of categorical predictors also cover all non-reference levels. Claims about systematic associations of administrative level, economic region, or a province-level dimension should therefore consider the joint test rather than selecting individual starred cells. Statistics are reported in Supplementary Table 1, Panel C.")

putdocx paragraph, style(Heading1)
putdocx text ("5. Results requiring cautious interpretation"), bold
putdocx paragraph
putdocx text ("Only five sub-provincial cities are observed, with zero cells for this category in Pattern 1 and Pattern 2; Pattern 1 contains only eight cities overall. Coefficients, standard errors, and marginal effects for sub-provincial cities may therefore be strongly influenced by a few observations. Large or statistically significant estimates should be reported with this sample limitation and should not be interpreted as a stable administrative-level effect.")
putdocx paragraph
putdocx text ("The four province-level net translation directions and economic region draw primarily on information across 27 provinces. Non-significant province-level results may reflect weak systematic associations, limited province-level sample size, measurement error, or heterogeneous city responses within provinces. The cross-sectional models cannot by themselves establish whether provinces do or do not serve as policy intermediaries.")

putdocx paragraph, style(Heading1)
putdocx text ("6. Reporting framework for the manuscript"), bold
putdocx paragraph
putdocx text ("We compare an ordinary multinomial logit model with a province-level random-intercept multilevel multinomial logit model using the same 103-city sample. Model comparison considers the random-intercept variance and its confidence interval, the ICC, the boundary likelihood-ratio test, AIC, and BIC rather than relying on any single statistic. Substantive associations are reported as average marginal effects for all four outcomes, with joint cross-equation Wald tests used to assess whether predictors systematically distinguish policy-translation configurations. Because the data are cross-sectional, estimates are interpreted as conditional associations rather than causal mechanisms.")
putdocx save "$OUT/M1_M2_Detailed_Results_Interpretation.docx", replace

display as result "M1+M2 analysis completed successfully."
display as result "N=" _N ", provinces=" `Nprov' ", M1 converged=" `conv1' ", M2 converged=" `conv2'


