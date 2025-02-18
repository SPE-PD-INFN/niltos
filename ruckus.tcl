# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

loadSource -lib nilt -dir "$::DIR_PATH/rtl"
loadSource -lib nilt -sim_only -dir "$::DIR_PATH/tb"
