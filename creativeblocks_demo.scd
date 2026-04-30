s.boot;

(
s.waitForBoot {

	// =====================================================
	// CREATIVEBLOCKS DEMO
	// 3 pads / 3 songs
	// 3 blocks / 3 stem groups
	//
	// Pad 0 = Song 1 = MPR slots 0 and 1
	// Pad 1 = Song 2 = MPR slots 2 and 3
	// Pad 2 = Song 3 = MPR slots 4 and 5
	//
	// Block behavior:
	// Both conductive points active = Block 0 = Drums
	// Left conductive point active = Block 1 = Vocals
	// Right conductive point active = Block 2 = Melody + Bass
	//
	// Expected OSC messages:
	//
	// /mpr slot on
	// Example:
	// /mpr 0 1
	// /mpr 0 0
	//
	// Knob control:
	// /tempo blockId value
	// /reverb blockId value
	//
	// value should be from 0.0 to 1.0
	//
	// /stopall 1
	// =====================================================

	"====================================================".postln;
	"CREATIVEBLOCKS DEMO BOOTING".postln;
	"3 PADS / 3 SONGS / 3 BLOCKS".postln;
	"====================================================".postln;


	// =====================================================
	// FILE PATHS
	// =====================================================

	~paths = [
		[
			"/home/pi/Downloads/drums1.mp3",
			"/home/pi/Downloads/vocals1.mp3",
			"/home/pi/Downloads/mel1.mp3"
		],
		[
			"/home/pi/Downloads/drums2.mp3",
			"/home/pi/Downloads/vocals2.mp3",
			"/home/pi/Downloads/mel2.mp3"
		],
		[
			"/home/pi/Downloads/drums3.mp3",
			"/home/pi/Downloads/vocals3.mp3",
			"/home/pi/Downloads/mel3.mp3"
		]
	];

	~numPads = 3;
	~numBlocks = 3;

	~stemNames = [
		"Drums",
		"Vocals",
		"Melody + Bass"
	];

	// Each pad uses two MPR slots: left and right
	~padSlots = [
		[0, 1], // Pad 0 / Song 1
		[2, 3], // Pad 1 / Song 2
		[4, 5]  // Pad 2 / Song 3
	];

	// Block mapping
	~blockBoth = 0;  // both points active = drums
	~blockLeft = 1;  // left only = vocals
	~blockRight = 2; // right only = melody + bass

	"Configured demo layout:".postln;
	"Pad 0 = Song 1 = MPR slots 0 and 1".postln;
	"Pad 1 = Song 2 = MPR slots 2 and 3".postln;
	"Pad 2 = Song 3 = MPR slots 4 and 5".postln;
	"".postln;
	"Block 0 = both conductive points active = Drums".postln;
	"Block 1 = left conductive point active only = Vocals".postln;
	"Block 2 = right conductive point active only = Melody + Bass".postln;
	"".postln;


	// =====================================================
	// LOAD AUDIO BUFFERS
	// =====================================================

	"Loading audio buffers...".postln;

	~bufs = Array.fill(~numPads, { |song|
		Array.fill(~numBlocks, { |stem|
			var path;
			path = ~paths[song][stem];

			("Loading file for pad/song " ++ song ++ ", block/stem " ++ stem ++ ":").postln;
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
			numChannels: 2,
			bufnum: bufnum,
			rate: BufRateScale.kr(bufnum) * rate,
			loop: 1
		);

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

	// ~padActive[pad][block]
	// true means that block/stem is currently detected on that pad/song
	~padActive = Array.fill(~numPads, {
		Array.fill(~numBlocks, { false });
	});

	// ~players[pad][stem]
	// stores currently playing synths
	~players = Array.fill(~numPads, {
		Array.fill(~numBlocks, { nil });
	});

	// Each block/stem has its own tempo and reverb values.
	// These apply across all songs.
	~tempoValues = Array.fill(~numBlocks, { 1.0 });
	~reverbValues = Array.fill(~numBlocks, { 0.12 });

	"State initialized.".postln;
	"".postln;


	// =====================================================
	// PRINT CURRENT STATE
	// =====================================================

	~printState = {
		"---------------- CURRENT STATE ----------------".postln;

		~numPads.do { |pad|
			("Pad " ++ pad ++ " / Song " ++ (pad + 1)).postln;

			~numBlocks.do { |block|
				(
					"    " ++ ~stemNames[block] ++
					" active = " ++ ~padActive[pad][block] ++
					", playing = " ++ ~players[pad][block].notNil
				).postln;
			};
		};

		"MPR slot states:".postln;
		6.do { |slot|
			("    Slot " ++ slot ++ " active = " ++ ~mprActive[slot]).postln;
		};

		"Knob values by block/stem:".postln;
		~numBlocks.do { |block|
			(
				"    Block " ++ block ++ " / " ++ ~stemNames[block] ++
				": tempo = " ++ ~tempoValues[block] ++
				", reverb = " ++ ~reverbValues[block]
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
				", Block " ++ stem ++
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
				", Block " ++ stem ++
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
			~numBlocks.do { |stem|
				~stopStem.value(pad, stem);
			};
		};

		~mprActive = Array.fill(6, { false });

		~padActive = Array.fill(~numPads, {
			Array.fill(~numBlocks, { false });
		});

		~printState.value;
	};


	// =====================================================
	// REBUILD AUDIO STATE
	// =====================================================

	~rebuildAudioState = {
		"Rebuilding audio state...".postln;

		~numPads.do { |pad|
			~numBlocks.do { |stem|
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

		// Clear previous block state for this pad first
		~numBlocks.do { |block|
			~padActive[pad][block] = false;
		};

		if(leftOn && rightOn) {
			~padActive[pad][~blockBoth] = true;
			(
				"Pad " ++ pad ++ " detected BOTH points -> Block " ++
				~blockBoth ++ " / " ++ ~stemNames[~blockBoth]
			).postln;
		} {
			if(leftOn && rightOn.not) {
				~padActive[pad][~blockLeft] = true;
				(
					"Pad " ++ pad ++ " detected LEFT point only -> Block " ++
					~blockLeft ++ " / " ++ ~stemNames[~blockLeft]
				).postln;
			};

			if(rightOn && leftOn.not) {
				~padActive[pad][~blockRight] = true;
				(
					"Pad " ++ pad ++ " detected RIGHT point only -> Block " ++
					~blockRight ++ " / " ++ ~stemNames[~blockRight]
				).postln;
			};

			if(leftOn.not && rightOn.not) {
				("Pad " ++ pad ++ " has no active block.").postln;
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
	// OPTIONAL DIRECT CONTROL:
	// /pad padIndex blockId on
	// Useful for testing without MPR hardware
	// =====================================================

	OSCdef(\padControl, { |msg, time, addr, recvPort|
		var pad, block, on;

		"".postln;
		"================ PAD OSC RECEIVED ================".postln;
		("Raw message: " ++ msg).postln;
		("From address: " ++ addr).postln;

		pad = msg[1].asInteger;
		block = msg[2].asInteger;
		on = msg[3].asInteger;

		("Parsed message -> pad: " ++ pad ++ ", block: " ++ block ++ ", on: " ++ on).postln;

		if(
			(pad >= 0) && (pad < ~numPads) &&
			(block >= 0) && (block < ~numBlocks)
		) {
			if(on == 1) {
				("Direct test: block " ++ block ++ " placed on pad/song " ++ pad).postln;
			} {
				("Direct test: block " ++ block ++ " removed from pad/song " ++ pad).postln;
			};

			~padActive[pad][block] = on == 1;

			~rebuildAudioState.value;
		} {
			"BAD PAD MESSAGE: index out of range.".postln;
			msg.postln;
		};

		"==================================================".postln;
		"".postln;

	}, '/pad', recvPort: ~myPort);


	// =====================================================
	// /tempo blockId value
	//
	// value should be 0.0 to 1.0 from the potentiometer
	// maps to playback rate 0.5 to 1.5
	// lower = slower, higher = faster
	// =====================================================

	OSCdef(\tempoControl, { |msg, time, addr, recvPort|
		var block, rawValue, mappedRate;

		"".postln;
		"=============== TEMPO OSC RECEIVED ===============".postln;
		("Raw message: " ++ msg).postln;

		block = msg[1].asInteger;
		rawValue = msg[2].asFloat.clip(0.0, 1.0);

		if((block >= 0) && (block < ~numBlocks)) {
			mappedRate = rawValue.linlin(0.0, 1.0, 0.5, 1.5);

			~tempoValues[block] = mappedRate;

			(
				"Tempo knob updated -> Block " ++ block ++
				" / " ++ ~stemNames[block] ++
				", raw = " ++ rawValue ++
				", playback rate = " ++ mappedRate
			).postln;

			~updateStemParams.value(block);
		} {
			"BAD TEMPO MESSAGE: block index out of range.".postln;
			msg.postln;
		};

		"==================================================".postln;
		"".postln;

	}, '/tempo', recvPort: ~myPort);


	// =====================================================
	// /reverb blockId value
	//
	// value should be 0.0 to 1.0 from the potentiometer
	// maps directly to reverb wetness
	// =====================================================

	OSCdef(\reverbControl, { |msg, time, addr, recvPort|
		var block, rawValue, mappedWet;

		"".postln;
		"=============== REVERB OSC RECEIVED ==============".postln;
		("Raw message: " ++ msg).postln;

		block = msg[1].asInteger;
		rawValue = msg[2].asFloat.clip(0.0, 1.0);

		if((block >= 0) && (block < ~numBlocks)) {
			mappedWet = rawValue.linlin(0.0, 1.0, 0.0, 0.75);

			~reverbValues[block] = mappedWet;

			(
				"Reverb knob updated -> Block " ++ block ++
				" / " ++ ~stemNames[block] ++
				", raw = " ++ rawValue ++
				", wet = " ++ mappedWet
			).postln;

			~updateStemParams.value(block);
		} {
			"BAD REVERB MESSAGE: block index out of range.".postln;
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
	"Example: /mpr 0 1".postln;
	"Example: /mpr 0 0".postln;
	"".postln;

	"Expected knob messages:".postln;
	"/tempo blockId value".postln;
	"/reverb blockId value".postln;
	"Example: /tempo 0 0.5".postln;
	"Example: /reverb 2 0.8".postln;
	"".postln;

	"Optional direct pad test messages:".postln;
	"/pad padIndex blockId on".postln;
	"Example: /pad 0 0 1".postln;
	"".postln;

	"Manual SuperCollider tests:".postln;
	"~mprActive[0] = true; ~decodeAllPadsFromMPR.value;".postln;
	"~mprActive[1] = true; ~decodeAllPadsFromMPR.value;".postln;
	"~mprActive[0] = false; ~decodeAllPadsFromMPR.value;".postln;
	"~tempoValues[0] = 1.25; ~updateStemParams.value(0);".postln;
	"~reverbValues[1] = 0.5; ~updateStemParams.value(1);".postln;
	"~stopAll.value;".postln;
	"====================================================".postln;

	~printState.value;

};
)
