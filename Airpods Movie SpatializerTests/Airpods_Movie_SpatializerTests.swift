//
//  Airpods_Movie_SpatializerTests.swift
//  Airpods Movie SpatializerTests
//
//  Created by Vlad on 14.07.2026.
//

import Testing
import SwiftUI
@testable import Airpods_Movie_Spatializer

struct Airpods_Movie_SpatializerTests {

    @Test func testAppThemes() {
        #expect(AppTheme.system.rawValue == "system")
        #expect(AppTheme.light.rawValue == "light")
        #expect(AppTheme.dark.rawValue == "dark")

        #expect(AppTheme.system.colorScheme == nil)
        #expect(AppTheme.light.colorScheme == .light)
        #expect(AppTheme.dark.colorScheme == .dark)

        #expect(AppTheme.system.icon == "circle.righthalf.filled")
        #expect(AppTheme.light.icon == "sun.max.fill")
        #expect(AppTheme.dark.icon == "moon.fill")
    }

    @Test func testThemeSettingPersistence() {
        let settings = AppSettings.shared
        let originalTheme = settings.appTheme

        settings.appTheme = .dark
        #expect(settings.appTheme == .dark)
        #expect(UserDefaults.standard.string(forKey: "appTheme") == "dark")

        settings.appTheme = .light
        #expect(settings.appTheme == .light)
        #expect(UserDefaults.standard.string(forKey: "appTheme") == "light")

        settings.appTheme = originalTheme
    }

    @Test func testFFprobeNotFoundErrorMessage() {
        let error = FFmpegError.ffprobeNotFound
        #expect(error.errorDescription?.contains("ffprobe") == true)
    }
}
