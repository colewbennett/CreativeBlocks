(
// ================================
// CreativeBlocks SuperCollider Demo
// mono mp3 version: drums1_mono.mp3
// ================================

s.options.numOutputBusChannels = 2;
s.options.memSize = 131072;
s.options.numBuffers = 1024;

s.waitForBoot({

    "=== CreativeBlocks starting ===".postln;

    // ----------------
    // file setup
    // ----------------

    ~audioPath = "/home/pi/Downloads/";

    ~trackNames = [
        "drums1_mono.mp3",
        "vocals1_mono.mp3",
        "bass1_mono.mp3",
        "melody1_mono.mp3",

        "drums2_mono.mp3",
        "vocals2_mono.mp3",
        "bass2_mono.mp3",
        "melody2_mono.mp3",

        "drums3_mono.mp3",
        "vocals3_mono.mp3",
        "bass3_mono.mp3",
        "melody3_mono.mp3"
    ];

    ~buffers = Dictionary.new;
    ~players = Dictionary.new;

    ~trackNames.do({ |name|
        var fullPath = ~audioPath ++ name;
        ("loading: " ++ fullPath).postln;
        ~buffers[name] = Buffer.read(s, fullPath);
    });

    s.sync;

    "=== all buffers loaded ===".postln;

    // ----------------
    // SynthDef
    // ----------------

    SynthDef(\stemPlayer, { |out=0, bufnum=0, amp=0.6, rate=1.0, revMix=0.0|
        var sig, wet;

        sig = PlayBuf.ar(
            1,
            bufnum,
            BufRateScale.kr(bufnum) * rate,
            loop: 1
        );

        // mono to both ears
        sig = sig ! 2;

        // reverb
        wet = FreeVerb.ar(sig, mix: revMix, room: 0.85, damp: 0.45);

        Out.ar(out, wet * amp);
    }).add;

    s.sync;

    // ----------------
    // helper functions
    // ----------------

    ~playTrack = { |trackName|
        if(~buffers[trackName].notNil, {
            if(~players[trackName].isNil, {
                ("PLAYING: " ++ trackName).postln;
                ~players[trackName] = Synth(\stemPlayer, [
                    \bufnum, ~buffers[trackName],
                    \rate, 1.0,
                    \revMix, 0.0,
                    \amp, 0.6
                ]);
            }, {
                ("already playing: " ++ trackName).postln;
            });
        }, {
            ("ERROR: no buffer for " ++ trackName).postln;
        });
    };

    ~stopTrack = { |trackName|
        if(~players[trackName].notNil, {
            ("STOPPING: " ++ trackName).postln;
            ~players[trackName].free;
            ~players[trackName] = nil;
        });
    };

    ~setTempo = { |trackName, knobValue|
        var rate;
        knobValue = knobValue.clip(0, 1);
        rate = 1.0 + (knobValue * 0.5);

        if(~players[trackName].notNil, {
            ~players[trackName].set(\rate, rate);
            ("TEMPO " ++ trackName ++ " = " ++ rate).postln;
        }, {
            ("tempo ignored, track not playing: " ++ trackName).postln;
        });
    };

    ~setReverb = { |trackName, knobValue|
        var mix;
        mix = knobValue.clip(0, 1);

        if(~players[trackName].notNil, {
            ~players[trackName].set(\revMix, mix);
            ("REVERB " ++ trackName ++ " = " ++ mix).postln;
        }, {
            ("reverb ignored, track not playing: " ++ trackName).postln;
        });
    };

    // ----------------
    // OSC input
    // ----------------
    // Expected Python messages:
    //
    // Play:
    // /play drums1
    //
    // Stop:
    // /stop drums1
    //
    // Tempo:
    // /tempo drums1 0.75
    //
    // Reverb:
    // /reverb drums1 0.4
    //
    // Track name should be WITHOUT "_mono.mp3"
    // Example: drums1, vocals2, melody3

    OSCdef(\play, { |msg|
        var name;
        name = msg[1].asString ++ "_mono.mp3";
        ~playTrack.(name);
    }, "/play");

    OSCdef(\stop, { |msg|
        var name;
        name = msg[1].asString ++ "_mono.mp3";
        ~stopTrack.(name);
    }, "/stop");

    OSCdef(\tempo, { |msg|
        var name, value;
        name = msg[1].asString ++ "_mono.mp3";
        value = msg[2].asFloat;
        ~setTempo.(name, value);
    }, "/tempo");

    OSCdef(\reverb, { |msg|
        var name, value;
        name = msg[1].asString ++ "_mono.mp3";
        value = msg[2].asFloat;
        ~setReverb.(name, value);
    }, "/reverb");

    // ----------------
    // manual test commands
    // ----------------
    // Run these one at a time in SC if needed:
    //
    // ~playTrack.("drums1_mono.mp3");
    // ~setTempo.("drums1_mono.mp3", 1.0);
    // ~setReverb.("drums1_mono.mp3", 0.7);
    // ~stopTrack.("drums1_mono.mp3");

    "=== CreativeBlocks ready ===".postln;
    "OSC: /play drums1 | /stop drums1 | /tempo drums1 0-1 | /reverb drums1 0-1".postln;

    // keep alive
    Routine({
        loop {
            1.wait;
        }
    }).play;
});
)
