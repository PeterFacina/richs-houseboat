extends RefCounted

const RATE := 22050


# Filtered, pulsed air/mechanical noise instead of a sustained oscillator.
# Seeds keep the sound identical for every player without using gameplay RNG.
static func loop_texture(seed_value: int, pulses: float, softness: float, level: float) -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var frames := PackedFloat32Array()
	frames.resize(RATE * 4)
	var body := 0.0
	var rumble := 0.0
	for index in frames.size():
		body = lerpf(body, random.randf_range(-1.0, 1.0), softness)
		rumble = lerpf(rumble, body, .025)
		var t := float(index) / RATE
		var pulse := pow(.5 + .5 * sin(TAU * pulses * t), 3.0)
		frames[index] = (body - rumble) * (.65 + .35 * pulse) * level
	return sample(frames, RATE, true)


# Remove DC, cap peaks, and blend loop joins or taper one-shot edges.
static func sample(frames: PackedFloat32Array, rate: int, repeat := false) -> AudioStreamWAV:
	var fade := mini(int(rate * .012), frames.size() / 4)
	if repeat:
		var count := frames.size() - fade
		for index in fade:
			frames[index] = lerpf(frames[count + index], frames[index], float(index) / fade)
		frames.resize(count)
	else:
		for index in fade:
			var gain := smoothstep(0.0, float(fade), float(index))
			frames[index] *= gain
			frames[frames.size() - 1 - index] *= gain
	var mean := 0.0
	for value in frames:
		mean += value
	mean /= frames.size()
	var peak := 0.0
	for value in frames:
		peak = maxf(peak, absf(value - mean))
	var gain := minf(1.0, .32 / maxf(peak, .0001))
	var pcm := PackedByteArray()
	pcm.resize(frames.size() * 2)
	for index in frames.size():
		# A second taper keeps DC correction from reintroducing an edge step.
		var edge := 1.0 if repeat else smoothstep(0.0, float(fade), float(mini(index, frames.size() - 1 - index)))
		pcm.encode_s16(index * 2, roundi((frames[index] - mean) * gain * edge * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = pcm
	if repeat:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames.size()
	return stream
