/*
* ========================================================================== *
*                                                                            *
*    This file is part of the Openterface Mini KVM                           *
*                                                                            *
*    Copyright (C) 2024   <info@openterface.com>                             *
*                                                                            *
*    This program is free software: you can redistribute it and/or modify    *
*    it under the terms of the GNU General Public License as published by    *
*    the Free Software Foundation version 3.                                 *
*                                                                            *
*    This program is distributed in the hope that it will be useful, but     *
*    WITHOUT ANY WARRANTY; without even the implied warranty of              *
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU        *
*    General Public License for more details.                                *
*                                                                            *
*    You should have received a copy of the GNU General Public License       *
*    along with this program. If not, see <http://www.gnu.org/licenses/>.    *
*                                                                            *
* ========================================================================== *
*/

import SwiftUI

// 窗口工具类，提供窗口相关的通用功能
final class WindowUtils {
    // 单例模式
    static let shared = WindowUtils()
    
    private init() {}
    
    /// 显示屏幕比例选择器窗口
    /// - Parameter completion: 选择完成后的回调，传入是否需要更新窗口
    func showAspectRatioSelector(completion: @escaping (Bool) -> Void) {
        guard let window = NSApplication.shared.mainWindow else {
            completion(false)
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Select Aspect Ratio"
        alert.informativeText = "Please select your preferred aspect ratio:"
        
        // Create vertical stack view container
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 65))
        
        // Add aspect ratio dropdown menu
        let aspectRatioPopup = NSPopUpButton(frame: NSRect(x: 0, y: 30, width: 200, height: 25))
        
        // Add all preset ratio options
        for option in AspectRatioOption.allCases {
            aspectRatioPopup.addItem(withTitle: option.rawValue)
        }
        
        // Set currently selected ratio
        if let index = AspectRatioOption.allCases.firstIndex(of: UserSettings.shared.customAspectRatio) {
            aspectRatioPopup.selectItem(at: index)
        }
        
        // Add checkbox for HID resolution change alerts
        let showHidAlertCheckbox = NSButton(checkboxWithTitle: "Show HID resolution change alerts", target: nil, action: nil)
        showHidAlertCheckbox.state = UserSettings.shared.doNotShowHidResolutionAlert ? .off : .on
        showHidAlertCheckbox.frame = NSRect(x: 0, y: 0, width: 200, height: 20)
        
        // Add controls to container view
        containerView.addSubview(aspectRatioPopup)
        containerView.addSubview(showHidAlertCheckbox)
        
        alert.accessoryView = containerView
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let selectedIndex = aspectRatioPopup.indexOfSelectedItem
            if selectedIndex >= 0 && selectedIndex < AspectRatioOption.allCases.count {
                // Save user's aspect ratio selection
                UserSettings.shared.customAspectRatio = AspectRatioOption.allCases[selectedIndex]
                UserSettings.shared.useCustomAspectRatio = true
                
                // Save user's choice for HID resolution change alerts
                UserSettings.shared.doNotShowHidResolutionAlert = (showHidAlertCheckbox.state == .off)
                
                // Log settings changes
                Logger.shared.log(content: "User selected aspect ratio: \(UserSettings.shared.customAspectRatio.rawValue)")
                Logger.shared.log(content: "User \(UserSettings.shared.doNotShowHidResolutionAlert ? "disabled" : "enabled") HID resolution change alerts")
                
                // Notify caller to update window size
                completion(true)
            } else {
                completion(false)
            }
        } else {
            completion(false)
        }
    }
    
    /// 直接调用系统通知更新窗口大小
    func updateWindowSizeThroughNotification() {
        NotificationCenter.default.post(name: Notification.Name.updateWindowSize, object: nil)
    }
    
    /// 显示HID分辨率变化提示设置对话框
    /// - Parameter completion: 设置完成后的回调
    func showHidResolutionAlertSettings(completion: @escaping () -> Void = {}) {
        let alert = NSAlert()
        alert.messageText = "HID Resolution Change Alert Settings"
        alert.informativeText = "Do you want to show alerts when HID resolution changes?"
        
        // Add checkbox
        let showAlertCheckbox = NSButton(checkboxWithTitle: "Show HID resolution change alerts", target: nil, action: nil)
        // Set checkbox state based on current settings
        showAlertCheckbox.state = UserSettings.shared.doNotShowHidResolutionAlert ? .off : .on
        alert.accessoryView = showAlertCheckbox
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Save user choice
            UserSettings.shared.doNotShowHidResolutionAlert = (showAlertCheckbox.state == .off)
            
            // Log settings change
            Logger.shared.log(content: "User \(UserSettings.shared.doNotShowHidResolutionAlert ? "disabled" : "enabled") HID resolution change alerts")
            
            completion()
        }
    }
}

// 扩展通知名称，便于全局访问
extension Notification.Name {
    static let updateWindowSize = Notification.Name("UpdateWindowSizeNotification")
} 
