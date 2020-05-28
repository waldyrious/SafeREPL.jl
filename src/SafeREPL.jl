module SafeREPL

using REPL

function __init__()
    activate = get(ENV, "SAFEREPL_INIT", "true")
    if activate == "true"
        swapliterals!(:big, :big, :big, nothing, firsttime=true)
    end
end

const FLOATS_USE_RATIONALIZE = Ref(false)

"""
    floats_use_rationalize!(yesno::Bool=true)

If `true`, a `Float64` input is first converted to `Rational{Int}`
via `rationalize` before being further transformed.
"""
floats_use_rationalize!(yesno::Bool=true) = FLOATS_USE_RATIONALIZE[] = yesno


const SmallArgs = Union{Nothing,Symbol}
const BigArgs = Union{Nothing,String,Symbol}

function literalswapper(Float64, Int, Int128, BigInt=nothing)
    @nospecialize
    literalswapper(; Float64, Int, Int128, BigInt)
end

function literalswapper(; swaps...)
    @nospecialize

    function swapper(@nospecialize(ex::Union{Float64,Int,String}), quoted=false)
        ts = ex isa Int ? :Int : Symbol(typeof(ex))
        swap = swaps[ts]

        if quoted || swap === nothing
            ex
        elseif !(ex isa Int) && swap isa String
            Expr(:macrocall, Symbol(swap), nothing, string(ex))
        elseif ex isa Float64 && FLOATS_USE_RATIONALIZE[]
            if swap == :big # big(1//2) doesn't return BigFloat
                swap = :BigFloat
            end
            :($swap(rationalize($ex)))
        else
            :($swap($ex))
        end
    end

    function swapper(@nospecialize(ex), quoted=false)
        if ex isa Expr && ex.head == :macrocall &&
            ex.args[1] isa GlobalRef &&
            ex.args[1].name ∈ (Symbol("@int128_str"),
                               Symbol("@big_str"))

            swap = swaps[ex.args[1].name == Symbol("@big_str") ?
                         :BigInt :
                         :Int128]

            if quoted || swap === nothing
                ex
            else
                if swap == :big
                    swap = "@big_str"
                end
                if swap isa String
                    ex.args[1] = Symbol(swap)
                    ex
                else # Symbol
                    :($swap($ex))
                end
            end
        else
            ex =
                if ex isa Expr
                    h = ex.head
                    # copied from REPL.softscope
                    if h in (:meta, :import, :using, :export, :module, :error, :incomplete, :thunk)
                        ex
                    elseif Meta.isexpr(ex, :$, 1)
                        swapper(ex.args[1], true)
                    else
                        ex′ = Expr(h)
                        map!(swapper, resize!(ex′.args, length(ex.args)), ex.args)
                        ex′
                    end
                else
                    ex
                end
            if quoted
                Expr(:$, ex)
            else
                ex
            end
        end
    end
end

function get_transforms()
    if isdefined(Base, :active_repl_backend) &&
        isdefined(Base.active_repl_backend, :ast_transforms)
        Base.active_repl_backend.ast_transforms::Vector{Any}
    elseif isdefined(REPL, :repl_ast_transforms)
        REPL.repl_ast_transforms::Vector{Any}
    else
        nothing
    end
end

"""
    SafeREPL.swapliterals!(F, I, I128, B)

Specify transformations for literals: `F` for literals of type `Float64`,
`I` for `Int`, `I128` for `Int128` and `B` for `BigInt`.

A transformation can be
* a `Symbol`, to refer to a function, e.g. `:big`;
* `nothing` to not transform literals of this type;
* a `String` specifying the name of a string macro, e.g. `"@big_str"`,
  which will be applied to the input. Available only for
  `I128` and `B`, and experimentally for `F`.
"""
function swapliterals!(F::BigArgs,
                       I::SmallArgs,
                       I128::BigArgs,
                       B::BigArgs=nothing;
                       S::BigArgs=nothing,
                       firsttime::Bool=false)
    @nospecialize

    swapliterals!(; Float64=F, Int=I, Int128=I128, BigInt=B, String=S,
                  firsttime
                  )
end

function swapliterals!(; firsttime=false, swaps...)
    @nospecialize

    # firsttime: when loading, avoiding filtering shaves off few tens of ms
    firsttime || swapliterals!(false) # remove previous settings
    transforms = get_transforms()
    if transforms === nothing
        @warn "$(@__MODULE__) could not be loaded"
    else
        push!(transforms, literalswapper(; swaps...))
    end
    nothing
end

function swapliterals!(swap::Bool)
    if swap
        swapliterals!(:big, :big, :big)
    else # deactivate
        filter!(f -> parentmodule(f) != @__MODULE__, get_transforms())
    end
    nothing
end

isactive() = any(==(@__MODULE__) ∘ parentmodule, get_transforms())


## macro

transform_arg(@nospecialize(x)) =
    if x isa QuoteNode
        x.value
    elseif x == :nothing
        nothing
    elseif x isa String
        x
    else
        throw(ArgumentError("invalid argument"))
    end

function macro_swapliterals(ex, swaps...)
    swaps = map(transform_arg, swaps)
    n = NamedTuple{(:Float64, :Int, :Int128, :BigInt, :String)}(swaps)
    literalswapper(; n...)
end

macro swapliterals(args...)
    if length(args) == 1
        macro_swapliterals(esc(args[1]), :(:big), :(:big), :(:big), :nothing, :nothing)
    elseif length(args) == 4
        macro_swapliterals(esc(args[4]), args[1:3]..., :nothing, :nothing)
    elseif length(args) == 5
        macro_swapliterals(esc(args[5]), args[1:4]..., :nothing)
    elseif length(args) == 6
        macro_swapliterals(esc(args[6]), args[1:5]...)
    else
        throw(ArgumentError("wrong number of arguments"))
    end
end


end # module
