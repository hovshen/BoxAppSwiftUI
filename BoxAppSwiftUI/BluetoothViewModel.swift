import Foundation
import CoreBluetooth
import Combine

class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    // --- 模擬開關 ---
    private let simulationMode = true // 設定為 true 來啟用模擬模式

    // MARK: - 藍牙相關屬性
    private var centralManager: CBCentralManager!
    private var smartBoxPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?

    let smartBoxServiceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b") //
    let commandCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8") //

    // MARK: - @Published 屬性
    @Published var statusMessage: String = "尚未連線"
    @Published var isConnected: Bool = false
    @Published var errorAlert: ErrorAlert?

    // MARK: - 零件資料模型
    let componentData: [String: [String]] = [ //
        "電阻": ["1K", "2K", "3K"],
        "BJT": ["2N3904", "BC547", "S8050"],
        "MOS": ["IRF540N", "2N7000", "BS170"]
    ]
    let categories: [String] = ["電阻", "BJT", "MOS"] //

    // MARK: - 初始化
    override init() {
        super.init()
        // 只在非模擬模式下才初始化真實藍牙
        if !simulationMode {
            centralManager = CBCentralManager(delegate: self, queue: nil)
        }
    }

    // MARK: - 公開函式 (已修改加入模擬邏輯)
    func connectButtonTapped() {
        if isConnected {
            disconnectDevice()
        } else {
            // --- 修改連線邏輯 ---
            if simulationMode {
                // 模擬模式：直接模擬連線成功
                statusMessage = "模擬連線中..."
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // 模擬延遲
                    self.isConnected = true
                    self.statusMessage = "✅ 已連線 (模擬模式)"
                }
            } else {
                // 真實模式：啟動掃描
                startScanning() // <-- 真實掃描被移到這裡
            }
            // --- 修改結束 ---
        }
    }

    func send(command: String) {
        // --- 修改指令傳送邏輯 ---
        if simulationMode {
            // 模擬模式：模擬盒子運作
            guard !command.isEmpty else { return } // 避免空指令
            print("模擬模式：收到指令 '\(command)'")
            statusMessage = "正在取出 \(command)..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // 模擬延遲
                 // 模擬完成後恢復狀態
                 if self.isConnected { // 檢查是否仍然在模擬連線狀態
                    self.statusMessage = "✅ 已連線 (模擬模式)"
                 }
            }
            return // <--- 重要：模擬模式下直接返回，不執行後續真實藍牙操作
        }
        // --- 修改結束 ---

        // --- 真實藍牙邏輯 (保持不變) ---
        guard let peripheral = smartBoxPeripheral, let characteristic = commandCharacteristic else {
            self.errorAlert = ErrorAlert(title: "傳送失敗", message: "尚未連接到智慧零件盒，請先點擊連接。") //
            return
        }
        guard let data = command.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse) //
        print("已發送指令：\(command)") //
        // --- 真實藍牙邏輯結束 ---
    }

    // MARK: - 私有藍牙函式 (disconnectDevice 已修改)
    private func startScanning() {
        // (只在真實模式下被呼叫)
        guard centralManager != nil, centralManager.state == .poweredOn else { //
            let message = "藍牙未開啟，請檢查您手機的「設定」>「藍牙」。" //
            self.statusMessage = "藍牙未開啟" //
            self.errorAlert = ErrorAlert(title: "藍牙未就緒", message: message) //
            return
        }
        statusMessage = "掃描中..." //
        centralManager.scanForPeripherals(withServices: [smartBoxServiceUUID], options: nil) //
    }

    private func disconnectDevice() {
        // --- 修改斷線邏輯 ---
        if simulationMode {
            // 模擬模式：直接斷開
            print("模擬模式：斷開連線")
            isConnected = false
            statusMessage = "尚未連線"
        } else {
            // 真實模式：取消連線
            if let peripheral = smartBoxPeripheral {
                centralManager.cancelPeripheralConnection(peripheral) //
            }
            // (狀態會在 centralManager(_:didDisconnectPeripheral:) 中更新)
        }
        // --- 修改結束 ---
    }

    // MARK: - CBCentralManagerDelegate (只在真實模式下 relevant)
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard !simulationMode else { return } // 模擬模式下忽略
        switch central.state { //
            case .poweredOn: statusMessage = "藍牙已就緒，請點擊連接"
            case .poweredOff:
                statusMessage = "藍牙已關閉"; isConnected = false
                self.errorAlert = ErrorAlert(title: "藍牙已關閉", message: "請至「設定」>「藍牙」開啟藍牙以連接零件盒。") //
            case .unauthorized:
                statusMessage = "未授權使用藍牙"
                self.errorAlert = ErrorAlert(title: "藍牙未授權", message: "請至「設定」>「隱私權與安全性」>「藍牙」允許本 App 使用藍牙。") //
            case .unsupported:
                statusMessage = "此設備不支援藍牙"
                self.errorAlert = ErrorAlert(title: "設備不支援", message: "您的設備不支援藍牙低功耗(BLE)，無法使用此功能。") //
            default: statusMessage = "藍牙狀態未知"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard !simulationMode else { return } // 模擬模式下忽略
        centralManager.stopScan() //
        smartBoxPeripheral = peripheral
        smartBoxPeripheral?.delegate = self
        statusMessage = "找到零件盒，連線中..." //
        centralManager.connect(peripheral, options: nil) //
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard !simulationMode else { return } // 模擬模式下忽略
        statusMessage = "✅ 已連線" //
        isConnected = true
        peripheral.discoverServices([smartBoxServiceUUID]) //
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard !simulationMode else { return } // 模擬模式下忽略
        let errorMessage = error?.localizedDescription ?? "未知錯誤" //
        statusMessage = "連線失敗" //
        self.errorAlert = ErrorAlert(title: "連線失敗", message: "無法連接到零件盒：\(errorMessage)") //
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard !simulationMode else { return } // 模擬模式下忽略
        statusMessage = "已斷線" //
        isConnected = false
        smartBoxPeripheral = nil
        commandCharacteristic = nil
        if let error = error { //
            self.errorAlert = ErrorAlert(title: "意外斷線", message: "連線已中斷：\(error.localizedDescription)") //
        }
    }

    // MARK: - CBPeripheralDelegate (只在真實模式下 relevant)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard !simulationMode else { return } // 模擬模式下忽略
        guard let services = peripheral.services else { return } //
        for service in services {
            peripheral.discoverCharacteristics([commandCharacteristicUUID], for: service) //
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard !simulationMode else { return } // 模擬模式下忽略
        guard let characteristics = service.characteristics else { return } //
        for characteristic in characteristics {
            if characteristic.uuid == commandCharacteristicUUID {
                commandCharacteristic = characteristic //
                print("已找到指令特徵！準備發送指令。") //
            }
        }
    }
}
