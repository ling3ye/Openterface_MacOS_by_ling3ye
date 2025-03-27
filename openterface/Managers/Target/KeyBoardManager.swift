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

import Cocoa
import Carbon.HIToolbox


class KeyboardManager {
    static let SHIFT_KEYS = ["~", "!", "@", "#", "$", "%", "^", "&", "*", "(", ")", "_", "+", "{", "}", "|", ":", "\"", "<", ">", "?"]
    static let shared = KeyboardManager()

    var escKeyDownCounts = 0
    var escKeyDownTimeStart = 0.0
    
    let kbm = KeyboardMapper()
    
    // 新增一个数组用于存储同时按下的键
    var pressedKeys: [UInt16] = [255,255,255,255,255,255]
    
    init() {
        monitorKeyboardEvents()
    }
    
    func modifierFlagsDescription(_ flags: NSEvent.ModifierFlags) -> String {
        var descriptions: [String] = []
        
        if flags.contains(.control) {
            descriptions.append("Ctrl")
        }
        if flags.contains(.option) {
            descriptions.append("Alt")
        }
        if flags.contains(.command) {
            descriptions.append("Cmd")
        }
        if flags.contains(.shift) {
            descriptions.append("Shift")
        }
        if flags.contains(.capsLock) {
            descriptions.append("CapsLock")
        }
        return descriptions.isEmpty ? "None" : descriptions.joined(separator: ", ")
    }

    
    func pressKey(keys: [UInt16], modifiers: NSEvent.ModifierFlags) {
        kbm.pressKey(keys: keys, modifiers: modifiers)
    }

    func releaseKey(keys: [UInt16]) {
        kbm.releaseKey(keys: self.pressedKeys)
    }

