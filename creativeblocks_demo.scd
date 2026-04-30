s.boot;
s.freeAll;

(
s.waitForBoot {

	// =====================================================
	// CREATIVEBLOCKS DEMO
	// Updated to work with existing ESP32 code
	//
	// MPR from Python/RPi:
	// /mpr slot on
	//
	// Stack from ESP32:
	// /stack blockId pin on
	//
	// Existing ESP32 knob messages:
	// /reverb value
	// /delay value
	//
	// Since ESP32 knobs do NOT send blockId:
	// this file uses the most recently touched /stack block
	// as the active knob target.
	//
	// /delay controls tempo:
	// 0.0 = 100%
	// 1.0 = 150%
	//
	// /reverb controls reverb:
	// 0.0 = dry
	// 1.0 = wet
	// =====================================================

	"====================================================".postln;
	"CREATIVEBLOCKS DEMO BOOTING".postln;
	"UPDATED ESP32 KNOB SUPPORT".postln;
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
	~numBlocks = 3;

	~stemNames = [
		"Drums",
		"Vocals",
		"Melody + Bass"
	];

	// Each pad uses two MPR slots: left and right
	~padSlots = [
		[0, 1],
		[2, 3],
		[4, 5]
	];

	// Stem mapping
	~blockBoth = 0;  // both points active = drums
	~blockLeft = 1;  // left only = vocals
	~blockRight = 2; // right only = melody + bass

	// ESP32 knob fallback target.
	// Your ESP32 knob messages are /reverb value and /delay value,
	// so they do not identify which block sent them.
	// This gets updated whenever /stack blockId pin on is received.
	~activeKnobBlock = 1;

	// =====================================================
	// LOAD AUDIO BUFFERS
	// =====================================================

	"Loading audio buffers...".postln;

	~bufs = Array.fill(~numPads, { |song|
		Array.fill(~numBlocks, { |stem|
			var path;
			path = ~paths[song][stem];

			("Loading file: " ++ path).postln;
			Buffer.read(s, path);
		});
	});

	s.sync;

	"Audio buffer loading complete.".postln;

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
			rate: BufRateScale.kr(bufnum) * Lag.kr(rate, 0.1),
			loop: 1
		);

		// mono file -> centered stereo, both ears
		sig = Pan2.ar(sig, 0);

		sig = sig * amp;

		dry = sig;
		rev = FreeVerb.ar(sig, wet, room, damp);
		mix = (dry * (1 - wet)) + (rev * wet);

		// IMPORTANT: output processed mix, not raw signal
		Out.ar(out, mix);
	}).add;

	s.sync;

	"SynthDef ready.".postln;

	// =====================================================
	// STATE
	// =====================================================

	~mprActive = Array.fill(6, { false });

	~padActive = Array.fill(~numPads, {
		Array.fill(~numBlocks, { false });
	});

	~players = Array.fill(~numPads, {
		Array.fill(~numBlocks, { nil });
	});

	~tempoValues = Array.fill(~numBlocks, { 1.0 });
	~reverbValues = Array.fill(~numBlocks, { 0.12 });

	// Track ESP32 /stack touches too, just for knob targeting.
	~stackActive = Array.fill(~numBlocks, {
		Array.fill(12, { false });
	});

	// =====================================================
	// HELPERS
	// =====================================================

	~normalizeBlockId = { |incomingId|
		var block;

		incomingId = incomingId.asInteger;

		// Supports either 0,1,2 or 1,2,3.
		// Your shown ESP32 sends block 1.
		if((incomingId >= 1) && (incomingId <= 3)) {
			block = incomingId - 1;
		} {
			block = incomingId;
		};

		block.clip(0, ~numBlocks - 1);
	};

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

		("Active knob target block = " ++ ~activeKnobBlock ++ " / " ++ ~stemNames[~activeKnobBlock]).postln;

		"Knob values by block/stem:".postln;
		~numBlocks.do { |block|
			(
				"    Block " ++ block ++ " / " ++ ~stemNames[block] ++
				": tempo = " ++ ~tempoValues[block] ++
				", reverb = " ++ ~reverbValues[block]
			).postln;
		};

		"------------------------------------------------".postln;
	};

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
					"UPDATED ACTIVE PLAYER -> Song " ++ (pad + 1) ++
					", " ++ ~stemNames[stem] ++
					", tempo = " ++ ~tempoValues[stem] ++
					", reverb = " ++ ~reverbValues[stem]
				).postln;
			};
		};
	};

	~setTempo = { |block, rawValue|
		var mappedRate;

		rawValue = rawValue.asFloat.clip(0.0, 1.0);

		if((block >= 0) && (block < ~numBlocks)) {
			mappedRate = rawValue.linlin(0.0, 1.0, 1.0, 1.5);

			~tempoValues[block] = mappedRate;

			(
				"TEMPO UPDATED -> Block " ++ block ++
				" / " ++ ~stemNames[block] ++
				", raw = " ++ rawValue ++
				", playback rate = " ++ mappedRate
			).postln;

			~updateStemParams.value(block);
		} {
			"BAD TEMPO BLOCK INDEX".postln;
		};
	};

	~setReverb = { |block, rawValue|
		var mappedWet;

		rawValue = rawValue.asFloat.clip(0.0, 1.0);

		if((block >= 0) && (block < ~numBlocks)) {
			mappedWet = rawValue.linlin(0.0, 1.0, 0.0, 0.75);

			~reverbValues[block] = mappedWet;

			(
				"REVERB UPDATED -> Block " ++ block ++
				" / " ++ ~stemNames[block] ++
				", raw = " ++ rawValue ++
				", wet = " ++ mappedWet
			).postln;

			~updateStemParams.value(block);
		} {
			"BAD REVERB BLOCK INDEX".postln;
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

	~rebuildAudioState = {
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

	~decodePadFromSlots = { |pad|
		var leftSlot, rightSlot, leftOn, rightOn;

		leftSlot = ~padSlots[pad][0];
		rightSlot = ~padSlots[pad][1];

		leftOn = ~mprActive[leftSlot];
		rightOn = ~mprActive[rightSlot];

		~numBlocks.do { |block|
			~padActive[pad][block] = false;
		};

		if(leftOn && rightOn) {
			~padActive[pad][~blockBoth] = true;
			("Pad " ++ pad ++ " detected BOTH -> Drums").postln;
		} {
			if(leftOn && rightOn.not) {
				~padActive[pad][~blockLeft] = true;
				("Pad " ++ pad ++ " detected LEFT -> Vocals").postln;
			};

			if(rightOn && leftOn.not) {
				~padActive[pad][~blockRight] = true;
				("Pad " ++ pad ++ " detected RIGHT -> Melody + Bass").postln;
			};

			if(leftOn.not && rightOn.not) {
				("Pad " ++ pad ++ " empty").postln;
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

	// =====================================================
	// /mpr slot on
	// From Raspberry Pi MPR121 Python
	// =====================================================

	OSCdef(\mprControl, { |msg, time, addr, recvPort|
		var slot, on;

		"".postln;
		"================ MPR OSC RECEIVED ================".postln;
		("Raw message: " ++ msg).postln;

		slot = msg[1].asInteger;
		on = msg[2].asInteger;

		if((slot >= 0) && (slot < 6)) {
			~mprActive[slot] = on == 1;
			("MPR slot " ++ slot ++ " active = " ++ ~mprActive[slot]).postln;
			~decodeAllPadsFromMPR.value;
		} {
			"BAD MPR MESSAGE: expected slot 0 through 5.".postln;
			msg.postln;
		};

		"==================================================".postln;

	}, '/mpr', recvPort: ~myPort);

	// =====================================================
	// /stack blockId pin on
	// From ESP32 blocks
	//
	// This does NOT control pad audio directly here.
	// It lets SC know which block's knobs should be active.
	// =====================================================

	OSCdef(\stackControl, { |msg, time, addr, recvPort|
		var incomingBlock, block, pin, on;

		"".postln;
		"================ STACK OSC RECEIVED ==============".postln;
		("Raw message: " ++ msg).postln;

		incomingBlock = msg[1].asInteger;
		block = ~normalizeBlockId.value(incomingBlock);
		pin = msg[2].asInteger;
		on = msg[3].asInteger;

		if((block >= 0) && (block < ~numBlocks)) {
			if((pin >= 0) && (pin < 12)) {
				~stackActive[block][pin] = on == 1;
			};

			if(on == 1) {
				~activeKnobBlock = block;

				(
					"Active knob target set to block " ++ block ++
					" / " ++ ~stemNames[block] ++
					" from incoming block ID " ++ incomingBlock
				).postln;
			} {
				(
					"Stack release from block " ++ block ++
					" / " ++ ~stemNames[block]
				).postln;
			};
		} {
			"BAD STACK MESSAGE: block index out of range.".postln;
			msg.postln;
		};

		"==================================================".postln;

	}, '/stack', recvPort: ~myPort);

	// =====================================================
	// /delay value
	// Existing ESP32 tempo potentiometer
	// =====================================================

	OSCdef(\delayAsTempoControl, { |msg, time, addr, recvPort|
		var rawValue;

		"".postln;
		"=============== DELAY/TEMPO OSC RECEIVED =========".postln;
		("Raw message: " ++ msg).postln;

		rawValue = msg[1].asFloat;

		~setTempo.value(~activeKnobBlock, rawValue);

		"==================================================".postln;

	}, '/delay', recvPort: ~myPort);

	// =====================================================
	// /reverb value
	// Existing ESP32 reverb potentiometer
	//
	// Also accepts /reverb block value if sent later.
	// =====================================================

	OSCdef(\reverbControl, { |msg, time, addr, recvPort|
		var block, rawValue;

		"".postln;
		"=============== REVERB OSC RECEIVED ==============".postln;
		("Raw message: " ++ msg).postln;

		if(msg.size == 2) {
			block = ~activeKnobBlock;
			rawValue = msg[1].asFloat;
		} {
			block = ~normalizeBlockId.value(msg[1].asInteger);
			rawValue = msg[2].asFloat;
		};

		~setReverb.value(block, rawValue);

		"==================================================".postln;

	}, '/reverb', recvPort: ~myPort);

	// =====================================================
	// Optional compatibility:
	// /tempo block value
	// =====================================================

	OSCdef(\tempoControl, { |msg, time, addr, recvPort|
		var block, rawValue;

		"".postln;
		"=============== TEMPO OSC RECEIVED ===============".postln;
		("Raw message: " ++ msg).postln;

		if(msg.size == 2) {
			block = ~activeKnobBlock;
			rawValue = msg[1].asFloat;
		} {
			block = ~normalizeBlockId.value(msg[1].asInteger);
			rawValue = msg[2].asFloat;
		};

		~setTempo.value(block, rawValue);

		"==================================================".postln;

	}, '/tempo', recvPort: ~myPort);

	// =====================================================
	// Optional direct pad test:
	// /pad padIndex blockId on
	// =====================================================

	OSCdef(\padControl, { |msg, time, addr, recvPort|
		var pad, block, on;

		"".postln;
		"================ PAD OSC RECEIVED ================".postln;
		("Raw message: " ++ msg).postln;

		pad = msg[1].asInteger;
		block = ~normalizeBlockId.value(msg[2].asInteger);
		on = msg[3].asInteger;

		if(
			(pad >= 0) && (pad < ~numPads) &&
			(block >= 0) && (block < ~numBlocks)
		) {
			~padActive[pad][block] = on == 1;
			~rebuildAudioState.value;
		} {
			"BAD PAD MESSAGE".postln;
			msg.postln;
		};

		"==================================================".postln;

	}, '/pad', recvPort: ~myPort);

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
	"Supported messages:".postln;
	"/mpr slot on".postln;
	"/stack blockId pin on".postln;
	"/delay value    -> tempo for active block".postln;
	"/reverb value   -> reverb for active block".postln;
	"/tempo value    -> tempo for active block".postln;
	"".postln;
	"Tempo mapping: 0.0 = 100%, 1.0 = 150%".postln;
	"Reverb mapping: 0.0 = dry, 1.0 = wet".postln;
	"".postln;
	"Manual tests:".postln;
	"~mprActive[0] = true; ~decodeAllPadsFromMPR.value;".postln;
	"~mprActive[1] = true; ~decodeAllPadsFromMPR.value;".postln;
	"~setTempo.value(1, 1.0);".postln;
	"~setReverb.value(1, 1.0);".postln;
	"~stopAll.value;".postln;
	"====================================================".postln;

	~printState.value;
};
)
