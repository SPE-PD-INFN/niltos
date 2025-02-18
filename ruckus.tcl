# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

loadSource -lib niltos -dir "$::DIR_PATH/rtl"
loadSource -lib niltos -sim_only -dir "$::DIR_PATH/tb"
