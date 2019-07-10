********************************************************************************

** Title: Thermostats - Events Data
** Author: Ariel Listo
** Email: alisto@uchicago.edu
** Project: Smart Thermostats
** Date Started: 05/01/2019
** Last Updated: 06/26/2019
** Description: Exploits events data. Cleans and merges potentially complementary datasets.

********************************************************************************

** 0. Directory

cd "H:\downloads"

***** Hour level collapse *****

use ThermostatsEvents001, clear

drop created updated 

gen time = sent_at_sdt - cofd(dofc(sent_at_sdt))
	format time %tcHH
gen hour = 60 * 60000 * floor(time / (60 * 60 * 1000))
	format hour %tcHH
drop time

gen date = dofc(sent_at_sdt)
	format date %td

di date("20110101","YMD")
drop if date < 18628

gen minutes = mm(sent_at_sdt)
gen setpoint = 0
	replace setpoint = 1 if (event_type == "heating_setpoint" | event_type == "cooling_setpoint") & (minutes == 00 | minutes == 30)
gen override = 0
	replace override = 1 if (event_type == "heating_setpoint" | event_type == "cooling_setpoint") & minutes != 00 & minutes != 30

/*
********************************************************************************
****** Detour: Setpoint (permament) behavior over time	
	
	drop if setpoint != 1
	/* Close to 75% of setpoints occur at minutes == 0 */
	drop if minutes != 0
	

	destring value, replace force
	drop if value < 50 | value > 90
	
	gen hr = 0 if hour == 00
		replace hr = 1 if hour == 3600000
		replace hr = 2 if hour == 7200000
		replace hr = 3 if hour == 1.08e+07
		replace hr = 4 if hour == 1.44e+07
		replace hr = 5 if hour == 1.80e+07
		replace hr = 6 if hour == 2.16e+07
		replace hr = 7 if hour == 2.52e+07
		replace hr = 8 if hour == 2.88e+07
		replace hr = 9 if hour == 3.24e+07
		replace hr = 10 if hour == 3.60e+07
		replace hr = 11 if hour == 3.96e+07
		replace hr = 12 if hour == 4.32e+07
		replace hr = 13 if hour == 4.68e+07
		replace hr = 14 if hour == 5.04e+07
		replace hr = 15 if hour == 5.40e+07
		replace hr = 16 if hour == 5.76e+07
		replace hr = 17 if hour == 6.12e+07
		replace hr = 18 if hour == 6.48e+07
		replace hr = 19 if hour == 6.84e+07
		replace hr = 20 if hour == 7.20e+07
		replace hr = 21 if hour == 7.56e+07
		replace hr = 22 if hour == 7.92e+07
		replace hr = 23 if hour == 8.28e+07
		
	drop hour
	
	levelsof hr, local(hour)
	foreach l of local hour {
		preserve
		drop if hr != `l'
		sort user_id thermostat_id date
		bysort user_id thermostat_id: gen diff_`l' = value - value[_n-1] if event_type == event_type[_n-1]
		save data_diff_`l', replace
		restore
	}
	
	
use data_diff_0, clear
foreach n of numlist 1/23 {
	append using data_diff_`n'
}
	
	
foreach i of numlist 0/23 {
	bysort user_id thermostat_id: egen mean_cooling_diff_`i' = mean(diff_`i') if event_type == "cooling_setpoint"
}

foreach i of numlist 0/23 {
	bysort user_id thermostat_id: egen mean_heating_diff_`i' = mean(diff_`i') if event_type == "heating_setpoint"
}	
	
	
by user_id thermostat_id, sort: egen average_cooling_diff = mean(diff_0/23) if event_type == "cooling_setpoint"		
histogram average_cooling_diff
graph export "H:\Thermostats\average_cooling_setpoint_diff.eps", as(eps) preview(off) replace
		
by user_id thermostat_id, sort: egen average_heating_diff = mean(diff_0/23) if event_type == "heating_setpoint"
histogram average_heating_diff	
graph export "H:\Thermostats\average_heating_setpoint_diff.eps", as(eps) preview(off) replace
	
	
*** Counts of changes.....
*/
	
*br user_id thermostat_id date hr minutes value diff*

	
********************************************************************************
	
drop minutes
 
