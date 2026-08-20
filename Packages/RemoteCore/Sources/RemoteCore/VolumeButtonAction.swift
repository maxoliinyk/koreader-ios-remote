//
//  VolumeButtonAction.swift
//  RemoteCore
//
//  Created by Max Oliinyk on 20.08.26.
//

public enum VolumeButtonAction {
    public static func remoteAction(
        from oldValue: Float,
        to newValue: Float,
        ignoring expectedValue: Float? = nil,
        tolerance: Float = 0.01
    ) -> RemoteAction? {
        if let expectedValue, abs(newValue - expectedValue) < tolerance {
            return nil
        }
        guard abs(newValue - oldValue) >= tolerance else { return nil }
        return newValue > oldValue ? .nextPage : .previousPage
    }
}
