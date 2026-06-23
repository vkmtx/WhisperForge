//
//  FocusUtils.swift
//  WhisperForge
//
//  Created by user on 07.02.2025.
//

import AppKit
import ApplicationServices
import Carbon
import Cocoa
import Foundation
import KeyboardShortcuts
import SwiftUI

class FocusUtils {
    
    static func getCurrentCursorPosition() -> NSPoint {
        return NSEvent.mouseLocation
    }
    
    static func getCaretRect() -> CGRect? {
        // Get the system-wide element to access the whole UI
        let systemElement = AXUIElementCreateSystemWide()
        
        // Get the focused element
        var focusedElement: CFTypeRef? // Keep as CFTypeRef? if you prefer
        let errorFocused = AXUIElementCopyAttributeValue(systemElement,
                                                         kAXFocusedUIElementAttribute as CFString,
                                                         &focusedElement)
        
        Log.debug("errorFocused: \(errorFocused)")
        guard errorFocused == .success else {
            Log.debug("Failed to get the focused element")
            return nil
        }
        
        guard let focusedElementCF = focusedElement else { // Optional binding to safely unwrap CFTypeRef
            Log.debug("Failed to get the focused element (CFTypeRef is nil)") // Extra safety check, though unlikely
            return nil
        }
        
        let element = focusedElementCF as! AXUIElement
        // Get the selected text range of the focused element
        var selectedTextRange: AnyObject?
        let errorRange = AXUIElementCopyAttributeValue(element,
                                                       kAXSelectedTextRangeAttribute as CFString,
                                                       &selectedTextRange)
        guard errorRange == .success,
              let textRange = selectedTextRange
        else {
            Log.debug("Failed to get the selected text range")
            return nil
        }
        
        // Use the parameterized attribute to get the range bounds (caret position)
        var caretBounds: CFTypeRef?
        let errorBounds = AXUIElementCopyParameterizedAttributeValue(element,
                                                                     kAXBoundsForRangeParameterizedAttribute as CFString,
                                                                     textRange,
                                                                     &caretBounds)
        
        Log.debug("errorbounds: \(errorBounds), caretBounds \(String(describing: caretBounds))")
        guard errorBounds == .success else {
            Log.debug("Failed to get the caret bounds")
            return nil
        }
        
        let rect = caretBounds as! AXValue
        
        return rect.toCGRect()
    }
    
    /// Converts a point from AX API coordinate system (Quartz: origin at top-left of primary screen, Y increases downward)
    /// to Cocoa coordinate system (origin at bottom-left of primary screen, Y increases upward)
    static func convertAXPointToCocoa(_ axPoint: CGPoint) -> NSPoint {
        guard let primaryScreen = NSScreen.screens.first else {
            return NSPoint(x: axPoint.x, y: axPoint.y)
        }
        // Primary screen maxY represents the total height in Cocoa coordinates
        // AX Y=0 is at Cocoa Y=maxY, so we subtract axPoint.y from maxY
        let cocoaY = primaryScreen.frame.maxY - axPoint.y
        return NSPoint(x: axPoint.x, y: cocoaY)
    }
    
    /// Finds the screen that contains the given point (in Cocoa coordinates)
    static func screenContaining(point: NSPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main
    }
    
}

private extension AXValue {
    func toCGRect() -> CGRect? {
        var rect = CGRect.zero
        let type: AXValueType = AXValueGetType(self)
        
        guard type == .cgRect else {
            Log.debug("AXValue is not of type CGRect, but \(type)") // More informative error
            return nil
        }
        
        let success = AXValueGetValue(self, .cgRect, &rect)
        
        guard success else {
            Log.debug("Failed to get CGRect value from AXValue")
            return nil
        }
        return rect
    }
}
