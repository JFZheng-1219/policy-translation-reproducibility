clear all
version 18.0
set more off
set linesize 255
capture log close _all

args project_root
if `"`project_root'"' == "" local project_root "."
cd `"`project_root'"'



global ROOT "data/analysis"
global OUT  "outputs/stata"
capture mkdir "$OUT"
log using "$OUT/M3_M4_M5_M6_run.log", text replace

use "$ROOT/Regression_Analysis_Data.dta", clear


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

label define pattern_rb 1 "Implementation_weakening" 2 "Cross_element_weakening" ///
    3 "Non_weakening" 4 "Commitment_weakening", replace
label values pattern pattern_rb
label define admin_rb 4 "Provincial capital" 5 "Sub-provincial city" 6 "Ordinary prefecture-level city", replace
label values admin_level admin_rb
label define econ_rb 1 "Eastern region" 2 "Central region" 3 "Western region" 4 "Northeastern region", replace
label values economic_region econ_rb
fvset base 6 admin_level
fvset base 4 economic_region
xtset province_id

local xcity "c.ln_GDPpc c.ln_CEI ib6.admin_level ib4.economic_region"
local xprov "c.S_PC_goal c.S_PC_instrument c.S_PC_actor c.S_PC_temporal"
local xfull "`xcity' `xprov'"
local mfull "ln_GDPpc ln_CEI i.admin_level i.economic_region S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal"

* M4: collapse the outcome into whether the commitment side is weakened.
generate byte commitment_weak = inlist(pattern,2,4)
label define commitment_rb 0 "Commitment strengthened or not weakened" 1 "Commitment weakened", replace
label values commitment_weak commitment_rb
quietly count if commitment_weak==0
assert r(N)==49
quietly count if commitment_weak==1
assert r(N)==54

* M5: construct the prespecified three-category provincial configuration; Provincial Pattern 2 is the reference.
generate byte province_pattern = .
replace province_pattern = 2 if inlist(province_id,9,26)
replace province_pattern = 3 if inlist(province_id,2,3,5,7,8,13,15,17,18,20) ///
    | inlist(province_id,21,24)
replace province_pattern = 4 if inlist(province_id,1,4,6,10,11,12,14,16,19,22) ///
    | inlist(province_id,23,25,27)
assert !missing(province_pattern)
label define province_pattern_rb 2 "Provincial Pattern 2" 3 "Provincial Pattern 3" 4 "Provincial Pattern 4", replace
label values province_pattern province_pattern_rb
fvset base 2 province_pattern

preserve
    keep province_id province_pattern
    duplicates drop province_id, force
    assert _N==27
    quietly count if province_pattern==2
    assert r(N)==2
    quietly count if province_pattern==3
    assert r(N)==12
    quietly count if province_pattern==4
    assert r(N)==13
restore

quietly tabulate province_pattern pattern, matcell(PROV_CROSS)
quietly count if province_pattern==2
local pp2cities=r(N)
assert `pp2cities'==7



capture program drop save_ame_standard
program define save_ame_standard
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
    }
end

capture program drop save_ame_m5
program define save_ame_m5
    syntax, Prefix(name)
    forvalues k=1/4 {
        quietly margins, dydx(ln_GDPpc ln_CEI i.admin_level i.economic_region ///
            i.province_pattern) predict(pr outcome(`k'))
        matrix __R=r(table)
        local c1=colnumb(__R,"ln_GDPpc")
        local c2=colnumb(__R,"ln_CEI")
        local c3=colnumb(__R,"4.admin_level")
        local c4=colnumb(__R,"5.admin_level")
        local c5=colnumb(__R,"1.economic_region")
        local c6=colnumb(__R,"2.economic_region")
        local c7=colnumb(__R,"3.economic_region")
        local c8=colnumb(__R,"3.province_pattern")
        local c9=colnumb(__R,"4.province_pattern")
        matrix `prefix'`k'=__R[1...,`c1'],__R[1...,`c2'],__R[1...,`c3'], ///
            __R[1...,`c4'],__R[1...,`c5'],__R[1...,`c6'],__R[1...,`c7'], ///
            __R[1...,`c8'],__R[1...,`c9']
    }
end