    func monitorKeyboardEvents() {
        // 用于跟踪当前按下的修饰键
        var currentModifiers: NSEvent.ModifierFlags = []
        
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { event in
            // 检查是否有任何修饰键状态变化
            let modifiers = event.modifierFlags
            let modifierDescription = self.modifierFlagsDescription(modifiers)
            Logger.shared.log(content: "Modifier flags changed: \(modifierDescription), CapsLock toggle: \(modifiers.contains(.capsLock))")
            
            // 只在控制模式下处理修饰键
            if AppStatus.isControlling {
                // 更新当前的修饰键状态
                currentModifiers = modifiers
                
                // 如果有非修饰键在pressedKeys中，则使用新的修饰键状态更新它们
                let nonModifierKeysPressed = self.pressedKeys.contains { $0 != 255 && 
                    $0 != UInt16(kVK_Shift) && 
                    $0 != UInt16(kVK_RightShift) && 
                    $0 != UInt16(kVK_Control) && 
                    $0 != UInt16(kVK_RightControl) && 
                    $0 != UInt16(kVK_Option) && 
                    $0 != UInt16(kVK_RightOption) && 
                    $0 != UInt16(kVK_Command) && 
                    $0 != UInt16(kVK_RightCommand) && 
                    $0 != UInt16(kVK_CapsLock) }
                
                if nonModifierKeysPressed {
                    // 发送带有更新后修饰键状态的非修饰键
                    self.kbm.pressKey(keys: self.pressedKeys, modifiers: modifiers)
                }
                
                // 专门处理CapsLock键，因为它是一个切换键
                if modifiers.contains(.capsLock) && !currentModifiers.contains(.capsLock) {
                    self.kbm.pressKey(keys: [UInt16(kVK_CapsLock)], modifiers: [])
                    Thread.sleep(forTimeInterval: 0.01)
                    self.kbm.releaseKey(keys: [UInt16(kVK_CapsLock)])
                }
            }
            
            return nil
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            let modifiers = event.modifierFlags
            let modifierDescription = self.modifierFlagsDescription(modifiers)
            
            // Log the key press with its keycode
            Logger.shared.log(content: "Key pressed: keyCode=\(event.keyCode), modifiers=\(modifierDescription)")
            
            if event.keyCode == UInt16(kVK_Escape) {
                for w in NSApplication.shared.windows.filter({ $0.title == "Area Selector".local }) {
                    w.close()
                    AppStatus.isAreaOCRing = false
                }
                
                if self.escKeyDownCounts == 0 {
                    self.escKeyDownTimeStart = event.timestamp
                    self.escKeyDownCounts = self.escKeyDownCounts + 1
                }
                else
                {
                    if self.escKeyDownCounts >= 2 {
                        if event.timestamp - self.escKeyDownTimeStart < 2 {

                            AppStatus.isExit = true
                            
                        }
                        self.escKeyDownCounts = 0
                    }
                    else {
                        if event.timestamp - self.escKeyDownTimeStart < 2 {
                            self.escKeyDownCounts = self.escKeyDownCounts + 1
                        }
                        else {
                            self.escKeyDownCounts = 1
                            self.escKeyDownTimeStart = event.timestamp
                        }
                    }
                }
                return event
            }
            
            if AppStatus.isControlling {
                // 检查按下的键是否是修饰键
                let isModifierKey = 
                    event.keyCode == UInt16(kVK_Shift) ||
                    event.keyCode == UInt16(kVK_RightShift) ||
                    event.keyCode == UInt16(kVK_Control) ||
                    event.keyCode == UInt16(kVK_RightControl) ||
                    event.keyCode == UInt16(kVK_Option) ||
                    event.keyCode == UInt16(kVK_RightOption) ||
                    event.keyCode == UInt16(kVK_Command) ||
                    event.keyCode == UInt16(kVK_RightCommand) ||
                    event.keyCode == UInt16(kVK_CapsLock)
                
                // 如果不是修饰键，则添加到pressedKeys并发送
                if !isModifierKey {
                    // 首先从pressedKeys中移除可能存在的修饰键
                    for i in 0..<self.pressedKeys.count {
                        let key = self.pressedKeys[i]
                        let keyIsModifier = 
                            key == UInt16(kVK_Shift) ||
                            key == UInt16(kVK_RightShift) ||
                            key == UInt16(kVK_Control) ||
                            key == UInt16(kVK_RightControl) ||
                            key == UInt16(kVK_Option) ||
                            key == UInt16(kVK_RightOption) ||
                            key == UInt16(kVK_Command) ||
                            key == UInt16(kVK_RightCommand) ||
                            key == UInt16(kVK_CapsLock)
                        
                        if keyIsModifier {
                            self.pressedKeys[i] = 255
                        }
                    }
                    
                    // 然后添加新按下的键
                    if let index = self.pressedKeys.firstIndex(of: 255) {
                        self.pressedKeys[index] = event.keyCode
                        self.kbm.pressKey(keys: self.pressedKeys, modifiers: modifiers)
                    }
                }
            }
            
            // 只有在键盘模式下才会截住
            if AppStatus.isKeyboardMode {
                return nil
            }

            return event
        }
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyUp]) { event in
            
            // 处理键盘的keyup
            if AppStatus.isControlling {
                // 检查释放的键是否是修饰键
                let isModifierKey = 
                    event.keyCode == UInt16(kVK_Shift) ||
                    event.keyCode == UInt16(kVK_RightShift) ||
                    event.keyCode == UInt16(kVK_Control) ||
                    event.keyCode == UInt16(kVK_RightControl) ||
                    event.keyCode == UInt16(kVK_Option) ||
                    event.keyCode == UInt16(kVK_RightOption) ||
                    event.keyCode == UInt16(kVK_Command) ||
                    event.keyCode == UInt16(kVK_RightCommand) ||
                    event.keyCode == UInt16(kVK_CapsLock)
                
                // 如果不是修饰键，才处理键释放
                if !isModifierKey {
                    // 当一个键被释放时找到这个键，然后释放它
                    if let index = self.pressedKeys.firstIndex(of: event.keyCode) {
                        self.pressedKeys[index] = 255
                        self.kbm.releaseKey(keys: self.pressedKeys)
                    }
                }
            }
            
            // 只有在键盘模式下才会截住
            if AppStatus.isKeyboardMode {
                return nil
            }
            
            return event
        }
    }
    
    func needShiftWhenPaste(char:Character) -> Bool {
        return char.isUppercase || KeyboardManager.SHIFT_KEYS.contains(String(char))
    }
    
    func sendTextToKeyboard(text:String) {
        // sent the text to keyboard
        let textArray = Array(text.utf8)
        for charString in textArray {
            let key:UInt16 = UInt16(kbm.fromCharToKeyCode(char: UInt16(charString)))
            let char = Character(String(UnicodeScalar(charString)))
            let modifiers: NSEvent.ModifierFlags = needShiftWhenPaste(char: char) ? [.shift] : []
            kbm.pressKey(keys: [key], modifiers: modifiers)
            Thread.sleep(forTimeInterval: 0.005) // 1 ms
            kbm.releaseKey(keys: self.pressedKeys)
            Thread.sleep(forTimeInterval: 0.01) // 5 ms
        }
    }


    func sendSpecialKeyToKeyboard(code: KeyboardMapper.SpecialKey) {
        if code == KeyboardMapper.SpecialKey.CtrlAltDel {
            if let key = kbm.fromSpecialKeyToKeyCode(code: code) {
                kbm.pressKey(keys: [key], modifiers: [.option, .control])
                Thread.sleep(forTimeInterval: 0.005) // 1 ms
                kbm.releaseKey(keys: self.pressedKeys)
                Thread.sleep(forTimeInterval: 0.01) // 5 ms
            }
        }else{
            if let key = kbm.fromSpecialKeyToKeyCode(code: code) {
                kbm.pressKey(keys: [key], modifiers: [])
                Thread.sleep(forTimeInterval: 0.005) // 1 ms
                kbm.releaseKey(keys: self.pressedKeys)
                Thread.sleep(forTimeInterval: 0.01) // 5 ms
            }
        }
    }
}