** Extract strings
gen hvac_state = value if event_type == "hvac_state"
gen hvac = value if event_type == "hvac"
gen fan_state = value if event_type == "fan"

drop if event_type == "gateway"

** Destring value variable and drop outliers **
destring value, replace force
	drop if value < 50 | value > 90
gen initial_ambient_temperature = value if event_type == "ambient_temperature"
	destring initial_ambient_temperature, replace
gen last_ambient_temperature = value if event_type == "ambient_temperature"
	destring last_ambient_temperature, replace

********************************************************************************
gen cooling_setpoint = value if event_type == "cooling_setpoint" & setpoint == 1
	destring cooling_setpoint, replace
gen heating_setpoint = value if event_type == "heating_setpoint" & setpoint == 1
	destring heating_setpoint, replace
gen cooling_override = value if event_type == "cooling_setpoint" & override == 1
	destring cooling_override, replace
gen heating_override = value if event_type == "heating_setpoint" & override == 1
	destring heating_override, replace
********************************************************************************

gen cooling = 1 if hvac_state == "cooling" | hvac_state == "pending_cool" | hvac == "cooling"
gen heating = 1 if hvac_state == "heating" | hvac_state == "pending_heat" | hvac == "heating"
gen fan = 1 if hvac_state == "fan" | fan_state != "" 
gen off = 1 if hvac_state == "off" | hvac == "off"

drop hvac_state hvac fan_state 

*Note: Figures with no missing user_id data - user_id as identifier
drop if missing(user_id)

collapse (firstnm) opower_customer_id zip county treated_dt_stata trt therm solar status selection_status ///
family pets year_built heat_type heat_electric heat_gas heat_mia multifam_dwelling ncal her her2 her_mia ///
her_recode sqft env_ind n_hhobs initial_ambient_temperature (lastnm) last_ambient_temperature ///
(mean) cooling_setpoint heating_setpoint cooling_override heating_override ///
(count) cooling heating fan off, by(user_id thermostat_id date hour)

drop cooling heating fan off


***** Means and Counts of Setpoints and Overrides *****
** Means
by thermostat_id hour, sort: egen mean_cooling_setpoint = mean(cooling_setpoint)
by thermostat_id hour: egen mean_heating_setpoint = mean(heating_setpoint)
by thermostat_id hour: egen mean_cooling_override = mean(cooling_override)
by thermostat_id hour: egen mean_heating_override = mean(heating_override)

**Figure 2 info
graph bar (mean) mean_cooling_setpoint (mean) mean_heating_setpoint, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Temperature) legend(on order(1 "Cooling Setpoint" 2 "Heating Setpoint")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\mean_setpoints.eps", as(eps) preview(off) replace

graph box mean_cooling_setpoint mean_heating_setpoint, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Temperature) legend(on order(1 "Cooling Setpoint" 2 "Heating Setpoint")) bar(2, fcolor(red) lcolor(red)) nooutsides
graph export "H:\Thermostats\mean_setpoints_box.eps", as(eps) preview(off) replace

graph bar (mean) mean_cooling_override (mean) mean_heating_override, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Temperature) legend(on order(1 "Cooling Override" 2 "Heating Override")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\mean_overrides.eps", as(eps) preview(off) replace

graph box mean_cooling_override mean_heating_override, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Temperature) legend(on order(1 "Cooling Override" 2 "Heating Override")) bar(2, fcolor(red) lcolor(red)) nooutsides
graph export "H:\Thermostats\mean_overrides_box.eps", as(eps) preview(off) replace

