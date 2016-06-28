
N = 4
ARRAY = zeros(Int, 4)
RAND = rand(4)*10

for i in 1:N
	@async begin
		sleep(RAND[i])
		ARRAY[i] = i
	end
end

ARRAY
