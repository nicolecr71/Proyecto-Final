connect

targets -set -filter {name =~ "Hart #0"}

puts "=== READ SWAP CONTROL / MAGIC ==="
set v1 [mrd -force -value 0x0003FFF8]
puts $v1

puts "=== WRITE SWAP REQUEST ==="
mwr -force 0x0003FFF8 0x00000001

after 100

puts "=== READ SWAP CONTROL / MAGIC AGAIN ==="
set v2 [mrd -force -value 0x0003FFF8]
puts $v2

exit