graph bar (mean) mean_cooling_setpoint (mean) mean_heating_setpoint if family == 1, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Temperature) legend(on order(1 "Cooling Setpoint" 2 "Heating Setpoint")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\mean_setpoints_fam.eps", as(eps) preview(off) replace

graph bar (mean) mean_cooling_override (mean) mean_heating_override if family == 1, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Temperature) legend(on order(1 "Cooling Override" 2 "Heating Override")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\mean_overrides_fam.eps", as(eps) preview(off) replace

graph bar (mean) mean_cooling_setpoint (mean) mean_heating_setpoint if family == 0, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Temperature) legend(on order(1 "Cooling Setpoint" 2 "Heating Setpoint")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\mean_setpoints_nofam.eps", as(eps) preview(off) replace

graph bar (mean) mean_cooling_override (mean) mean_heating_override if family == 0, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Temperature) legend(on order(1 "Cooling Override" 2 "Heating Override")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\mean_overrides_nofam.eps", as(eps) preview(off) replace


** Counts
by user_id hour, sort: egen count_cooling_setpoint = count(cooling_setpoint)
by user_id hour: egen count_heating_setpoint = count(heating_setpoint)
by user_id hour: egen count_cooling_override = count(cooling_override)
by user_id hour: egen count_heating_override = count(heating_override)


graph bar (mean) count_cooling_setpoint (mean) count_heating_setpoint, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Count) legend(on order(1 "Cooling Setpoint" 2 "Heating Setpoint")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\count_setpoints.eps", as(eps) preview(off) replace

graph bar (mean) count_cooling_override (mean) count_heating_override, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Count) legend(on order(1 "Cooling Override" 2 "Heating Override")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\count_overrides.eps", as(eps) preview(off) replace

graph bar (mean) count_cooling_setpoint (mean) count_heating_setpoint if family == 1, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Count) legend(on order(1 "Cooling Setpoint" 2 "Heating Setpoint")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\count_setpoints_fam.eps", as(eps) preview(off) replace

graph bar (mean) count_cooling_override (mean) count_heating_override if family == 1, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Count) legend(on order(1 "Cooling Override" 2 "Heating Override")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\count_overrides_fam.eps", as(eps) preview(off) replace

graph bar (mean) count_cooling_setpoint (mean) count_heating_setpoint if family == 0, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Count) legend(on order(1 "Cooling Setpoint" 2 "Heating Setpoint")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\count_setpoints_nofam.eps", as(eps) preview(off) replace

graph bar (mean) count_cooling_override (mean) count_heating_override if family == 0, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Count) legend(on order(1 "Cooling Override" 2 "Heating Override")) bar(2, fcolor(red) lcolor(red))
graph export "H:\Thermostats\count_overrides_nofam.eps", as(eps) preview(off) replace


***** Efficiency figures = difference between overrides and setpoints *****
sort user_id date hour

gen last_cooling_setpoint = cooling_setpoint
	replace last_cooling_setpoint = last_cooling_setpoint[_n-1] if last_cooling_setpoint == .

gen cooling_diff = cooling_override - last_cooling_setpoint 

graph bar (mean) cooling_diff, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Override Difference - Cooling)
graph export "H:\Thermostats\cooling_diff.eps", as(eps) preview(off) replace

gen last_heating_setpoint = heating_setpoint
	replace last_heating_setpoint = last_heating_setpoint[_n-1] if last_heating_setpoint == .
	
gen heating_diff = heating_override - last_heating_setpoint

graph bar (mean) heating_diff, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Override Difference - Heat) bar(1, fcolor(red) lcolor(red))
graph export "H:\Thermostats\heating_diff.eps", as(eps) preview(off) replace


***** Month (months in data) Indicator - Figures by Month *****
gen month = month(date)
gen year = year(date)

gen month_year = ym(year, month)
format month_year %tm

	** Generates month number var
	save events_data_nomonth, replace
	
	by user_id month_year, sort: gen x = _n
	keep if x == 1
	by user_id, sort: gen month_number = _n
	drop x
	keep user_id month_year month_number

	merge 1:m user_id month_year using events_data_nomonth
	drop _merge
	
	save events_data_wmonths, replace
	******************************************************

	
***** Merges Assign and Install Dates ******
merge m:1 user_id using assign_install_data, force

drop if _merge != 3
drop _merge

format day_assign %td
format day_install %td

* Generates Central California Indicator

di date("20121101", "YMD") 

gen ccal = 0
	replace ccal = 1 if day_assign > 19298

	
eststo central: estpost sum initial_ambient_temperature ///
	last_ambient_temperature cooling_setpoint heating_setpoint ///
	cooling_override heating_override if ccal == 1
eststo north: estpost sum initial_ambient_temperature ///
	last_ambient_temperature cooling_setpoint heating_setpoint ///
	cooling_override heating_override if ccal != 1
eststo all: estpost sum initial_ambient_temperature ///
	last_ambient_temperature cooling_setpoint heating_setpoint ///
	cooling_override heating_override

