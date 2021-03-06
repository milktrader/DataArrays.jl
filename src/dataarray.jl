abstract AbstractDataArray{T, N} <: AbstractArray{T, N}

type DataArray{T, N} <: AbstractDataArray{T, N}
    data::Array{T, N}
    na::BitArray{N}

    # Sanity check that new data values and missingness metadata match
    function DataArray(d::Array{T, N}, m::BitArray{N})
        if size(d) != size(m)
            msg = "Data and missingness arrays must be the same size"
            throw(ArgumentError(msg))
        end
        new(d, m)
    end
end

typealias AbstractDataVector{T} AbstractDataArray{T, 1}
typealias AbstractDataMatrix{T} AbstractDataArray{T, 2}
typealias DataVector{T} DataArray{T, 1}
typealias DataMatrix{T} DataArray{T, 2}

# Need to redefine inner constructor as outer constuctor
function DataArray{T, N}(d::Array{T, N},
                         m::BitArray{N} = falses(size(d)))
    return DataArray{T, N}(d, m)
end

# Convert Array{Bool} NA values to a BitArray
DataArray(d::Array, m::Array{Bool}) = DataArray(d, bitpack(m))

# Convert a BitArray into a DataArray
function DataArray(d::BitArray, m::BitArray = falses(size(d)))
    return DataArray(convert(Array{Bool}, d), m)
end

# Convert a Ranges object into a DataVector
DataArray(r::Ranges) = DataArray([r], falses(length(r)))

# Construct an all-NA DataArray of a specific type
DataArray(t::Type, dims::Integer...) = DataArray(Array(t, dims...),
                                                 trues(dims...))
DataArray{N}(t::Type, dims::NTuple{N,Int}) = DataArray(Array(t, dims...), 
                                                 trues(dims...))

# Copying
Base.copy(d::DataArray) = DataArray(copy(d.data), copy(d.na))
Base.deepcopy(d::DataArray) = DataArray(deepcopy(d.data), deepcopy(d.na))
function Base.copy!(dest::DataArray, src::Any)
    i = 1
    for x in src
        dest[i] = x
        i += 1
    end
    return dest
end

# Similar array allocation
function Base.similar(d::DataArray, T::Type, dims::Dims)
    DataArray(Array(T, dims), BitArray(dims))
end

# Size information
Base.size(d::DataArray) = size(d.data)
Base.ndims(d::DataArray) = ndims(d.data)
Base.length(d::DataArray) = length(d.data)
Base.endof(d::DataArray) = endof(d.data)
Base.eltype{T, N}(d::DataArray{T, N}) = T

# Dealing with NA's
function failNA(da::DataArray)
    if anyna(da)
        throw(NAException())
    else
        return copy(da.data)
    end
end

# NB: Can do strange things on DataArray of rank > 1
function removeNA(da::DataArray)
    return copy(da.data[!da.na])
end

function replaceNA(da::DataArray, replacement_val::Any)
    res = copy(da.data)
    for i in 1:length(da)
        if da.na[i]
            res[i] = replacement_val
        end
    end
    return res
end

replaceNA(replacement_val::Any) = x -> replaceNA(x, replacement_val)

# TODO: Re-implement these methods for PooledDataArray's
function failNA{T}(da::AbstractDataArray{T})
    if anyna(da)
        throw(NAException())
    else
        res = Array(T, size(da))
        for i in 1:length(da)
            res[i] = da[i]
        end
        return res
    end
end

# TODO: Figure out how to make this work for Array's
function removeNA{T}(da::AbstractDataVector{T})
    n = length(da)
    res = Array(T, n)
    total = 0
    for i in 1:n
        if !isna(da[i])
            total += 1
            res[total] = convert(T, da[i])
        end
    end
    return res[1:total]
end

removeNA(a::AbstractArray) = a

function replaceNA{S, T}(da::AbstractDataArray{S}, replacement_val::T)
    res = Array(S, size(da))
    for i in 1:length(da)
        if isna(da[i])
            res[i] = replacement_val
        else
            res[i] = da[i]
        end
    end
    return res
