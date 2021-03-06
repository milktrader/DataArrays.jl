module TestAbstractArray
	using Base.Test
	using DataArrays

	unsorted_dv = @data [2, 1, NA]
	sorted_dv = @data [NA, 1, 2]

	@assert isequal(sort(unsorted_dv), sorted_dv)
	@assert isequal(sortperm(unsorted_dv), [3, 2, 1])
	# TODO: Make this work
	# tiedrank(dv)

	@assert first(unsorted_dv) == 2
	@assert isna(last(unsorted_dv))
end