esttab central north all, ///
cells("mean(pattern(1 1 1) fmt(2)) sd(pattern(1 1 1)) count(pattern(1 1 1))") ///
label	
	
	
	
* Mean of Setpoints
bysort month_number: egen ccal_monthly_cooling_setpoint = mean(mean_cooling_setpoint) if ccal == 1
bysort month_number: egen ccal_monthly_heating_setpoint = mean(mean_heating_setpoint) if ccal == 1

* Mean of Overrides
bysort month_number: egen ccal_monthly_cooling_override = mean(mean_cooling_override) if ccal == 1
bysort month_number: egen ccal_monthly_heating_override = mean(mean_heating_override) if ccal == 1

* Mean of Diffs
bysort month_number: egen ccal_monthly_cooling_diff = mean(cooling_diff) if ccal == 1
bysort month_number: egen ccal_monthly_heating_diff = mean(heating_diff) if ccal == 1

line ccal_monthly_cooling_setpoint month_number
line ccal_monthly_heating_setpoint month_number
line ccal_monthly_cooling_override month_number 
line ccal_monthly_heating_override month_number
line ccal_monthly_cooling_diff month_number 
line ccal_monthly_heating_diff month_number


* Generates week and month from install variables
gen daysfrominstall = date - day_install

gen weeksfrominstall = round((daysfrominstall/7), 1)
gen monthsfrominstall = round((daysfrominstall/30.5), 1)

* Drops if event_data occurs before installation
drop if weeksfrominstall < 0

***** By weeksfromsintall figures *****
* Mean of Setpoints
bysort weeksfrominstall: egen weekly_cooling_setpoint = mean(mean_cooling_setpoint)
bysort weeksfrominstall: egen weekly_heating_setpoint = mean(mean_heating_setpoint)

* Mean of Overrides
bysort weeksfrominstall: egen weekly_cooling_override = mean(mean_cooling_override)
bysort weeksfrominstall: egen weekly_heating_override = mean(mean_heating_override)

* Mean of Diffs
bysort weeksfrominstall: egen weekly_cooling_diff = mean(cooling_diff)
bysort weeksfrominstall: egen weekly_heating_diff = mean(heating_diff) 


line weekly_cooling_setpoint weeksfrominstall
line weekly_heating_setpoint weeksfrominstall
line weekly_cooling_override weeksfrominstall 
line weekly_heating_override weeksfrominstall
line weekly_cooling_diff weeksfrominstall 
line weekly_heating_diff weeksfrominstall

line weekly_cooling_setpoint weeksfrominstall if months < 6, ytitle(Temperature) xtitle(Weeks from Install)
graph export "H:\Thermostats\weekly_cooling_setpoint.eps", as(eps) preview(off) replace

line weekly_heating_setpoint weeksfrominstall if months < 6, ytitle(Temperature) xtitle(Weeks from Install)
graph export "H:\Thermostats\weekly_heating_setpoint.eps", as(eps) preview(off) replace

line weekly_cooling_override weeksfrominstall if months < 6, ytitle(Temperature) xtitle(Weeks from Install)
graph export "H:\Thermostats\weekly_cooling_override.eps", as(eps) preview(off) replace

line weekly_heating_override weeksfrominstall if months < 6, ytitle(Temperature) xtitle(Weeks from Install)
*graph export "H:\Thermostats\weekly_heating_override.eps", as(eps) preview(off) replace

line weekly_cooling_diff weeksfrominstall if months < 6, ytitle(Temperature Difference) xtitle(Weeks from Install)
graph export "H:\Thermostats\weekly_cooling_diff.eps", as(eps) preview(off) replace

line weekly_heating_diff weeksfrominstall if months < 6, ytitle(Temperature Difference) xtitle(Weeks from Install)
graph export "H:\Thermostats\weekly_heating_diff.eps", as(eps) preview(off) replace

**************************************************************************************************************************
twoway (line weekly_heating_setpoint weeksfrominstall) (line weekly_heating_override weeksfrominstall)

**************************************************************************************************************************


***** Cooling and Heating Diff if first month *****
** Cooling
graph bar (mean) cooling_diff if monthsfrominstall <= 1, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Override Difference)
graph export "H:\Thermostats\cooling_diff_firstmonth.eps", as(eps) preview(off) replace

