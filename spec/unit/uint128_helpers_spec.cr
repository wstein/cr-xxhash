require "../spec_helper"

describe "UInt128 helpers" do
  it "from_halves / high64 / low64 round-trip" do
    high = 0x123456789ABCDEF0_u64
    low = 0xFEDCBA9876543210_u64
    u = UInt128.from_halves(high, low)
    u.high64.should eq(high)
    u.low64.should eq(low)
  end

  it "to_bytes and to_hex32 produce canonical output" do
    u = UInt128.from_halves(0x0123456789ABCDEF_u64, 0xFEDCBA9876543210_u64)
    bytes = u.to_bytes
    bytes.size.should eq(16)
    bytes[0].should eq(0x01)
    bytes[7].should eq(0xEF)
    bytes[8].should eq(0xFE)
    bytes[15].should eq(0x10)

    u.to_hex32.should eq("0123456789abcdeffedcba9876543210")
  end

  it "from_c_hash / to_c_hash round-trip" do
    c = LibXXH::XXH128_hash_t.new
    c.low64 = 0xAAAAAAAAAAAAAAAA_u64
    c.high64 = 0x5555555555555555_u64

    u = UInt128.from_c_hash(c)
    c2 = u.to_c_hash
    c2.low64.should eq(c.low64)
    c2.high64.should eq(c.high64)
  end
end
