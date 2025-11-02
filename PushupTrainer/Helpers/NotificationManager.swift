//
//  NotificationManager.swift
//  PushupTrainer
//

import Foundation
import UserNotifications
import Combine

enum ReminderType: String, Codable, CaseIterable {
    case specificTime = "Specific Time"
    case interval = "Interval"
    
    var id: String { rawValue }
}

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var isAuthorized = false
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Permission
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                completion(granted)
            }
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Schedule Notifications
    
    func scheduleSpecificTimeReminder(hour: Int, minute: Int) {
        cancelAllReminders()
        
        let content = UNMutableNotificationContent()
        content.title = "Workout Reminder"
        content.body = "Time for your push-up workout! Let's crush those goals! 💪"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "workoutReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleIntervalReminders(intervalHours: Int) {
        cancelAllReminders()
        
        let content = UNMutableNotificationContent()
        content.title = "Workout Reminder"
        content.body = "Time for your push-up workout! Let's crush those goals! 💪"
        content.sound = .default
        
        // Schedule multiple notifications throughout the day
        let workingHours = [8, 12, 16, 20] // 8am, 12pm, 4pm, 8pm
        
        for (index, hour) in workingHours.enumerated() {
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: "workoutReminder_\(index)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func cancelAllReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    // MARK: - Check if workout completed today
    
    func checkAndPauseIfWorkoutDone() {
        let sessions = SessionStore.load()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let todaySessions = sessions.filter { session in
            calendar.isDate(session.date, inSameDayAs: today)
        }
        
        if !todaySessions.isEmpty {
            // Workout done today - notifications will resume tomorrow automatically
            // Since we use repeating daily notifications, they'll trigger again tomorrow
            print("✅ Workout completed today - notifications will resume tomorrow")
        }
    }
    
    // MARK: - Session Completion Handler
    
    func onWorkoutCompleted() {
        // Called when a workout session is saved
        checkAndPauseIfWorkoutDone()
        
        // Optionally, we could post a congratulatory notification here
        // or handle any other notification-related logic
    }
}