** Heating
graph bar (mean) heating_diff if monthsfrominstall <= 1, ///
over(hour, relabel(00 "00" 01 "1" 02 "2" 03 "3" 04 "4" 05 "5" 06 "6" 07 "7" 08 "8" 09 "9" 10 "10" ///
11 "11" 12 "12" 13 "13" 14 "14" 15 "15" 16 "16" 17 "17" 18 "18" 19 "19" 20 "20" 21 "21" 22 "22" 23 "23" 24 "00")) ///
ytitle(Override Difference) bar(1, fcolor(red) lcolor(red))
graph export "H:\Thermostats\heating_diff_firstmonth.eps", as(eps) preview(off) replace


***** By month_number figures *****
* Mean of Setpoints
bysort monthsfrominstall: egen monthly_cooling_setpoint = mean(mean_cooling_setpoint)
bysort monthsfrominstall: egen monthly_heating_setpoint = mean(mean_heating_setpoint)

* Mean of Overrides
bysort monthsfrominstall: egen monthly_cooling_override = mean(mean_cooling_override)
bysort monthsfrominstall: egen monthly_heating_override = mean(mean_heating_override)

* Mean of Diffs
bysort monthsfrominstall: egen monthly_cooling_diff = mean(cooling_diff)
bysort monthsfrominstall: egen monthly_heating_diff = mean(heating_diff)


line monthly_cooling_setpoint monthsfrominstall if monthsfrominstall < 6
line monthly_heating_setpoint monthsfrominstall if monthsfrominstall < 6
line monthly_cooling_override monthsfrominstall if monthsfrominstall < 6 
line monthly_heating_override monthsfrominstall if monthsfrominstall < 6
line monthly_cooling_diff monthsfrominstall if monthsfrominstall < 6 
line monthly_heating_diff monthsfrominstall if monthsfrominstall < 6




/***** Merge with Outside Temperature Data (A modified version of ThermostatsHour001) *****/

** Reformat hour variable
gen hr = 0 if hour == 00
	replace hr = 1 if hour == 3600000
	replace hr = 2 if hour == 7200000
	replace hr = 3 if hour == 1.08e+07
	replace hr = 4 if hour == 1.44e+07
	replace hr = 5 if hour == 1.80e+07
	replace hr = 6 if hour == 2.16e+07
	replace hr = 7 if hour == 2.52e+07
	replace hr = 8 if hour == 2.88e+07
	replace hr = 9 if hour == 3.24e+07
	replace hr = 10 if hour == 3.60e+07
	replace hr = 11 if hour == 3.96e+07
	replace hr = 12 if hour == 4.32e+07
	replace hr = 13 if hour == 4.68e+07
	replace hr = 14 if hour == 5.04e+07
	replace hr = 15 if hour == 5.40e+07
	replace hr = 16 if hour == 5.76e+07
	replace hr = 17 if hour == 6.12e+07
	replace hr = 18 if hour == 6.48e+07
	replace hr = 19 if hour == 6.84e+07
	replace hr = 20 if hour == 7.20e+07
	replace hr = 21 if hour == 7.56e+07
	replace hr = 22 if hour == 7.92e+07
	replace hr = 23 if hour == 8.28e+07
	
drop hour
rename hr hour

merge 1:1 user_id date hour using "D:\Thermostats\thermshour_formerge.dta"
keep if _merge == 3
drop _merge x

* Outside temperature difference variables
gen heating_setpoint_outside_diff = heating_setpoint - m_deg
gen cooling_setpoint_outside_diff = m_deg - cooling_setpoint

gen heating_override_outside_diff = heating_override - m_deg
gen cooling_override_outside_diff = m_deg - cooling_override

** Weekly and monthly figures of outside temp differences
bysort weeksfrominstall: egen weekly_heating_stp_outside_diff = mean(heating_setpoint_outside_diff)
bysort weeksfrominstall: egen weekly_cooling_stp_outside_diff = mean(cooling_setpoint_outside_diff)

bysort weeksfrominstall: egen weekly_heating_ovr_outside_diff = mean(heating_override_outside_diff)
bysort weeksfrominstall: egen weekly_cooling_ovr_outside_diff = mean(cooling_override_outside_diff)

