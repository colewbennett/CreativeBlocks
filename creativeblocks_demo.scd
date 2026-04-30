s.boot;
s.freeAll;

(
s.waitForBoot {

	"====================================================".postln;
	"CREATIVEBLOCKS DEMO BOOTING".postln;
	"PAD = SONG, PINS = STEM".postln;
	"====================================================".postln;

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

	~stemNames = ["Drums", "Vocals", "Melody"];

	~padSlots = [
		[0, 1],
		[2, 3],
		[4, 5]
	];

	~stemBoth = 0;
	~stemLeft = 1;
	~stemRight = 2;

	"Loading audio buffers...".postln;

	~bufs = Array.fill(~numPads, { |song|
		Array.fill(~numStems, { |stem|
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

		// mono track centered in both ears
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
		Array.fill(~numStems, { false });
	});

	~players = Array.fill(~numPads, {
		Array.fill(~numStems, { nil });
	});

	~tempoValues = Array.fill(~numStems, { 1.0 });
	~reverbValues = Array.fill(~numStems, { 0.12 });

	~normalizeStemId = { |incomingId|
		var stem;
		incomingId = incomingId.asInteger;

		// Accept either:
		// 0,1,2 from direct testing
		// or 1,2,3 from ESP32 blocks
		if((incomingId >= 1) && (incomingId <= 3)) {
			stem = incomingId - 1;
		} {
			stem = incomingId;
		};

		stem;
	};

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

		"Knob values by stem:".postln;

		~numStems.do { |stem|
			(
				"    " ++ ~stemNames[stem] ++
				": tempo = " ++ ~tempoValues[stem] ++
				", reverb = " ++ ~reverbValues[stem]
			).postln;
		};

		"------------------------------------------------".postln;
	};

	~startStem = { |pad, stem|
		if(~players[pad][stem].isNil) {
			(
				"STARTING AUDIO -> Song " ++ (pad + 1) ++
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
				"STOPPING AUDIO -> Song " ++ (pad + 1) ++
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
					"UPDATED -> Song " ++ (pad + 1) ++
					", " ++ ~stemNames[stem] ++
					", tempo = " ++ ~tempoValues[stem] ++
					", reverb = " ++ ~reverbValues[stem]
				).postln;
			};
		};
	};

	~stopAll = {
		"STOPPING ALL AUDIO".postln;

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

	~rebuildAudioState = {
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

	~decodePadFromSlots = { |pad|
		var leftSlot, rightSlot, leftOn, rightOn;

		leftSlot = ~padSlots[pad][0];
		rightSlot = ~padSlots[pad][1];

		leftOn = ~mprActive[leftSlot];
		rightOn = ~mprActive[rightSlot];

		~numStems.do { |stem|
			~padActive[pad][stem] = false;
		};

		if(leftOn && rightOn) {
			~padActive[pad][~stemBoth] = true;
			("Pad " ++ pad ++ " -> Drums").postln;
		} {
			if(leftOn && rightOn.not) {
				~padActive[pad][~stemLeft] = true;
				("Pad " ++ pad ++ " -> Vocals").postln;
			};

			if(rightOn && leftOn.not) {
				~padActive[pad][~stemRight] = true;
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

	("Listening for OSC on port " ++ ~myPort).postln;

	OSCdef(\mprControl, { |msg, time, addr, recvPort|
		var slot, on;

		"".postln;
		"================ MPR OSC RECEIVED ================".postln;
		("Raw message: " ++ msg).postln;

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

		"==================================================".postln;

	}, '/mpr', recvPort: ~myPort);

	OSCdef(\tempoControl, { |msg, time, addr, recvPort|
		var incomingId, stem, rawValue, mappedRate;

		"".postln;
		"=============== TEMPO OSC RECEIVED ===============".postln;
		("Raw message: " ++ msg).postln;

		incomingId = msg[1].asInteger;
		stem = ~normalizeStemId.value(incomingId);
		rawValue = msg[2].asFloat.clip(0.0, 1.0);

		if((stem >= 0) && (stem < ~numStems)) {
			mappedRate = rawValue.linlin(0.0, 1.0, 1.0, 1.5);

			~tempoValues[stem] = mappedRate;

			(
				"Tempo incoming ID " ++ incomingId ++
				" -> stem " ++ stem ++
				" / " ++ ~stemNames[stem] ++
				", raw = " ++ rawValue ++
				", rate = " ++ mappedRate
			).postln;

			~updateStemParams.value(stem);
		} {
			"BAD TEMPO MESSAGE".postln;
			msg.postln;
		};

		"==================================================".postln;

	}, '/tempo', recvPort: ~myPort);

	OSCdef(\reverbControl, { |msg, time, addr, recvPort|
		var incomingId, stem, rawValue, mappedWet;

		"".postln;
		"=============== REVERB OSC RECEIVED ==============".postln;
		("Raw message: " ++ msg).postln;

		incomingId = msg[1].asInteger;
		stem = ~normalizeStemId.value(incomingId);
		rawValue = msg[2].asFloat.clip(0.0, 1.0);

		if((stem >= 0) && (stem < ~numStems)) {
			mappedWet = rawValue.linlin(0.0, 1.0, 0.0, 0.75);

			~reverbValues[stem] = mappedWet;

			(
				"Reverb incoming ID " ++ incomingId ++
				" -> stem " ++ stem ++
				" / " ++ ~stemNames[stem] ++
				", raw = " ++ rawValue ++
				", wet = " ++ mappedWet
			).postln;

			~updateStemParams.value(stem);
		} {
			"BAD REVERB MESSAGE".postln;
			msg.postln;
		};

		"==================================================".postln;

	}, '/reverb', recvPort: ~myPort);

	OSCdef(\padControl, { |msg, time, addr, recvPort|
		var pad, stem, on;

		pad = msg[1].asInteger;
		stem = ~normalizeStemId.value(msg[2].asInteger);
		on = msg[3].asInteger;

		if(
			(pad >= 0) && (pad < ~numPads) &&
			(stem >= 0) && (stem < ~numStems)
		) {
			~padActive[pad][stem] = on == 1;
			~rebuildAudioState.value;
		} {
			"BAD PAD MESSAGE".postln;
			msg.postln;
		};

	}, '/pad', recvPort: ~myPort);

	OSCdef(\stopAllControl, { |msg|
		~stopAll.value;
	}, '/stopall', recvPort: ~myPort);

	"====================================================".postln;
	"CREATIVEBLOCKS READY".postln;
	"====================================================".postln;
	"Expected MPR: /mpr slot on".postln;
	"Expected tempo from ESP32: /tempo 1-3 value".postln;
	"Expected reverb from ESP32: /reverb 1-3 value".postln;
	"1=drums, 2=vocals, 3=melody".postln;
	"Tempo maps 0.0 -> 100%, 1.0 -> 150%".postln;
	"====================================================".postln;

	~printState.value;
};
)
