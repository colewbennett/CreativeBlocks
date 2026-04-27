s.boot;

(
s.waitForBoot {

	// =====================================================
	// CREATIVEBLOCKS DEMO
	// 2 pads / 2 songs
	// 2 blocks / 2 stem groups
	//
	// Pad 0 = Song 1
	// Pad 1 = Song 2
	//
	// Block 0 = Drums + Melody
	// Block 1 = Vocals + Bass
	//
	// Expected OSC messages:
	// /pad padIndex blockId on
	// /stack lowerBlock upperBlock on
	// =====================================================

	"====================================================".postln;
	"CREATIVEBLOCKS DEMO BOOTING".postln;
	"====================================================".postln;


	// =====================================================
	// FILE PATHS
	// CHANGE THESE IF YOUR MP3 FILE NAMES ARE DIFFERENT
	// =====================================================

	~paths = [
		[
			"/home/pi/Downloads/edA.mp3",
			"/home/pi/Downloads/edB.mp3"
		],
		[
			"/home/pi/Downloads/downA.mp3",
			"/home/pi/Downloads/downB.mp3"
		]
	];

	~numPads = 2;
	~numBlocks = 2;

	"Configured demo layout:".postln;
	"Pad 0 = Song 1".postln;
	"Pad 1 = Song 2".postln;
	"Block 0 = Drums + Melody".postln;
	"Block 1 = Vocals + Bass".postln;
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
		|out=0, bufnum=0, amp=0.8, wet=0.12, room=0.7, damp=0.5,
		delayTime=0.25, delayFeedback=0.2, delayMix=0.08|

		var sig, rev, delaySig, delay, mix;

		sig = PlayBuf.ar(
			numChannels: 2,
			bufnum: bufnum,
			rate: BufRateScale.kr(bufnum),
			loop: 1
		);

		sig = sig * amp;

		rev = FreeVerb.ar(sig, wet, room, damp);

		delaySig = LocalIn.ar(2);

		delay = CombL.ar(
			sig + (delaySig * delayFeedback),
			delayTime,
			delayTime,
			2
		);

		LocalOut.ar(delay);

		mix = (sig * (1 - wet - delayMix)) + (rev * wet) + (delay * delayMix);

		Out.ar(out, mix);
	}).add;

	s.sync;

	"SynthDef ready.".postln;
	"".postln;


	// =====================================================
	// STATE
	// =====================================================

	"Initializing state arrays...".postln;

	// ~padActive[pad][block]
	// true means block is currently detected directly on that pad
	~padActive = Array.fill(~numPads, {
		Array.fill(~numBlocks, { false });
	});

	// ~stackActive[lowerBlock][upperBlock]
	// true means upperBlock is currently stacked on lowerBlock
	~stackActive = Array.fill(~numBlocks, {
		Array.fill(~numBlocks, { false });
	});

	// ~players[pad][stem]
	// stores currently playing synths
	~players = Array.fill(~numPads, {
		Array.fill(~numBlocks, { nil });
	});

	"State initialized.".postln;
	"".postln;


	// =====================================================
	// PRINT CURRENT STATE
	// =====================================================

	~printState = {
		"---------------- CURRENT STATE ----------------".postln;

		("Pad 0 / Song 1: block 0 direct = " ++ ~padActive[0][0] ++ ", block 1 direct = " ++ ~padActive[0][1]).postln;
		("Pad 1 / Song 2: block 0 direct = " ++ ~padActive[1][0] ++ ", block 1 direct = " ++ ~padActive[1][1]).postln;

		("Stack: lower block 0 has upper block 0 = " ++ ~stackActive[0][0] ++ ", upper block 1 = " ++ ~stackActive[0][1]).postln;
		("Stack: lower block 1 has upper block 0 = " ++ ~stackActive[1][0] ++ ", upper block 1 = " ++ ~stackActive[1][1]).postln;

		("Playing Song 1 drums+melody = " ++ ~players[0][0].notNil).postln;
		("Playing Song 1 vocals+bass  = " ++ ~players[0][1].notNil).postln;
		("Playing Song 2 drums+melody = " ++ ~players[1][0].notNil).postln;
		("Playing Song 2 vocals+bass  = " ++ ~players[1][1].notNil).postln;

		"------------------------------------------------".postln;
		"".postln;
	};


	// =====================================================
	// AUDIO FUNCTIONS
	// =====================================================

	~startStem = { |pad, stem|
		if(~players[pad][stem].isNil) {
			("STARTING AUDIO -> pad/song " ++ pad ++ ", block/stem " ++ stem).postln;

			if(pad == 0) {
				if(stem == 0) { "Now playing: Song 1 - Drums + Melody".postln; };
				if(stem == 1) { "Now playing: Song 1 - Vocals + Bass".postln; };
			};

			if(pad == 1) {
				if(stem == 0) { "Now playing: Song 2 - Drums + Melody".postln; };
				if(stem == 1) { "Now playing: Song 2 - Vocals + Bass".postln; };
			};

			~players[pad][stem] = Synth(\stemPlayer, [
				\bufnum, ~bufs[pad][stem].bufnum,
				\amp, 0.8
			]);
		} {
			("Already playing -> pad/song " ++ pad ++ ", block/stem " ++ stem).postln;
		};
	};

	~stopStem = { |pad, stem|
		if(~players[pad][stem].notNil) {
			("STOPPING AUDIO -> pad/song " ++ pad ++ ", block/stem " ++ stem).postln;

			if(pad == 0) {
				if(stem == 0) { "Stopped: Song 1 - Drums + Melody".postln; };
				if(stem == 1) { "Stopped: Song 1 - Vocals + Bass".postln; };
			};

			if(pad == 1) {
				if(stem == 0) { "Stopped: Song 2 - Drums + Melody".postln; };
				if(stem == 1) { "Stopped: Song 2 - Vocals + Bass".postln; };
			};

			~players[pad][stem].free;
			~players[pad][stem] = nil;
		};
	};

	~stopAll = {
		"EMERGENCY STOP: stopping all audio and resetting state.".postln;

		~numPads.do { |pad|
			~numBlocks.do { |stem|
				~stopStem.value(pad, stem);
			};
		};

		~padActive = Array.fill(~numPads, {
			Array.fill(~numBlocks, { false });
		});

		~stackActive = Array.fill(~numBlocks, {
			Array.fill(~numBlocks, { false });
		});

		~printState.value;
	};


	// =====================================================
	// REBUILD AUDIO STATE
	// =====================================================

	~rebuildAudioState = {
		var desired;

		"Rebuilding audio state...".postln;

		desired = Array.fill(~numPads, {
			Array.fill(~numBlocks, { false });
		});

		// Direct pad placement
		~numPads.do { |pad|
			~numBlocks.do { |block|
				if(~padActive[pad][block]) {
					("Direct placement active: pad/song " ++ pad ++ " has block/stem " ++ block).postln;
					desired[pad][block] = true;
				};
			};
		};

		// Stacking behavior
		~numPads.do { |pad|
			~numBlocks.do { |lowerBlock|
				if(~padActive[pad][lowerBlock]) {
					~numBlocks.do { |upperBlock|
						if(~stackActive[lowerBlock][upperBlock]) {
							(
								"Stack active: lower block " ++ lowerBlock ++
								" is on pad/song " ++ pad ++
								", upper block " ++ upperBlock ++
								" should also play for that song."
							).postln;

							desired[pad][upperBlock] = true;
						};
					};
				};
			};
		};

		// Apply starts/stops
		~numPads.do { |pad|
			~numBlocks.do { |stem|
				if(desired[pad][stem]) {
					~startStem.value(pad, stem);
				} {
					~stopStem.value(pad, stem);
				};
			};
		};

		~printState.value;
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
	// /pad padIndex blockId on
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
				("Detected block " ++ block ++ " placed on pad/song " ++ pad).postln;
			} {
				("Detected block " ++ block ++ " removed from pad/song " ++ pad).postln;
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
	// /stack lowerBlock upperBlock on
	// =====================================================

	OSCdef(\stackControl, { |msg, time, addr, recvPort|
		var lowerBlock, upperBlock, on;

		"".postln;
		"=============== STACK OSC RECEIVED ===============".postln;
		("Raw message: " ++ msg).postln;
		("From address: " ++ addr).postln;

		lowerBlock = msg[1].asInteger;
		upperBlock = msg[2].asInteger;
		on = msg[3].asInteger;

		("Parsed message -> lower block: " ++ lowerBlock ++ ", upper block: " ++ upperBlock ++ ", on: " ++ on).postln;

		if(
			(lowerBlock >= 0) && (lowerBlock < ~numBlocks) &&
			(upperBlock >= 0) && (upperBlock < ~numBlocks)
		) {
			if(on == 1) {
				("Detected upper block " ++ upperBlock ++ " stacked on lower block " ++ lowerBlock).postln;
			} {
				("Detected upper block " ++ upperBlock ++ " removed from lower block " ++ lowerBlock).postln;
			};

			~stackActive[lowerBlock][upperBlock] = on == 1;

			~rebuildAudioState.value;
		} {
			"BAD STACK MESSAGE: index out of range.".postln;
			msg.postln;
		};

		"==================================================".postln;
		"".postln;

	}, '/stack', recvPort: ~myPort);


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
	"Expected messages:".postln;
	"/pad padIndex blockId on".postln;
	"/stack lowerBlock upperBlock on".postln;
	"/stopall 1".postln;
	"".postln;
	"Manual test commands you can run in SuperCollider:".postln;
	"~padActive[0][0] = true; ~rebuildAudioState.value;".postln;
	"~padActive[0][1] = true; ~rebuildAudioState.value;".postln;
	"~padActive[0][0] = false; ~rebuildAudioState.value;".postln;
	"~stackActive[0][1] = true; ~rebuildAudioState.value;".postln;
	"~stopAll.value;".postln;
	"====================================================".postln;

	~printState.value;

};
)