s.boot;
s.quit;

(
s.waitForBoot {

	// ~samplePath = "/Users/tristankanitz/repos/CreativeBlocks/amen-break-120bpm.mp3";  // Tristan laptop's filepath
	~samplePath = "/home/pi/CreativeBlocks/amen-break-120bpm.mp3";  // pi's filepath
    ~buf = Buffer.read(s, ~samplePath);

	// reverb params
    ~wet = 0.2;
    ~room = 0.8;
    ~damp = 0.5;
    ~amp = 0.8;

	// delay params
	~delayTime = 0.3;
	~delayFeedback = 0.4;
	~delayMix = 0.3;

    ~player = nil;

    SynthDef(\samplePlayer, {
		|out=0, bufnum=0, amp=0.8, wet=0.2, room=0.8, damp=0.5,
		 delayTime=0.3, delayFeedback=0.4, delayMix=0.3|
		var sig, rev, delay, delaySig, mix;

		sig = PlayBuf.ar(
			numChannels: 2,
			bufnum: bufnum,
			rate: BufRateScale.kr(bufnum),
			loop: 1
		);
		sig = sig * amp;

		rev = FreeVerb.ar(sig, wet, room, damp);

		delaySig = LocalIn.ar(2);
		delay = CombL.ar(sig + (delaySig * delayFeedback), delayTime, delayTime, 2);
		LocalOut.ar(delay);

		mix = (sig * (1 - wet - delayMix)) + (rev * wet) + (delay * delayMix);
		Out.ar(out, [mix, mix]);
	}).add;

	s.sync;

	~startSample = {
		if(~player.isNil) {
			~player = Synth(\samplePlayer, [
				\bufnum, ~buf.bufnum,
				\amp, ~amp,
				\wet, ~wet,
				\room, ~room,
				\damp, ~damp,
				\delayTime, ~delayTime,
				\delayFeedback, ~delayFeedback,
				\delayMix, ~delayMix
			]);
			"SAMPLE STARTED".postln;
		};
	};

	~stopSample = {
		if(~player.notNil) {
			~player.free;
			~player = nil;
			"SAMPLE STOPPED".postln;
		};
	};

	~updateFX = {
		if(~player.notNil) {
			~player.set(
				\wet, ~wet,
				\room, ~room,
				\damp, ~damp,
				\amp, ~amp,
				\delayTime, ~delayTime,
				\delayFeedback, ~delayFeedback,
				\delayMix, ~delayMix
			);
		};
	};

	// start playing by default
	~startSample.value;

	// OSCdef does not need a specified IP address to listen to
	~myPort = 57121;

	OSCdef(\reverbControl, { |msg|
		~wet = msg[1].asFloat.clip(0.0, 1.0);
		~updateFX.value;
		("REVERB -> " ++ ~wet).postln;
	}, '/reverb', recvPort: ~myPort);

	OSCdef(\delayControl, { |msg|
		~delayMix = msg[1].asFloat.clip(0.0, 1.0);
		~updateFX.value;
		("DELAY -> " ++ ~delayMix).postln;
	}, '/delay', recvPort: ~myPort);

	// reversed gate: connection turns sound OFF
	OSCdef(\gateControl, { |msg|
		var on = msg[1].asFloat.clip(0, 1).round;
		if(on == 1) {
			~stopSample.value;
		} {
			~startSample.value;
		};
		("GATE -> " ++ ~on).postln;
	}, '/gate', recvPort: ~myPort);

    "SuperCollider ready.".postln;
	("Listening for OSC on port " ++ ~myPort).postln;

};
)