end

# Iterators

type EachFailNA{T}
    da::AbstractDataArray{T}
end
each_failNA{T}(da::AbstractDataArray{T}) = EachFailNA(da)
Base.start(itr::EachFailNA) = 1
function Base.done(itr::EachFailNA, ind::Integer)
    return ind > length(itr.da)
end
function Base.next(itr::EachFailNA, ind::Integer)
    if isna(itr.da[ind])
        throw(NAException())
    else
        (itr.da[ind], ind + 1)
    end
end

type EachRemoveNA{T}
    da::AbstractDataArray{T}
end
each_removeNA{T}(da::AbstractDataArray{T}) = EachRemoveNA(da)
Base.start(itr::EachRemoveNA) = 1
function Base.done(itr::EachRemoveNA, ind::Integer)
    return ind > length(itr.da)
end
function Base.next(itr::EachRemoveNA, ind::Integer)
    while ind <= length(itr.da) && isna(itr.da[ind])
        ind += 1
    end
    (itr.da[ind], ind + 1)
end

type EachReplaceNA{S, T}
    da::AbstractDataArray{S}
    replacement_val::T
end
function each_replaceNA(da::AbstractDataArray, val::Any)
    EachReplaceNA(da, convert(eltype(da), val))
end
function each_replaceNA(val::Any)
    x -> each_replaceNA(x, val)
end
Base.start(itr::EachReplaceNA) = 1
function Base.done(itr::EachReplaceNA, ind::Integer)
    return ind > length(itr.da)
end
function Base.next(itr::EachReplaceNA, ind::Integer)
    if isna(itr.da[ind])
        (itr.replacement_val, ind + 1)
    else
        (itr.da[ind], ind + 1)
    end
end

# Indexing

typealias SingleIndex Real
typealias MultiIndex Union(Vector, BitVector, Ranges, Range1)
typealias BooleanIndex Union(BitVector, Vector{Bool})

# TODO: Solve ambiguity warnings here without
#       ridiculous accumulation of methods
# v[dv]
function Base.getindex(x::Vector,
                       inds::AbstractDataVector{Bool})
    return x[find(replaceNA(inds, false))]
end
function Base.getindex(x::Vector,
                       inds::AbstractDataArray{Bool})
    return x[find(replaceNA(inds, false))]
end
function Base.getindex(x::Array,
                       inds::AbstractDataVector{Bool})
    return x[find(replaceNA(inds, false))]
end
function Base.getindex(x::Array,
                       inds::AbstractDataArray{Bool})
    return x[find(replaceNA(inds, false))]
end
function Base.getindex{S, T}(x::Vector{S},
                             inds::AbstractDataArray{T})
    return x[removeNA(inds)]
end
function Base.getindex{S, T}(x::Array{S},
                             inds::AbstractDataArray{T})
    return x[removeNA(inds)]
end

# d[SingleItemIndex]
function Base.getindex(d::DataArray, i::SingleIndex)
	if d.na[i]
		return NA
	else
		return d.data[i]
	end
end

# d[MultiItemIndex]
# TODO: Return SubDataArray
function Base.getindex(d::DataArray,
                       inds::AbstractDataVector{Bool})
    inds = find(replaceNA(inds, false))
    return d[inds]
end
function Base.getindex(d::DataArray,
                       inds::AbstractDataVector)
    inds = removeNA(inds)
    return d[inds]
end

# There are two definitions in order to remove ambiguity warnings
# TODO: Return SubDataArray
# TODO: Make inds::AbstractVector
function Base.getindex{T <: Number, N}(d::DataArray{T,N},
                                       inds::BooleanIndex)
    DataArray(d.data[inds], d.na[inds])
end

function Base.getindex(d::DataArray, inds::BooleanIndex)
    res = similar(d, sum(inds))
    j = 1
    for i in 1:length(inds)
        if inds[i]
            if !d.na[i]
                res[j] = d.data[i]
            end
            j += 1
        end
    end
    return res
