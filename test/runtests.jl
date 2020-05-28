using Test

using SafeREPL
using SafeREPL: literalswapper, @swapliterals
using BitIntegers, SaferIntegers

@testset "swapliterals" begin
    swapbig = literalswapper(:BigFloat, :big, "@big_str")
    @test swapbig(1) == :(big(1))
    @test swapbig(1.2) == :(BigFloat(1.2))

    @swapliterals :BigFloat :big "@big_str" begin
        @test 1 == Int(1)
        @test 1 isa BigInt
        @test 1.2 isa BigFloat
        @test 1.0 == Float64(1.0)
        @test $1 isa Int
        @test $1.2 isa Float64
    end

    # TODO: these tests in loop are dubious
    for T in Base.BitUnsigned_types
        @test typeof(swapbig(T(1))) == T
    end
    for T in [Float32, Float16]
        @test typeof(swapbig(T(1))) == T
    end

    x = eval(swapbig(1.0))
    @test x isa BigFloat && x == 1.0
    x = eval(swapbig(1))
    @test x == 1 && x isa BigInt
    x = eval(swapbig(:11111111111111111111))
    @test x == 11111111111111111111 && x isa BigInt
    x = eval(swapbig(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    @swapliterals :BigFloat :big "@big_str" begin
        x = 1.0
        @test x isa BigFloat && x == Float64(1.0)
        x = 1
        @test x == Int(1) && x isa BigInt
        x = 11111111111111111111
        @test x == big"11111111111111111111" && x isa BigInt
        x = 1111111111111111111111111111111111111111
        @test x isa BigInt

        @test $1.0 isa Float64
        @test $11111111111111111111 isa Int128
        @test $1111111111111111111111111111111111111111 isa BigInt
    end

    swap128 = literalswapper(:Float64, :Int128, "@int128_str")
    x = eval(swap128(1))
    @test x == 1 && x isa Int128
    x = eval(swap128(:11111111111111111111))
    @test x == 11111111111111111111 && x isa Int128
    x = eval(swap128(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    @swapliterals :Float64 :Int128 "@int128_str" begin
        x = 1
        @test x == Int(1) && x isa Int128
        x = 11111111111111111111
        @test x == Int128(11111111111111111111) && x isa Int128
        x = 1111111111111111111111111111111111111111
        @test x isa BigInt
    end

    swapnothing = literalswapper(nothing, nothing, nothing)
    x = eval(swapnothing(1.0))
    @test x isa Float64
    x = eval(swapnothing(:11111111111111111111))
    @test x isa Int128
    x = eval(swapnothing(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    @swapliterals nothing nothing nothing begin
        x = 1.0
        @test x isa Float64
        x = 11111111111111111111
        @test x isa Int128
        x = 1111111111111111111111111111111111111111
        @test x isa BigInt
    end

    # pass :big instead of a string macro
    swaponly128 = literalswapper(nothing, nothing, :big)
    x = eval(swaponly128(:11111111111111111111))
    @test x isa BigInt

    @swapliterals nothing nothing :big begin
        x = 11111111111111111111
        @test x isa BigInt
    end

    # pass symbol for Int128
    swapBitIntegers = literalswapper(nothing, :Int256, :Int256)
    x = eval(swapBitIntegers(123))
    @test x isa Int256
    x = eval(swapBitIntegers(:11111111111111111111))
    @test x isa Int256

    swapSaferIntegers = literalswapper(nothing, :SafeInt, :SafeInt128)
    x = eval(swapSaferIntegers(123))
    @test x isa SafeInt
    x = eval(swapSaferIntegers(:11111111111111111111))
    @test x isa SafeInt128

    @swapliterals nothing :Int256 :Int256 begin
        x = 123
        @test x isa Int256
        x = 11111111111111111111
        @test x isa Int256
    end

    @swapliterals nothing :SafeInt :SafeInt128 begin
        x = 123
        @test x isa SafeInt
        x = 11111111111111111111
        @test x isa SafeInt128
    end

    # pass symbol for BigInt
    swapbig = literalswapper(nothing, nothing, :Int1024, :Int1024)
    x = eval(swapbig(:11111111111111111111))
    @test x isa Int1024
    x = eval(swapbig(:1111111111111111111111111111111111111111))
    @test x isa Int1024

    @swapliterals nothing nothing :Int1024 :Int1024 begin
        @test 11111111111111111111 isa Int1024
        @test 1111111111111111111111111111111111111111 isa Int1024
        @test $11111111111111111111 isa Int128
        @test $1111111111111111111111111111111111111111 isa BigInt
    end

    swapbig = literalswapper(nothing, nothing, :big, :big)
    x = eval(swapbig(:11111111111111111111))
    @test x isa BigInt
    x = eval(swapbig(:1111111111111111111111111111111111111111))
    @test x isa BigInt

    @swapliterals nothing nothing :big :big begin
        x = 11111111111111111111
        @test x isa BigInt
        x = 1111111111111111111111111111111111111111
        @test x isa BigInt
    end

    # strings
    @swapliterals nothing nothing nothing nothing "@r_str" begin
        @test "123" isa Regex
    end

    @swapliterals nothing nothing nothing nothing :Symbol begin
        @test "123" isa Symbol
    end
end

## playing with floats_use_rationalize!()

# can't be in a @testset apparently, probably because the parsing
# in @testset is done before floats_use_rationalize!() takes effect

@swapliterals "@big_str" nothing nothing nothing begin
    @test 1.2 == big"1.2"
end

SafeREPL.floats_use_rationalize!()
@swapliterals begin
    @test 1.2 == big"1.2"
end

# try again, with explicit `true` arg, and with :BigFloat instead of :big
SafeREPL.floats_use_rationalize!(true)
@swapliterals :BigFloat nothing nothing begin
    @test 1.2 == big"1.2"
end

SafeREPL.floats_use_rationalize!(false)
@swapliterals :BigFloat nothing nothing begin
    @test 1.2 == big"1.1999999999999999555910790149937383830547332763671875"
end
