//
//  InfoViewController.swift
//  bluefruitconnect
//
//  Created by Antonio García on 25/09/15.
//  Copyright © 2015 Adafruit. All rights reserved.
//

import Cocoa
import CoreBluetooth

class InfoViewController: NSViewController {
    private static let kExpandAllNodes  = true
    
    // UI
    @IBOutlet weak var baseTableView: NSOutlineView!
    @IBOutlet weak var refreshOnLoadButton: NSButton!
    @IBOutlet weak var refreshButton: NSButton!
    @IBOutlet weak var discoveringStatusLabel: NSTextField!
    
    // Delegates
    var onServicesDiscovered : (() -> ())?
    
    // Data
    private var blePeripheral : BlePeripheral?
    private var services : [CBService]?
    
    private var shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled

    private var isDiscoveringServices = false
    private var elementsToDiscover = 0
    private var elementsDiscovered = 0
    private var valuesToRead = 0
    private var valuesRead = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        refreshOnLoadButton.state = Preferences.infoIsRefreshOnLoadEnabled ? NSOnState : NSOffState
    }
    
    func discoverServices() {
        isDiscoveringServices = true
        elementsToDiscover = 0
        elementsDiscovered = 0
        valuesToRead = 0
        valuesRead = 0
        updateDiscoveringStatusLabel()
        
        services = nil
        self.baseTableView.reloadData()
        BleManager.sharedInstance.discover(blePeripheral!, serviceUUIDs: nil)
    }

    func updateDiscoveringStatusLabel() {
        var text = ""
        if isDiscoveringServices {
            text = "Discovering Services..."
            refreshButton.enabled = false
        }
        else if elementsDiscovered < elementsToDiscover || valuesRead < valuesToRead {
            if shouldDiscoverCharacteristics {
                text = "Discovering (\(elementsDiscovered)/\(elementsToDiscover)) and reading values (\(valuesRead)/\(valuesToRead))..."
            }
            else {
                text = "Discovering (\(elementsDiscovered)/\(elementsToDiscover))..."
            }
            refreshButton.enabled = false
        }
        else {
            refreshButton.enabled = true
        }
        
        discoveringStatusLabel.stringValue = text
    }
    
    // MARK: - Actions

    @IBAction func onClickRefreshOnLoad(sender: NSButton) {
        Preferences.infoIsRefreshOnLoadEnabled = sender.state == NSOnState
    }
    
    @IBAction func onClickRefresh(sender: AnyObject) {
        shouldDiscoverCharacteristics = true
        discoverServices()
    }
}

// MARK: - DetailTab
extension InfoViewController : DetailTab {
    
    func tabWillAppear() {
        updateDiscoveringStatusLabel()
        baseTableView.reloadData()
    }
    
    func tabWillDissapear() {
    }
    
    func tabReset() {
        // Peripheral should be connected
        blePeripheral = BleManager.sharedInstance.blePeripheralConnected
        if (blePeripheral == nil) {
            DLog("Error: Info: blePeripheral is nil")
        }
        
        shouldDiscoverCharacteristics = Preferences.infoIsRefreshOnLoadEnabled
        updateDiscoveringStatusLabel()
        
        // Discover services
        services = nil
        discoverServices()
    }
    
}

// MARK: - NSOutlineViewDataSource
extension InfoViewController : NSOutlineViewDataSource {
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if (item == nil) {
            // Services
            if let services = services {
                return services.count
            }
            else {
                return 0
            }
        }
        else if let service = item as? CBService {
            return service.characteristics == nil ?0:service.characteristics!.count
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors == nil ?0:characteristic.descriptors!.count
        }
        else {
            return 0
        }
        
    }
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        if let service = item as? CBService {
            return service.characteristics?.count > 0
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors?.count > 0
        }
        else {
            return false
        }
    }
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if (item == nil) {
            return services![index]
        }
        else if let service = item as? CBService {
            return service.characteristics![index]
        }
        else if let characteristic = item as? CBCharacteristic {
            return characteristic.descriptors![index]
        }
        else {
            return "<Unknown>"
        }
    }
}

// MARK: NSOutlineViewDelegate

