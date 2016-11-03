type Op
    name::Symbol
    inputs::Vector{Symbol}
    outputs::Vector{Symbol}
    body::Vector{Op}
    info::Expr
end

function parse_function(expr)
    @assert (expr.head == :function || expr.head == :(=)) && length(expr.args) == 2  "Only functions can be differentiated"
    header = expr.args[1]
    @assert header.head == :call "Only functions can be differentiated"
    name = header.args[1]
    inputs = header.args[2:end]
    body = expr.args[2]
    @assert body.head == :block "Body of the function is not found"

    ops = []
    outputs = []
    info = Expr(:line)

    for line in body.args
        if line.head == :(=)
            outputs = parse_kw!(ops, info, line.args...)
        elseif line.head == :call
            outputs = [parse_arg!(ops, info, line)]
        elseif line.head == :tuple
            outputs = parse_tuple!(ops, info, line)
        elseif line.head == :line
            info = line
        else
            error("Do not know how to handle $line")
        end
    end
    Op(name, inputs, outputs, ops, info)
end

function parse_kw!(ops, info, vals, expr)
    func, inputs = parse_expr!(ops, info, expr)
    outputs = typeof(vals) == Symbol ? [vals] : [vals.args...]
    push!(ops, Op(func, inputs, outputs, [], info))
    outputs
end

function parse_expr!(ops, info, expr)
    @assert expr.head == :call "Do not know how to handle $expr"
    pretty(expr.args[1]), [parse_arg!(ops, info, arg) for arg in expr.args[2:end]]
end

pretty(name) = get(opnames, name, name)

const opnames = Dict(:(.*) => :dottimes, :(*) => :times, :(.+) => :dotplus, :(+) => :plus,
                     :(./) => :dotdivide, :(/) => :divide, :(.-) => :dotminus, :(-) => :minus,
                     :(.^) => :dotpower, :(^) => :power)

function parse_arg!(ops, info, arg)
    @assert typeof(arg) == Expr || typeof(arg) == Symbol "Do not know how to handle $arg"
    if typeof(arg) == Expr
        func, inputs = parse_expr!(ops, info, arg)
        arg = Symbol("tmp$(length(ops)+1)")
        push!(ops, Op(func, inputs, [arg], [], info))
    end
    arg
end

function parse_tuple!(ops, info, expr)
    @assert expr.head == :tuple
    [parse_arg!(ops, info, arg) for arg in expr.args]
end