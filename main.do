/*
Project Title: DIB - National Datasets
Author: Aly Abdou 
Date: 29/09/1991

Description: Creates tables and figures for the DIB publication
*/

clear all
cap program drop _all

**# Initialize Project folder
init_project "C:/Ourfolders/Aly" "DIB_National"

**# Load Global Macros
// cd "C:/Ourfolders/Aly/MT_analysis_DIB"
do "./codes/utility/config_macros.do"
macro list

local countries AM AT BD BE BG BR CO CY CZ DE DK EE ES FI FR GE GR HR HU ID IE IS IT KE LT LU LV MK MT MX NL NO PL PT PY RO SE SI SK UK US UY
// local countries MT CY

frame create desc_table
frame change desc_table
local vars country years observations contracts unq_buyers unq_bidders total_value contracts_serv total_value_serv contracts_suppl total_value_suppl contracts_works total_value_works cri    
foreach var in `vars'{
	gen `var' = ""
}

frame create CRI_breakdown


**# Descriptives Table 
foreach country in `countries'{
cap frame drop dataset
frame create dataset
frame change dataset

// Load Data
get_data "GTI_FTP" $ftp_username $ftp_password"/08akkiGH/gtipipeline/output_datasets/CEU_GCO" "`country'_GTI_202209" "csv" "y"

// Years
quie levelsof tender_year if filter_ok=="TRUE"
local year_first = substr(r(levels),1,4)
local year_last = substr(r(levels),-4,.)
local years "`year_first' - `year_last'"

// Observations 
quie count 
local observations "`r(N)'"
// Contracts 
quie count if filter_ok=="TRUE"
local contracts "`r(N)'"

replace buyer_masterid="" if buyer_masterid=="NA"
replace bidder_masterid="" if bidder_masterid=="NA"
replace bid_priceusd="" if bid_priceusd=="NA"
destring bid_priceusd, force replace
if inlist("`country'","US","UY") gen tender_supplytype="NA"

// Buyers
quie unique buyer_masterid if !missing(buyer_masterid)
local unq_buyers "`r(unique)'"

// Bidders
quie unique bidder_masterid if !missing(bidder_masterid)
local unq_bidders "`r(unique)'"

// Contract value
quie sum bid_priceusd if filter_ok=="TRUE"
local total_value `r(sum)' 

// Contract value by supply type
quie sum bid_priceusd if filter_ok=="TRUE" & tender_supplytype=="SERVICES"
local total_value_serv `r(sum)' 
quie sum bid_priceusd if filter_ok=="TRUE" & tender_supplytype=="SUPPLIES"
local total_value_suppl `r(sum)' 
quie sum bid_priceusd if filter_ok=="TRUE" & tender_supplytype=="WORKS"
local total_value_works `r(sum)' 

// Contracts by supply type
quie count if filter_ok=="TRUE" & tender_supplytype=="SERVICES"
local contracts_serv "`r(N)'"
quie count if filter_ok=="TRUE" & tender_supplytype=="SUPPLIES"
local contracts_suppl "`r(N)'"
quie count if filter_ok=="TRUE" & tender_supplytype=="WORKS"
local contracts_works "`r(N)'"

// CRI
qui sum cri if filter_ok=="TRUE"
if inlist("`country'","CO","US") destring cri, force replace
local cri `r(mean)' 
di `cri'

// CRI breakdown
keep if filter_ok=="TRUE"
keep corr_* cri
ds corr_* cri, has(type str#)
foreach var in `r(varlist)'{
	replace `var' = "" if `var'=="NA"
	destring `var', replace force
}
cap drop non_miss
egen non_miss = rownonmiss(corr_*) , strok 

egen mean_cri = mean(cri) 

ds corr_*
foreach var in `r(varlist)' {
	replace `var' = `var'/non_miss
}
cap drop non_miss
gen country = "`country'"
order country *

// Place indicator breakdown in CRI_breakdown
frame change CRI_breakdown
frameappend dataset, drop
 
// Place Descriptive stats in desc_table
frame change desc_table
drop if country == "`country'"
count
local i = `r(N)' + 1
quie set obs `i'
replace country = "`country'" in `i'
replace years = "`years'"  in `i'
replace observations = "`observations'"  in `i'
replace contracts = "`contracts'"  in `i'
replace unq_buyers = "`unq_buyers'" in `i'
replace unq_bidders = "`unq_bidders'"  in `i'
replace total_value = "`total_value'"  in `i'

replace contracts_serv = "`contracts_serv'"  in `i'
replace total_value_serv = "`total_value_serv'"  in `i'

replace contracts_suppl = "`contracts_suppl'"  in `i'
replace total_value_suppl = "`total_value_suppl'"  in `i'

replace contracts_works = "`contracts_works'"  in `i'
replace total_value_works = "`total_value_works'"  in `i'

replace cri = "`cri'"  in `i'

}

// Save frames
frame change desc_table
save "${data_processed}/desc_table.dta", replace
frame change CRI_breakdown
save "${data_processed}/CRI_breakdown.dta", replace


set scheme plotplain					

clear 
use "${data_processed}/desc_table.dta", clear

// fixes
replace cri = "0.343582" if country=="CO"
replace cri = "0.56317507" if country=="PT"
replace cri = "0.0821548" if country=="US"
destring cri, replace 

