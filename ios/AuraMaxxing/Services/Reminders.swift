import UserNotifications

/// Notifications locales qui ramènent les joueurs : thème du jour, série en danger, fin de saison.
/// Aucune infrastructure push nécessaire.
enum Reminders {

    static func requestAndSchedule() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            schedule(center)
        }
    }

    private static func schedule(_ center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: ["daily-theme", "streak", "season-end"])

        add(center, id: "daily-theme",
            title: "Le thème du jour est tombé ⚡",
            body: "+25 % de points si ta vidéo colle au thème. Tu fais quoi ?",
            components: DateComponents(hour: 17, minute: 30))

        add(center, id: "streak",
            title: "Ta série 🔥 est en danger",
            body: "Poste une vidéo avant minuit pour garder ton bonus de série.",
            components: DateComponents(hour: 21, minute: 0))

        // Dimanche (weekday 1) : dernières heures de la saison.
        add(center, id: "season-end",
            title: "Dernières heures de la saison 👑",
            body: "Le classement se fige à minuit. Une dernière vidéo pour monter ?",
            components: DateComponents(hour: 18, minute: 0, weekday: 1))
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, title: String, body: String, components: DateComponents) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
