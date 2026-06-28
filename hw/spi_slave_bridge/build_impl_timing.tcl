# Re-implementa SOLO impl_1 (reusa synth_1) con estrategia agresiva + phys_opt
# para cerrar la violación de timing (~-1ns, route-dominated) en el video core.
set repo_root [file normalize [file join [file dirname [info script]] .. ..]]
open_project [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.xpr]

reset_run impl_1

# Directivas agresivas de place/route + phys_opt pre y post route.
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.ARGS.DIRECTIVE Explore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]

launch_runs impl_1 -to_step write_bitstream -jobs 6
wait_on_run impl_1

set wns [get_property STATS.WNS [get_runs impl_1]]
puts "================ IMPL RESULT ================"
puts "WNS = $wns"
puts "PROGRESS = [get_property PROGRESS [get_runs impl_1]]"
puts "STATUS = [get_property STATUS [get_runs impl_1]]"

if {[get_property PROGRESS [get_runs impl_1]] == "100%"} {
    set bit [glob -nocomplain [file join $repo_root Projects el3313_proyecto2 el3313_proyecto2.runs impl_1 *.bit]]
    if {[llength $bit] > 0} {
        file copy -force [lindex $bit 0] [file join $repo_root artifacts pong_slave.bit]
        write_hw_platform -fixed -include_bit -force \
            [file join $repo_root artifacts el3313_proyecto2.xsa]
        puts "Bitstream copiado a artifacts/pong_slave.bit"
    }
}
exit 0