extension InfoViewController: NSOutlineViewDelegate {
    func outlineView(outlineView: NSOutlineView, viewForTableColumn tableColumn: NSTableColumn?, item: AnyObject) -> NSView? {
        
        var cell = NSTableCellView()
        
        if let columnIdentifier = tableColumn?.identifier {
            switch(columnIdentifier) {
            case "UUIDColumn":
                cell = outlineView.makeViewWithIdentifier("InfoNameCell", owner: self) as! NSTableCellView
                
                var identifier = ""
                if let service = item as? CBService {
                    identifier = service.UUID.UUIDString
                }
                else if let characteristic = item as? CBCharacteristic {
                    identifier = characteristic.UUID.UUIDString
                }
                else if let descriptor = item as? CBDescriptor {
                    identifier = descriptor.UUID.UUIDString
                }
                
                if let name = BleUUIDNames.sharedInstance.nameForUUID(identifier) {
                    identifier = name
                }
                cell.textField?.stringValue = identifier
            
            case "ValueStringColumn":
                cell = outlineView.makeViewWithIdentifier("InfoValueStringCell", owner: self) as! NSTableCellView
                var value : String = ""
                if let characteristic = item as? CBCharacteristic {
                    if let characteristicValue = characteristic.value {
                        if let characteristicString = NSString(data:characteristicValue, encoding: NSUTF8StringEncoding) as String? {
                            value = characteristicString
                        }
                    }
                }
                else if let descriptor = item as? CBDescriptor {
                    if let descriptorValue = descriptor.value as? NSData{
                        if let descriptorString = NSString(data:descriptorValue, encoding: NSUTF8StringEncoding) as String? {
                            value = descriptorString
                        }
                    }
                }
                
                cell.textField?.stringValue = value
                
            case "ValueHexColumn":
                cell = outlineView.makeViewWithIdentifier("InfoValueHexCell", owner: self) as! NSTableCellView
                var value : String = ""
                if let characteristic = item as? CBCharacteristic {
                    if let characteristicValue = characteristic.value {
                        value = hexString(characteristicValue)
                    }
                }
                else if let descriptor = item as? CBDescriptor {
                    if let descriptorValue = descriptor.value as? NSData{
                        value = hexString(descriptorValue)
                    }
                }
                
                cell.textField?.stringValue = value
                
            case "TypeColumn":
                cell = outlineView.makeViewWithIdentifier("InfoTypeCell", owner: self) as! NSTableCellView
                
                var type = "<Unknown Type>"
                if let _ = item as? CBService {
                    type = "Service"
                }
                else if let _ = item as? CBCharacteristic {
                    type = "Characteristic"
                }
                else if let _ = item as? CBDescriptor {
                    type = "Descriptor"
                }
                cell.textField?.stringValue = type
                
            default:
                cell.textField?.stringValue = ""
            }
        }
        
        return cell
    }
}

// MARK: - CBPeripheralDelegate
extension InfoViewController : CBPeripheralDelegate {
    
    func peripheralDidUpdateName(peripheral: CBPeripheral) {
        DLog("centralManager peripheralDidUpdateName: \(peripheral.name != nil ? peripheral.name! : "")")
        discoverServices()
    }
    func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        DLog("centralManager didModifyServices: \(peripheral.name != nil ? peripheral.name! : "")")
        discoverServices()
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        isDiscoveringServices = false
        
        if services == nil {
            //DLog("centralManager didDiscoverServices: \(peripheral.name != nil ? peripheral.name! : "")")
            
            services = blePeripheral?.peripheral.services
            elementsToDiscover = 0
            elementsDiscovered = 0
            
            // Discover characteristics
            if shouldDiscoverCharacteristics {
                if let services = services {
                    for service in services {
                        elementsToDiscover++
                        blePeripheral?.peripheral.discoverCharacteristics(nil, forService: service)
                    }
                }
            }
            
            // Update UI
            dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
                
                self.updateDiscoveringStatusLabel()
                self.baseTableView.reloadData()
                self.onServicesDiscovered?()
                })
        }
    }

    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        //DLog("centralManager didDiscoverCharacteristicsForService: \(service.UUID.UUIDString)")
        
        elementsDiscovered++
        
        var discoveringDescriptors = false
        if let characteristics = service.characteristics {
            if (characteristics.count > 0)  {
                discoveringDescriptors = true
            }
            for characteristic in characteristics {
                if (characteristic.properties.rawValue & CBCharacteristicProperties.Read.rawValue != 0) {
                    valuesToRead++
                    peripheral.readValueForCharacteristic(characteristic)
                }
                
                elementsToDiscover++
                blePeripheral?.peripheral.discoverDescriptorsForCharacteristic(characteristic)
            }
        }
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.updateDiscoveringStatusLabel()
            self.baseTableView.reloadData()
            if (!discoveringDescriptors && InfoViewController.kExpandAllNodes) {
                // Expand all nodes if not waiting for descriptors
                self.baseTableView.expandItem(nil, expandChildren: true)
            }
            })
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        //DLog("centralManager didDiscoverDescriptorsForCharacteristic: \(characteristic.UUID.UUIDString)")
        elementsDiscovered++
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.updateDiscoveringStatusLabel()
            self.baseTableView.reloadData()
            
            if (InfoViewController.kExpandAllNodes) {
                // Expand all nodes
                self.baseTableView.expandItem(nil, expandChildren: true)
            }
            })
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        //DLog("centralManager didUpdateValueForCharacteristic: \(characteristic.UUID.UUIDString)")

        valuesRead++
        
        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.updateDiscoveringStatusLabel()
            self.baseTableView.reloadData()
            })
    }
    
    func peripheral(peripheral: CBPeripheral, didUpdateValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
        //DLog("centralManager didUpdateValueForDescriptor: \(descriptor.UUID.UUIDString)")

        dispatch_async(dispatch_get_main_queue(),{ [unowned self] in
            self.updateDiscoveringStatusLabel()
            self.baseTableView.reloadData()
            })
    }
}