//
//  SFSpeechViewController.swift
//  TextToSpeech
//
//  Created by Tony Hung on 7/29/16.
//  Copyright © 2016 Vonage. All rights reserved.
//

import UIKit
import Speech

class SFSpeechViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    
    var startDate:NSDate?
    var endDate:NSDate?
    var numRequests:Int?
    
    private var _speechRecognizer: AnyObject?
    @available(iOS 10.0, *)
    var speechRecognizer: SFSpeechRecognizer? {
        get {
            let t = SFSpeechRecognizer(locale: Locale(localeIdentifier: "en-US"))!
            return t
        }
        set {
            _speechRecognizer = newValue
        }
    }
    
    private var _recognitionRequest: AnyObject?
    @available(iOS 10.0, *)
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest? {
        get {
            return _recognitionRequest as? SFSpeechAudioBufferRecognitionRequest
        }
        set {
            _recognitionRequest = newValue
        }
    }
    
//    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    
    private var _recognitionTask: AnyObject?
    @available(iOS 10.0, *)
    var recognitionTask: SFSpeechRecognitionTask? {
        get {
            return _recognitionTask as? SFSpeechRecognitionTask
        }
        set {
            _recognitionTask = newValue
        }
    }

    
//    var recognitionTask: SFSpeechRecognitionTask?
    
    private let audioEngine = AVAudioEngine()
    
    @IBOutlet var textView : UITextView!
    
    @IBOutlet var recordButton : UIButton!
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "IOS10 API"
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
    }
    
     override func viewDidAppear(_ animated: Bool) {
        
        guard #available(iOS 10, *) else {
            let alert = UIAlertController(title: "Not Supported", message: "Speech Recognizer is only available on IOS10", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))

            self.navigationController?.present(alert, animated: true, completion: nil)
            return
        }
        speechRecognizer?.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("User denied access to speech recognition", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted on this device", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not yet authorized", for: .disabled)
                }
            }
        }
    }
    
    private func startRecording() throws {
        
        guard #available(iOS 10, *) else {
            return
        }
        self.textView.text = ""
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                self.textView.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                let translationWithTimestamp = "<\(NSDate().timeIntervalSince1970 * 1000)>\(self.textView.text!)\n"
                print("sending \(translationWithTimestamp)")
                
                LexifoneTranslateUploadS3.sharedManager().translateMode = LexifoneTranslateUploadModeSFAPI
                LexifoneTranslateUploadS3.sharedManager().writeTranslationToFile(withText: translationWithTimestamp)

                
//                self.recordButton.isEnabled = true
//                self.recordButton.setTitle("Start Recording", for: [])
                
                try! self.startRecording()
                
            }
        }

        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
        
        textView.text = "(Go ahead, I'm listening)"
    }
    
    // MARK: SFSpeechRecognizerDelegate
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition not available", for: .disabled)
        }
    }
    
    // MARK: Interface Builder actions
    
    @IBAction func recordButtonTapped() {
        guard #available(iOS 10, *) else {
            return
        }
        if audioEngine.isRunning {
            audioEngine.stop()
            
            self.endDate = NSDate()
            let duration = self.startDate?.timeIntervalSince(self.endDate! as Date)
            print("duration \(duration)")
            
            recognitionRequest?.endAudio()
            recordButton.isEnabled = false
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            try! startRecording()
            self.startDate = NSDate()
            recordButton.setTitle("Stop recording", for: [])
        }
    }
}