** Weekly setpoint and outside temp diff
twoway (line weekly_heating_stp_outside_diff weeksfrominstall, lpattern(dash) lcolor(black)) (line weekly_heating_ovr_outside_diff weeksfrominstall, lpattern(dot) lcolor(black)), ///
ytitle(Temperature Difference) xtitle(Weeks from Installs) legend(on order(1 "Setpoint" 2 "Override"))
graph export "H:\Thermostats\heat_outside_diff.eps", as(eps) preview(off) replace

twoway (line weekly_cooling_stp_outside_diff weeksfrominstall, lpattern(dash) lcolor(black)) (line weekly_cooling_ovr_outside_diff weeksfrominstall, lpattern(dot) lcolor(black)), ///
ytitle(Temperature Difference) xtitle(Weeks from Installs) legend(on order(1 "Setpoint" 2 "Override"))
graph export "H:\Thermostats\cool_outside_diff.eps", as(eps) preview(off) replace


** Natural changes in outside temperature by weeksofinstall
bysort weeksfrominstall: egen mean_outside_temp = mean(m_deg)
line mean_outside_temp weeksfrominstall, ytitle(Mean Outside Temperature) xtitle(Weeks from Install)
graph export "H:\Thermostats\nat_outside_temp_diff.eps", as(eps) preview(off) replace


******Lfit figures
twoway (scatter heating_diff weeksfrominstall) (lfit heating_diff weeksfrominstall), ///
ytitle(Temperature Difference) xtitle(Weeks from Install) legend(on order(1 "Heating Difference" 2 "Fitted Values"))
graph export "H:\Thermostats\heat_diff_lfit.eps", as(eps) preview(off) replace

twoway (scatter cooling_diff weeksfrominstall) (lfit cooling_diff weeksfrominstall), ///
ytitle(Temperature Difference) xtitle(Weeks from Install) legend(on order(1 "Cooling Difference" 2 "Fitted Values"))
graph export "H:\Thermostats\cool_diff_lfit.eps", as(eps) preview(off) replace

twoway (scatter heating_setpoint_outside_diff weeksfrominstall) (lfit heating_setpoint_outside_diff weeksfrominstall), ///
ytitle(Temperature Difference) xtitle(Weeks from Install) legend(on order(1 "Heating Setpoint" 2 "Fitted Values"))
graph export "H:\Thermostats\heat_stp_lfit.eps", as(eps) preview(off) replace

twoway (scatter cooling_setpoint_outside_diff weeksfrominstall) (lfit cooling_setpoint_outside_diff weeksfrominstall), ///
ytitle(Temperature Difference) xtitle(Weeks from Install) legend(on order(1 "Cooling Setpoint" 2 "Fitted Values"))
graph export "H:\Thermostats\cool_stp_lfit.eps", as(eps) preview(off) replace

twoway (scatter heating_override_outside_diff weeksfrominstall) (lfit heating_override_outside_diff weeksfrominstall), ///
ytitle(Temperature Difference) xtitle(Weeks from Install) legend(on order(1 "Heating Override" 2 "Fitted Values"))
graph export "H:\Thermostats\heat_ovr_lfit.eps", as(eps) preview(off) replace

twoway (scatter cooling_override_outside_diff weeksfrominstall) (lfit cooling_override_outside_diff weeksfrominstall), ///
ytitle(Temperature Difference) xtitle(Weeks from Install) legend(on order(1 "Cooling Override" 2 "Fitted Values"))
graph export "H:\Thermostats\cool_ovr_lfit.eps", as(eps) preview(off) replace
**************************************


***** Regressions

reg heating_setpoint m_deg weeksfrominstall i.hour if ncal == 1
reg cooling_setpoint m_deg weeksfrominstall i.hour if ncal == 1

reg heating_override m_deg weeksfrominstall i.hour if ncal == 1
reg cooling_override m_deg weeksfrominstall i.hour if ncal == 1

reg heating_diff m_deg weeksfrominstall i.hour if ncal == 1
reg cooling_diff m_deg weeksfrominstall i.hour if ncal == 1



reg heating_setpoint m_deg m_deg2 weeksfrominstall i.hour if ncal == 1
reg cooling_setpoint m_deg m_deg2 weeksfrominstall i.hour if ncal == 1

reg heating_override m_deg m_deg2 weeksfrominstall i.hour if ncal == 1
reg cooling_override m_deg m_deg2 weeksfrominstall i.hour if ncal == 1

