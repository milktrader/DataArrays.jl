module TestConversions
	using Base.Test
	using DataArrays

	@assert isequal((@data [1, 2, NA]),
		            DataArray((@pdata [1, 2, NA])))

	# Test vector() and matrix() conversion tools
	dv = @data ones(5)
	@assert isa(array(dv), Vector{Float64})
	@assert isa(convert(Vector{Float64}, dv), Vector{Float64})
	dv[1] = NA
	# Should raise errors:
	# vector(dv)
	# convert(Vector{Float64}, dv)
	@assert isa(array(dv, fail = false, out = Any), Vector{Any})
	@assert isnan(array(dv, out = Float64, replace = NaN)[1])

	dm = @data ones(3, 3)
	@assert isa(array(dm), Matrix{Float64})
	@assert isa(convert(Matrix{Float64}, dm), Matrix{Float64})
	dm[1, 1] = NA
	# Should raise errors:
	# matrix(dm)
	# convert(Matrix{Float64}, dm)
	@assert isa(array(dm, fail = false, out = Any), Matrix{Any})
	@assert isnan(array(dm, out = Float64, replace = NaN)[1, 1])
end