end

function Base.getindex{T <: Number, N}(d::DataArray{T, N},
                                       inds::MultiIndex)
    return DataArray(d.data[inds], d.na[inds])
end

function Base.getindex(d::DataArray, inds::MultiIndex)
    res = similar(d, length(inds))
    for i in 1:length(inds)
        ix = inds[i]
        if !d.na[ix]
            res[i] = d.data[ix]
        else
            res[i] = NA # We could also change this in similar
        end
    end
    return res
end

# TODO: Return SubDataArray
# TODO: Make inds::AbstractVector
## # The following assumes that T<:Number won't have #undefs
## # There are two definitions in order to remove ambiguity warnings
function Base.getindex{T <: Number, N}(d::DataArray{T, N},
                                       inds::BooleanIndex)
    DataArray(d.data[inds], d.na[inds])
end
function Base.getindex{T <: Number, N}(d::DataArray{T, N},
                                       inds::MultiIndex)
    DataArray(d.data[inds], d.na[inds])
end

# setindex!()

# d[SingleItemIndex] = NA
function Base.setindex!(da::DataArray, val::NAtype, i::SingleIndex)
	da.na[i] = true
    return NA
end

# d[SingleItemIndex] = Single Item
function Base.setindex!(da::DataArray, val::Any, i::SingleIndex)
	da.data[i] = val
	da.na[i] = false
    return val
end

# d[MultiIndex] = NA
function Base.setindex!(da::DataArray{NAtype},
                        val::NAtype,
                        inds::AbstractVector{Bool})
    throw(ArgumentError("DataArray{NAtype} is incoherent"))
end
function Base.setindex!(da::DataArray{NAtype},
                        val::NAtype,
                        inds::AbstractVector)
    throw(ArgumentError("DataArray{NAtype} is incoherent"))
end
function Base.setindex!(da::DataArray,
                        val::NAtype,
                        inds::AbstractVector{Bool})
    da.na[find(inds)] = true
    return NA
end
function Base.setindex!(da::DataArray,
                        val::NAtype,
                        inds::AbstractVector)
    da.na[inds] = true
    return NA
end

# d[MultiIndex] = Multiple Values
function Base.setindex!(da::AbstractDataArray,
                        vals::AbstractVector,
                        inds::AbstractVector{Bool})
    setindex!(da, vals, find(inds))
end
function Base.setindex!(da::AbstractDataArray,
                        vals::AbstractVector,
                        inds::AbstractVector)
    for (val, ind) in zip(vals, inds)
        da[ind] = val
    end
    return vals
end

# x[MultiIndex] = Single Item
function Base.setindex!{T}(da::AbstractDataArray{T},
                           val::Union(Number, String, T),
                           inds::AbstractVector{Bool})
    setindex!(da, val, find(inds))
end
function Base.setindex!{T}(da::AbstractDataArray{T},
                           val::Union(Number, String, T),
                           inds::AbstractVector)
    val = convert(T, val)
    for ind in inds
        da[ind] = val
    end
    return val
end
function Base.setindex!(da::AbstractDataArray,
                        val::Any,
                        inds::AbstractVector{Bool})
    setindex!(da, val, find(inds))
end
function Base.setindex!{T}(da::AbstractDataArray{T},
                           val::Any,
                           inds::AbstractVector)
    val = convert(T, val)
    for ind in inds
        da[ind] = val
    end
    return val
end

# Predicates

isna(da::DataArray) = copy(da.na)

Base.isnan(da::DataArray) = DataArray(isnan(da.data), copy(da.na))

Base.isfinite(da::DataArray) = DataArray(isfinite(da.data), copy(da.na))

isna(a::AbstractArray) = falses(size(a))

anyna(a::AbstractArray) = false
anyna(d::AbstractDataArray) = any(isna, d)

allna(a::AbstractArray) = false
allna(d::AbstractDataArray) = allp(isna, d)

# Generic iteration over AbstractDataArray's