reg heating_diff m_deg m_deg2 weeksfrominstall i.hour if ncal == 1
reg cooling_diff m_deg m_deg2 weeksfrominstall i.hour if ncal == 1



reg heating_setpoint m_deg m_deg2 i.weeksfrominstall i.hour if ncal == 1
reg cooling_setpoint m_deg m_deg2 i.weeksfrominstall i.hour if ncal == 1

reg heating_override m_deg m_deg2 i.weeksfrominstall i.hour if ncal == 1
reg cooling_override m_deg m_deg2 i.weeksfrominstall i.hour if ncal == 1

reg heating_diff m_deg m_deg2 i.weeksfrominstall i.hour if ncal == 1
reg cooling_diff m_deg m_deg2 i.weeksfrominstall i.hour if ncal == 1


** Efficient override dummies

gen eff_heat_override = 0
	replace eff_heat_override = 1 if heating_diff < 0

gen ineff_heat_override = 0
	replace ineff_heat_override = 1 if heating_diff >= 0
	
gen eff_cool_override = 0
	replace eff_cool_override = 1 if heating_diff >= 0

gen ineff_cool_override = 0
	replace ineff_cool_override = 1 if heating_diff < 0
	


reg eff_heat_override m_deg m_deg2 i.weeksfrominstall i.hour if ncal == 1
reg eff_cool_override m_deg m_deg2 i.weeksfrominstall i.hour if ncal == 1
	
reg eff_heat_override m_deg m_deg2 weeksfrominstall i.hour if ncal == 1
reg eff_cool_override m_deg m_deg2 weeksfrominstall i.hour if ncal == 1





gen diff_heat_setpoint = heating_setpoint - heating_setpoint[_n-1]
gen diff_cool_setpoint = cooling_setpoint - cooling_setpoint[_n-1]

twoway (histogram diff_cool_setpoint, bcolor(blue)) (histogram diff_heat_setpoint, bcolor(red) legend(order(1 "Cooling" 2 "Heating")))


twoway (histogram cooling_diff, bcolor(blue)) (histogram heating_diff, bcolor(red) legend(order(1 "Cooling" 2 "Heating")))
*graph export "H:\Thermostats\diff_histogram.eps", as(eps) preview(off) replace



*********************************
** Changes in setpoints histogram
*********************************










	
	

