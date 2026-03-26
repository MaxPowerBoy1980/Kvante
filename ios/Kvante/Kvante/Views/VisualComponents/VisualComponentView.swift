import SwiftUI

/// Routes a VisualInstruction to the correct visual component.
/// Falls back to plain text for unknown types.
struct VisualComponentView: View {
    let visual: VisualInstruction
    let animate: Bool
    let cumulativeObjects: Int
    let cumulativeCrossedOut: Int
    let cumulativeRows: Int
    let cumulativeGrouped: Int

    init(visual: VisualInstruction, animate: Bool,
         cumulativeObjects: Int = 0, cumulativeCrossedOut: Int = 0,
         cumulativeRows: Int = 2, cumulativeGrouped: Int = 0) {
        self.visual = visual
        self.animate = animate
        self.cumulativeObjects = cumulativeObjects
        self.cumulativeCrossedOut = cumulativeCrossedOut
        self.cumulativeRows = cumulativeRows
        self.cumulativeGrouped = cumulativeGrouped
    }

    var body: some View {
        switch visual.type {
        case "equation":
            EquationVisualView(visual: visual, animate: animate)
        case "object_collection":
            ObjectCollectionVisualView(
                visual: visual, animate: animate,
                cumulativeObjects: cumulativeObjects,
                cumulativeCrossedOut: cumulativeCrossedOut,
                cumulativeRows: cumulativeRows
            )
        case "number_line":
            NumberLineVisualView(visual: visual, animate: animate)
        case "array_grid":
            ArrayGridVisualView(visual: visual, animate: animate)
        case "grouping":
            GroupingVisualView(visual: visual, animate: animate, cumulativeGrouped: cumulativeGrouped)
        case "pie_chart":
            PieChartVisualView(visual: visual, animate: animate)
        case "bar_model":
            BarModelVisualView(visual: visual, animate: animate)
        case "coordinate_grid":
            CoordinateGridVisualView(visual: visual, animate: animate)
        default:
            // Fallback: unknown visual type — show nothing (text is shown by parent)
            EmptyView()
        }
    }
}
