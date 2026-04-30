s.boot;

(
s.waitForBoot {

	// =====================================================
	// CREATIVEBLOCKS DEMO
	// 3 pads / 3 songs
	//
	// Pad 0 = Song 1 = MPR slots 0 and 1
	// Pad 1 = Song 2 = MPR slots 2 and 3
	// Pad 2 = Song 3 = MPR slots 4 and 5
	//
	// BOTH pins active = Drums
	// LEFT / first pin active = Vocals
	// RIGHT / second pin active = Melody
	//
	// Files:
	// drums1_mono.mp3, vocals1_mono.mp3, mel1_mono.mp3
	// drums2_mono.mp3, vocals2_mono.mp3, mel2_mono.mp3
	// drums3_mono.mp3, vocals3_mono.mp3, mel3_mono.mp3
	// =====================================================

	"====================================================".postln;
	"CREATIVEBLOCKS DEMO BOOTING".postln;
	"PAD = SONG, PINS = STEM".postln;
	"====================================================".postln;

	// =====================================================
	// FILE PATHS
	// =====================================================

	~paths = [
		[
			"/home/pi/Downloads/drums1_mono.mp3",
			"/home/pi/Downloads/vocals1_mono.mp3",
			"/home/pi/Downloads/mel1_mono.mp3"
		],
		[
			"/home/pi/Downloads/drums2_mono.mp3",
			"/home/pi/Downloads/vocals2_mono.mp3",
			"/home/pi/Downloads/mel2_mono.mp3"
		],
		[
			"/home/pi/Downloads/drums3_mono.mp3",
			"/home/pi/Downloads/vocals3_mono.mp3",
			"/home/pi/Downloads/mel3_mono.mp3"
		]
	];

	~numPads = 3;
	~numStems = 3;

	~stemNames = [
		"Drums",
		"Vocals",
		"Melody"
	];

	// Each pad uses two MPR slots: left and right
	~padSlots = [
		[0, 1], // Pad 0 / Song 1
		[2, 3], // Pad 1 / Song 2
		[4, 5]  // Pad 2 / Song 3
	];

	// Stem mapping
	~stemBoth = 0;  // both points active = drums
	~stemLeft = 1;  // left only = vocals
	~stemRight = 2; // right only = melody

	"Configured layout:".postln;
	"Pad 0 = Song 1 = MPR slots 0 and 1".postln;
	"Pad 1 = Song 2 = MPR slots 2 and 3".postln;
	"Pad 2 = Song 3 = MPR slots 4 and 5".postln;
	"".postln;
	"Both pins active = Drums".postln;
	"Left/first pin active only = Vocals".postln;
	"Right/second pin active only = Melody".postln;
	"".postln;

	// =====================================================
	// LOAD AUDIO BUFFERS
	// =====================================================

	"Loading audio buffers...".postln;

	~bufs = Array.fill(~numPads, { |song|
		Array.fill(~numStems, { |stem|
			var path;
			path = ~paths[song][stem];

			("Loading file for song " ++ (song + 1) ++ ", stem " ++ stem ++ " / " ++ ~stemNames[stem] ++ ":").postln;
			path.postln;

			Buffer.read(s, path);
		});
	});

	s.sync;

	"Audio buffer loading complete.".postln;
	"".postln;

	// =====================================================
	// SYNTHDEF
	// =====================================================

	"Creating SynthDef...".postln;

	SynthDef(\stemPlayer, {
		|out=0, bufnum=0, amp=0.8, rate=1.0, wet=0.12, room=0.7, damp=0.5|

		var sig, dry, rev, mix;

		sig = PlayBuf.ar(
			numChannels: 1,
			bufnum: bufnum,
			rate: BufRateScale.kr(bufnum) * rate,
			loop: 1
		);

		// mono file -> both ears
		sig = sig ! 2;

		sig = sig * amp;

		dry = sig;
		rev = FreeVerb.ar(sig, wet, room, damp);

		mix = (dry * (1 - wet)) + (rev * wet);

		Out.ar(out, mix);
	}).add;

	s.sync;

	"SynthDef ready.".postln;
	"".postln;

	// =====================================================
	// STATE
	// =====================================================

	"Initializing state arrays...".postln;

	// MPR slot state, slots 0 through 5
	~mprActive = Array.fill(6, { false });

	// ~padActive[pad][stem]
	~padActive = Array.fill(~numPads, {
		Array.fill(~numStems, { false });
	});

	// ~players[pad][stem]
	~players = Array.fill(~numPads, {
		Array.fill(~numStems, { nil });
	});

	// Each stem has its own tempo and reverb values.
	// Drums, vocals, melody values apply across songs.
	~tempoValues = Array.fill(~numStems, { 1.0 });
	~reverbValues = Array.fill(~numStems, { 0.12 });

	"State initialized.".postln;
	"".postln;

	// =====================================================
	// PRINT CURRENT STATE
	// =====================================================

	~printState = {
		"---------------- CURRENT STATE ----------------".postln;

		~numPads.do { |pad|
			("Pad " ++ pad ++ " / Song " ++ (pad + 1)).postln;

			~numStems.do { |stem|
				(
					"    " ++ ~stemNames[stem] ++
					" active = " ++ ~padActive[pad][stem] ++
					", playing = " ++ ~players[pad][stem].notNil
				).postln;
			};
		};

		"MPR slot states:".postln;
		6.do { |slot|
			("    Slot " ++ slot ++ " active = " ++ ~mprActive[slot]).postln;
		};

		"Knob values by stem:".postln;
		~numStems.do { |stem|
			(
				"    Stem " ++ stem ++ " / " ++ ~stemNames[stem] ++
				": tempo = " ++ ~tempoValues[stem] ++
				", reverb = " ++ ~reverbValues[stem]
			).postln;
		};

		"------------------------------------------------".postln;
		"".postln;
	};

	// =====================================================
	// AUDIO FUNCTIONS
	// =====================================================

	~startStem = { |pad, stem|
		if(~players[pad][stem].isNil) {
			(
				"STARTING AUDIO -> Song " ++ (pad + 1) ++
				", Stem " ++ stem ++
				" / " ++ ~stemNames[stem]
			).postln;

			~players[pad][stem] = Synth(\stemPlayer, [
				\bufnum, ~bufs[pad][stem].bufnum,
				\amp, 0.8,
				\rate, ~tempoValues[stem],
				\wet, ~reverbValues[stem]
			]);

			(
				"Now playing: Song " ++ (pad + 1) ++
				" - " ++ ~stemNames[stem]
			).postln;
		} {
			(
				"Already playing -> Song " ++ (pad + 1) ++
				", " ++ ~stemNames[stem]
			).postln;
		};
	};

	~stopStem = { |pad, stem|
		if(~players[pad][stem].notNil) {
			(
				"STOPPING AUDIO -> Song " ++ (pad + 1) ++
				", Stem " ++ stem ++
				" / " ++ ~stemNames[stem]
			).postln;

			~players[pad][stem].free;
			~players[pad][stem] = nil;

			(
				"Stopped: Song " ++ (pad + 1) ++
				" - " ++ ~stemNames[stem]
			).postln;
		};
	};

	~updateStemParams = { |stem|
		~numPads.do { |pad|
			if(~players[pad][stem].notNil) {
				~players[pad][stem].set(
					\rate, ~tempoValues[stem],
					\wet, ~reverbValues[stem]
				);

				(
					"Updated active player -> Song " ++ (pad + 1) ++
					", " ++ ~stemNames[stem] ++
					", tempo = " ++ ~tempoValues[stem] ++
					", reverb = " ++ ~reverbValues[stem]
				).postln;
			};
		};
	};

	~stopAll = {
		"EMERGENCY STOP: stopping all audio and resetting state.".postln;

		~numPads.do { |pad|
			~numStems.do { |stem|
				~stopStem.value(pad, stem);
			};
		};

		~mprActive = Array.fill(6, { false });

		~padActive = Array.fill(~numPads, {
			Array.fill(~numStems, { false });
		});

		~printState.value;
	};

	// =====================================================
	// REBUILD AUDIO STATE
	// =====================================================

	~rebuildAudioState = {
		"Rebuilding audio state...".postln;

		~numPads.do { |pad|
			~numStems.do { |stem|
				if(~padActive[pad][stem]) {
					~startStem.value(pad, stem);
				} {
					~stopStem.value(pad, stem);
				};
			};
		};

		~printState.value;
	};

	// =====================================================
	// MPR SLOT DECODING
	// =====================================================

	~decodePadFromSlots = { |pad|
		var leftSlot, rightSlot, leftOn, rightOn;

		leftSlot = ~padSlots[pad][0];
		rightSlot = ~padSlots[pad][1];

		leftOn = ~mprActive[leftSlot];
		rightOn = ~mprActive[rightSlot];

		(
			"Decoding Pad " ++ pad ++
			" / Song " ++ (pad + 1) ++
			": left slot " ++ leftSlot ++ " = " ++ leftOn ++
			", right slot " ++ rightSlot ++ " = " ++ rightOn
		).postln;

		// clear previous state for this pad
		~numStems.do { |stem|
			~padActive[pad][stem] = false;
		};

		if(leftOn && rightOn) {
			~padActive[pad][~stemBoth] = true;

			(
				"Pad " ++ pad ++ " detected BOTH pins -> " ++
				~stemNames[~stemBoth]
			).postln;
		} {
			if(leftOn && rightOn.not) {
				~padActive[pad][~stemLeft] = true;

				(
					"Pad " ++ pad ++ " detected LEFT/FIRST pin only -> " ++
					~stemNames[~stemLeft]
				).postln;
			};

			if(rightOn && leftOn.not) {
				~padActive[pad][~stemRight] = true;

				(
					"Pad " ++ pad ++ " detected RIGHT/SECOND pin only -> " ++
					~stemNames[~stemRight]
				).postln;
			};

			if(leftOn.not && rightOn.not) {
				("Pad " ++ pad ++ " has no active stem.").postln;
			};
		};
	};

	~decodeAllPadsFromMPR = {
		~numPads.do { |pad|
			~decodePadFromSlots.value(pad);
		};

		~rebuildAudioState.value;
	};

	// =====================================================
	// OSC SETUP
	// =====================================================

	~myPort = 57121;

	("Opening UDP port " ++ ~myPort ++ "...").postln;
	thisProcess.openUDPPort(~myPort);
	("Listening for OSC on port " ++ ~myPort).postln;
	"".postln;

	// =====================================================
	// /mpr slot on
	// =====================================================

	OSCdef(\mprControl, { |msg, time, addr, recvPort|
		var slot, on;

		"".postln;
		"================ MPR OSC RECEIVED ================".postln;
		("Raw message: " ++ msg).postln;
		("From address: " ++ addr).postln;

		slot = msg[1].asInteger;
		on = msg[2].asInteger;

		("Parsed message -> MPR slot: " ++ slot ++ ", on: " ++ on).postln;

		if((slot >= 0) && (slot < 6)) {
			~mprActive[slot] = on == 1;

			if(on == 1) {
				("MPR slot " ++ slot ++ " is now ACTIVE.").postln;
			} {
				("MPR slot " ++ slot ++ " is now INACTIVE.").postln;
			};

			~decodeAllPadsFromMPR.value;
		} {
			"BAD MPR MESSAGE: slot index out of range. Expected 0 through 5.".postln;
			msg.postln;
		};

		"==================================================".postln;
		"".postln;

	}, '/mpr', recvPort: ~myPort);

	// =====================================================
	// OPTIONAL DIRECT CONTROL
	// /pad padIndex stemId on
	// stemId: 0=drums, 1=vocals, 2=melody
	// =====================================================

	OSCdef(\padControl, { |msg, time, addr, recvPort|
		var pad, stem, on;

		"".postln;
		"================ PAD OSC RECEIVED ================".postln;
		("Raw message: " ++ msg).postln;
		("From address: " ++ addr).postln;

		pad = msg[1].asInteger;
		stem = msg[2].asInteger;
		on = msg[3].asInteger;

		("Parsed message -> pad: " ++ pad ++ ", stem: " ++ stem ++ ", on: " ++ on).postln;

		if(
			(pad >= 0) && (pad < ~numPads) &&
			(stem >= 0) && (stem < ~numStems)
		) {
			~padActive[pad][stem] = on == 1;
			~rebuildAudioState.value;
		} {
			"BAD PAD MESSAGE: index out of range.".postln;
			msg.postln;
		};

		"==================================================".postln;
		"".postln;

	}, '/pad', recvPort: ~myPort);

	// =====================================================
	// /tempo stemId value
	//
	// value 0.0 = 100%
	// value 1.0 = 150%
	// =====================================================

	OSCdef(\tempoControl, { |msg, time, addr, recvPort|
		var stem, rawValue, mappedRate;

		"".postln;
		"=============== TEMPO OSC RECEIVED ===============".postln;
		("Raw message: " ++ msg).postln;

		stem = msg[1].asInteger;
		rawValue = msg[2].asFloat.clip(0.0, 1.0);

		if((stem >= 0) && (stem < ~numStems)) {
			mappedRate = rawValue.linlin(0.0, 1.0, 1.0, 1.5);

			~tempoValues[stem] = mappedRate;

			(
				"Tempo knob updated -> Stem " ++ stem ++
				" / " ++ ~stemNames[stem] ++
				", raw = " ++ rawValue ++
				", playback rate = " ++ mappedRate
			).postln;

			~updateStemParams.value(stem);
		} {
			"BAD TEMPO MESSAGE: stem index out of range.".postln;
			msg.postln;
		};

		"==================================================".postln;
		"".postln;

	}, '/tempo', recvPort: ~myPort);

	// =====================================================
	// /reverb stemId value
	//
	// value 0.0 = dry
	// value 1.0 = lots of reverb
	// =====================================================

	OSCdef(\reverbControl, { |msg, time, addr, recvPort|
		var stem, rawValue, mappedWet;

		"".postln;
		"=============== REVERB OSC RECEIVED ==============".postln;
		("Raw message: " ++ msg).postln;

		stem = msg[1].asInteger;
		rawValue = msg[2].asFloat.clip(0.0, 1.0);

		if((stem >= 0) && (stem < ~numStems)) {
			mappedWet = rawValue.linlin(0.0, 1.0, 0.0, 0.75);

			~reverbValues[stem] = mappedWet;

			(
				"Reverb knob updated -> Stem " ++ stem ++
				" / " ++ ~stemNames[stem] ++
				", raw = " ++ rawValue ++
				", wet = " ++ mappedWet
			).postln;

			~updateStemParams.value(stem);
		} {
			"BAD REVERB MESSAGE: stem index out of range.".postln;
			msg.postln;
		};

		"==================================================".postln;
		"".postln;

	}, '/reverb', recvPort: ~myPort);

	// =====================================================
	// /stopall 1
	// =====================================================

	OSCdef(\stopAllControl, { |msg|
		"".postln;
		"STOP ALL OSC RECEIVED".postln;
		~stopAll.value;
	}, '/stopall', recvPort: ~myPort);

	// =====================================================
	// STARTUP COMPLETE
	// =====================================================

	"====================================================".postln;
	"CREATIVEBLOCKS SUPERCOLLIDER READY".postln;
	"====================================================".postln;
	("Listening on UDP/OSC port: " ++ ~myPort).postln;
	"".postln;

	"Expected MPR messages:".postln;
	"/mpr slot on".postln;
	"Example: /mpr 0 1  -> Pad 0 left pin = vocals1".postln;
	"Example: /mpr 1 1  -> Pad 0 right pin = mel1".postln;
	"Example: /mpr 0 1 and /mpr 1 1 together -> drums1".postln;
	"".postln;

	"Expected knob messages:".postln;
	"/tempo stemId value".postln;
	"/reverb stemId value".postln;
	"stemId: 0=drums, 1=vocals, 2=melody".postln;
	"Example: /tempo 0 1.0".postln;
	"Example: /reverb 2 0.8".postln;
	"".postln;

	"Manual tests:".postln;
	"~mprActive[0] = true; ~decodeAllPadsFromMPR.value; // vocals1".postln;
	"~mprActive[1] = true; ~decodeAllPadsFromMPR.value; // drums1 if slot 0 also true".postln;
	"~mprActive[0] = false; ~decodeAllPadsFromMPR.value; // mel1 if slot 1 still true".postln;
	"~stopAll.value;".postln;
	"====================================================".postln;

	~printState.value;
};
)
