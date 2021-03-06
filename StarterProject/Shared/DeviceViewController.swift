//
//  DeviceViewController.swift
//  SwiftStarter
//
//  Created by Stephen Schiffli on 10/20/15.
//  Copyright © 2015 MbientLab Inc. All rights reserved.
//

import UIKit
import MetaWear
import MetaWearCpp

class DeviceViewController: UIViewController {
    @IBOutlet weak var deviceStatus: UILabel!
    @IBOutlet weak var textField: UITextView!

    var device: MetaWear!
    var textMessage: String! = "Empty"
    
    @IBAction func calibratePressed(_ sender: Any) {
        let board = device.board

        // set fusion mode to ndof (n degress of freedom)
        mbl_mw_sensor_fusion_set_mode(board, MBL_MW_SENSOR_FUSION_MODE_NDOF);
        // set acceleration rangen to +/-8G, note accelerometer is configured here
        mbl_mw_sensor_fusion_set_acc_range(board, MBL_MW_SENSOR_FUSION_ACC_RANGE_8G);
        // write changes to the board
        mbl_mw_sensor_fusion_write_config(board);
        
        /*  CONVERT TO SWIFT FOR DATA CALIBRATION READ AND STORAGE
        let signal = mbl_mw_sensor_fusion_calibration_state_data_signal(board);
        mbl_mw_datasignal_subscribe(signal, nullptr, [](void* context, const MblMwData* data) {
            let casted = (MblMwCalibrationState*) data->value;
            print ("calibration state: {accelerometer: " << casted->accelerometer
                << ", gyroscope: " << casted->gyroscope
                << ", magnetometer: " << casted->magnetometer
                << "}" << endl;
        });
        
        mbl_mw_datasignal_read(signal);
        */
        self.updateLabel("Calibrating and Configuring...")

        let signal = mbl_mw_sensor_fusion_calibration_state_data_signal(board);
        mbl_mw_datasignal_read(signal);
        print("Signal: ", signal)

    }
    
    
    
    @IBAction func startPressed(_ sender: Any) {
        let board = device.board
        
        /** Acceleration
        guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_ACCELEROMETER) != MBL_MW_MODULE_TYPE_NA else {
            print("No accelerometer")
            return
        }
        let signal = mbl_mw_acc_get_acceleration_data_signal(board)
        mbl_mw_datasignal_subscribe(signal, bridge(obj: self)) { (context, data) in
            let _self: DeviceViewController = bridge(ptr: context!)
            let obj: MblMwCartesianFloat = data!.pointee.valueAs()
            print(obj)
        }
        mbl_mw_acc_enable_acceleration_sampling(board)
        mbl_mw_acc_start(board)
        **/
 

        /** Stream Quaterion **/
        let signal = mbl_mw_sensor_fusion_get_data_signal(board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION);
        mbl_mw_datasignal_subscribe(signal, bridge(obj: self)) { (context, data) in
            let _self: DeviceViewController = bridge(ptr: context!)
            let obj: MblMwQuaternion = data!.pointee.valueAs()
            print(obj)
        }

        mbl_mw_sensor_fusion_enable_data(board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION);
        mbl_mw_sensor_fusion_start(board);
        /** **/
    }
    
    @IBAction func deviceInformation(_ sender: Any) {
        let board = device.board
        
        // UnsafePointer<MblMwDeviceInformation>?
        let deviceInfoPtr = mbl_mw_metawearboard_get_device_information(board)
        let deviceInfo = deviceInfoPtr?.pointee
        let manufacturer = String(cString: (deviceInfo?.manufacturer)!)
        let modelNumber = String(cString: (deviceInfo?.model_number)!)
        let firmwareRevision = String(cString: (deviceInfo?.firmware_revision)!)
        let serialNumber = String(cString: (deviceInfo?.serial_number)!)
        let hardwareRevision = String(cString: (deviceInfo?.hardware_revision)!)

        let message = ("*Device Information* \n\tManufacturer: \(manufacturer)\n\tModel: \(modelNumber)\n\tFirmware Rev: \(firmwareRevision)\n\tSerial Number: \(serialNumber)\n\tHardware Revision: \(hardwareRevision)\n\n ")
        print(message)

        self.textMessage = message
        
        self.textField.text = textMessage

    }
    
    /* Start calibration - press stop when complete */
    @IBAction func startCalibrate(_ sender: Any) {
        self.updateLabel("Starting Calibration... ")
        print ("Starting calibration...")
        
        let board = device.board
        let signal = mbl_mw_sensor_fusion_calibration_state_data_signal(board)
        mbl_mw_datasignal_subscribe(signal,  bridge(obj: self), { (context, data) in
            let _self: DeviceViewController = bridge(ptr: context!)
            let obj: MblMwCalibrationState = data!.pointee.valueAs()
            print("Calibration Values: \(obj)")
            _self.textMessage = "Calibration Values: \(obj)"
            })
        
        self.textField.text = textMessage

    }
    
