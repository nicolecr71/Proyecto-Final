connect

targets -set -filter {name =~ "Hart #0"}

puts "=== INPUT READS ==="

set v [mrd -force -value 0x40000000]
puts $v

after 123
set v [mrd -force -value 0x40000000]
puts $v

after 157
set v [mrd -force -value 0x40000000]
puts $v

after 211
set v [mrd -force -value 0x40000000]
puts $v

after 333
set v [mrd -force -value 0x40000000]
puts $v

exit