Base.start(x::AbstractDataArray) = 1

function Base.next(x::AbstractDataArray, state::Integer)
    return (x[state], state + 1)
end

function Base.done(x::AbstractDataArray, state::Integer)
    return state > length(x)
end

# Promotion rules

# promote_rule{T, T}(::Type{AbstractDataArray{T}},
#                    ::Type{T}) = promote_rule(T, T)
# promote_rule{S, T}(::Type{AbstractDataArray{S}},
#                    ::Type{T}) = promote_rule(S, T)
# promote_rule{T}(::Type{AbstractDataArray{T}}, ::Type{T}) = T

# Conversion rules

# TODO: Remove this
function Base.convert{N}(::Type{BitArray{N}}, d::DataArray{BitArray{N}, N})
    throw(ArgumentError("Can't convert to BitArray"))
end

function Base.convert{T, N}(::Type{BitArray{N}}, d::DataArray{T, N})
    throw(ArgumentError("Can't convert to BitArray"))
end

function Base.convert{T, N}(::Type{Array{T, N}}, x::DataArray{T, N})
    if anyna(x)
        err = "Cannot convert DataArray with NA's to base type"
        throw(NAException(err))
    else
        return x.data
    end
end

function Base.convert{S, T, N}(::Type{Array{S, N}}, x::DataArray{T, N})
    if anyna(x)
        err = "Cannot convert DataArray with NA's to desired type"
        throw(NAException(err))
    else
        return convert(S, x.data)
    end
end

function Base.convert{S, T, N}(::Type{DataArray{S, N}}, x::DataArray{T, N})
    return DataArray(convert(Array{S}, x.data), x.na)
end

# Conversion convenience functions

# TODO: Make sure these handle copying correctly
# Data -> Not Data
for f in (:(Base.int), :(Base.float), :(Base.bool))
    @eval begin
        function ($f)(da::DataArray)
            if anyna(da)
                err = "Cannot convert DataArray with NA's to desired type"
                throw(NAException(err))
            else
                ($f)(da.data)
            end
        end
    end
end

# Not Data -> Data
# Data{T} -> Data{S}
for (f, basef) in ((:dataint, :int),
                   (:datafloat, :float64),
                   (:databool, :bool))
    @eval begin
        function ($f)(a::Array)
            DataArray(($basef)(a))
        end
        function ($f)(da::DataArray)
            DataArray(($basef)(da.data), copy(da.na))
        end
    end
end

# Conversion to Array

# TODO: Review these
function vector(adv::AbstractDataVector, t::Type, replacement_val::Any)
    n = length(adv)
    res = Array(t, n)
    for i in 1:n
        if isna(adv[i])
            res[i] = replacement_val
        else
            res[i] = adv[i]
        end
    end
    return res
end

function vector(adv::AbstractDataVector, t::Type)
    n = length(adv)
    res = Array(t, n)
    for i in 1:n
        res[i] = adv[i]
    end
    return res
end

vector{T}(adv::AbstractDataVector{T}) = vector(adv, T)

vector{T}(v::Vector{T}) = v

function matrix(adm::AbstractDataMatrix, t::Type, replacement_val::Any)
    n, p = size(adm)
    res = Array(t, n, p)
    for i in 1:n
        for j in 1:p
            if isna(adm[i, j])
                res[i, j] = replacement_val
            else
                res[i, j] = adm[i, j]
            end
        end
    end
    return res
end

function matrix(adm::AbstractDataMatrix, t::Type)
    n, p = size(adm)
    res = Array(t, n, p)
    for i in 1:n
        for j in 1:p
            res[i, j] = adm[i, j]
        end
    end
    return res
end

matrix{T}(adm::AbstractDataMatrix{T}) = matrix(adm, T)

# Hashing
# TODO: Make sure this agrees with is_equals()

function Base.hash(a::AbstractDataArray)
    h = hash(size(a)) + 1
    for i in 1:length(a)
        h = bitmix(h, int(hash(a[i])))
    end
    return uint(h)
end
