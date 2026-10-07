extends SceneTree
const Bank=preload("res://src/content/fsb5.gd")
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func run():
	var reader:=Bank.new()
	var block:=PackedByteArray();block.resize(36);block.fill(0x77);block.encode_u32(0,0)
	var result:=reader.decode_ima(block,64,1)
	# Independent IMA shift/add golden prefix; includes predictor and clipping.
	var expected:=[0,11,41,104,240,533,1164,2521,5431,11667,25039,32767]
	check(result.size()==128,"Mono Xbox IMA block must have 64 samples")
	for i in expected.size():check(result.decode_s16(i*2)==expected[i],"IMA predictor/step or clipping mismatch at %d"%i)
	block[35]=0xf7
	check(reader.decode_ima(block,64,1)==result,"Xbox IMA decoded the discarded high nibble")
	block[2]=89
	check(reader.decode_ima(block,64,1).is_empty(),"Invalid IMA step state was accepted")
	check(reader.decode_ima(PackedByteArray(),64,2).is_empty(),"Truncated stereo IMA was accepted")
	# A long sample is decoded in parts on worker threads. Every block must land
	# where decoding the blocks one at a time puts it, in both channel layouts
	# and with a last block cut short.
	var random:=RandomNumberGenerator.new();random.seed=7
	for channels in [1,2]:
		var count: int=64*(Bank.IMA_BLOCKS_PER_TASK*5+3)+17;var blocks: int=(count+63)/64
		var long:=PackedByteArray();long.resize(blocks*36*channels)
		for i in long.size():long[i]=random.randi()&255
		for header in range(0,long.size(),36*channels):
			for channel in channels:long[header+4*channel+2]=random.randi_range(0,88);long[header+4*channel+3]=0
		var whole:=reader.decode_ima(long,count,channels);var pieces:=PackedByteArray()
		for index in blocks:pieces.append_array(reader.decode_ima(long.slice(index*36*channels,(index+1)*36*channels),mini(64,count-index*64),channels))
		check(whole.size()==count*channels*2 and whole==pieces,"A sample decoded in parts differs from its blocks decoded one by one")
		long[(blocks-2)*36*channels+2]=89
		check(reader.decode_ima(long,count,channels).is_empty(),"An invalid late IMA block was accepted in a long sample")
	# A stereo block carries both headers, then four bytes of each channel in
	# turn. Its channels must decode as the same two blocks do alone.
	var left:=PackedByteArray();left.resize(36);var right:=left.duplicate()
	for i in range(4,36):left[i]=random.randi()&255;right[i]=random.randi()&255
	left.encode_s16(0,-1200);left[2]=31;right.encode_s16(0,900);right[2]=60
	var both:=left.slice(0,4)+right.slice(0,4)
	for group in 8:both.append_array(left.slice(4+group*4,8+group*4));both.append_array(right.slice(4+group*4,8+group*4))
	var stereo:=reader.decode_ima(both,64,2);var alone:=[reader.decode_ima(left,64,1),reader.decode_ima(right,64,1)]
	var interleaved:=stereo.size()==256
	for frame in 64:
		for channel in 2:interleaved=interleaved and stereo.decode_s16((frame*2+channel)*2)==alone[channel].decode_s16(frame*2)
	check(interleaved,"Stereo IMA channels are not the two blocks decoded alone")
	var bytes:=pcm_fixture()
	check(reader.open(bytes),reader.error)
	var stream: AudioStreamWAV=reader.stream(0,true)
	check(stream!=null and stream.data==PackedByteArray([0,0,0xff,0x7f,0,0x80]) and stream.mix_rate==44100 and stream.loop_end==3,"PCM source samples or full loop changed")
	var broken:=bytes.duplicate();broken.encode_u32(20,1)
	check(not reader.open(broken) and reader.samples.is_empty(),"FSB5 size mismatch retained the previous bank")
	broken=bytes.duplicate();broken.encode_u32(60+8,0xffffffff)
	check(not reader.open(broken),"Out-of-bounds FSB5 sample name was accepted")
	var args:=OS.get_cmdline_user_args()
	for i in range(0,args.size(),3):verify_source(args[i])
	print("FSB5: %d checks; %d failures"%[checks,failures]);quit(1 if failures else 0)
func pcm_fixture() -> PackedByteArray:
	var data:=PackedByteArray();data.resize(80);data.fill(0)
	for i in 4:data[i]=[70,83,66,53][i]
	data.encode_u32(4,1);data.encode_u32(8,1);data.encode_u32(12,8);data.encode_u32(16,6);data.encode_u32(20,6);data.encode_u32(24,2)
	data.encode_u64(60,(3<<34)|(8<<1));data.encode_u32(68,4);data[72]=120
	data[76]=0xff;data[77]=0x7f;data[79]=0x80
	return data
func verify_source(root_path: String):
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("manifest.json")))
	var banks:=0;var total:=0
	for name in manifest.files:
		if not name.ends_with(".fsb"):continue
		var reader:=Bank.new()
		if not reader.open(FileAccess.get_file_as_bytes(root_path.path_join(name))):check(false,name+": "+reader.error);continue
		banks+=1;total+=reader.samples.size()
		if name=="resources/FMOD_GOF2_MUSIC.fsb":
			for index in [0,5]:
				var stream: AudioStreamMP3=reader.stream(index,true)
				check(stream!=null,reader.error)
				if stream!=null:check(absf(stream.get_length()-float(reader.samples[index].samples)/reader.samples[index].rate)<0.0001,"MPEG framing changed duration")
		if name=="resources/FMOD_GOF2_SFX_SPACE.fsb":
			for index in [23,24,25,38,39]:
				var stream: AudioStreamWAV=reader.stream(index)
				check(stream!=null,reader.error)
				if stream!=null:check(stream.data.size()==reader.samples[index].samples*reader.samples[index].channels*2,"IMA decode sample count changed")
	check(banks==22 and total==4416,"Source audio inventory incomplete")
func check(value: bool,message: String):
	checks+=1
	if not value:failures+=1;push_error(message)