capture program drop save_ame_m6
program define save_ame_m6
    syntax, Prefix(name)
    forvalues k=1/4 {
        quietly margins, dydx(ln_GDPpc ln_CEI i.admin_level i.economic_region ///
            S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal) ///
            predict(pr outcome(`k'))
        matrix __R=r(table)
        local c1=colnumb(__R,"ln_GDPpc")
        local c2=colnumb(__R,"ln_CEI")
        local c3=colnumb(__R,"4.admin_level")
        local c4=colnumb(__R,"1.economic_region")
        local c5=colnumb(__R,"2.economic_region")
        local c6=colnumb(__R,"3.economic_region")
        local c7=colnumb(__R,"S_PC_goal")
        local c8=colnumb(__R,"S_PC_instrument")
        local c9=colnumb(__R,"S_PC_actor")
        local c10=colnumb(__R,"S_PC_temporal")
        matrix `prefix'`k'=__R[1...,`c1'],__R[1...,`c2'],__R[1...,`c3'], ///
            __R[1...,`c4'],__R[1...,`c5'],__R[1...,`c6'],__R[1...,`c7'], ///
            __R[1...,`c8'],__R[1...,`c9'],__R[1...,`c10']
    }
end

capture program drop save_ame_binary
program define save_ame_binary
    syntax, Prefix(name)
    quietly margins, dydx(ln_GDPpc ln_CEI i.admin_level i.economic_region ///
        S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal) predict(pu0)
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
    matrix `prefix'2=__R[1...,`c1'],__R[1...,`c2'],__R[1...,`c3'], ///
        __R[1...,`c4'],__R[1...,`c5'],__R[1...,`c6'],__R[1...,`c7'], ///
        __R[1...,`c8'],__R[1...,`c9'],__R[1...,`c10'],__R[1...,`c11']
    matrix `prefix'1=`prefix'2
    forvalues __j=1/11 {
        matrix `prefix'1[1,`__j']=-`prefix'2[1,`__j']
    }
end



matrix FIT=J(4,17,.)
matrix rownames FIT=M3 M4 M5 M6
matrix colnames FIT=N Groups LL K AIC BIC ModelChi2 ModelDF ModelP ///
    RE_LR RE_P Tau2 Tau_L Tau_U ICC MOR DeltaLL

*---------------------------- M3 ---------------------------------------------*
quietly mlogit pattern `xfull', baseoutcome(1) vce(cluster province_id) nolog
assert e(N)==103
assert e(N_clust)==27
estimates store M3
local ll3=e(ll)

local k3=colsof(e(b))
local conv3=e(converged)
matrix FIT[1,1]=e(N)
matrix FIT[1,2]=e(N_clust)
matrix FIT[1,3]=`ll3'
matrix FIT[1,4]=`k3'
matrix FIT[1,5]=-2*`ll3'+2*`k3'
matrix FIT[1,6]=-2*`ll3'+`k3'*ln(e(N))
matrix FIT[1,7]=e(chi2)
matrix FIT[1,8]=e(df_m)
matrix FIT[1,9]=e(p)

matrix G3=J(8,3,.)
matrix rownames G3=lnGDP lnCEI Admin Region Goal Instrument Actor Temporal
matrix colnames G3=Chi2 df p
local rr=0
foreach term in "ln_GDPpc" "ln_CEI" "i.admin_level" "i.economic_region" ///
    "S_PC_goal" "S_PC_instrument" "S_PC_actor" "S_PC_temporal" {
    local ++rr
    quietly testparm `term'
    matrix G3[`rr',1]=r(chi2)
    matrix G3[`rr',2]=r(df)
    matrix G3[`rr',3]=r(p)
}
quietly save_ame_standard, prefix(AM3_)


quietly xtlogit commitment_weak `xfull', re intpoints(4) nolog
local ll44=e(ll)
quietly xtlogit commitment_weak `xfull', re intpoints(7) nolog
assert e(N)==103
assert e(N_g)==27
estimates store M4
local ll4=e(ll)
local k4=e(rank)
local conv4=e(converged)
local tau4=e(sigma_u)^2
local icc4=e(rho)
local mor4=exp(invnormal(.75)*sqrt(2*`tau4'))
local lr4=e(chi2_c)
* A single non-negative variance component lies on the boundary; use a 50:50 mixture chi-square distribution.
local lrp4=0.5*chi2tail(1,`lr4')
local dll4=abs(`ll4'-`ll44')
matrix FIT[2,1]=e(N)
matrix FIT[2,2]=e(N_g)
matrix FIT[2,3]=`ll4'
matrix FIT[2,4]=`k4'
matrix FIT[2,5]=-2*`ll4'+2*`k4'
matrix FIT[2,6]=-2*`ll4'+`k4'*ln(e(N))
matrix FIT[2,7]=e(chi2)
matrix FIT[2,8]=e(df_m)
matrix FIT[2,9]=e(p)
matrix FIT[2,10]=`lr4'
matrix FIT[2,11]=`lrp4'
matrix FIT[2,12]=`tau4'
matrix FIT[2,15]=`icc4'
matrix FIT[2,16]=`mor4'
matrix FIT[2,17]=`dll4'

matrix G4=J(8,3,.)
matrix rownames G4=lnGDP lnCEI Admin Region Goal Instrument Actor Temporal
matrix colnames G4=Chi2 df p
local rr=0
foreach term in "ln_GDPpc" "ln_CEI" "i.admin_level" "i.economic_region" ///
    "S_PC_goal" "S_PC_instrument" "S_PC_actor" "S_PC_temporal" {
    local ++rr
    quietly testparm `term'
    matrix G4[`rr',1]=r(chi2)
    matrix G4[`rr',2]=r(df)
    matrix G4[`rr',3]=r(p)
}
quietly save_ame_binary, prefix(AM4_)


if 0 {
local xm5 "`xcity' ib2.province_pattern"
quietly xtmlogit pattern `xm5', re baseoutcome(1) covariance(identity) ///
    intpoints(3) difficult iterate(1500) nolog
local ll53=e(ll)
quietly xtmlogit pattern `xm5', re baseoutcome(1) covariance(identity) ///
    intpoints(7) difficult iterate(1500) nolog
assert e(N)==103
assert e(N_g)==27
estimates store M5
local ll5=e(ll)
local k5=e(rank)
local conv5=e(converged)
local lr5=e(chi2_c)
local lrp5=e(p_c)
local tau5=_b[/var(u2)]
local setau5=_se[/var(u2)]
local tau5L=.
local tau5U=.
if `tau5'>0 & `setau5'<. {
    local selog5=`setau5'/`tau5'
    local tau5L=`tau5'*exp(-invnormal(.975)*`selog5')
    local tau5U=`tau5'*exp( invnormal(.975)*`selog5')
}
local icc5=`tau5'/(`tau5'+(_pi^2/3))
local mor5=exp(invnormal(.75)*sqrt(2*`tau5'))
local dll5=abs(`ll5'-`ll53')
matrix FIT[3,1]=e(N)
matrix FIT[3,2]=e(N_g)
matrix FIT[3,3]=`ll5'
matrix FIT[3,4]=`k5'
matrix FIT[3,5]=-2*`ll5'+2*`k5'
matrix FIT[3,6]=-2*`ll5'+`k5'*ln(e(N))
matrix FIT[3,7]=e(chi2)
matrix FIT[3,8]=e(df_m)
matrix FIT[3,9]=e(p)
matrix FIT[3,10]=`lr5'
matrix FIT[3,11]=`lrp5'
matrix FIT[3,12]=`tau5'
matrix FIT[3,13]=`tau5L'
matrix FIT[3,14]=`tau5U'
matrix FIT[3,15]=`icc5'
matrix FIT[3,16]=`mor5'
matrix FIT[3,17]=`dll5'

matrix G5=J(5,3,.)
matrix rownames G5=lnGDP lnCEI Admin Region ProvincePattern
matrix colnames G5=Chi2 df p
quietly test [Cross_element_weakening]ln_GDPpc [Non_weakening]ln_GDPpc [Commitment_weakening]ln_GDPpc
matrix G5[1,1]=r(chi2)
matrix G5[1,2]=r(df)
matrix G5[1,3]=r(p)
quietly test [Cross_element_weakening]ln_CEI [Non_weakening]ln_CEI [Commitment_weakening]ln_CEI
matrix G5[2,1]=r(chi2)
matrix G5[2,2]=r(df)
matrix G5[2,3]=r(p)
quietly test [Cross_element_weakening]4.admin_level [Cross_element_weakening]5.admin_level ///
    [Non_weakening]4.admin_level [Non_weakening]5.admin_level ///
    [Commitment_weakening]4.admin_level [Commitment_weakening]5.admin_level
matrix G5[3,1]=r(chi2)
matrix G5[3,2]=r(df)
matrix G5[3,3]=r(p)
quietly test [Cross_element_weakening]1.economic_region [Cross_element_weakening]2.economic_region ///
    [Cross_element_weakening]3.economic_region [Non_weakening]1.economic_region ///
    [Non_weakening]2.economic_region [Non_weakening]3.economic_region ///
    [Commitment_weakening]1.economic_region [Commitment_weakening]2.economic_region ///
    [Commitment_weakening]3.economic_region
matrix G5[4,1]=r(chi2)
matrix G5[4,2]=r(df)
matrix G5[4,3]=r(p)
quietly test [Cross_element_weakening]3.province_pattern [Cross_element_weakening]4.province_pattern ///
    [Non_weakening]3.province_pattern [Non_weakening]4.province_pattern ///
    [Commitment_weakening]3.province_pattern [Commitment_weakening]4.province_pattern
matrix G5[5,1]=r(chi2)
matrix G5[5,2]=r(df)
matrix G5[5,3]=r(p)
quietly save_ame_m5, prefix(AM5_)
}

local conv5=0
matrix FIT[3,1]=103
matrix FIT[3,2]=27
matrix G5=J(5,3,.)
matrix rownames G5=lnGDP lnCEI Admin Region ProvincePattern
matrix colnames G5=Chi2 df p
forvalues k=1/4 {
    matrix AM5_`k'=J(9,9,.)
}

*---------------------------- M6 ---------------------------------------------*
preserve
    drop if admin_level==5
    assert _N==98
    quietly levelsof province_id, local(provs6)
    local Nprov6 : word count `provs6'
    assert `Nprov6'==27

    quietly xtmlogit pattern `xfull', re baseoutcome(1) covariance(identity) ///
        intpoints(3) difficult iterate(1500) nolog
    local ll63=e(ll)
    estimates store M6_3
    quietly xtmlogit pattern `xfull', re baseoutcome(1) covariance(identity) ///
        intpoints(7) difficult iterate(1500) nolog
    assert e(N)==98
    assert e(N_g)==27
    estimates store M6
    local ll6=e(ll)
    local k6=e(rank)
    local conv6=e(converged)
    local lr6=e(chi2_c)
    local lrp6=e(p_c)
    local tau6=_b[/var(u2)]
    local setau6=_se[/var(u2)]
    local tau6L=.
    local tau6U=.
    if `tau6'>0 & `setau6'<. {
        local selog6=`setau6'/`tau6'
        local tau6L=`tau6'*exp(-invnormal(.975)*`selog6')
        local tau6U=`tau6'*exp( invnormal(.975)*`selog6')
    }
    local icc6=`tau6'/(`tau6'+(_pi^2/3))
    local mor6=exp(invnormal(.75)*sqrt(2*`tau6'))
    local dll6=abs(`ll6'-`ll63')
    matrix FIT[4,1]=e(N)
    matrix FIT[4,2]=e(N_g)
    matrix FIT[4,3]=`ll6'
    matrix FIT[4,4]=`k6'
    matrix FIT[4,5]=-2*`ll6'+2*`k6'
    matrix FIT[4,6]=-2*`ll6'+`k6'*ln(e(N))
    matrix FIT[4,7]=e(chi2)
    matrix FIT[4,8]=e(df_m)
    matrix FIT[4,9]=e(p)
    matrix FIT[4,10]=`lr6'
    matrix FIT[4,11]=`lrp6'
    matrix FIT[4,12]=`tau6'
    matrix FIT[4,13]=`tau6L'
    matrix FIT[4,14]=`tau6U'
    matrix FIT[4,15]=`icc6'
    matrix FIT[4,16]=`mor6'
    matrix FIT[4,17]=`dll6'

    matrix G6=J(8,3,.)
    matrix rownames G6=lnGDP lnCEI Admin Region Goal Instrument Actor Temporal
    matrix colnames G6=Chi2 df p
    quietly test [Cross_element_weakening]ln_GDPpc [Non_weakening]ln_GDPpc [Commitment_weakening]ln_GDPpc
    matrix G6[1,1]=r(chi2)
    matrix G6[1,2]=r(df)
    matrix G6[1,3]=r(p)
    quietly test [Cross_element_weakening]ln_CEI [Non_weakening]ln_CEI [Commitment_weakening]ln_CEI
    matrix G6[2,1]=r(chi2)
    matrix G6[2,2]=r(df)
    matrix G6[2,3]=r(p)
    quietly test [Cross_element_weakening]4.admin_level [Non_weakening]4.admin_level ///
        [Commitment_weakening]4.admin_level
    matrix G6[3,1]=r(chi2)
    matrix G6[3,2]=r(df)
    matrix G6[3,3]=r(p)
    quietly test [Cross_element_weakening]1.economic_region [Cross_element_weakening]2.economic_region ///
        [Cross_element_weakening]3.economic_region [Non_weakening]1.economic_region ///
        [Non_weakening]2.economic_region [Non_weakening]3.economic_region ///
        [Commitment_weakening]1.economic_region [Commitment_weakening]2.economic_region ///
        [Commitment_weakening]3.economic_region
    matrix G6[4,1]=r(chi2)
    matrix G6[4,2]=r(df)
    matrix G6[4,3]=r(p)
    local rr=4
    foreach v in S_PC_goal S_PC_instrument S_PC_actor S_PC_temporal {
        local ++rr
        quietly test [Cross_element_weakening]`v' [Non_weakening]`v' [Commitment_weakening]`v'
        matrix G6[`rr',1]=r(chi2)
        matrix G6[`rr',2]=r(df)
        matrix G6[`rr',3]=r(p)
    }
    * AMEs use three-point integration to reduce high-dimensional numerical-differentiation time; formal fit statistics use seven points.
    estimates restore M6_3
    quietly save_ame_m6, prefix(AM6_)
restore


assert `conv3'==1
assert `conv4'==1
assert `conv6'==1



capture program drop write_cell4
program define write_cell4
    args tbl row col prefix outcome j scale
    matrix __A=`prefix'`outcome'
    scalar __b=__A[1,`j']*`scale'
    scalar __se=__A[2,`j']*`scale'
    scalar __p=__A[4,`j']
    if missing(__b) | missing(__se) | missing(__p) {
        putdocx table `tbl'(`row',`col')=("—")
        exit
    }
    local st ""
    if __p<.10 local st "*"
    if __p<.05 local st "**"
    if __p<.01 local st "***"
    local bt : display %6.2f __b
    local se : display %6.2f __se
    local bt=strtrim("`bt'")
    local se=strtrim("`se'")
    putdocx table `tbl'(`row',`col')=("`bt'`st' (`se')")
end

capture program drop style_ame4
program define style_ame4
    args tbl nrow
    putdocx table `tbl'(.,.), border(all,nil)
    putdocx table `tbl'(.,1), width(2.20)
    forvalues c=2/5 {
        putdocx table `tbl'(.,`c'), width(1.82)
    }
    putdocx table `tbl'(1,.), bold halign(center) shading("D9EAF7") ///
        border(top,single,"000000") border(bottom,single,"000000")
    putdocx table `tbl'(2/`nrow',2/5), halign(center)
    putdocx table `tbl'(`nrow',.), border(bottom,single,"000000")
end

capture program drop write_ame_standard
program define write_ame_standard
    args tbl title prefix modelnote
    putdocx paragraph, style(Heading2)
    putdocx text ("`title'"), bold
    putdocx table `tbl'=(16,5)
    putdocx table `tbl'(1,1)=("Predictor")
    putdocx table `tbl'(1,2)=("Implementation-design weakening")
    putdocx table `tbl'(1,3)=("Cross-element weakening")
    putdocx table `tbl'(1,4)=("Non-weakening")
    putdocx table `tbl'(1,5)=("Commitment-side weakening")
    putdocx table `tbl'(2,1)=("City economic and emissions conditions"), bold italic shading("F2F2F2")
    putdocx table `tbl'(2,2/5), shading("F2F2F2")
    putdocx table `tbl'(5,1)=("Administrative level"), bold italic shading("F2F2F2")
    putdocx table `tbl'(5,2/5), shading("F2F2F2")
    putdocx table `tbl'(8,1)=("Economic region"), bold italic shading("F2F2F2")
    putdocx table `tbl'(8,2/5), shading("F2F2F2")
    putdocx table `tbl'(12,1)=("Province-level net translation direction"), bold italic shading("F2F2F2")
    putdocx table `tbl'(12,2/5), shading("F2F2F2")
    local labs `""ln(GDP per capita)" "ln(carbon-emission intensity)" "Provincial capital" "Sub-provincial city" "Eastern region" "Central region" "Western region" "Goal dimension" "Instrument dimension" "Actor dimension" "Temporal dimension""' 
    local rows "3 4 6 7 9 10 11 13 14 15 16"
    forvalues j=1/11 {
        local lab : word `j' of `labs'
        local row : word `j' of `rows'
        putdocx table `tbl'(`row',1)=("`lab'")
        scalar __scale=100
        if inlist(`j',1,2) scalar __scale=100*ln(1.1)
        if `j'>=8 scalar __scale=10
        forvalues k=1/4 {
            local col=`k'+1
            quietly write_cell4 `tbl' `row' `col' `prefix' `k' `j' `=__scale'
        }
    }
    quietly style_ame4 `tbl' 16
    putdocx paragraph
    putdocx text ("Notes: Cells report average marginal effects (standard errors) in percentage points. Effects for logged variables are scaled to a 10% increase in the original measure, and effects for continuous province-level measures are scaled to a 0.1-unit increase. Ordinary prefecture-level cities and the Northeastern region are the reference categories. `modelnote' Stars are based on unadjusted two-sided P values: * P<0.10, ** P<0.05, *** P<0.01.")
end

capture program drop write_ame_binary
program define write_ame_binary
    args tbl title prefix
    putdocx paragraph, style(Heading2)
    putdocx text ("`title'"), bold
    putdocx table `tbl'=(16,3), border(all,nil)
    putdocx table `tbl'(.,1), width(2.20)
    forvalues __c=2/3 {
        putdocx table `tbl'(.,`__c'), width(3.65)
    }
    putdocx table `tbl'(1,1)=("Predictor")
    putdocx table `tbl'(1,2)=("Commitment strengthened or not weakened")
    putdocx table `tbl'(1,3)=("Commitment weakened")
    putdocx table `tbl'(1,.), bold halign(center) shading("D9EAF7") ///
        border(top,single,"000000") border(bottom,single,"000000")
    foreach r in 2 5 8 12 {
        putdocx table `tbl'(`r',.), shading("F2F2F2")
    }
    putdocx table `tbl'(2,1)=("City economic and emissions conditions"), bold italic
    putdocx table `tbl'(5,1)=("Administrative level"), bold italic
    putdocx table `tbl'(8,1)=("Economic region"), bold italic
    putdocx table `tbl'(12,1)=("Province-level net translation direction"), bold italic
    local labs `""ln(GDP per capita)" "ln(carbon-emission intensity)" "Provincial capital" "Sub-provincial city" "Eastern region" "Central region" "Western region" "Goal dimension" "Instrument dimension" "Actor dimension" "Temporal dimension""' 
    local rows "3 4 6 7 9 10 11 13 14 15 16"
    forvalues j=1/11 {
        local lab : word `j' of `labs'
        local row : word `j' of `rows'
        putdocx table `tbl'(`row',1)=("`lab'")
        scalar __scale=100
        if inlist(`j',1,2) scalar __scale=100*ln(1.1)
        if `j'>=8 scalar __scale=10
        forvalues k=1/2 {
            local col=`k'+1
            quietly write_cell4 `tbl' `row' `col' `prefix' `k' `j' `=__scale'
        }
    }
    putdocx table `tbl'(2/16,2/3), halign(center)
    putdocx table `tbl'(16,.), border(bottom,single,"000000")
    putdocx paragraph
    putdocx text ("Notes: Cells report average marginal effects (standard errors) in percentage points. For the binary outcome, the two marginal effects have equal absolute values and opposite signs. M4 is a province-level random-intercept binary logit model; all other scaling and reference categories match the main analysis. Stars are based on unadjusted two-sided P values: * P<0.10, ** P<0.05, *** P<0.01.")
end

capture program drop write_ame_m5
program define write_ame_m5
    args tbl title prefix
    putdocx paragraph, style(Heading2)
    putdocx text ("`title'"), bold
    putdocx table `tbl'=(14,5)
    putdocx table `tbl'(1,1)=("Predictor")
    putdocx table `tbl'(1,2)=("Implementation-design weakening")
    putdocx table `tbl'(1,3)=("Cross-element weakening")
    putdocx table `tbl'(1,4)=("Non-weakening")
    putdocx table `tbl'(1,5)=("Commitment-side weakening")
    foreach r in 2 5 8 12 {
        putdocx table `tbl'(`r',.), shading("F2F2F2")
    }
    putdocx table `tbl'(2,1)=("City economic and emissions conditions"), bold italic
    putdocx table `tbl'(5,1)=("Administrative level"), bold italic
    putdocx table `tbl'(8,1)=("Economic region"), bold italic
    putdocx table `tbl'(12,1)=("Provincial translation configuration"), bold italic
    local labs `""ln(GDP per capita)" "ln(carbon-emission intensity)" "Provincial capital" "Sub-provincial city" "Eastern region" "Central region" "Western region" "Provincial Pattern 3" "Provincial Pattern 4""' 
    local rows "3 4 6 7 9 10 11 13 14"
    forvalues j=1/9 {
        local lab : word `j' of `labs'
        local row : word `j' of `rows'
        putdocx table `tbl'(`row',1)=("`lab'")
        scalar __scale=100
        if inlist(`j',1,2) scalar __scale=100*ln(1.1)
        forvalues k=1/4 {
            local col=`k'+1
            quietly write_cell4 `tbl' `row' `col' `prefix' `k' `j' `=__scale'
        }
    }
    quietly style_ame4 `tbl' 14
    putdocx paragraph
    putdocx text ("Notes: Provincial Pattern 2 is the reference category but contains only two provinces and seven cities, with zero cells for City Patterns 1 and 3. The multilevel multinomial maximum-likelihood model therefore exhibits structural separation and cannot produce finite, interpretable AMEs. Dashes indicate that the model is not estimable, not that the effect is zero. This failure shows that the current three-category construction is not a viable maximum-likelihood robustness alternative to M2.")
end

capture program drop write_ame_m6
program define write_ame_m6
    args tbl title prefix
    putdocx paragraph, style(Heading2)
    putdocx text ("`title'"), bold
    putdocx table `tbl'=(15,5)
    putdocx table `tbl'(1,1)=("Predictor")
    putdocx table `tbl'(1,2)=("Implementation-design weakening")
    putdocx table `tbl'(1,3)=("Cross-element weakening")
    putdocx table `tbl'(1,4)=("Non-weakening")
    putdocx table `tbl'(1,5)=("Commitment-side weakening")
    foreach r in 2 5 7 11 {
        putdocx table `tbl'(`r',.), shading("F2F2F2")
    }
    putdocx table `tbl'(2,1)=("City economic and emissions conditions"), bold italic
    putdocx table `tbl'(5,1)=("Administrative level"), bold italic
    putdocx table `tbl'(7,1)=("Economic region"), bold italic
    putdocx table `tbl'(11,1)=("Province-level net translation direction"), bold italic
    local labs `""ln(GDP per capita)" "ln(carbon-emission intensity)" "Provincial capital" "Eastern region" "Central region" "Western region" "Goal dimension" "Instrument dimension" "Actor dimension" "Temporal dimension""' 
    local rows "3 4 6 8 9 10 12 13 14 15"
    forvalues j=1/10 {
        local lab : word `j' of `labs'
        local row : word `j' of `rows'
        putdocx table `tbl'(`row',1)=("`lab'")
        scalar __scale=100
        if inlist(`j',1,2) scalar __scale=100*ln(1.1)
        if `j'>=7 scalar __scale=10
        forvalues k=1/4 {
            local col=`k'+1
            quietly write_cell4 `tbl' `row' `col' `prefix' `k' `j' `=__scale'
        }
    }
    quietly style_ame4 `tbl' 15
    putdocx paragraph
    putdocx text ("Notes: Cells report average marginal effects (standard errors) in percentage points. M6 excludes the five sub-provincial cities, leaving 98 cities; administrative level therefore compares only provincial capitals with ordinary prefecture-level cities. Formal model fit, random effects, and joint tests use seven-point integration, whereas AMEs and delta-method standard errors use a three-point approximation. Panel A reports the corresponding absolute log-likelihood difference. All other scaling, reference categories, and significance notation match the main analysis.")
end


putdocx clear
putdocx begin, pagesize(letter) landscape margin(top,0.55) margin(bottom,0.55) ///
    margin(left,0.55) margin(right,0.55) font("Microsoft YaHei",9.5)
putdocx paragraph, style(Title) halign(center)
putdocx text ("Robustness analyses for city policy-translation configurations"), bold ///
    font("Microsoft YaHei",18)
putdocx paragraph
putdocx text ("This document reports four prespecified sensitivity analyses. Conclusions are based jointly on average marginal effects, predictor-group tests, random-effect variances, ICCs, boundary likelihood-ratio tests, and numerical convergence rather than on isolated unadjusted significance stars.")

putdocx paragraph, style(Heading1)
putdocx text ("Part I. Average marginal effects from M3-M6")
quietly write_ame_standard T3 "Table 1. M3: ordinary multinomial logit with province-clustered standard errors" AM3_ ///
    "M3 uses cluster-robust standard errors based on 27 province-level clusters; point estimates are identical to M1."
* Table 1 occupies nearly a full page; allow Word to paginate M4 naturally.
quietly write_ame_binary T4 "Table 2. M4: province-level random-intercept binary logit after collapsing sparse outcome categories" AM4_
putdocx pagebreak
quietly write_ame_m5 T5 "Table 3. M5: identification result for the three-category provincial translation configuration" AM5_
putdocx pagebreak
quietly write_ame_m6 T6 "Table 4. M6: province-level random-intercept multinomial logit excluding sub-provincial cities" AM6_

putdocx pagebreak
putdocx paragraph, style(Heading1)
putdocx text ("Part II. Supplementary Table 2: model diagnostics and joint tests")

putdocx paragraph, style(Heading2)
putdocx text ("Panel A. Model fit and sample"), bold
putdocx table SA=(10,5), border(all,nil)
putdocx table SA(1,1)=("Statistic")
putdocx table SA(1,2)=("M3")
putdocx table SA(1,3)=("M4")
putdocx table SA(1,4)=("M5")
putdocx table SA(1,5)=("M6")
local fitlabs `""Cities" "Province-level units" "Outcome categories" "Log-likelihood" "Estimated parameters" "AIC" "BIC" "Converged" "Absolute log-likelihood difference between low-point and seven-point integration""' 
forvalues r=2/10 {
    local j=`r'-1
    local lab : word `j' of `fitlabs'
    putdocx table SA(`r',1)=("`lab'")
}
forvalues m=1/4 {
    local c=`m'+1
    local Ntxt : display %6.0f FIT[`m',1]
    local Gtxt : display %6.0f FIT[`m',2]
    local Ltxt : display %9.3f FIT[`m',3]
    local Ktxt : display %6.0f FIT[`m',4]
    local Atxt : display %9.3f FIT[`m',5]
    local Btxt : display %9.3f FIT[`m',6]
    local Dtxt : display %8.4f FIT[`m',17]
    foreach z in Ntxt Gtxt Ltxt Ktxt Atxt Btxt Dtxt {
        local `z'=strtrim("``z''")
    }
    putdocx table SA(2,`c')=("`Ntxt'")
    putdocx table SA(3,`c')=("`Gtxt'")
    if `m'==2 putdocx table SA(4,`c')=("2")
    else putdocx table SA(4,`c')=("4")
    if `m'==3 {
        putdocx table SA(5,`c')=("Not estimable")
        putdocx table SA(6,`c')=("Not estimable")
        putdocx table SA(7,`c')=("Not estimable")
        putdocx table SA(8,`c')=("Not estimable")
        putdocx table SA(9,`c')=("No")
        putdocx table SA(10,`c')=("Not applicable")
        continue
    }
    putdocx table SA(5,`c')=("`Ltxt'")
    putdocx table SA(6,`c')=("`Ktxt'")
    putdocx table SA(7,`c')=("`Atxt'")
    putdocx table SA(8,`c')=("`Btxt'")
    if `m'==1 putdocx table SA(9,`c')=("Yes")
    if `m'==2 putdocx table SA(9,`c')=("Yes")
    if `m'==4 putdocx table SA(9,`c')=("Yes")
    if `m'==1 putdocx table SA(10,`c')=("Not applicable")
    else putdocx table SA(10,`c')=("`Dtxt'")
}
putdocx table SA(.,1), width(3.15)
forvalues c=2/5 {
    putdocx table SA(.,`c'), width(1.60)
}
putdocx table SA(1,.), bold halign(center) shading("D9EAF7") ///
    border(top,single,"000000") border(bottom,single,"000000")
putdocx table SA(2/10,2/5), halign(center)
putdocx table SA(10,.), border(bottom,single,"000000")

putdocx paragraph, style(Heading2)
putdocx text ("Panel B. Province-level random effects"), bold
putdocx table SB=(7,5), border(all,nil)
putdocx table SB(1,1)=("Statistic")
putdocx table SB(1,2)=("M3")
putdocx table SB(1,3)=("M4")
putdocx table SB(1,4)=("M5")
putdocx table SB(1,5)=("M6")
local relabs `""Province-level variance" "95% CI for province-level variance" "ICC" "Median odds ratio (MOR)" "Boundary LR statistic" "Boundary LR P value""' 
forvalues r=2/7 {
    local j=`r'-1
    local lab : word `j' of `relabs'
    putdocx table SB(`r',1)=("`lab'")
    putdocx table SB(`r',2)=("Not applicable")
}
forvalues m=2/4 {
    local c=`m'+1
    if `m'==3 {
        forvalues r=2/7 {
            putdocx table SB(`r',`c')=("Not estimable")
        }
        continue
    }
    local taut : display %8.3f FIT[`m',12]
    local tL : display %8.3f FIT[`m',13]
    local tU : display %8.3f FIT[`m',14]
    local icct : display %7.3f FIT[`m',15]
    local mort : display %7.3f FIT[`m',16]
    local lrt : display %8.3f FIT[`m',10]
    local lrp : display %7.4f FIT[`m',11]
    foreach z in taut tL tU icct mort lrt lrp {
        local `z'=strtrim("``z''")
    }
    putdocx table SB(2,`c')=("`taut'")
    if `m'==2 putdocx table SB(3,`c')=("Not estimated")
    else putdocx table SB(3,`c')=("[`tL', `tU']")
    putdocx table SB(4,`c')=("`icct'")
    putdocx table SB(5,`c')=("`mort'")
    putdocx table SB(6,`c')=("`lrt'")
    putdocx table SB(7,`c')=("`lrp'")
}
putdocx table SB(.,1), width(3.15)
forvalues c=2/5 {
    putdocx table SB(.,`c'), width(1.60)
}
putdocx table SB(1,.), bold halign(center) shading("D9EAF7") ///
    border(top,single,"000000") border(bottom,single,"000000")
putdocx table SB(2/7,2/5), halign(center)
putdocx table SB(7,.), border(bottom,single,"000000")
putdocx paragraph
putdocx text ("Notes: M3 has no random effects. M4 is a random-intercept binary logit model. M5 and M6 are category-specific random-intercept multinomial logit models with independent random intercepts constrained to share one variance. Variance intervals for M5 and M6 use the delta method on the log scale and therefore cannot include zero under the non-negativity constraint; the boundary likelihood-ratio test should be given priority when evaluating random effects.")

putdocx pagebreak
putdocx paragraph, style(Heading2)
putdocx text ("Panel C. Joint Wald-test P values for predictor groups"), bold
putdocx table SC=(10,5), border(all,nil)
putdocx table SC(1,1)=("Predictor group")
putdocx table SC(1,2)=("M3")
putdocx table SC(1,3)=("M4")
putdocx table SC(1,4)=("M5")
putdocx table SC(1,5)=("M6")
local glabs `""ln(GDP per capita)" "ln(carbon-emission intensity)" "Administrative level" "Economic region" "Province-level goal dimension" "Province-level instrument dimension" "Province-level actor dimension" "Province-level temporal dimension" "Three-category provincial translation configuration""' 
forvalues r=2/10 {
    local j=`r'-1
    local lab : word `j' of `glabs'
    putdocx table SC(`r',1)=("`lab'")
    forvalues c=2/5 {
        putdocx table SC(`r',`c')=("—")
    }
}
forvalues j=1/8 {
    local p3 : display %7.4f G3[`j',3]
    local p4 : display %7.4f G4[`j',3]
    local p6 : display %7.4f G6[`j',3]
    putdocx table SC(`=`j'+1',2)=(strtrim("`p3'"))
    putdocx table SC(`=`j'+1',3)=(strtrim("`p4'"))
    putdocx table SC(`=`j'+1',5)=(strtrim("`p6'"))
}
forvalues r=2/10 {
    putdocx table SC(`r',4)=("Not estimable")
}
putdocx table SC(.,1), width(3.15)
forvalues c=2/5 {
    putdocx table SC(.,`c'), width(1.60)
}
putdocx table SC(1,.), bold halign(center) shading("D9EAF7") ///
    border(top,single,"000000") border(bottom,single,"000000")
putdocx table SC(2/10,2/5), halign(center)
putdocx table SC(10,.), border(bottom,single,"000000")
putdocx paragraph
putdocx text ("Notes: Tests for multinomial models jointly cover the corresponding predictor in the Pattern 2, Pattern 3, and Pattern 4 equations relative to Pattern 1. Tests of categorical predictors cover all non-reference levels. P values are not adjusted for multiple testing.")

putdocx paragraph, style(Heading2)
putdocx text ("Panel D. Model changes and identification limitations"), bold
putdocx table SD=(5,4), border(all,single,"D9D9D9")
putdocx table SD(1,1)=("Model")
putdocx table SD(1,2)=("Change")
putdocx table SD(1,3)=("Primary diagnostic question")
putdocx table SD(1,4)=("Caution")
putdocx table SD(2,1)=("M3")
putdocx table SD(2,2)=("Ordinary MNL with province-clustered standard errors")
putdocx table SD(2,3)=("Does fixed-effect inference depend on the independent-error assumption?")
putdocx table SD(2,4)=("Only 27 clusters; random effects are not tested.")
putdocx table SD(3,1)=("M4")
putdocx table SD(3,2)=("Collapse P1+P3 and P2+P4 into a binary outcome")
putdocx table SD(3,3)=("Are conclusions driven by sparse cells in the multinomial outcome?")
putdocx table SD(3,4)=("Differences on the implementation-design side are no longer retained.")
putdocx table SD(4,1)=("M5")
putdocx table SD(4,2)=("Replace four continuous province-level measures with a three-category provincial configuration")
putdocx table SD(4,3)=("Do conclusions depend on the continuous net-direction construction?")
putdocx table SD(4,4)=("The reference group contains only two provinces and seven cities, with zero outcome cells.")
putdocx table SD(5,1)=("M6")
putdocx table SD(5,2)=("Exclude five sub-provincial cities")
putdocx table SD(5,3)=("Are results driven by a small number of high-leverage cities?")
putdocx table SD(5,4)=("The sample falls to 98 cities but still covers 27 provinces.")
putdocx table SD(.,1), width(0.75)
putdocx table SD(.,2), width(2.75)
putdocx table SD(.,3), width(2.95)
putdocx table SD(.,4), width(3.15)
putdocx table SD(1,.), bold halign(center) shading("D9EAF7")

* Format key statistics dynamically for the results interpretation.
foreach m in 2 3 4 {
    local tau`m't : display %7.3f FIT[`m',12]
    local icc`m't : display %7.3f FIT[`m',15]
    local lr`m't : display %7.3f FIT[`m',10]
    local lrp`m't : display %7.4f FIT[`m',11]
    foreach z in tau`m't icc`m't lr`m't lrp`m't {
        local `z'=strtrim("``z''")
    }
}
local p3g : display %7.4f G3[5,3]
local p3i : display %7.4f G3[6,3]
local p3a : display %7.4f G3[7,3]
local p3t : display %7.4f G3[8,3]
local p4g : display %7.4f G4[5,3]
local p4i : display %7.4f G4[6,3]
local p4a : display %7.4f G4[7,3]
local p4t : display %7.4f G4[8,3]
local p6g : display %7.4f G6[5,3]
local p6i : display %7.4f G6[6,3]
local p6a : display %7.4f G6[7,3]
local p6t : display %7.4f G6[8,3]
foreach z in p3g p3i p3a p3t p4g p4i p4a p4t p6g p6i p6a p6t {
    local `z'=strtrim("``z''")
}

putdocx pagebreak
putdocx paragraph, style(Heading1)
putdocx text ("Part III. Comprehensive interpretation of the results")

putdocx paragraph, style(Heading2)
putdocx text ("1. Interpreting the robustness analyses"), bold
putdocx paragraph
putdocx text ("The four analyses modify the standard-error structure, outcome classification, province-level variable construction, and sample composition, respectively. A conclusion is robust to alternative specifications only when its direction is consistent and model diagnostics do not indicate serious instability. Failure to reach statistical significance means that the current sample does not provide sufficient evidence to reject the null hypothesis; it does not prove that the true effect is exactly zero.")
putdocx paragraph
putdocx text ("Average marginal effects report the sample-average change, in percentage points, in the predicted probability of each configuration following a change in a predictor. Effects for categorical predictors are relative to the reference categories reported in the table notes. In multinomial models, the marginal effects across the four outcome probabilities sum to zero, so an increase in one probability must be offset by decreases in others.")

putdocx paragraph, style(Heading2)
putdocx text ("2. M3: cluster-robust MNL"), bold
putdocx paragraph
putdocx text ("M3 retains the coefficients, predicted probabilities, and average marginal effects from M1 but estimates the variance using 27 province-level clusters. Joint Wald-test P values for the province-level goal, instrument, actor, and temporal dimensions are `p3g', `p3i', `p3a', and `p3t', respectively. Conclusions should therefore consider the joint tests in Panel C together with effect sizes and standard errors in Table 1 rather than selecting isolated significance stars. Inference is also subject to finite-sample uncertainty because only 27 clusters are available.")

putdocx paragraph, style(Heading2)
putdocx text ("3. M4: multilevel binary logit after collapsing categories"), bold
putdocx paragraph
putdocx text ("M4 reduces the city configurations to whether the commitment side is weakened, mitigating partial-separation risks caused by the small Pattern 1 sample and zero cells among sub-provincial cities. The province-level random-intercept variance is `tau2t' and the ICC is `icc2t'; the boundary LR statistic is `lr2t' (P=`lrp2t'). Joint P values for the four province-level dimensions are `p4g', `p4i', `p4a', and `p4t'. The boundary test is not significant at 5% but provides suggestive evidence at 10%, and the ICC also indicates possible province-level clustering in the binary outcome. M4 therefore does not confirm that province-level differences equal zero. Because it no longer distinguishes weakening on the implementation-design side, it is a sensitivity analysis rather than a replacement for the main model.")

putdocx paragraph, style(Heading2)
putdocx text ("4. M5: three-category provincial translation configuration"), bold
putdocx paragraph
putdocx text ("M5 was designed to replace the four continuous net-direction measures with a three-category provincial configuration. However, the Provincial Pattern 2 reference group contains only Jiangxi and Xinjiang, covering seven cities, with no observations of City Pattern 1 or City Pattern 3. The provincial configuration therefore perfectly excludes some city outcome categories, causing structural separation in the multilevel multinomial maximum-likelihood model. Finite, stable, and interpretable coefficients and AMEs cannot be obtained. M5 can neither support nor refute province-level effects; it shows that this alternative measure is not identified in the current sample. Dashes in Table 3 do not indicate zero or non-significant effects. Estimating this model in future research would require a larger Provincial Pattern 2 sample, a different prespecified grouping, or a regularized Bayesian model with explicit priors; each would constitute a new model design.")

putdocx paragraph, style(Heading2)
putdocx text ("5. M6: exclusion of sub-provincial cities"), bold
putdocx paragraph
putdocx text ("M6 excludes the five sub-provincial cities, leaving 98 cities in 27 province-level units. Joint P values for the province-level goal, instrument, actor, and temporal dimensions are `p6g', `p6i', `p6a', and `p6t', respectively. The random-intercept variance is `tau4t', the ICC is `icc4t', and the boundary LR statistic is `lr4t' (P=`lrp4t'). This model evaluates whether city economic conditions, province-level predictors, and random effects in the main model are driven by the five sub-provincial cities. Administrative level in M6 compares only provincial capitals with ordinary prefecture-level cities and cannot estimate a sub-provincial-city contrast.")

putdocx paragraph, style(Heading2)
putdocx text ("6. Synthesis across models"), bold
putdocx paragraph
putdocx text ("Systematic province-level associations should be evaluated using three forms of evidence: whether predictor-group Wald tests are stable across alternative specifications; whether province-level variances, ICCs, and boundary tests in M4-M6 support identifiable residual heterogeneity; and whether the direction and magnitude of AMEs are consistent across models with reasonable uncertainty. Significant outcome-specific AMEs do not override non-significant global tests, particularly with multiple outcomes, predictors, and unadjusted tests.")
putdocx paragraph
putdocx text ("The four analyses do not consistently show that province-level context has no influence. In M3, cluster-robust joint tests for the province-level goal and instrument dimensions reach the unadjusted 5% level; the random effect in M4 provides suggestive evidence at the 10% level; after excluding sub-provincial cities, neither the four province-level joint tests nor the boundary test in M6 reaches 5%; and M5 is not estimable because of structural separation. The most defensible conclusion is therefore not that province-level effects are zero, but that province-level associations are sensitive to model specification and are not stable across alternatives. This pattern may support discussion of a limited or unstable provincial intermediary role, but it does not exclude limited province-level sample size, measurement error, within-province city heterogeneity, or low statistical power.")

putdocx paragraph, style(Heading2)
putdocx text ("7. Reporting boundaries"), bold
putdocx paragraph
putdocx text ("All models are cross-sectional association models and cannot independently identify causal mechanisms. Significance stars and P values are not adjusted for multiple testing; joint tests, effect sizes, and uncertainty should provide the primary evidence. M5 has a very small reference group, M3 uses only 27 clusters, and M6 is a post hoc exclusion analysis. These limitations should be fully disclosed in the Supplementary Information.")

putdocx save "$OUT/Robustness_checks.docx", replace
capture log close _all
display as result "Robustness analysis M3-M6 completed successfully."
display as result "M3 N=" FIT[1,1] ", M4 N=" FIT[2,1] ", M5 N=" FIT[3,1] ", M6 N=" FIT[4,1]