/****************************NOTE: Will get back to this************************
** Twoway histograms and kdensities
twoway (histogram cooling_dif, bcolor(blue)) (histogram heating_dif, bcolor(red) legend(order(1 "Cooling" 2 "Heating")))
graph export "D:\Thermostats\diff_histogram.eps", as(eps) preview(off) replace

twoway (kdensity cooling_diff if month_number == 1, normal) (kdensity cooling_diff if month_number == 2, normal)

kdensity cooling_diff if month_number == 1, normal

graph twoway hist cooling_diff if month_number == 1, normal || hist cooling_diff if month_number == 2, normal


** Alternative to twoway kdensity, normal **
sum cooling_diff if month == 1
local m1 = r(mean)
local s1 = r(sd)

sum cooling_diff if month == 2
local m2 = r(mean)
local s2 = r(sd)

graph twoway (function normalden(x,`m1',`s1'), range(cooling_diff)) ///
             (function normalden(x,`m2',`s2'), range(cooling_diff))


** Kdensities by month
twoway (kdensity cooling_diff if month_number == 1, lwidth(thin) lcolor(black) normal) ///
    (kdensity cooling_diff if month_number == 2, lwidth(med) lcolor(green)) ///
    (kdensity cooling_diff if month_number == 3, lwidth(med) lcolor(green)) ///
    (kdensity cooling_diff if month_number == 4, lwidth(med) lcolor(green)) ///
    (kdensity cooling_diff if month_number == 5, lwidth(med) lcolor(green)) ///
    (kdensity cooling_diff if month_number == 6, lwidth(med) lcolor(green)) ///
    (kdensity cooling_diff if month_number == 7, lwidth(med) lcolor(blue)) ///    
    (kdensity cooling_diff if month_number == 8, lwidth(med) lcolor(blue)) ///
	(kdensity cooling_diff if month_number == 9, lwidth(med) lcolor(blue)) ///
	(kdensity cooling_diff if month_number == 10, lwidth(med) lcolor(blue)) ///
	(kdensity cooling_diff if month_number == 11, lwidth(med) lcolor(blue)) ///
	(kdensity cooling_diff if month_number == 12, lwidth(med) lcolor(blue)), ///
    xtitle("Deviations from Setpoints") /// 
    ytitle("Density") title("Cooling") /// 
    legend( label(1 "M1") label(2 "M2") label(3 "M3") ///
            label(4 "M4") label(5 "M5") label(6 "M6") ///
            label(7 "M7") label(8 "M8") label(9 "M9") ///
			label(10 "M10") label(11 "M11") label(12 "M12") cols(4) rows(3) ) ///
    scheme(s2color)
graph export "D:\Thermostats\coolingdiff_histogram_bymonth.eps", as(eps) preview(off) replace

twoway (kdensity heating_diff if month_number == 1, lwidth(thick) lcolor(black)) ///
    (kdensity heating_diff if month_number == 2, lwidth(med) lcolor(green)) ///
    (kdensity heating_diff if month_number == 3, lwidth(med) lcolor(green)) ///
    (kdensity heating_diff if month_number == 4, lwidth(med) lcolor(green)) ///
    (kdensity heating_diff if month_number == 5, lwidth(med) lcolor(green)) ///
    (kdensity heating_diff if month_number == 6, lwidth(med) lcolor(green)) ///
    (kdensity heating_diff if month_number == 7, lwidth(med) lcolor(red)) ///    
    (kdensity heating_diff if month_number == 8, lwidth(med) lcolor(red)) ///
	(kdensity heating_diff if month_number == 9, lwidth(med) lcolor(red)) ///
	(kdensity heating_diff if month_number == 10, lwidth(med) lcolor(red)) ///
	(kdensity heating_diff if month_number == 11, lwidth(med) lcolor(red)) ///
	(kdensity heating_diff if month_number == 12, lwidth(med) lcolor(red)), ///
    xtitle("Deviations from Setpoints") /// 
    ytitle("Density") title("Heating") /// 
    legend( label(1 "M1") label(2 "M2") label(3 "M3") ///
            label(4 "M4") label(5 "M5") label(6 "M6") ///
            label(7 "M7") label(8 "M8") label(9 "M9") ///
			label(10 "M10") label(11 "M11") label(12 "M12") cols(4) rows(3) ) ///
    scheme(s2color)
graph export "D:\Thermostats\heatingdiff_histogram_bymonth.eps", as(eps) preview(off) replace

gen first_semester = 0
	replace first_semester = 1 if month_number == 1 | month_number == 2 | month_number == 3 | month_number == 4 | month_number == 5 | month_number == 6
	
gen second_semester = 0
	replace second_semester = 1 if month_number == 7 | month_number == 8 | month_number == 9 | month_number == 10 | month_number == 11 | month_number == 12

twoway (kdensity cooling_diff if first_semester == 1, lwidth(thick) lcolor(blue)) ///
    (kdensity cooling_diff if second_semester == 1, lwidth(med) lcolor(green)) ///
    (kdensity cooling_diff if month_number > 12, lwidth(med) lcolor(red)), ///
    xtitle("Deviations from Setpoints") /// 
    ytitle("Density") title("Cooling") /// 
    legend( label(1 "First Semester") label(2 "Second Semester") label(3 "After 1 Year") ///
			cols(3) rows(1) ) ///
    scheme(s2color)
graph export "D:\Thermostats\coolingdiff_histogram_bysemester.eps", as(eps) preview(off) replace

twoway (kdensity heating_diff if first_semester == 1, lwidth(thick) lcolor(red)) ///
    (kdensity heating_diff if second_semester == 1, lwidth(med) lcolor(green)) ///
    (kdensity heating_diff if month_number > 12, lwidth(med) lcolor(black)), ///
    xtitle("Deviations from Setpoints") /// 
    ytitle("Density") title("Heating") /// 
    legend( label(1 "First Semester") label(2 "Second Semester") label(3 "After 1 Year") ///
			cols(3) rows(1) ) ///
    scheme(s2color)
graph export "D:\Thermostats\heatingdiff_histogram_bysemester.eps", as(eps) preview(off) replace
	

	
	



