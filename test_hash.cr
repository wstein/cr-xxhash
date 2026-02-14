require "./src/xxh"

empty = ""
puts "XXH32(\"\"): #{XXH::XXH32.hash(empty)}"
puts "Expected:   #{0x02cc5d05_u32} (which is #{0x02cc5d05_u32})"

test_a = "a"
puts "\nXXH32(\"a\"): #{XXH::XXH32.hash(test_a)}"
puts "Expected:   #{0x3c265948_u32}"
