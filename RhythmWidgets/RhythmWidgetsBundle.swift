import WidgetKit
import SwiftUI

@main
struct RhythmWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        RitualsWidget()
        BalanceWidget()
        CalendarIntegrityWidget()
        LockScreenWidget()
    }
}
