s.boot;
s.freeAll;

(
s.waitForBoot {

	"====================================================".postln;
	"CREATIVEBLOCKS DEMO BOOTING".postln;
	"BLOCK-SPECIFIC TEMPO + REVERB ENABLED".postln;
	"====================================================".postln;

	~paths = [
		[
			"/home/pi/CreativeBlocks/audio/drums1_mono.mp3",
			"/home/pi/CreativeBlocks/audio/vocals1_mono.mp3",
			"/home/pi/CreativeBlocks/audio/mel1_mono.mp3"
		],
		[
			"/home/pi/CreativeBlocks/audio/drums2_mono.mp3",
			"/home/pi/CreativeBlocks/audio/vocals2_mono.mp3",
			"/home/pi/CreativeBlocks/audio/mel2_mono.mp3"
		],
		[
			"/home/pi/CreativeBlocks/audio/drums3_mono.mp3",
			"/home/pi/CreativeBlocks/audio/vocals3_mono.mp3",
			"/home/pi/CreativeBlocks/audio/mel3_mono.mp3"
		]
	];

	~numPads = 3;
	~numBlocks = 3;

	~stemNames = ["Drums", "Vocals", "Melody"];

	~padSlots = [
		[0, 1],
		[2, 3],
		[4, 5]
	];

	~blockBoth = 0;  // drums
	~blockLeft = 1;  // vocals
	~blockRight = 2; // melody

	"Loading audio buffers...".postln;

	~bufs = Array.fill(~numPads, { |song|
		Array.fill(~numBlocks, { |stem|
			var path;
			path = ~paths[song][stem];
			("Loading: " ++ path).postln;
			Buffer.read(s, path);
		});
	});

	s.sync;
	"Audio buffer loading complete.".postln;

	SynthDef(\stemPlayer, {
		|out=0, bufnum=0, amp=0.8, rate=1.0, wet=0.12, room=0.7, damp=0.5|

		var sig, dry, rev, mix;

		sig = PlayBuf.ar(
			numChannels: 1,
			bufnum: bufnum,
			rate: BufRateScale.kr(bufnum) * Lag.kr(rate, 0.1),
			loop: 1
		);

		// mono -> both ears
		sig = Pan2.ar(sig, 0);

		sig = sig * amp;

		dry = sig;
		rev = FreeVerb.ar(sig, wet, room, damp);
		mix = (dry * (1 - wet)) + (rev * wet);

		Out.ar(out, mix);
	}).add;

	s.sync;
	"SynthDef ready.".postln;

	~mprActive = Array.fill(6, { false });

	~padActive = Array.fill(~numPads, {
		Array.fill(~numBlocks, { false });
	});

	~players = Array.fill(~numPads, {
		Array.fill(~numBlocks, { nil });
	});

	~tempoValues = Array.fill(~numBlocks, { 1.0 });
	~reverbValues = Array.fill(~numBlocks, { 0.12 });

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

		"Block controls:".postln;
		~numBlocks.do { |block|
			(
				"    Block " ++ block ++
				" / " ++ ~stemNames[block] ++
				": tempo = " ++ ~tempoValues[block] ++
				", reverb = " ++ ~reverbValues[block]
			).postln;
		};

		"------------------------------------------------".postln;
	};

	~startStem = { |pad, stem|
		if(~players[pad][stem].isNil) {
			(
				"STARTING -> Song " ++ (pad + 1) ++
				", " ++ ~stemNames[stem]
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
				"STOPPING -> Song " ++ (pad + 1) ++
				", " ++ ~stemNames[stem]
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
					"UPDATED -> " ++ ~stemNames[stem] ++
					" on Song " ++ (pad + 1) ++
					", tempo = " ++ ~tempoValues[stem] ++
					", reverb = " ++ ~reverbValues[stem]
				).postln;
			};
		};
	};

	~setTempo = { |block, rawValue|
		var mappedRate;

		block = block.asInteger;
		rawValue = rawValue.asFloat.clip(0.0, 1.0);

		if((block >= 0) && (block < ~numBlocks)) {
			mappedRate = rawValue.linlin(0.0, 1.0, 1.0, 1.5);
			~tempoValues[block] = mappedRate;

			(
				"TEMPO -> Block " ++ block ++
				" / " ++ ~stemNames[block] ++
				", raw = " ++ rawValue ++
				", rate = " ++ mappedRate
			).postln;

			~updateStemParams.value(block);
		} {
			"BAD TEMPO MESSAGE: block must be 0, 1, or 2".postln;
		};
	};

	~setReverb = { |block, rawValue|
		var mappedWet;

		block = block.asInteger;
		rawValue = rawValue.asFloat.clip(0.0, 1.0);

		if((block >= 0) && (block < ~numBlocks)) {
			mappedWet = rawValue.linlin(0.0, 1.0, 0.0, 0.75);
			~reverbValues[block] = mappedWet;

			(
				"REVERB -> Block " ++ block ++
				" / " ++ ~stemNames[block] ++
				", raw = " ++ rawValue ++
				", wet = " ++ mappedWet
			).postln;

			~updateStemParams.value(block);
		} {
			"BAD REVERB MESSAGE: block must be 0, 1, or 2".postln;
		};
	};

	~stopAll = {
		"STOPPING ALL".postln;

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
			("Pad " ++ pad ++ " -> Drums").postln;
		} {
			if(leftOn && rightOn.not) {
				~padActive[pad][~blockLeft] = true;
				("Pad " ++ pad ++ " -> Vocals").postln;
			};

			if(rightOn && leftOn.not) {
				~padActive[pad][~blockRight] = true;
				("Pad " ++ pad ++ " -> Melody").postln;
			};

			if(leftOn.not && rightOn.not) {
				("Pad " ++ pad ++ " -> Empty").postln;
			};
		};
	};

	~decodeAllPadsFromMPR = {
		~numPads.do { |pad|
			~decodePadFromSlots.value(pad);
		};

		~rebuildAudioState.value;
	};

	~myPort = 57121;
	thisProcess.openUDPPort(~myPort);
	("Listening on UDP port " ++ ~myPort).postln;

	// /mpr slot on
	OSCdef(\mprControl, { |msg|
		var slot, on;

		"".postln;
		"================ MPR RECEIVED ================".postln;
		("Raw: " ++ msg).postln;

		slot = msg[1].asInteger;
		on = msg[2].asInteger;

		if((slot >= 0) && (slot < 6)) {
			~mprActive[slot] = on == 1;
			("MPR slot " ++ slot ++ " = " ++ ~mprActive[slot]).postln;
			~decodeAllPadsFromMPR.value;
		} {
			"BAD MPR MESSAGE".postln;
			msg.postln;
		};

		"==============================================".postln;

	}, '/mpr', recvPort: ~myPort);

	// /tempo blockId value
	OSCdef(\tempoControl, { |msg|
		var block, value;

		"".postln;
		"================ TEMPO RECEIVED ================".postln;
		("Raw: " ++ msg).postln;

		block = msg[1].asInteger;
		value = msg[2].asFloat;

		~setTempo.value(block, value);

		"================================================".postln;

	}, '/tempo', recvPort: ~myPort);

	// /reverb blockId value
	OSCdef(\reverbControl, { |msg|
		var block, value;

		"".postln;
		"================ REVERB RECEIVED ================".postln;
		("Raw: " ++ msg).postln;

		block = msg[1].asInteger;
		value = msg[2].asFloat;

		~setReverb.value(block, value);

		"=================================================".postln;

	}, '/reverb', recvPort: ~myPort);

	// optional: /stack blockId pin on
	OSCdef(\stackControl, { |msg|
		"".postln;
		"================ STACK RECEIVED ================".postln;
		("Raw: " ++ msg).postln;
		"Stack received for debugging only; tempo/reverb now use blockId directly.".postln;
		"===============================================".postln;
	}, '/stack', recvPort: ~myPort);

	OSCdef(\stopAllControl, { |msg|
		~stopAll.value;
	}, '/stopall', recvPort: ~myPort);

	"====================================================".postln;
	"CREATIVEBLOCKS READY".postln;
	"====================================================".postln;
	"Expected ESP32 messages:".postln;
	"/tempo 0 value   -> drums".postln;
	"/tempo 1 value   -> vocals".postln;
	"/tempo 2 value   -> melody".postln;
	"/reverb 0 value  -> drums".postln;
	"/reverb 1 value  -> vocals".postln;
	"/reverb 2 value  -> melody".postln;
	"".postln;
	"Tempo: 0.0 = 100%, 1.0 = 150%".postln;
	"Reverb: 0.0 = dry, 1.0 = wet".postln;
	"====================================================".postln;

	~printState.value;
};
)