    @IBAction func checkCalibration(_ sender: Any) {
        self.updateLabel("Checking Calibration...")
        print ("Checking calibration...")
        
        let board = device.board
        let signal = mbl_mw_sensor_fusion_calibration_state_data_signal(board)
        mbl_mw_datasignal_subscribe(signal,  bridge(obj: self), { (context, data) in
            let _self: DeviceViewController = bridge(ptr: context!)
            let obj: MblMwCalibrationState = data!.pointee.valueAs()
            print("Calibration Values: \(obj)")
            _self.textMessage = "Calibration Values: \(obj)"
        })

        // Force the read, calling the callback closure.
        mbl_mw_datasignal_read(signal);

        self.textField.text = textMessage

    }

    @IBAction func stopCalibration(_ sender: Any) {
        self.updateLabel("Stopping Calibration...")
        print ("Stopping calibration...")
        
        let board = device.board
        
         mbl_mw_sensor_fusion_read_calibration_data(board,  bridge(obj: self), { (context, board, data) in
            print ("Preparing to write calibration data...")

            // returns null if an error occured, such as using with unsupported firmware
            // write to board, or save to local file to always have on hand
            guard data != nil else {
                print ("ERROR: No calibration data returned.")
                return
            }
            // calibration data is reloaded everytime mode changes
            print ("Writing calibration data...")
            mbl_mw_sensor_fusion_write_calibration_data(board, data);
                
            // free memory after we're done with the pointer
            print ("Freeing memory on board...")
            // FIXME mbl_mw_memory_free(newData);
            
            let textMessage = "Calibration done.";
            //let _self: DeviceViewController = bridge(ptr: context!)
            //_self.textMessage = textMessage
        })
        
        self.updateLabel(textMessage)
    }
    
    
    @IBAction func stopPressed(_ sender: Any) {
        let board = device.board
        let signal = mbl_mw_acc_get_acceleration_data_signal(board)
        //mbl_mw_acc_stop(board)
        //mbl_mw_acc_disable_acceleration_sampling(board)
        mbl_mw_sensor_fusion_stop(board)
        mbl_mw_datasignal_unsubscribe(signal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated);
        
        self.updateLabel("Restoring")
        if let state = DeviceState.loadForDevice(device) {
            // Initialize the device
            device.deserialize(state.serializedState)
            self.updateLabel("Connecting")
            device.connectAndSetup().continueWith { t in
                if let error = t.error {
                    // Sorry we couldn't connect
                    self.deviceStatus.text = error.localizedDescription
                } else {
                    // The result of a connectAndSetup call is a task which completes upon disconnection.
                    t.result!.continueWith {
                        state.serializedState = self.device.serialize()
                        state.saveToUrl(self.device.uniqueUrl)
                        self.updateLabel($0.error?.localizedDescription ?? "Disconnected")
                    }
                    
                    self.updateLabel("Connected")
                    self.device.flashLED(color: .green, intensity: 1.0, _repeat: 3)
                    
                    self.doDownload(state: state)
                }
            }
        }
    }
    
    func doDownload(state :DeviceState) {
        updateLabel("Downloading")
        // Attach log download handlers for the data
        let temperatureSignal = mbl_mw_logger_lookup_id(device.board, state.temperatureLogId)
        mbl_mw_logger_subscribe(temperatureSignal, bridge(obj: self)) { (context, data) in
            let _self: DeviceViewController = bridge(ptr: context!)
            _self.didGetTemperature(timestamp: data!.pointee.timestamp, entry: data!.pointee.valueAs())
        }
        
        // Setup the handlers for events during the download
        var handlers = MblMwLogDownloadHandler()
        handlers.context = bridge(obj: self)
        handlers.received_progress_update = { (context, entriesLeft, totalEntries) in
            let _self: DeviceViewController = bridge(ptr: context!)
            _self.progress(entriesLeft: entriesLeft, totalEntries: totalEntries)
        }
        handlers.received_unknown_entry = { (context, id, epoch, data, length) in
            let _self: DeviceViewController = bridge(ptr: context!)
            _self.unknownEntry(id: id, epoch: epoch, data: data, length: length)
        }
        handlers.received_unhandled_entry = { (context, data) in
            let _self: DeviceViewController = bridge(ptr: context!)
            _self.unhandledEntry(data: data)
        }
        
        // Start the log download
        mbl_mw_logging_download(device.board!, 100, &handlers)
    }
    
    func updateLabel(_ msg: String) {
        DispatchQueue.main.async {
            self.deviceStatus.text = msg
        }
    }
    
    func didGetTemperature(timestamp: Date, entry: Float) {
        print("temp: \(timestamp) \(entry)")
    }
    
    func progress(entriesLeft: UInt32, totalEntries: UInt32) {
        // Clear the in progress flag
        if entriesLeft == 0 {
            self.updateLabel("Finished download \(totalEntries) entries")
        }
    }
    
    func unknownEntry(id: UInt8, epoch: Int64, data: UnsafePointer<UInt8>?, length: UInt8) {
        print("unknownEntry: \(epoch) \(String(describing: data)) \(length)")
    }
    
    func unhandledEntry(data: UnsafePointer<MblMwData>?) {
        print("unhandledEntry: \(String(describing: data))")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        device.flashLED(color: .red, intensity: 1.0, _repeat: 3)
        mbl_mw_debug_disconnect(device.board)
    }
}
