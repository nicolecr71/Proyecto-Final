connect

targets

targets -set -filter {name =~ "Hart #0"}
stop
rst -processor

dow /home/leandro/el3313_proyecto2/workspace/pong_app/build/pong_app.elf
con

puts "=== FIRMWARE PONG CON DOBLE BUFFER CARGADO ==="

exit
