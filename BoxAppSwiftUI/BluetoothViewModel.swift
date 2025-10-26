import Foundation
import CoreBluetooth
import Combine
// 讓 ViewModel 遵從藍牙相關協定
class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {

    // MARK: - 藍牙相關屬性
    private var centralManager: CBCentralManager!
    private var smartBoxPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?

    // UUIDs (與 PartsBoxViewController 相同)
    let smartBoxServiceUUID = CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")
    let commandCharacteristicUUID = CBUUID(string: "beb5483e-36e1-4688-b7f5-ea07361b26a8")

    // MARK: - @Published 屬性 (用於驅動 SwiftUI 更新)
    @Published var statusMessage: String = "尚未連線"
    @Published var isConnected: Bool = false
    @Published var errorAlert: ErrorAlert?
    // MARK: - 零件資料模型
    // (從 PartsBoxViewController 搬移過來)
    let componentData: [String: [String]] = [
        "電阻": ["1K", "2K", "3K"],
        "BJT": ["2N3904", "BC547", "S8050"],
        "MOS": ["IRF540N", "2N7000", "BS170"]
    ]
    let categories: [String] = ["電阻", "BJT", "MOS"]

    // MARK: - 初始化
    override init() {
        super.init()
        // 初始化藍牙 Central Manager
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - 公開給 View 呼叫的函式
    func connectButtonTapped() {
        if isConnected {
            disconnectDevice()
        } else {
            startScanning()
        }
    }
    
    // 發送指令
    func send(command: String) {
        guard let peripheral = smartBoxPeripheral, let characteristic = commandCharacteristic else {
            self.errorAlert = ErrorAlert(title: "傳送失敗", message: "尚未連接到智慧零件盒，請先點擊連接。")
            return
        }
        
        guard let data = command.data(using: .utf8) else { return }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
        print("已發送指令：\(command)")
    }

    // MARK: - 私有藍牙函式
    private func startScanning() {
        guard centralManager.state == .poweredOn else {
            let message = "藍牙未開啟，請檢查您手機的「設定」>「藍牙」。"
                        print(message)
                        // 更新狀態並發布 Alert
                        self.statusMessage = "藍牙未開啟"
                        self.errorAlert = ErrorAlert(title: "藍牙未就緒", message: message)
            return
        }
        statusMessage = "掃描中..."
        centralManager.scanForPeripherals(withServices: [smartBoxServiceUUID], options: nil)
    }

    private func disconnectDevice() {
        if let peripheral = smartBoxPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    // MARK: - CBCentralManagerDelegate (搬移自 PartsBoxViewController)
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
                case .poweredOn:
                    statusMessage = "藍牙已就緒，請點擊連接"
                case .poweredOff:
                    statusMessage = "藍牙已關閉"
                    isConnected = false
                    self.errorAlert = ErrorAlert(title: "藍牙已關閉", message: "請至「設定」>「藍牙」開啟藍牙以連接零件盒。")
                case .unauthorized:
                    statusMessage = "未授權使用藍牙"
                    self.errorAlert = ErrorAlert(title: "藍牙未授權", message: "請至「設定」>「隱私權與安全性」>「藍牙」允許本 App 使用藍牙。")
                case .unsupported:
                    statusMessage = "此設備不支援藍牙"
                    self.errorAlert = ErrorAlert(title: "設備不支援", message: "您的設備不支援藍牙低功耗(BLE)，無法使用此功能。")
                default:
                    statusMessage = "藍牙狀態未知"
                }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        centralManager.stopScan()
        smartBoxPeripheral = peripheral
        smartBoxPeripheral?.delegate = self
        statusMessage = "找到零件盒，連線中..."
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        statusMessage = "✅ 已連線"
        isConnected = true
        peripheral.discoverServices([smartBoxServiceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let errorMessage = error?.localizedDescription ?? "未知錯誤"
                statusMessage = "連線失敗"
                self.errorAlert = ErrorAlert(title: "連線失敗", message: "無法連接到零件盒：\(errorMessage)")
                // --- 結束修改 ---
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        statusMessage = "已斷線"
        isConnected = false
        smartBoxPeripheral = nil
        commandCharacteristic = nil
        
        if let error = error {
                    self.errorAlert = ErrorAlert(title: "意外斷線", message: "連線已中斷：\(error.localizedDescription)")
                }
    }

    // MARK: - CBPeripheralDelegate (搬移自 PartsBoxViewController)
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([commandCharacteristicUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == commandCharacteristicUUID {
                commandCharacteristic = characteristic
                print("已找到指令特徵！準備發送指令。")
            }
        }
    }
}
