connect

targets -set -filter {name =~ "Hart #0"}

puts "=== INPUT READ 1 ==="
set v1 [mrd -force -value 0x40000000]
puts $v1

after 500

puts "=== INPUT READ 2 ==="
set v2 [mrd -force -value 0x40000000]
puts $v2

after 500

puts "=== INPUT READ 3 ==="
set v3 [mrd -force -value 0x40000000]
puts $v3

exit
