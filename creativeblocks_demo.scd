(
// ================================
// CreativeBlocks SuperCollider Demo
// PAD = song
// PIN 1 = vocals
// PIN 2 = mix
// PIN 1 + PIN 2 = drums
// Files: vocals1_mono.mp3, mix1_mono.mp3, drums1_mono.mp3
// ================================

s.options.numOutputBusChannels = 2;
s.options.memSize = 131072;
s.options.numBuffers = 1024;

s.waitForBoot({

    "=== CreativeBlocks starting ===".postln;

    ~audioPath = "/home/pi/Downloads/";

    ~trackNames = [
        "vocals1_mono.mp3", "mix1_mono.mp3", "drums1_mono.mp3",
        "vocals2_mono.mp3", "mix2_mono.mp3", "drums2_mono.mp3",
        "vocals3_mono.mp3", "mix3_mono.mp3", "drums3_mono.mp3"
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

    SynthDef(\stemPlayer, { |out=0, bufnum=0, amp=0.6, rate=1.0, revMix=0.0|
        var sig, wet;

        sig = PlayBuf.ar(
            1,
            bufnum,
            BufRateScale.kr(bufnum) * rate,
            loop: 1
        );

        sig = sig ! 2;

        wet = FreeVerb.ar(sig, mix: revMix, room: 0.85, damp: 0.45);

        Out.ar(out, wet * amp);
    }).add;

    s.sync;

    ~trackForPadAndPins = { |padNum, pin1, pin2|
        var layer;

        padNum = padNum.asInteger;
        pin1 = pin1.asInteger;
        pin2 = pin2.asInteger;

        layer = if((pin1 == 1) && (pin2 == 1), {
            "drums";
        }, {
            if(pin1 == 1, {
                "vocals";
            }, {
                if(pin2 == 1, {
                    "mix";
                }, {
                    nil;
                });
            });
        });

        if(layer.notNil, {
            layer ++ padNum.asString ++ "_mono.mp3";
        }, {
            nil;
        });
    };

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

    ~stopPad = { |padNum|
        ["vocals", "mix", "drums"].do({ |layer|
            ~stopTrack.(layer ++ padNum.asString ++ "_mono.mp3");
        });
    };

    ~updatePad = { |padNum, pin1, pin2|
        var targetTrack;

        targetTrack = ~trackForPadAndPins.(padNum, pin1, pin2);

        ("PAD " ++ padNum ++ " pin1=" ++ pin1 ++ " pin2=" ++ pin2 ++ " -> " ++ targetTrack).postln;

        // only one layer per pad at a time
        ~stopPad.(padNum);

        if(targetTrack.notNil, {
            ~playTrack.(targetTrack);
        }, {
            ("PAD " ++ padNum ++ " empty").postln;
        });
    };

    ~setTempoForPad = { |padNum, knobValue|
        var rate;

        knobValue = knobValue.clip(0, 1);
        rate = 1.0 + (knobValue * 0.5);

        ["vocals", "mix", "drums"].do({ |layer|
            var trackName = layer ++ padNum.asString ++ "_mono.mp3";

            if(~players[trackName].notNil, {
                ~players[trackName].set(\rate, rate);
                ("TEMPO " ++ trackName ++ " = " ++ rate).postln;
            });
        });
    };

    ~setReverbForPad = { |padNum, knobValue|
        var mix;

        mix = knobValue.clip(0, 1);

        ["vocals", "mix", "drums"].do({ |layer|
            var trackName = layer ++ padNum.asString ++ "_mono.mp3";

            if(~players[trackName].notNil, {
                ~players[trackName].set(\revMix, mix);
                ("REVERB " ++ trackName ++ " = " ++ mix).postln;
            });
        });
    };

    // ================================
    // OSC INPUT
    // ================================
    //
    // Python should send:
    //
    // /pad 1 1 0    -> pad 1, pin 1 touched, pin 2 not touched = vocals1
    // /pad 1 0 1    -> pad 1, pin 2 touched = mix1
    // /pad 1 1 1    -> pad 1, both touched = drums1
    // /pad 1 0 0    -> pad 1 empty = stop pad 1
    //
    // /tempo 1 0.0  -> pad 1 normal speed
    // /tempo 1 1.0  -> pad 1 150% speed
    //
    // /reverb 1 0.0 -> pad 1 dry
    // /reverb 1 1.0 -> pad 1 full reverb

    OSCdef(\padUpdate, { |msg|
        var padNum, pin1, pin2;

        padNum = msg[1].asInteger;
        pin1 = msg[2].asInteger;
        pin2 = msg[3].asInteger;

        ~updatePad.(padNum, pin1, pin2);
    }, "/pad");

    OSCdef(\tempo, { |msg|
        var padNum, value;

        padNum = msg[1].asInteger;
        value = msg[2].asFloat;

        ~setTempoForPad.(padNum, value);
    }, "/tempo");

    OSCdef(\reverb, { |msg|
        var padNum, value;

        padNum = msg[1].asInteger;
        value = msg[2].asFloat;

        ~setReverbForPad.(padNum, value);
    }, "/reverb");

    "=== CreativeBlocks ready ===".postln;
    "OSC examples: /pad 1 1 0 | /pad 1 0 1 | /pad 1 1 1 | /tempo 1 0.5 | /reverb 1 0.8".postln;

    // manual tests:
    // ~updatePad.(1, 1, 0); // vocals1
    // ~updatePad.(1, 0, 1); // mix1
    // ~updatePad.(1, 1, 1); // drums1
    // ~updatePad.(1, 0, 0); // stop pad 1
    // ~setTempoForPad.(1, 1.0);
    // ~setReverbForPad.(1, 0.7);

    Routine({
        loop {
            1.wait;
        }
    }).play;
});
)