**# CRI bars
graph bar cri , over(country, label(ticks labsize(vsmall) labgap(.05in) alternate) sort(cri))  ytitle("Composite risk score (CRI)", size(vsmall)) legend(off) blabel(bar, format(%8.2f) size(tiny))
graph export "${output_figures}/CRI_bars.png", as(png)  replace

**# Supply type bars
destring total_value_serv total_value_suppl total_value_works contracts_serv contracts_suppl contracts_works, replace
total total_value_serv total_value_suppl total_value_works
//Serv $167 tn
//Suppl $4.42 tn
//Works $396 tn

graph bar contracts_serv contracts_suppl contracts_works, ///
legend(label(1 "Services") label(2 "Supplies") label(3 "Works") pos(6) cols(3) rows(1) ) ///
bar(1, color(red%60)) ///
bar(2, color(blue%60)) ///
bar(3, color(ebblue%60)) ///
bargap(150)   

**# CRI Breakdown plot
clear
use "${data_processed}/CRI_breakdown.dta", clear

// keep if inlist(country,"AT","AM","BD","BE")

cap drop country_enc
gsort mean_cri
cap label drop lab2
egen country_enc = group(country)
//  CREATE A VALUE LABEL FOR VAR2 FROM THE VALUES OF VAR1
levelsof country_enc
forvalues i = 1/`r(r)'{
 levelsof country if country_enc==`i', local(country)
 label define lab2 `i' `country', add
 }
label list lab2
label values country_enc lab2

local vars  corr_singleb corr_proc corr_subm corr_nocft corr_decp corr_tax_haven corr_buyer_concentration
foreach var in `vars'{
	replace `var'=0.0000001 if missing(`var')
}

use "${data_processed}/CRI_breakdown.dta", clear


graph hbar corr_singleb corr_proc corr_subm corr_nocft corr_decp corr_tax_haven corr_buyer_concentration  , over(country_enc, sort((mean) mean_cri) lab(labsize(tiny)) )  stack cw  ///
bar(1, color(red%60)) ///
bar(2, color(blue%60)) ///
bar(3, color(ebblue%60)) ///
bar(4, color(purple%60)) ///
bar(5,color(olive_teal%60)) ///
bar(6, color(uwred%60)) ///
bar(7, color(yellow%60)) ///
legend(label(1 "Single Bidding") label(2 "Procedure type") label(3 "Submission Period") label(4 "No CFT published") label(5 "Decision Period") label(6 "Tax haven") label(7 "Spending share") pos(6) cols(4) rows(2)  )
graph export "${output_figures}/CRI_component_bars.png", as(png)  replace

graph hbar corr_singleb corr_proc corr_subm corr_nocft corr_decp corr_tax_haven corr_buyer_concentration , over(country_enc, sort((mean) mean_cri) lab(labsize(tiny)) ) stack per  ///
bar(1, color(red%60)) ///
bar(2, color(blue%60)) ///
bar(3, color(ebblue%60)) ///
bar(4, color(purple%60)) ///
bar(5,color(olive_teal%60)) ///
bar(6, color(uwred%60)) ///
bar(7, color(yellow%60)) ///
legend(label(1 "Single Bidding") label(2 "Procedure type") label(3 "Submission Period") label(4 "No CFT published") label(5 "Decision Period") label(6 "Tax haven") label(7 "Spending share") pos(6) cols(4) rows(2)  )
graph export "${output_figures}/CRI_component_percent_bars.png", as(png)  replace

**# CRI Map
set scheme plotplain					

cap frame drop map
frame create map 
frame change map

shp2dta using "${data_utility}/shp/World_Countries.shp", database("${data_utility}/shp/WC_db") coordinates("${data_utility}/shp/WC_coord") replace

use "${data_utility}/shp/WC_db", clear
gen iso = COUNTRY
do "${codes_utility}/country-to-iso.do" iso 
tab COUNTRY if missing(iso)
rename iso country

cap frame drop cri
frame create cri 
frame change cri

use "${data_processed}/desc_table.dta", clear
keep country cri
duplicates drop country, force

frame change map

frlink 1:1 country, frame(cri) gen(lnk)
frget cri=cri , from(lnk)
drop lnk
// drop country

cap frame drop map_coord
frame create map_coord 
frame change map_coord
use "${data_utility}/shp//WC_coord", clear
bys _ID: egen mean_x = mean(_X)
bys _ID: egen mean_y = mean(_Y)
duplicates drop _ID , force

frame change map
cap drop lnk
frlink 1:1 _ID, frame(map_coord) gen(lnk)
frget mean_x=mean_x , from(lnk)
frget mean_y=mean_y , from(lnk)

drop lnk

destring cri, replace

// spmap cri using "${data_utility}/shp//WC_coord" if !missing(cri), id(_ID) fcolor(Reds) ocolor(none ..)  label(xc(mean_x) yc(mean_y) label(country) select(keep if cri != .) size(*0.85 ..) position(2 3))   legstyle(0) legtitle(Higher CRI) 

cap drop cri_x
gen cri_x = 0.999 if !missing(cri)
replace cri_x=0.001 if missing(cri_x)

drop if length(country)>2 | country=="AQ"
levelsof _ID if length(country)>2 | country=="AQ", local(drops)
frame change map_coord
foreach drop in `drops'{
	drop if _ID==`drop'
}
frame change map

spmap cri_x using "${data_utility}/shp//WC_coord" , id(_ID) fcolor(PuBu) ocolor(grey%30 ..) clmethod(unique) legend(off)
graph export "${output_figures}/Data_available_map.png", as(png)  replace
