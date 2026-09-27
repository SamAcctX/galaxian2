extends RefCounted
## Test input timestamps and expected native intervals. The production clock
## samples absolute millisecond endpoints, including after a focus rebase.

static func rate_delta_us(index: int,rate: int) -> int:
	assert(index>=0 and rate>0 and rate<=1000)
	return (index+1)*1000000/rate-index*1000000/rate

static func native_delta_ms(start_us: int,delta_us: int) -> int:
	return (start_us+delta_us)/1000-start_us/1000
