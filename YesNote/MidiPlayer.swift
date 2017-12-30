//
//  Midi.swift
//  YesNote
//
//  Created by Zack Ulam on 11/2/17.
//  Copyright © 2017 Elad. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class MidiPlayer {
    //begin Jeff's Midi Player // this one is from a midi file
    var midiPlayer:AVMIDIPlayer?
    var loop = false
    let tempoDivider: Float = 120.0
    var tempoConverted: Float = 1.0
    // this one is from a sequence turned into data
    var midiPlayerFromData:AVMIDIPlayer?
    
    var musicPlayer:MusicPlayer?
    var soundbank:URL?
    let soundFontMuseCoreName = "GeneralUser GS MuseScore v1.442"
    let gMajor = "sibeliusGMajor"
    let nightBaldMountain = "ntbldmtn"
    
    var musicSequence:MusicSequence!
    //end Jeff's Midi Player
    //this one is from a midi file
    //begin midi
    func createAVMIDIPlayer(_ musicSequence:MusicSequence) {
        
       
        
        
        guard let bankURL = Bundle.main.url(forResource: "GeneralUser GS MuseScore v1.442", withExtension: "sf2") else {
            fatalError("\"GeneralUser GS MuseScore v1.442.sf2\" file not found.")
        }
        
        var status = OSStatus(noErr)
        var data:Unmanaged<CFData>?
        status = MusicSequenceFileCreateData (musicSequence,
                                              MusicSequenceFileTypeID.midiType,
                                              MusicSequenceFileFlags.eraseFile,
                                              480, &data)
        
        if status != OSStatus(noErr) {
            print("bad status \(status)")
        }
        
        if let md = data {
            let midiData = md.takeUnretainedValue() as Data
            do {
                try self.midiPlayerFromData = AVMIDIPlayer(data: midiData, soundBankURL: bankURL)
                print("created midi player with sound bank url \(bankURL)")
            } catch let error as NSError {
                print("nil midi player")
                print("Error \(error.localizedDescription)")
            }
            data?.release()
            
            self.midiPlayerFromData?.prepareToPlay()
        }
    }
    
    func playMidi() {
        createAVMIDIPlayerFromMIDIFIle()
        self.midiPlayer?.setValue(tempoConverted, forKey: "rate")
        loop = !loop
        if (self.midiPlayer?.isPlaying)! {
            self.midiPlayer?.stop()
        }
        DispatchQueue.global(qos: .background).async {
            while self.loop {
                //usleep(1000000)
                if self.midiPlayer?.isPlaying == false {
                    self.midiPlayer?.play({ () -> Void in
                        print("finished")
                        self.midiPlayer?.currentPosition = 0
                    })
                }
                else {
                    continue
                }
            }
        }
        /*DispatchQueue.main.async {
         print("This is run on the main queue, after the previous code in outer block")
         }
         }
         */
    }
    
    func createAVMIDIPlayerFromMIDIFIle() {
        
        let mainVC = UIApplication.shared.keyWindow?.rootViewController as! MainViewController?
        let midiFileName = mainVC?.rhythmObj.getMIDIName()
        
        guard let midiFileURL = Bundle.main.url(forResource: midiFileName, withExtension: "mid") else {
            fatalError("\"\(String(describing: midiFileName))\" file not found.")
        }
        guard let bankURL = Bundle.main.url(forResource: "GeneralUser GS MuseScore v1.442", withExtension: "sf2") else {
            fatalError("\"GeneralUser GS MuseScore v1.442.sf2\" file not found.")
        }
        
        do {
            try self.midiPlayer = AVMIDIPlayer(contentsOf: midiFileURL, soundBankURL: bankURL)
            print("created midi player with sound bank url \(bankURL)")
        } catch let error as NSError {
            print("Error \(error.localizedDescription)")
        }
        
        self.midiPlayer?.prepareToPlay()
        //setupSlider()
    }
    
    func playWithMusicPlayer() {
        self.musicPlayer = createMusicPlayer(self.musicSequence)
        playMusicPlayer()
    }
    
    func createMusicPlayer(_ musicSequence:MusicSequence) -> MusicPlayer {
        var musicPlayer:MusicPlayer? = nil
        var status = OSStatus(noErr)
        status = NewMusicPlayer(&musicPlayer)
        if status != OSStatus(noErr) {
            print("bad status \(status) creating player")
        }
        status = MusicPlayerSetSequence(musicPlayer!, musicSequence)
        if status != OSStatus(noErr) {
            print("setting sequence \(status)")
        }
        status = MusicPlayerPreroll(musicPlayer!)
        if status != OSStatus(noErr) {
            print("prerolling player \(status)")
        }
        return musicPlayer!
    }
    
    func playMusicPlayer() {
        var status = OSStatus(noErr)
        var playing:DarwinBoolean = false
        status = MusicPlayerIsPlaying(musicPlayer!, &playing)
        if playing != false {
            print("music player is playing. stopping")
            status = MusicPlayerStop(musicPlayer!)
            if status != OSStatus(noErr) {
                print("Error stopping \(status)")
                return
            }
        } else {
            print("music player is not playing.")
        }
        
        status = MusicPlayerSetTime(musicPlayer!, 0)
        if status != OSStatus(noErr) {
            print("setting time \(status)")
            return
        }
        
        status = MusicPlayerStart(musicPlayer!)
        if status != OSStatus(noErr) {
            print("Error starting \(status)")
            return
        }
    }
    
    func createMusicSequence() -> MusicSequence {
        // create the sequence
        var musicSequence:MusicSequence? = nil
        var status = NewMusicSequence(&musicSequence)
        if status != OSStatus(noErr) {
            print("\(#line) bad status \(status) creating sequence")
        }
        
        var tempoTrack:MusicTrack? = nil
        if MusicSequenceGetTempoTrack(musicSequence!, &tempoTrack) != noErr {
            assert(tempoTrack != nil, "Cannot get tempo track")
        }
        //MusicTrackClear(tempoTrack, 0, 1)
        if MusicTrackNewExtendedTempoEvent(tempoTrack!, 0.0, 128.0) != noErr {
            print("could not set tempo")
        }
        if MusicTrackNewExtendedTempoEvent(tempoTrack!, 4.0, 256.0) != noErr {
            print("could not set tempo")
        }
        
        
        // add a track
        var track:MusicTrack? = nil
        status = MusicSequenceNewTrack(musicSequence!, &track)
        if status != OSStatus(noErr) {
            print("error creating track \(status)")
        }
        
        // bank select msb
        var chanmess = MIDIChannelMessage(status: 0xB0, data1: 0, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating bank select event \(status)")
        }
        // bank select lsb
        chanmess = MIDIChannelMessage(status: 0xB0, data1: 32, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating bank select event \(status)")
        }
        
        // program change. first data byte is the patch, the second data byte is unused for program change messages.
        chanmess = MIDIChannelMessage(status: 0xC0, data1: 0, data2: 0, reserved: 0)
        status = MusicTrackNewMIDIChannelEvent(track!, 0, &chanmess)
        if status != OSStatus(noErr) {
            print("creating program change event \(status)")
        }
        
        // now make some notes and put them on the track
        var beat:MusicTimeStamp = 0.0
        for i:UInt8 in 60...72 {
            var mess = MIDINoteMessage(channel: 0,
                                       note: i,
                                       velocity: 64,
                                       releaseVelocity: 0,
                                       duration: 1.0 )
            status = MusicTrackNewMIDINoteEvent(track!, beat, &mess)
            if status != OSStatus(noErr) {
                print("creating new midi note event \(status)")
            }
            beat += 1
        }
        
        CAShow(UnsafeMutablePointer<MusicSequence>(musicSequence!))
        
        return musicSequence!
    }
    
    //end midi
}

